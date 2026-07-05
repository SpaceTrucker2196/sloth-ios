// ICMPLogView — dashboard drill-in for the `icmp` ring. Category
// chips (echo / errors / discovery) + search over a newest-first
// list. Names and categories come from `ICMPClassify`, which mirrors
// sloth's `icmp_log.c` tables. Spec: docs/views/icmp-log.md.

import SwiftUI
import SlothCore

struct ICMPLogView: View {

    @Environment(SlothStore.self) private var store

    enum Chip: Hashable, Sendable { case all, echo, errors, discovery }

    @State private var chip: Chip = .all
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(
                chips: [
                    .init(id: .all,       label: "All"),
                    .init(id: .echo,      label: "Echo",      tint: .phosphorTeal),
                    .init(id: .errors,    label: "Errors",    tint: .alertHotWarn),
                    .init(id: .discovery, label: "Discovery", tint: .phosphorBright),
                ],
                selection: $chip,
                query:     $query,
                placeholder: "src, dst, type…"
            )

            let visible = filtered
            if visible.isEmpty {
                emptyState
            } else {
                List(visible.reversed(), id: \.identityKey) { entry in
                    ICMPRow(
                        entry:  entry,
                        srcHot: store.alertHot.severity(for: entry.src ?? ""),
                        dstHot: store.alertHot.severity(for: entry.dst ?? "")
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("ICMP")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [ICMPEntry] {
        store.icmp.filter { e in
            let cat = ICMPClassify.category(for: e)
            let chipOK: Bool
            switch chip {
            case .all:       chipOK = true
            case .echo:      chipOK = cat == .echo
            case .errors:    chipOK = cat == .error
            case .discovery: chipOK = cat == .discovery
            }
            guard chipOK else { return false }
            return LogFilter.matches(
                query:  query,
                fields: [e.src, e.dst, ICMPClassify.name(for: e)]
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No ICMP traffic",
            systemImage: "arrow.left.arrow.right",
            description: Text(store.icmp.isEmpty
                              ? "Pings, unreachables, and neighbor chatter show up here as sloth observes them."
                              : "No ICMP records match the current filter.")
        )
    }
}

// MARK: - Row

private struct ICMPRow: View {

    let entry: ICMPEntry
    let srcHot: AlertSeverity?
    let dstHot: AlertSeverity?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: glyph)
                .imageScale(.small)
                .foregroundStyle(category == .error ? Color.alertHotWarn : .phosphorTeal)

            VStack(alignment: .leading, spacing: 2) {
                Text(ICMPClassify.name(for: entry))
                    .font(.callout)
                    .foregroundStyle(category == .error ? Color.alertHotWarn : .primary)
                HStack(spacing: 4) {
                    Text(entry.src ?? "—")
                        .foregroundStyle(srcHot?.color ?? .secondary)
                    Text("→").foregroundStyle(.tertiary)
                    Text(entry.dst ?? "—")
                        .foregroundStyle(dstHot?.color ?? .secondary)
                }
                .font(.caption2.monospaced())
            }

            Spacer(minLength: 8)

            if let t = entry.icmpType {
                Text("type \(t)/\(entry.code ?? 0)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var category: ICMPClassify.Category {
        ICMPClassify.category(for: entry)
    }

    private var glyph: String {
        switch category {
        case .echo:      return "dot.radiowaves.left.and.right"
        case .error:     return "exclamationmark.triangle"
        case .discovery: return "antenna.radiowaves.left.and.right"
        case .other:     return "circle.dotted"
        }
    }

    private var a11y: String {
        var s = "\(ICMPClassify.name(for: entry)), from \(entry.src ?? "unknown") to \(entry.dst ?? "unknown")"
        if let t = entry.icmpType { s += ", type \(t) code \(entry.code ?? 0)" }
        return s
    }
}

private extension ICMPEntry {
    var identityKey: String {
        "\(ts)-\(src ?? "")-\(dst ?? "")-\(icmpType ?? -1)-\(code ?? -1)"
    }
}
