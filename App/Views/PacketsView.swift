// PacketsView — live frame-header stream. One row per `packet`
// record (sloth omits raw payload by design; this is headers only).
//
// Unlike the snapshot views, packets are an event ring: newest at
// the top, capped at `RingSizes.packets` (1024). Each row mirrors
// sloth's TUI `packets.c` line shape: timestamp, src→dst, proto,
// length, free-form info.
//
// Search filters by src / dst / info — handy for "what's that one
// host doing" without scrolling.

import SwiftUI
import SlothCore

struct PacketsView: View {

    @Environment(SlothStore.self) private var store

    @State private var query: String = ""

    var body: some View {
        let visible = filtered
        Group {
            if visible.isEmpty {
                ContentUnavailableView(
                    "No packets",
                    systemImage: "rectangle.stack",
                    description: Text(store.packets.isEmpty
                        ? "Sloth emits one `packet` record per observed frame header. Records appear as the stream opens."
                        : "No packets match the current filter.")
                )
            } else {
                List(Array(visible.enumerated()), id: \.offset) { _, packet in
                    PacketRow(packet: packet)
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            }
        }
        .navigationTitle("Packets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [PacketEntry] {
        let reversed = store.packets.reversed()
        guard !query.isEmpty else { return Array(reversed) }
        return reversed.filter {
            LogFilter.matches(
                query:  query,
                fields: [$0.src, $0.dst, $0.proto, $0.info].compactMap { $0 }
            )
        }
    }
}

private struct PacketRow: View {

    let packet: PacketEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(timeStamp)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                if let p = packet.proto, !p.isEmpty {
                    Text(p.uppercased())
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(protoTint)
                }
                Text("\(packet.len)B")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 4) {
                Text(endpointWithPort(packet.src, port: packet.srcPort))
                    .foregroundStyle(.phosphorTeal)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(endpointWithPort(packet.dst, port: packet.dstPort))
                    .foregroundStyle(.phosphorBright)
            }
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            if let info = packet.info, !info.isEmpty {
                Text(info)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var timeStamp: String {
        let sec = packet.tsSec > 0 ? packet.tsSec : packet.ts
        let date = Date(timeIntervalSince1970: TimeInterval(sec))
        let base = date.formatted(date: .omitted, time: .standard)
        // Append fractional ms from ts_usec when sloth provides it.
        if packet.tsUSec > 0 {
            let ms = packet.tsUSec / 1_000
            return "\(base).\(String(format: "%03d", ms))"
        }
        return base
    }

    private func endpointWithPort(_ host: String, port: Int?) -> String {
        guard let port else { return host }
        // Bracket IPv6 for legibility.
        if host.contains(":") {
            return "[\(host)]:\(port)"
        }
        return "\(host):\(port)"
    }

    private var protoTint: Color {
        switch (packet.proto ?? "").uppercased() {
        case "TCP":  return .phosphorTeal
        case "UDP":  return .phosphorBright
        case "ICMP": return .alertHotLow
        case "ARP":  return .secondary
        default:     return .secondary
        }
    }
}
