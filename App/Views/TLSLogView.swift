// TLSLogView — M5. Filter bar + TLS version mix chart + log list.
// TLS 1.0 / 1.1 rows render in WARN orange (downgrade signal); JA3
// prefixes are hash-coloured so the same JA3 across hosts pops as a
// correlation cue. alert-hot src or dst IPs pick up their tier hue.

import SwiftUI
import SlothCore

struct TLSLogView: View {

    @Environment(SlothStore.self) private var store

    enum FilterChip: Hashable, Sendable { case all, deprecated }

    @State private var filter: FilterChip = .all
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(
                chips: [
                    .init(id: .all,        label: "All"),
                    .init(id: .deprecated, label: "TLS 1.0 / 1.1", tint: .alertHotWarn),
                ],
                selection: $filter,
                query:     $query,
                placeholder: "sni, src, dst, ja3…"
            )

            let visible = filtered
            TLSVersionMixChart(shares: TLSVersionMix.shares(visible))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            Divider()

            if visible.isEmpty {
                emptyState
            } else {
                List(visible.reversed(), id: \.identityKey) { entry in
                    TLSRow(
                        entry: entry,
                        dstHot: store.alertHot.severity(for: entry.dst ?? ""),
                        srcHot: store.alertHot.severity(for: entry.src ?? "")
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("TLS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [TLSEntry] {
        store.tls.filter { e in
            if filter == .deprecated, !TLSVersionMix.isDeprecated(e.version) {
                return false
            }
            return LogFilter.matches(
                query:  query,
                fields: [e.sni, e.src, e.dst, e.ja3, e.version]
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No TLS handshakes",
            systemImage: "lock",
            description: Text(store.tls.isEmpty
                              ? "TLS ClientHellos show up here as sloth observes them."
                              : "No TLS records match the current filter.")
        )
    }
}

// MARK: - Row

private struct TLSRow: View {
    let entry: TLSEntry
    let dstHot: AlertSeverity?
    let srcHot: AlertSeverity?

    var body: some View {
        let deprecated = TLSVersionMix.isDeprecated(entry.version)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: deprecated ? "exclamationmark.shield" : "lock.shield")
                .imageScale(.small)
                .foregroundStyle(deprecated ? Color.alertHotWarn : Color.phosphorBright)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.version ?? "?")
                        .font(.caption2.monospaced())
                        .fontWeight(deprecated ? .bold : .regular)
                        .foregroundStyle(deprecated ? Color.alertHotWarn : Color.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(entry.sni ?? "(no SNI)")
                        .font(.callout)
                        .foregroundStyle(sniTint)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let src = entry.src, !src.isEmpty {
                        Text(src)
                            .font(.caption2.monospaced())
                            .foregroundStyle(srcHot?.color ?? .secondary)
                    }
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let dst = entry.dst, !dst.isEmpty {
                        Text(dst)
                            .font(.caption2.monospaced())
                            .foregroundStyle(dstHot?.color ?? .secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            if let ja3 = entry.ja3, !ja3.isEmpty {
                Text(ja3.prefix(12))
                    .font(.caption2.monospaced())
                    .foregroundStyle(Theme.ja3Color(ja3))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var sniTint: Color {
        if let sev = dstHot ?? srcHot { return sev.color }
        if let brand = Theme.brand(for: entry.sni) { return brand }
        return .primary
    }

    private var a11y: String {
        let ver = entry.version ?? "unknown version"
        let dep = TLSVersionMix.isDeprecated(entry.version) ? " (deprecated)" : ""
        let sni = entry.sni ?? "no SNI"
        return "\(ver)\(dep) to \(sni)"
    }
}

private extension TLSEntry {
    var identityKey: String {
        "\(ts)-\(src ?? "")-\(dst ?? "")-\(sni ?? "")-\(ja3 ?? "")"
    }
}
