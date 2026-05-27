// QTypeDistributionChart — slice-per-qtype pie at the top of the
// DNS log view. Hides the legend (slices are labelled inline);
// uses the same phosphor palette as the JA3 hash colours so the
// overall chart hue family is consistent.

import SwiftUI
import Charts
import SlothCore

struct QTypeDistributionChart: View {

    let shares: [ShareSlice]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart(shares) { slice in
            SectorMark(
                angle:        .value("Count", slice.count),
                innerRadius:  .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(color(for: slice.label))
            .annotation(position: .overlay) {
                if slice.count > 0 {
                    Text(slice.label)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(height: 110)
        .chartLegend(.hidden)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: shares)
        .accessibilityLabel(a11yLabel)
    }

    /// Stable per-label colour. A/AAAA get the project's bright
    /// phosphor / teal pair; rest pulled from the JA3 palette so
    /// the hue family is consistent across charts.
    private func color(for label: String) -> Color {
        switch label {
        case "A":     return .phosphorBright
        case "AAAA":  return .phosphorTeal
        case "PTR":   return Color(red: 0.529, green: 0.686, blue: 0.843)
        case "CNAME": return Color(red: 0.843, green: 0.686, blue: 0.00)
        case "MX":    return Color(red: 1.00,  green: 0.686, blue: 0.373)
        case "TXT":   return Color(red: 0.843, green: 0.529, blue: 0.529)
        case "SRV":   return Color(red: 0.686, green: 1.00,  blue: 0.529)
        case "NS":    return Color(red: 0.529, green: 1.00,  blue: 0.686)
        case "other": return .secondary
        default:      return .secondary
        }
    }

    private var a11yLabel: String {
        guard !shares.isEmpty else {
            return "Query-type distribution. No DNS records yet."
        }
        let total = shares.reduce(0) { $0 + $1.count }
        let top = shares.prefix(3).map { "\($0.label) \(percent($0.count, total))" }
        return "Query-type distribution. " + top.joined(separator: ", ")
    }

    private func percent(_ n: Int, _ total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(n) / Double(total) * 100).rounded()))%"
    }
}
