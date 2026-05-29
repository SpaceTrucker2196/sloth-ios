// ConnectionDetailView — push destination for a single flow row.
// Larger RTT sparkline, headline-style src → dst, byte totals,
// state, retx, age. Read-only.

import SwiftUI
import SlothCore

struct ConnectionDetailView: View {

    let flow: ConnectionFlow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                sparklineCard
                metricsGrid
                if let s = flow.latest.state {
                    section("State") {
                        Text(s).font(.callout.monospaced())
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Flow")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: protoIcon)
                    .foregroundStyle(protoTint)
                Text(flow.latest.proto.rawValue.uppercased())
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(protoTint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(flow.latest.src)
                    .font(.body.monospaced())
                    .lineLimit(1).truncationMode(.middle)
                Text("→ \(flow.latest.dst)")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Text("\(flow.recordCount) sample\(flow.recordCount == 1 ? "" : "s")")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private var sparklineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RTT trend")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
            if flow.rttSeries.isEmpty {
                Text("No RTT samples — UDP, or sloth had no RTT to report yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                RTTSparkline(samples: flow.rttSeries)
                    .frame(height: 96)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private var metricsGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
            metric("RX", formatBytes(flow.latest.rxBytes))
            metric("TX", formatBytes(flow.latest.txBytes))
            if let rtt = flow.latest.rttMS {
                metric("RTT", String(format: "%.1f ms", rtt))
            }
            if let retx = flow.latest.retx {
                metric("Retx", "\(retx)")
            }
            if let age = flow.latest.ageS {
                metric("Age", "\(age)s")
            }
            metric("Updates", "\(flow.recordCount)")
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    private func section<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
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
}
