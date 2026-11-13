// MetalRadarView — SwiftUI bridge to the Metal `RadarRenderer`. Wraps
// an `MTKView` and feeds it the current fleet blips every update. The
// view is square (RadarView frames it), so radar space maps straight
// to clip space.

import SwiftUI
import MetalKit
import SlothCore

struct MetalRadarView: UIViewRepresentable {
    let blips: [RadarBlip]
    let reduceMotion: Bool
    var maxRangeMeters: Double = 30
    var markers: [RadarRenderer.Marker] = []

    func makeCoordinator() -> RadarRenderer? {
        RadarRenderer(device: MTLCreateSystemDefaultDevice())
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.isOpaque = true
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 30
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator else { return }
        renderer.blips = blips
        renderer.reduceMotion = reduceMotion
        renderer.maxRangeMeters = maxRangeMeters
        renderer.markers = markers
        if view.delegate == nil { view.delegate = renderer }
        // When motion is off, stop the frame clock and draw one still.
        view.isPaused = reduceMotion
        view.enableSetNeedsDisplay = reduceMotion
        if reduceMotion { view.setNeedsDisplay() }
    }
}
