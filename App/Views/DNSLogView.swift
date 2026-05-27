// DNSLogView — M5. Filter bar + qtype distribution pie + scrollable
// DNS log. NXDOMAIN rows render in WARN orange; alert-hot src or
// answer IPs pick up their tier hue (cross-panel rule from the
// AlertHotIndex). qnames brand-colour when known.

import SwiftUI
import SlothCore

struct DNSLogView: View {

    @Environment(SlothStore.self) private var store

    enum DirectionChip: Hashable, Sendable { case all, query, response }

    @State private var direction: DirectionChip = .all
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(
                chips: [
                    .init(id: .all,      label: "All"),
                    .init(id: .query,    label: "Q",   tint: .phosphorTeal),
                    .init(id: .response, label: "R",   tint: .phosphorBright),
                ],
                selection: $direction,
                query:     $query,
                placeholder: "qname, src, answer…"
            )

            let visible = filtered
            QTypeDistributionChart(shares: QTypeDistribution.shares(visible))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            Divider()

            if visible.isEmpty {
                emptyState
            } else {
                List(visible.reversed(), id: \.identityKey) { entry in
                    DNSRow(
                        entry: entry,
                        srcHot:    store.alertHot.severity(for: entry.src ?? ""),
                        answerHot: store.alertHot.severity(for: entry.answer ?? "")
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("DNS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [DNSEntry] {
        store.dns.filter { e in
            let dirOK: Bool
            switch direction {
            case .all:      dirOK = true
            case .query:    dirOK = (e.answer ?? "").isEmpty   // Q → no answer
            case .response: dirOK = !(e.answer ?? "").isEmpty  // R → has answer
            }
            guard dirOK else { return false }
            return LogFilter.matches(
                query:  query,
                fields: [e.qname, e.src, e.answer, e.qtype]
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No DNS records",
            systemImage: "questionmark.bubble",
            description: Text(store.dns.isEmpty
                              ? "DNS queries and responses show up here as sloth observes them."
                              : "No DNS records match the current filter.")
        )
    }
}

// MARK: - Row

private struct DNSRow: View {
    let entry: DNSEntry
    let srcHot: AlertSeverity?
    let answerHot: AlertSeverity?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isResponse ? "arrow.down.circle" : "arrow.up.circle")
                .imageScale(.small)
                .foregroundStyle(isResponse ? Color.phosphorBright : Color.phosphorTeal)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.qtype ?? "?")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .leading)
                    Text(entry.qname)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundStyle(qnameTint)
                        .lineLimit(1)
                }
                if let src = entry.src, !src.isEmpty {
                    Text(src)
                        .font(.caption2.monospaced())
                        .foregroundStyle(srcHot?.color ?? .secondary)
                }
            }

            Spacer(minLength: 8)

            answerLabel
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var isResponse: Bool { !(entry.answer ?? "").isEmpty }

    private var qnameTint: Color {
        if let brand = Theme.brand(for: entry.qname) { return brand }
        // If the answer IP is alert-hot, paint the qname in the alert
        // hue too — the qname *led to* a flagged host.
        if let sev = answerHot ?? srcHot { return sev.color }
        return .primary
    }

    @ViewBuilder
    private var answerLabel: some View {
        if let a = entry.answer, !a.isEmpty {
            if isNXDomain(a) {
                Text("NXDOMAIN")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(Color.alertHotWarn)
            } else {
                Text(a)
                    .font(.caption.monospaced())
                    .foregroundStyle(answerHot?.color ?? .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else if entry.rcode == 3 {
            Text("NXDOMAIN")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.alertHotWarn)
        }
    }

    private func isNXDomain(_ s: String) -> Bool {
        s.uppercased() == "NXDOMAIN"
    }

    private var a11y: String {
        var parts: [String] = []
        parts.append(isResponse ? "DNS response" : "DNS query")
        parts.append("\(entry.qtype ?? "unknown") record for \(entry.qname)")
        if let a = entry.answer, !a.isEmpty {
            parts.append(isNXDomain(a) ? "NXDOMAIN" : "answer \(a)")
        }
        return parts.joined(separator: ". ")
    }
}

private extension DNSEntry {
    var identityKey: String { "\(ts)-\(src ?? "")-\(qname)-\(qtype ?? "")-\(answer ?? "")" }
}
