// RTTSparkline — inline RTT trend for a single flow. Takes a pure
// `[Double]` series (oldest first), heat-grades the trace by the
// latest value relative to the row's max, hides axes, and fits the
// frame the row gives it. Sister of `BandwidthSparkline` (M4); same
// pattern, different domain.

import SwiftUI
import Charts
import SlothCore

struct RTTSparkline: View {

    let samples: [Double]
    var tint: Color? = nil   // nil → heat-graded by value vs. local peak

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { idx, value in
                LineMark(
                    x: .value("Bin", idx),
                    y: .value("RTT", value)
                )
                .foregroundStyle(stroke(for: value))
                .interpolationMethod(.monotone)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: samples)
        .accessibilityLabel(a11y)
    }

    private var peak: Double {
        samples.max() ?? 1
    }

    private func stroke(for value: Double) -> Color {
        if let tint { return tint }
        let p = peak
        guard p > 0 else { return .heatLo }
        return .heat(value / p)
    }

    private var a11y: String {
        guard let latest = samples.last, !samples.isEmpty else {
            return "No RTT samples yet."
        }
        let p = peak
        return "RTT trend over the last \(samples.count) samples. " +
               "Latest \(Int(latest)) ms, peak \(Int(p)) ms."
    }
}
