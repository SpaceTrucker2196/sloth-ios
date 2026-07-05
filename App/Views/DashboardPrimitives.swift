// DashboardPrimitives — the band frame and shared row atoms for the
// iPad Tufte dashboard. Mirrors sloth's dashboard_primitives.c role:
// everything here is presentation-only chrome shared by the bands
// (DashboardBands.swift) and the grid panels (DashboardGrid.swift).
//
// Tufte rules enforced here so panels can't drift: structure ink is
// a single hairline per band title and per column split; counts live
// in the title; numerals are monospaced.

import SwiftUI
import SlothCore

/// Drill-in routes. Band titles navigate to the existing full views —
/// the TUI's Enter-on-focused-panel, minus the focus state.
enum DashboardRoute: Hashable {
    case interfaces, alerts, connections, topHosts
    case wifi, lan, twins, dns, icmp, packets
}

/// Band header: SMALL-CAPS title · count, fused into a hairline rule.
/// Tappable when a route is given; the chevron is the only affordance
/// hint (no buttons, no card chrome).
struct BandTitle: View {

    let label: String
    var count: Int?             = nil
    var route: DashboardRoute?  = nil
    var tint:  Color            = .phosphorDim

    var body: some View {
        HStack(spacing: 6) {
            if let route {
                NavigationLink(value: route) { titleText }
                    .buttonStyle(.plain)
            } else {
                titleText
            }
            Rectangle()
                .fill(Color.phosphorDim.opacity(0.35))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var titleText: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.phosphor(.caption2, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(tint)
            if let count {
                Text("· \(count)")
                    .font(.phosphor(.caption2))
                    .foregroundStyle(.secondary)
            }
            if route != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.phosphorDim.opacity(0.6))
            }
        }
    }
}

/// Vertical hairline between panel columns.
struct ColumnRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.phosphorDim.opacity(0.25))
            .frame(width: 0.5)
    }
}

/// Quiet placeholder row — the band stays visible when its table is
/// empty so the operator can tell *quiet* from *broken* (the TUI's
/// always-visible CRIT band rule, applied everywhere).
struct QuietRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.phosphor(.caption2))
            .foregroundStyle(Color.phosphorDim.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Formatting

enum DashFormat {

    /// Compact rate, sloth's `bw_fmt_rate` shape: "842B/s" "1.2K/s"
    /// "3.4M/s". Density beats unit pedantry on the board.
    static func rate(_ bps: Double) -> String {
        switch bps {
        case ..<1_000:         return String(format: "%.0fB/s", bps)
        case ..<1_000_000:     return String(format: "%.1fK/s", bps / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM/s", bps / 1_000_000)
        default:               return String(format: "%.1fG/s", bps / 1_000_000_000)
        }
    }

    /// Compact byte total: "512B" "48K" "1.2M" "3.4G".
    static func bytes(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case ..<1_000:         return String(format: "%.0fB", v)
        case ..<1_000_000:     return String(format: "%.0fK", v / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", v / 1_000_000)
        default:               return String(format: "%.1fG", v / 1_000_000_000)
        }
    }

    /// Wall-clock HH:mm:ss for a wire epoch-seconds stamp.
    static func clock(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        return Self.clockFormatter.string(from: date)
    }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - Row text atoms

extension Text {

    /// Identity column (names, hosts, MACs): dim phosphor mono.
    func dashIdentity() -> some View {
        self.font(.phosphor(.caption2)).foregroundStyle(.phosphorTeal)
    }

    /// Numeric column: mono digits, secondary weight in the hierarchy.
    func dashValue() -> some View {
        self.font(.phosphor(.caption2)).foregroundStyle(.secondary)
    }

    /// Timestamp column.
    func dashStamp() -> some View {
        self.font(.phosphor(.caption2)).foregroundStyle(Color.phosphorDim)
    }
}

/// IP rendered in its alert-hot hue when the `AlertHotIndex` flags
/// it, with WARN+CRIT bold per the TUI rule; plain identity teal
/// otherwise.
struct HotIPText: View {

    let ip: String
    let hot: AlertSeverity?

    var body: some View {
        Text(ip)
            .font(.phosphor(.caption2,
                            weight: (hot == .warn || hot == .crit) ? .bold : .regular))
            .foregroundStyle(hot?.color ?? .phosphorTeal)
    }
}
