// ConnectionsView — M6. Active flow table fed by the SlothStore's
// `connections` ring + `ConnectionsAggregator`. Per-row RTT
// sparkline (`RTTSparkline`). Sort menu (bandwidth / state / RTT /
// age). Proto chip filter (All / TCP / UDP). Alert-hot src/dst IPs
// pick up their tier hue.
//
// Dark until sloth ships the `connections` JSONL emitter (sloth#5).
// Until then the empty state explains why.

import SwiftUI
import SlothCore

struct ConnectionsView: View {

    @Environment(SlothStore.self) private var store

    enum ProtoChip: Hashable, Sendable { case all, tcp, udp }

    @State private var proto: ProtoChip = .all
    @State private var query: String = ""
    @State private var sort: ConnectionsSort = .bandwidth

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(
                chips: [
                    .init(id: .all, label: "All"),
                    .init(id: .tcp, label: "TCP", tint: .phosphorTeal),
                    .init(id: .udp, label: "UDP", tint: .phosphorBright),
                ],
                selection: $proto,
                query:     $query,
                placeholder: "src, dst, state…"
            )

            let visible = filteredFlows
            if visible.isEmpty {
                emptyState
            } else {
                List(visible) { flow in
                    NavigationLink {
                        ConnectionDetailView(flow: flow)
                    } label: {
                        ConnectionRow(
                            flow: flow,
                            srcHot: store.alertHot.severity(for: flow.latest.src),
                            dstHot: store.alertHot.severity(for: flow.latest.dst)
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { sortMenu }
    }

    private var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    Text("Bandwidth").tag(ConnectionsSort.bandwidth)
                    Text("State").tag(ConnectionsSort.state)
                    Text("RTT").tag(ConnectionsSort.rtt)
                    Text("Age").tag(ConnectionsSort.age)
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
            }
            .accessibilityLabel("Sort flows")
        }
    }

    private var filteredFlows: [ConnectionFlow] {
        let snapshot = ConnectionsAggregator.snapshot(from: store.connections, sort: sort)
        return snapshot.filter { flow in
            let protoOK: Bool
            switch proto {
            case .all: protoOK = true
            case .tcp: protoOK = flow.latest.proto == .tcp
            case .udp: protoOK = flow.latest.proto == .udp
            }
            guard protoOK else { return false }
            return LogFilter.matches(
                query:  query,
                fields: [flow.latest.src, flow.latest.dst, flow.latest.state]
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No connection records",
            systemImage: "point.3.connected.trianglepath.dotted",
            description: Text(store.connections.isEmpty
                              ? "Active TCP / UDP flows show up here once sloth emits `connections` JSONL records (tracked upstream as sloth#5)."
                              : "No flows match the current filter.")
        )
    }
}

// MARK: - Row

private struct ConnectionRow: View {

    let flow: ConnectionFlow
    let srcHot: AlertSeverity?
    let dstHot: AlertSeverity?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: protoIcon)
                .imageScale(.small)
                .foregroundStyle(protoTint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(flow.latest.src)
                        .font(.caption.monospaced())
                        .foregroundStyle(srcHot?.color ?? .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(flow.latest.dst)
                        .font(.caption.monospaced())
                        .foregroundStyle(dstHot?.color ?? .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: 8) {
                    if let s = flow.latest.state {
                        Text(s)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let rtt = flow.latest.rttMS {
                        Label(String(format: "%.0fms", rtt),
                              systemImage: "stopwatch")
                            .font(.caption2.monospacedDigit())
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    }
                    Label(formatBytes(flow.totalBytes), systemImage: "arrow.up.arrow.down")
                        .font(.caption2.monospacedDigit())
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            RTTSparkline(samples: flow.rttSeries)
                .frame(width: 64, height: 28)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var protoIcon: String {
        switch flow.latest.proto {
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "dot.radiowaves.left.and.right"
        }
    }

    private var protoTint: Color {
        switch flow.latest.proto {
        case .tcp: return .phosphorTeal
        case .udp: return .phosphorBright
        }
    }

    private var a11y: String {
        let proto = flow.latest.proto.rawValue.uppercased()
        let state = flow.latest.state.map { " \($0)" } ?? ""
        let rtt   = flow.latest.rttMS.map { String(format: ", \($0.rounded())ms RTT", $0) } ?? ""
        return "\(proto) \(flow.latest.src) to \(flow.latest.dst)\(state)\(rtt)."
    }
}

// MARK: - Helpers

func formatBytes(_ bytes: Int) -> String {
    let kib: Double = 1024
    let v = Double(bytes)
    switch v {
    case ..<kib:                return "\(bytes) B"
    case ..<(kib * kib):        return String(format: "%.1f KiB", v / kib)
    case ..<(kib * kib * kib):  return String(format: "%.1f MiB", v / (kib * kib))
    default:                    return String(format: "%.2f GiB", v / (kib * kib * kib))
    }
}
