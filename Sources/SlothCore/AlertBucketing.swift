// AlertBucketing — pure logic that turns a flat alerts collection
// into per-minute counts split by severity. Pulled out of the chart
// view so it's hermetically testable (the chart itself stays in
// `App/Charts/AlertFrequencyChart.swift`).

import Foundation

/// One stacked bar in the alerts-frequency chart. Identifiable by the
/// minute the bucket starts at (truncated to the minute boundary in
/// the user's local zone — sloth emits epoch seconds, the bucketing
/// happens client-side so DST changes don't shift historical bars).
public struct AlertFrequencyBucket: Sendable, Equatable, Identifiable {
    public let minuteStart: Date
    public let severity: AlertSeverity
    public let count: Int

    public var id: String {
        "\(Int(minuteStart.timeIntervalSince1970))-\(severity.rawValue)"
    }

    public init(minuteStart: Date, severity: AlertSeverity, count: Int) {
        self.minuteStart = minuteStart
        self.severity    = severity
        self.count       = count
    }
}

public enum AlertBucketing {

    /// Bucket `alerts` into per-minute counts, split by severity, over
    /// a window ending at `now` and `windowMinutes` long. One row per
    /// (minute, severity) that has ≥ 1 alert; empty cells are omitted
    /// (the chart axes still anchor to the full window so the time
    /// scale is constant frame-to-frame).
    ///
    /// Bucketing key is the alert's `lastSeen` — treating each entry
    /// as one "event" regardless of `hits`. Counting `hits` would
    /// require synthesising timestamps for repeats, and we don't get
    /// per-hit times from sloth.
    public static func buckets(
        from alerts: [AlertEntry],
        now: Date = Date(),
        windowMinutes: Int = 60
    ) -> [AlertFrequencyBucket] {
        guard windowMinutes > 0 else { return [] }
        let windowSeconds = TimeInterval(windowMinutes * 60)
        let earliestEpoch = Int((now.timeIntervalSince1970 - windowSeconds).rounded(.down))

        // Aggregate into a (minute, severity) → count dictionary.
        var counts: [Key: Int] = [:]
        for a in alerts {
            guard a.lastSeen >= earliestEpoch else { continue }
            let minute = (a.lastSeen / 60) * 60
            let key = Key(minuteStart: minute, severity: a.severity)
            counts[key, default: 0] += 1
        }

        // Stable ordering: minute ascending, severity descending so
        // CRIT stacks on top of WARN stacks on top of LOW in the bar.
        return counts
            .map { (key, count) in
                AlertFrequencyBucket(
                    minuteStart: Date(timeIntervalSince1970: TimeInterval(key.minuteStart)),
                    severity:    key.severity,
                    count:       count
                )
            }
            .sorted { lhs, rhs in
                if lhs.minuteStart != rhs.minuteStart {
                    return lhs.minuteStart < rhs.minuteStart
                }
                return lhs.severity.rawValue < rhs.severity.rawValue
            }
    }

    private struct Key: Hashable {
        let minuteStart: Int
        let severity: AlertSeverity
    }
}
