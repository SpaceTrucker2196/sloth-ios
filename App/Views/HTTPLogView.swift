// HTTPLogView — M5. Filter bar + log list. No chart on this view per
// the M5 spec (HTTP traffic in modern networks is dominated by
// captive-portal noise; a method-distribution chart would be
// uninformative). Cleartext POSTs and attack-path patterns get
// WARN / CRIT row colouring even before sloth flags them.

import SwiftUI
import SlothCore

struct HTTPLogView: View {

    @Environment(SlothStore.self) private var store

    enum MethodChip: Hashable, Sendable { case all, get, post, other }

    @State private var method: MethodChip = .all
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(
                chips: [
                    .init(id: .all,   label: "All"),
                    .init(id: .get,   label: "GET",  tint: .phosphorTeal),
                    .init(id: .post,  label: "POST", tint: .alertHotWarn),
                    .init(id: .other, label: "Other"),
                ],
                selection: $method,
                query:     $query,
                placeholder: "host, path, src…"
            )

            let visible = filtered
            if visible.isEmpty {
                emptyState
            } else {
                List(visible.reversed(), id: \.identityKey) { entry in
                    HTTPRow(
                        entry: entry,
                        srcHot: store.alertHot.severity(for: entry.src ?? ""),
                        dstHot: store.alertHot.severity(for: entry.dst ?? "")
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("HTTP")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [HTTPEntry] {
        store.http.filter { e in
            let methodOK: Bool
            switch method {
            case .all:   methodOK = true
            case .get:   methodOK = (e.method ?? "").uppercased() == "GET"
            case .post:  methodOK = (e.method ?? "").uppercased() == "POST"
            case .other:
                let m = (e.method ?? "").uppercased()
                methodOK = !m.isEmpty && m != "GET" && m != "POST"
            }
            guard methodOK else { return false }
            return LogFilter.matches(
                query:  query,
                fields: [e.host, e.path, e.src, e.dst, e.method]
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No HTTP traffic",
            systemImage: "globe",
            description: Text(store.http.isEmpty
                              ? "Cleartext HTTP traffic shows up here as sloth observes it. " +
                                "Most modern traffic is HTTPS; expect this list to be sparse."
                              : "No HTTP records match the current filter.")
        )
    }
}

// MARK: - Row

private struct HTTPRow: View {
    let entry: HTTPEntry
    let srcHot: AlertSeverity?
    let dstHot: AlertSeverity?

    var body: some View {
        let suspect = isSuspect
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: suspect ? "exclamationmark.shield.fill" : "globe")
                .imageScale(.small)
                .foregroundStyle(suspect ? Color.alertHotWarn : Color.phosphorTeal)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.method ?? "?")
                        .font(.caption2.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(methodTint)
                        .frame(width: 44, alignment: .leading)
                    Text(entry.host ?? "(no host)")
                        .font(.callout)
                        .foregroundStyle(hostTint)
                        .lineLimit(1)
                }
                Text(entry.path ?? "/")
                    .font(.caption2.monospaced())
                    .foregroundStyle(pathTint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if let src = entry.src, !src.isEmpty {
                Text(src)
                    .font(.caption2.monospaced())
                    .foregroundStyle(srcHot?.color ?? .secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var hostTint: Color {
        if let sev = dstHot ?? srcHot { return sev.color }
        if let brand = Theme.brand(for: entry.host) { return brand }
        return .primary
    }

    private var methodTint: Color {
        switch (entry.method ?? "").uppercased() {
        case "GET":    return .phosphorTeal
        case "POST":   return .alertHotWarn
        case "DELETE", "PUT", "PATCH": return .alertHotWarn
        default:       return .secondary
        }
    }

    private var pathTint: Color {
        if isAttackPath { return .alertHotCrit }
        return .secondary
    }

    private var isSuspect: Bool { isAttackPath || dstHot == .crit || srcHot == .crit }

    /// Heuristic: classic recon / exploit-trail signatures. Mirrors
    /// what sloth's HTTP_ATTACK_PATH rule looks for so a row gets
    /// colour even before sloth flags it via an alert.
    private var isAttackPath: Bool {
        let p = (entry.path ?? "").lowercased()
        if p.isEmpty { return false }
        let needles = [".git/", ".env", "/wp-admin", "/wp-login", "/.aws/",
                       "/phpmyadmin", "/admin/config", "..%2f", "/etc/passwd"]
        return needles.contains { p.contains($0) }
    }

    private var a11y: String {
        let m = entry.method ?? "request"
        let h = entry.host ?? "no host"
        let p = entry.path ?? "/"
        return "\(m) \(h) path \(p)"
    }
}

private extension HTTPEntry {
    var identityKey: String {
        "\(ts)-\(src ?? "")-\(host ?? "")-\(method ?? "")-\(path ?? "")"
    }
}
