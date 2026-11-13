// RadarRenderer — Metal PPI scope for the fleet radar, modelled on
// slothweb's radar view but drawn on the device GPU.
//
// It paints, north-up:
//   * concentric range rings + bearing cross-hairs (phosphor dim)
//   * a sweeping line that rotates with time (reduce-motion stops it)
//   * one point per contact, placed by `RadarBlip` polar geometry
//     (range from RSSI, angle from id/bearing), heat-coloured by RSSI
//
// The view frames itself square, so radar space is clip space: a blip
// at range 1 sits on the unit circle at the rim. Vertex buffers are
// rebuilt each frame from `blips`; contact counts are small (hundreds)
// so the per-frame cost is trivial.
//
// MTKView drives `draw(in:)` on the main run loop, so the delegate
// methods assume the main actor.

import Foundation
import MetalKit
import simd
import SlothCore

@MainActor
final class RadarRenderer: NSObject {

    /// Contacts to plot. Set from SwiftUI; read on the next frame.
    var blips: [RadarBlip] = []
    /// Radians the sweep has advanced. Driven by the frame clock.
    private var sweep: Double = 0
    /// When true the sweep holds still (accessibility reduce-motion).
    var reduceMotion = false
    /// Zoom factor: 1 shows range 0…1 to the rim; >1 magnifies.
    var zoom: Float = 1

    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private var pointPipeline: (any MTLRenderPipelineState)!
    private var linePipeline: (any MTLRenderPipelineState)!
    private var lastFrame = CFAbsoluteTimeGetCurrent()

    init?(device: (any MTLDevice)?) {
        guard let device, let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        super.init()
        do { try buildPipelines() } catch { return nil }
    }

    // MARK: - Pipelines

    private func buildPipelines() throws {
        let lib = try device.makeLibrary(source: Self.shaderSource, options: nil)
        let point = MTLRenderPipelineDescriptor()
        point.vertexFunction = lib.makeFunction(name: "v_main")
        point.fragmentFunction = lib.makeFunction(name: "f_point")
        configureColor(point.colorAttachments[0])
        pointPipeline = try device.makeRenderPipelineState(descriptor: point)

        let line = MTLRenderPipelineDescriptor()
        line.vertexFunction = lib.makeFunction(name: "v_main")
        line.fragmentFunction = lib.makeFunction(name: "f_line")
        configureColor(line.colorAttachments[0])
        linePipeline = try device.makeRenderPipelineState(descriptor: line)
    }

    private func configureColor(_ a: MTLRenderPipelineColorAttachmentDescriptor?) {
        guard let a else { return }
        a.pixelFormat = .bgra8Unorm
        a.isBlendingEnabled = true
        a.rgbBlendOperation = .add
        a.alphaBlendOperation = .add
        a.sourceRGBBlendFactor = .sourceAlpha
        a.sourceAlphaBlendFactor = .sourceAlpha
        a.destinationRGBBlendFactor = .oneMinusSourceAlpha
        a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }

    // MARK: - Geometry builders

    private struct Vertex { var pos: SIMD2<Float>; var psize: Float; var color: SIMD4<Float> }

    private static let ringDim = SIMD4<Float>(0.0, 0.33, 0.23, 0.9)   // phosphorDim
    private static let sweepCol = SIMD4<Float>(0.0, 1.0, 0.685, 0.5)  // phosphorBright, soft

    private func lineVertices() -> [Vertex] {
        var v: [Vertex] = []
        // Three range rings as segmented loops.
        for r in [Float(0.33), 0.66, 1.0] {
            let seg = 72
            for i in 0..<seg {
                let a0 = Float(i)   / Float(seg) * 2 * .pi
                let a1 = Float(i+1) / Float(seg) * 2 * .pi
                v.append(Vertex(pos: SIMD2(cos(a0)*r, sin(a0)*r), psize: 1, color: Self.ringDim))
                v.append(Vertex(pos: SIMD2(cos(a1)*r, sin(a1)*r), psize: 1, color: Self.ringDim))
            }
        }
        // Cross-hairs.
        for (a, b) in [(SIMD2<Float>(0,-1), SIMD2<Float>(0,1)),
                       (SIMD2<Float>(-1,0), SIMD2<Float>(1,0))] {
            v.append(Vertex(pos: a, psize: 1, color: Self.ringDim))
            v.append(Vertex(pos: b, psize: 1, color: Self.ringDim))
        }
        // Sweep line from centre to rim at the current angle.
        let sa = Float(sweep)
        v.append(Vertex(pos: SIMD2(0,0), psize: 1, color: Self.sweepCol))
        v.append(Vertex(pos: SIMD2(sin(sa), cos(sa)), psize: 1, color: Self.sweepCol))
        return v
    }

    private func pointVertices() -> [Vertex] {
        blips.map { b in
            Vertex(pos: SIMD2(Float(b.x), Float(b.y)),
                   psize: pointSize(for: b.rssi),
                   color: color(for: b.rssi))
        }
    }

    private func pointSize(for rssi: Int) -> Float {
        switch rssi {
        case ..<(-85): return 7
        case ..<(-70): return 9
        case ..<(-55): return 12
        default:       return 15
        }
    }

    private func color(for rssi: Int) -> SIMD4<Float> {
        switch rssi {
        case ..<(-85): return SIMD4(0.38, 0.38, 0.38, 1)      // heatLo grey
        case ..<(-70): return SIMD4(0.0, 0.843, 0.685, 1)     // phosphorTeal
        case ..<(-55): return SIMD4(0.0, 1.0, 0.685, 1)       // phosphorBright
        default:       return SIMD4(1.0, 0.529, 0.0, 1)       // amber, very close
        }
    }
}

// MARK: - MTKViewDelegate

extension RadarRenderer: MTKViewDelegate {

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated { renderFrame(view) }
    }

    private func renderFrame(_ view: MTKView) {
        let now = CFAbsoluteTimeGetCurrent()
        let dt = now - lastFrame
        lastFrame = now
        if !reduceMotion {
            sweep += dt * 1.4                   // ~0.22 rev/s
            if sweep > 2 * .pi { sweep -= 2 * .pi }
        }

        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }

        var scale = zoom
        let lines = lineVertices()
        let points = pointVertices()

        enc.setRenderPipelineState(linePipeline)
        if !lines.isEmpty {
            enc.setVertexBytes(lines, length: MemoryLayout<Vertex>.stride * lines.count, index: 0)
            enc.setVertexBytes(&scale, length: MemoryLayout<Float>.stride, index: 1)
            enc.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lines.count)
        }
        enc.setRenderPipelineState(pointPipeline)
        if !points.isEmpty {
            enc.setVertexBytes(points, length: MemoryLayout<Vertex>.stride * points.count, index: 0)
            enc.setVertexBytes(&scale, length: MemoryLayout<Float>.stride, index: 1)
            enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: points.count)
        }
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }
}

// MARK: - Shaders

extension RadarRenderer {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VIn  { float2 pos; float psize; float4 color; };
    struct VOut { float4 position [[position]]; float psize [[point_size]]; float4 color; };

    vertex VOut v_main(const device VIn* verts [[buffer(0)]],
                       constant float& scale    [[buffer(1)]],
                       uint vid                  [[vertex_id]]) {
        VOut o;
        float2 p = verts[vid].pos * scale;   // y is already up in radar space
        o.position = float4(p.x, p.y, 0.0, 1.0);
        o.psize = verts[vid].psize;
        o.color = verts[vid].color;
        return o;
    }

    fragment float4 f_line(VOut in [[stage_in]]) {
        return in.color;
    }

    fragment float4 f_point(VOut in [[stage_in]], float2 pc [[point_coord]]) {
        float d = distance(pc, float2(0.5, 0.5));
        if (d > 0.5) discard_fragment();
        float a = smoothstep(0.5, 0.15, d);   // soft phosphor dot
        return float4(in.color.rgb, in.color.a * a);
    }
    """
}
