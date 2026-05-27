// AlertRowView — one row in the alerts list. Leading severity stripe,
// SF Symbol prefix (so colour-blind operators don't lose information),
// title, hit-count badge, relative time, one-line detail truncation.

import SwiftUI
import SlothCore

struct AlertRowView: View {

    let alert: AlertEntry
    let isHot: Bool   // alertHot index says match_ip is currently flagged

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Leading severity stripe — 4-pt vertical bar in the
            // severity hue. Reads as a colour-coded margin even on
            // small text sizes.
            Rectangle()
                .fill(alert.severity.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: alert.severity.symbolName)
                        .foregroundStyle(alert.severity.color)
                        .imageScale(.small)

                    Text(alert.severity.displayName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(alert.severity.color)
                        .fontWeight(alert.severity.prefersBold ? .bold : .regular)

                    Text(alert.title)
                        .font(.callout)
                        .fontWeight(alert.severity.prefersBold ? .semibold : .regular)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if alert.hits >= 2 {
                        Text("×\(alert.hits)")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                    }

                    Text(relativeTime)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let detail = alert.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let matchIP = alert.matchIP, !matchIP.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: isHot ? "flame.fill" : "network")
                            .imageScale(.small)
                            .foregroundStyle(isHot ? alert.severity.color : .secondary)
                        Text(matchIP)
                            .font(.caption2.monospaced())
                            .foregroundStyle(isHot ? alert.severity.color : .secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 10)
            .padding(.trailing, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var relativeTime: String {
        let now    = Date()
        let lastTS = Date(timeIntervalSince1970: TimeInterval(alert.lastSeen))
        let f      = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: lastTS, relativeTo: now)
    }

    private var a11yLabel: String {
        var parts: [String] = []
        parts.append("\(alert.severity.displayName) alert")
        parts.append(alert.title)
        if let d = alert.detail, !d.isEmpty { parts.append(d) }
        parts.append("\(alert.hits) occurrence\(alert.hits == 1 ? "" : "s")")
        parts.append("Last seen \(relativeTime)")
        return parts.joined(separator: ". ")
    }
}
