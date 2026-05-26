// AlertSeverity — three-tier alert severity that mirrors sloth's
// alert_sev_t. Numeric values are wire-stable (these are the integers
// in the JSONL `sev` field).

import Foundation

public enum AlertSeverity: Int, Sendable, Codable, CaseIterable {
    case low  = 0
    case warn = 1
    case crit = 2

    /// Promotion order. CRIT > WARN > LOW. Used by `AlertHotIndex` so
    /// a later LOW alert can't downgrade an earlier CRIT.
    public func max(_ other: AlertSeverity) -> AlertSeverity {
        rawValue > other.rawValue ? self : other
    }

    /// SF Symbol name. Always paired with the severity colour so
    /// colour-blind operators don't lose information.
    public var symbolName: String {
        switch self {
        case .low:  return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .crit: return "exclamationmark.octagon"
        }
    }

    /// Bold weight on WARN + CRIT; LOW stays regular. Mirrors sloth's
    /// `tui_alert_hot_attr` bold rule.
    public var prefersBold: Bool { self != .low }

    public var displayName: String {
        switch self {
        case .low:  return "LOW"
        case .warn: return "WARN"
        case .crit: return "CRIT"
        }
    }
}
