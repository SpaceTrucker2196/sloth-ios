// RadarView — the fleet's-eye view. A Metal PPI radar scope that
// plots every contact every online post currently hears. The radial
// axis is estimated distance in metres (from BLE RSSI), so the range
// rings carry metre labels; pinch to change how far the rim reaches.
// Bearing labels mark N/E/S/W. Below the scope, a compact roster of
// the posts feeding the picture.
//
// Read-only: this view shows what the fleet reports. It issues no
// commands to any post.

import SwiftUI
import Combine
import SlothCore

struct RadarView: View {

    @Environment(FleetCoordinator.self) private var fleet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Int(Date().timeIntervalSince1970)
    @State private var maxRange: Double = 30          // metres the rim reaches
    @GestureState private var pinch: CGFloat = 1
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var effectiveRange: Double {
        min(max(maxRange / Double(pinch), 5), 300)
    }

    private func addr(of blipID: String) -> String {
        blipID.split(separator: "/").last.map(String.init) ?? blipID
    }

    /// Post positions (pale blue) and triangulated contacts (amber),
    /// converted from the fleet's metre grid to radar clip space.
    private func buildMarkers(_ g: FleetStore.FleetGeometry, range: Double) -> [RadarRenderer.Marker] {
        let postColor = SIMD4<Float>(0.75, 0.90, 1.0, 1.0)
        let locColor  = SIMD4<Float>(1.0, 0.53, 0.0, 1.0)
        var out: [RadarRenderer.Marker] = []
        for p in g.posts {
            let c = clip(p.x, p.y, range)
            out.append(.init(x: c.0, y: c.1, size: 15, color: postColor))
        }
        for contact in g.located {
            let c = clip(contact.x, contact.y, range)
            out.append(.init(x: c.0, y: c.1, size: 12, color: locColor))
        }
        return out
    }

    /// Metre offset → clip space, clamped to the rim.
    private func clip(_ x: Double, _ y: Double, _ range: Double) -> (Float, Float) {
        let r = max(1, range)
        var cx = x / r, cy = y / r
        let mag = (cx*cx + cy*cy).squareRoot()
        if mag > 1 { cx /= mag; cy /= mag }
        return (Float(cx), Float(cy))
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height * 0.62)
            let fg = fleet.fleet.fleetGeometry(now: now)
            // Located contacts are drawn as markers at their real
            // position, so drop their ambiguous ranged blips.
            let blips = fleet.fleet.fleetBlips(now: now)
                .filter { !fg.locatedAddrs.contains(addr(of: $0.id)) }
            let markers = buildMarkers(fg, range: effectiveRange)
            VStack(spacing: 12) {
                ZStack {
                    MetalRadarView(blips: blips, reduceMotion: reduceMotion,
                                   maxRangeMeters: effectiveRange, markers: markers)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.phosphorDim, lineWidth: 1))
                    ScopeLabels(range: effectiveRange, side: side)
                    if blips.isEmpty {
                        Text("no contacts")
                            .font(.caption)
                            .foregroundStyle(Color.phosphorDim)
                    }
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            maxRange = min(max(maxRange / Double(value), 5), 300)
                        }
                )
                PostRoster(fleet: fleet.fleet, now: now)
            }
            .padding()
        }
        .navigationTitle("Radar")
        .onReceive(tick) { date in now = Int(date.timeIntervalSince1970) }
        .onAppear { fleet.start() }
    }
}

/// Bearing + range labels drawn over the Metal scope. Text is cheaper
/// and crisper in SwiftUI than in the shader, and it never rotates
/// with the sweep.
private struct ScopeLabels: View {
    let range: Double      // metres at the rim
    let side: CGFloat

    var body: some View {
        let c = side / 2
        let r = side / 2
        ZStack {
            bearing("N", CGPoint(x: c, y: 10))
            bearing("S", CGPoint(x: c, y: side - 10))
            bearing("E", CGPoint(x: side - 12, y: c))
            bearing("W", CGPoint(x: 12, y: c))
            ForEach([1.0/3.0, 2.0/3.0, 1.0], id: \.self) { frac in
                Text(rangeLabel(range * frac))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.phosphorDim)
                    .position(x: c + 18, y: c - CGFloat(frac) * r + 7)
            }
        }
        .allowsHitTesting(false)
    }

    private func bearing(_ s: String, _ p: CGPoint) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.phosphorTeal)
            .position(p)
    }

    private func rangeLabel(_ m: Double) -> String {
        m < 10 ? String(format: "%.1fm", m) : String(format: "%.0fm", m)
    }
}

private struct PostRoster: View {
    let fleet: FleetStore
    let now: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("POSTS")
                .font(.caption2).foregroundStyle(Color.phosphorDim)
            if fleet.roster.isEmpty {
                Text("searching for sloth posts…")
                    .font(.caption).foregroundStyle(Color.phosphorDim)
            }
            ForEach(fleet.roster) { post in
                HStack(spacing: 8) {
                    Circle()
                        .fill(fleet.isOnline(post, now: now) ? Color.phosphorBright : Color.phosphorDim)
                        .frame(width: 7, height: 7)
                    Text(post.name).font(.caption)
                    Spacer()
                    Text("\(post.orderedContacts.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.phosphorTeal)
                    if let d = nearest(post) {
                        Text(String(format: "~%.1fm", d))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.phosphorBright)
                    }
                    if let h = post.headingDeg {
                        Text("\(Int(h))°").font(.caption2).foregroundStyle(Color.phosphorDim)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nearest(_ post: FleetPost) -> Double? {
        post.orderedContacts
            .compactMap { FleetRadar.approxDistanceMeters(rssi: $0.rssi) }
            .min()
    }
}
