// DebugLogView — temporary merged log of every record in the store.
// Lives between M2 (when the store landed) and M3+ (when per-category
// views replace it). The view reads only from `SlothStore`; ring
// caps and dedup happen at the store layer.

import SwiftUI
import SlothCore

struct DebugLogView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let rows = merged
        if rows.isEmpty {
            ContentUnavailableView(
                "No records",
                systemImage: "waveform.path.ecg",
                description: Text("Records appear here once the sloth socket starts streaming.")
            )
        } else {
            ScrollViewReader { proxy in
                List(rows) { row in
                    DebugLogRow(row: row).id(row.id)
                }
                .listStyle(.plain)
                .onChange(of: rows.first?.id) { _, newest in
                    if let newest { proxy.scrollTo(newest, anchor: .top) }
                }
            }
        }
    }

    private var merged: [DebugLogRow.Row] {
        var out: [DebugLogRow.Row] = []
        out.reserveCapacity(
            store.dns.count + store.tls.count + store.quic.count +
            store.http.count + store.ntp.count + store.icmp.count +
            store.alerts.count
        )
        out.append(contentsOf: store.dns.map   { DebugLogRow.Row(typeTag: "dns",   ts: $0.ts, summary: summary(dns: $0)) })
        out.append(contentsOf: store.tls.map   { DebugLogRow.Row(typeTag: "tls",   ts: $0.ts, summary: summary(tls: $0)) })
        out.append(contentsOf: store.quic.map  { DebugLogRow.Row(typeTag: "quic",  ts: $0.ts, summary: summary(quic: $0)) })
        out.append(contentsOf: store.http.map  { DebugLogRow.Row(typeTag: "http",  ts: $0.ts, summary: summary(http: $0)) })
        out.append(contentsOf: store.ntp.map   { DebugLogRow.Row(typeTag: "ntp",   ts: $0.ts, summary: summary(ntp: $0)) })
        out.append(contentsOf: store.icmp.map  { DebugLogRow.Row(typeTag: "icmp",  ts: $0.ts, summary: summary(icmp: $0)) })
        out.append(contentsOf: store.alerts.map { DebugLogRow.Row(
            typeTag: "alert", ts: $0.lastSeen,
            summary: "[\($0.severity.displayName)] \($0.title) ×\($0.hits)",
            severity: $0.severity
        )})
        return out.sorted { $0.ts > $1.ts }
    }

    private func summary(dns e: DNSEntry) -> String {
        let answer = e.answer.map { " → \($0)" } ?? ""
        return "\(e.qname) \(e.qtype ?? "")\(answer)"
    }
    private func summary(tls  e: TLSEntry)  -> String { "\(e.sni ?? "?") \(e.version ?? "") → \(e.dst ?? "?")" }
    private func summary(quic e: QUICEntry) -> String { "\(e.sni ?? "?") \(e.version ?? "") → \(e.dst ?? "?")" }
    private func summary(http e: HTTPEntry) -> String { "\(e.method ?? "") \(e.host ?? "?")\(e.path ?? "")" }
    private func summary(ntp  e: NTPEntry)  -> String { "stratum \(e.stratum.map(String.init) ?? "?") → \(e.dst ?? "?")" }
    private func summary(icmp e: ICMPEntry) -> String { "type \(e.icmpType.map(String.init) ?? "?") → \(e.dst ?? "?")" }
}

struct DebugLogRow: View {

    struct Row: Identifiable, Equatable {
        let typeTag: String
        let ts: Int
        let summary: String
        let severity: AlertSeverity?

        init(typeTag: String, ts: Int, summary: String, severity: AlertSeverity? = nil) {
            self.typeTag = typeTag
            self.ts = ts
            self.summary = summary
            self.severity = severity
        }

        // Composite id keeps SwiftUI happy across re-renders without
        // a UUID per row (which would break diff stability).
        var id: String { "\(typeTag)-\(ts)-\(summary.hashValue)" }
    }

    let row: Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.typeTag.uppercased())
                .font(.caption2.monospaced().weight(.semibold))
                .frame(width: 44, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(row.summary)
                .font(.callout.monospaced())
                .fontWeight(row.severity?.prefersBold == true ? .semibold : .regular)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }
}
