// SkyView — the GNSS receiver's sky (#14): `gnss_sky`'s summary and one
// row per `gnss_sat`. A satellite that sets sends nothing; the store
// drops its row once its heartbeat lapses. Spec: docs/views/rf.md.

import SwiftUI
import SlothCore

/// The one-line summary RFView links from.
struct SkySummaryRow: View {
    @Environment(SlothStore.self) private var store
    var body: some View {
        HStack {
            Image(systemName: "globe.americas")
            Text("Sky")
            Spacer()
            Text(summary).foregroundStyle(.secondary)
        }
        .font(.callout.monospaced())
    }

    private var summary: String {
        let sky = store.gnssSky
        let used = sky?.usat ?? store.gnssSats.values.filter(\.isUsed).count
        let seen = sky?.nsat ?? store.gnssSats.count
        let cn0 = sky?.cn0Mean.map { String(format: " · %.0f dB-Hz", $0) } ?? ""
        return "\(used)/\(seen) used\(cn0)"
    }
}

struct SkyView: View {
    @Environment(SlothStore.self) private var store

    var body: some View {
        List {
            if let sky = store.gnssSky {
                Section("Pass") {
                    LabeledContent("Satellites", value: "\(sky.usat ?? 0) used of \(sky.nsat ?? 0)")
                    if let m = sky.cn0Mean {
                        LabeledContent("C/N0", value: String(format: "mean %.1f · max %.0f dB-Hz", m, sky.cn0Max ?? m))
                    }
                    LabeledContent("DOP", value: dops(sky))
                    if let o = sky.overflow, o > 0 {
                        Text("\(o) more listed than sloth keeps (48)").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Satellites · \(store.gnssSats.count)") {
                ForEach(RFRoster.satellites(store.gnssSats.values)) { SatRow(sat: $0) }
            }
        }
        .font(.callout)
        .navigationTitle("Sky")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dops(_ s: GNSSSkyEntry) -> String {
        let parts = [("H", s.hdop), ("V", s.vdop), ("P", s.pdop)]
            .compactMap { n, v in v.map { String(format: "%@ %.1f", n, $0) } }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

private struct SatRow: View {
    let sat: GNSSSatEntry

    var body: some View {
        HStack(spacing: 8) {
            // Shape as well as hue: filled = in the solution.
            Image(systemName: sat.isUsed ? "circle.fill" : "circle")
                .foregroundStyle(sat.isUsed ? Color.phosphorTeal : .secondary)
                .accessibilityLabel(sat.isUsed ? "used" : "not used")
            VStack(alignment: .leading, spacing: 2) {
                Text(sat.label)
                Text(position).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            if sat.health == 2 {
                Label("unhealthy", systemImage: "exclamationmark.triangle")
                    .labelStyle(.iconOnly).foregroundStyle(Color.alertHotWarn)
            }
            Text(sat.cn0.map { String(format: "%.0f dB-Hz", $0) } ?? "not tracked")
                .font(.callout.monospaced())
                .foregroundStyle(sat.cn0 == nil ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var position: String {
        let el = sat.el.map { String(format: "el %.0f°", $0) }
        let az = sat.az.map { String(format: "az %.0f°", $0) }
        let parts = [el, az].compactMap { $0 }
        return parts.isEmpty ? "no position from gpsd" : parts.joined(separator: " · ")
    }
}

/// One `aprs_packet`: who, through whom, and what it said.
struct APRSPacketRow: View {
    let p: APRSPacketEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(p.title).bold()
                Spacer()
                Text(Date(timeIntervalSince1970: TimeInterval(p.utime ?? p.ts)), style: .time)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(via).font(.caption).foregroundStyle(.secondary)
            if let c = p.comment ?? p.status, !c.isEmpty {
                Text(c).font(.caption).lineLimit(2)
            }
        }
        .font(.callout.monospaced())
        .accessibilityElement(children: .combine)
    }

    private var via: String {
        var parts: [String] = []
        if p.direct == 1 { parts.append("direct") }
        else if let h = p.heard { parts.append("via \(h)") }
        if let lat = p.lat, let lon = p.lon { parts.append(String(format: "%.3f, %.3f", lat, lon)) }
        if let s = p.speedKt { parts.append("\(Int(s)) kt") }
        return parts.joined(separator: " · ")
    }
}
