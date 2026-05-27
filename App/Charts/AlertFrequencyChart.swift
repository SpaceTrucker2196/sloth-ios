// AlertFrequencyChart — stacked bar of alerts/minute over the last
// 60 minutes, segmented by severity. Reads from `SlothStore.alerts`
// via the pure `AlertBucketing` helper so the chart itself stays
// declarative.
//
// Bar colours pull from `AlertSeverity.color` (App/Theme.swift) so the
// hues match every other tier-coloured surface in the app.

import SwiftUI
import Charts
import SlothCore

struct AlertFrequencyChart: View {

    let buckets: [AlertFrequencyBucket]
    let windowMinutes: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart(buckets) { b in
            BarMark(
                x: .value("Minute", b.minuteStart, unit: .minute),
                y: .value("Count",  b.count)
            )
            .foregroundStyle(by: .value("Severity", b.severity.displayName))
        }
        .chartForegroundStyleScale([
            AlertSeverity.crit.displayName: AlertSeverity.crit.color,
            AlertSeverity.warn.displayName: AlertSeverity.warn.color,
            AlertSeverity.low.displayName:  AlertSeverity.low.color,
        ])
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 15)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3))
        }
        .chartXScale(domain: xDomain)
        .frame(height: 80)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: buckets)
        .accessibilityLabel(a11yLabel)
    }

    /// Anchor the X axis to the full window so empty buckets still
    /// leave space — frame-to-frame the time axis doesn't reflow.
    private var xDomain: ClosedRange<Date> {
        let now = Date()
        let start = now.addingTimeInterval(-Double(windowMinutes) * 60)
        return start...now
    }

    private var a11yLabel: String {
        let crit = buckets.filter { $0.severity == .crit }.reduce(0) { $0 + $1.count }
        let warn = buckets.filter { $0.severity == .warn }.reduce(0) { $0 + $1.count }
        let low  = buckets.filter { $0.severity == .low  }.reduce(0) { $0 + $1.count }
        let total = crit + warn + low
        if total == 0 {
            return "Alert frequency over the last \(windowMinutes) minutes — no alerts."
        }
        return "Alert frequency over the last \(windowMinutes) minutes. " +
               "\(crit) critical, \(warn) warning, \(low) low."
    }
}

#Preview {
    AlertFrequencyChart(
        buckets: [
            AlertFrequencyBucket(minuteStart: Date().addingTimeInterval(-300), severity: .low,  count: 2),
            AlertFrequencyBucket(minuteStart: Date().addingTimeInterval(-180), severity: .warn, count: 1),
            AlertFrequencyBucket(minuteStart: Date().addingTimeInterval(-60),  severity: .crit, count: 3),
        ],
        windowMinutes: 60
    )
    .padding()
}
