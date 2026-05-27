// BandwidthSparkline — reusable inline sparkline. Takes a pure
// `[Double]` series (oldest first), heat-grades the trace by value,
// hides axes, fills to the row height. Reused across the Top Hosts
// list (M4), the connections RTT sparkline (M6), and the composite
// dashboard (M7).
//
// Naming note: "Bandwidth" matches the milestone-doc terminology and
// the future intent. Today the data source is records-per-minute
// (sloth doesn't emit byte counters in JSONL); when sloth grows a
// `bw` record this view doesn't change.

import SwiftUI
import Charts
import SlothCore

struct BandwidthSparkline: View {

    let samples: [Double]
    var tint: Color? = nil    // nil → heat-graded by value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { idx, value in
                AreaMark(
                    x: .value("Bin", idx),
                    y: .value("Rate", value)
                )
                .foregroundStyle(strokeColor(for: value).opacity(0.25))

                LineMark(
                    x: .value("Bin", idx),
                    y: .value("Rate", value)
                )
                .foregroundStyle(strokeColor(for: value))
                .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...max(samples.count - 1, 1))
        .chartYScale(domain: 0...max(maxValue, 1))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: samples)
        .accessibilityLabel(a11yLabel)
    }

    private var maxValue: Double {
        samples.max() ?? 0
    }

    /// Heat-grade by relative value if no caller-provided tint, else
    /// use the tint for every glyph.
    private func strokeColor(for value: Double) -> Color {
        if let tint { return tint }
        let m = maxValue
        guard m > 0 else { return .heatLo }
        return Color.heat(value / m)
    }

    private var a11yLabel: String {
        guard !samples.isEmpty else { return "No activity in the window." }
        let peak = maxValue
        let total = samples.reduce(0, +)
        let trend: String
        if samples.count >= 2 {
            let early = samples.prefix(samples.count / 2).reduce(0, +)
            let late  = samples.suffix(samples.count / 2).reduce(0, +)
            if      late > early * 1.25 { trend = "rising" }
            else if late * 1.25 < early { trend = "falling" }
            else                        { trend = "steady" }
        } else {
            trend = "single sample"
        }
        return "Activity sparkline, \(trend), peak \(Int(peak.rounded())) per minute, " +
               "\(Int(total.rounded())) total in the window."
    }
}

#Preview {
    VStack(spacing: 12) {
        BandwidthSparkline(samples: [0,0,0,1,2,3,4,3,2,1])
            .frame(width: 100, height: 24)
        BandwidthSparkline(samples: [5,5,4,3,2,1,1,0,0,0])
            .frame(width: 100, height: 24)
        BandwidthSparkline(samples: Array(repeating: 0.0, count: 30))
            .frame(width: 100, height: 24)
    }
    .padding()
}
