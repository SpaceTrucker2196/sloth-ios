// TLSVersionMixChart — stacked horizontal `BarMark`s for the TLS
// version share over the visible window. 1.0 and 1.1 render in
// WARN orange so deprecated tiers pop visually even before the
// user reads the legend.

import SwiftUI
import Charts
import SlothCore

struct TLSVersionMixChart: View {

    let shares: [ShareSlice]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart(shares) { slice in
            BarMark(
                x: .value("Count", slice.count),
                y: .value("Group", "TLS")    // single bar; share split via foregroundStyle(by:)
            )
            .foregroundStyle(by: .value("Version", slice.label))
        }
        .chartForegroundStyleScale([
            "TLS 1.3": Color.phosphorBright,
            "TLS 1.2": Color.phosphorTeal,
            "TLS 1.1": Color.alertHotWarn,
            "TLS 1.0": Color.alertHotWarn,
            "other":   Color.secondary,
        ])
        .chartLegend(position: .bottom, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(shares) { s in
                    HStack(spacing: 4) {
                        Circle().fill(legendColor(for: s.label))
                            .frame(width: 6, height: 6)
                        Text("\(s.label) ×\(s.count)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(s.label.contains("1.0") || s.label.contains("1.1")
                                             ? .orange : .secondary)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 56)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: shares)
        .accessibilityLabel(a11yLabel)
    }

    private func legendColor(for label: String) -> Color {
        switch label {
        case "TLS 1.3": return .phosphorBright
        case "TLS 1.2": return .phosphorTeal
        case "TLS 1.1", "TLS 1.0": return .alertHotWarn
        default: return .secondary
        }
    }

    private var a11yLabel: String {
        guard !shares.isEmpty else {
            return "TLS version mix. No handshakes observed."
        }
        let total = shares.reduce(0) { $0 + $1.count }
        let parts = shares.map { "\($0.label) \(percent($0.count, total))" }
        return "TLS version mix. " + parts.joined(separator: ", ")
    }

    private func percent(_ n: Int, _ total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(n) / Double(total) * 100).rounded()))%"
    }
}
