// RadarView — the fleet's-eye view. A phosphor PPI radar scope that
// plots every contact every online post currently hears. Range rings
// are RSSI bands (centre = right on top of a post, rim = barely
// audible); each blip is a BLE contact placed by `FleetRadar`
// geometry. Below the scope, a compact roster of the posts feeding
// the picture.
//
// Read-only: this view shows what the fleet reports. It issues no
// commands to any post.

import SwiftUI
import Combine
import SlothCore

struct RadarView: View {

    @Environment(FleetCoordinator.self) private var fleet
    @State private var now = Int(Date().timeIntervalSince1970)
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height * 0.62)
            VStack(spacing: 12) {
                RadarScope(blips: fleet.fleet.fleetBlips(now: now), side: side)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity)
                PostRoster(fleet: fleet.fleet, now: now)
            }
            .padding()
        }
        .navigationTitle("Radar")
        .onReceive(tick) { date in now = Int(date.timeIntervalSince1970) }
        .onAppear { fleet.start() }
    }
}

private struct RadarScope: View {
    let blips: [RadarBlip]
    let side: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.phosphorDim, lineWidth: 1)
            Circle().stroke(Color.phosphorDim.opacity(0.6), lineWidth: 1)
                .scaleEffect(0.66)
            Circle().stroke(Color.phosphorDim.opacity(0.6), lineWidth: 1)
                .scaleEffect(0.33)
            // Cross hairs.
            Path { p in
                p.move(to: CGPoint(x: side/2, y: 0)); p.addLine(to: CGPoint(x: side/2, y: side))
                p.move(to: CGPoint(x: 0, y: side/2)); p.addLine(to: CGPoint(x: side, y: side/2))
            }.stroke(Color.phosphorDim.opacity(0.4), lineWidth: 1)

            ForEach(blips) { blip in
                Circle()
                    .fill(color(for: blip.rssi))
                    .frame(width: 8, height: 8)
                    .position(position(for: blip))
                    .accessibilityLabel(Text(label(for: blip)))
            }

            if blips.isEmpty {
                Text("no contacts")
                    .font(.caption)
                    .foregroundStyle(Color.phosphorDim)
            }
        }
    }

    private func position(for blip: RadarBlip) -> CGPoint {
        let r = side / 2
        return CGPoint(x: r + blip.x * r, y: r - blip.y * r)
    }

    private func label(for blip: RadarBlip) -> String {
        if let d = blip.distanceM {
            return String(format: "contact %d dBm, about %.1f metres", blip.rssi, d)
        }
        return "contact \(blip.rssi) dBm"
    }

    private func color(for rssi: Int) -> Color {
        switch rssi {
        case ..<(-85): return .heatLo
        case ..<(-70): return .phosphorTeal
        case ..<(-55): return .phosphorBright
        default:       return .alertHotWarn   // very close
        }
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
