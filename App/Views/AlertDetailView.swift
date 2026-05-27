// AlertDetailView — push destination from AlertsView. Shows the full
// alert record + a "where else does this IP show up?" cross-reference
// block (DNS / TLS / HTTP rings, scanned for the alert's match_ip).

import SwiftUI
import SlothCore

struct AlertDetailView: View {

    let alert: AlertEntry

    @Environment(SlothStore.self) private var store

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: alert.severity.symbolName)
                        .foregroundStyle(alert.severity.color)
                    Text(alert.severity.displayName)
                        .font(.headline.monospaced())
                        .foregroundStyle(alert.severity.color)
                        .fontWeight(.bold)
                    Spacer()
                    if alert.hits >= 2 {
                        Text("×\(alert.hits) hits")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(alert.title)
                    .font(.title3.weight(.semibold))
                if let d = alert.detail, !d.isEmpty {
                    Text(d).font(.callout)
                }
            }

            Section("Timing") {
                LabeledContent("First seen", value: absolute(alert.firstSeen))
                LabeledContent("Last seen",  value: absolute(alert.lastSeen))
                LabeledContent("Span",       value: spanText)
            }

            Section("Identity") {
                if let k = alert.key { LabeledContent("Key", value: k) }
                if let ip = alert.matchIP, !ip.isEmpty {
                    LabeledContent("Match IP") {
                        Text(ip)
                            .font(.callout.monospaced())
                            .foregroundStyle(isMatchHot ? alert.severity.color : .primary)
                    }
                }
            }

            if let ip = alert.matchIP, !ip.isEmpty {
                let dnsHits  = dnsMatches(ip)
                let tlsHits  = tlsMatches(ip)
                let httpHits = httpMatches(ip)

                if !dnsHits.isEmpty || !tlsHits.isEmpty || !httpHits.isEmpty {
                    Section("Cross-references") {
                        if !dnsHits.isEmpty {
                            LabeledContent("DNS records", value: "\(dnsHits.count)")
                        }
                        if !tlsHits.isEmpty {
                            LabeledContent("TLS records", value: "\(tlsHits.count)")
                        }
                        if !httpHits.isEmpty {
                            LabeledContent("HTTP records", value: "\(httpHits.count)")
                        }
                    }
                }
            }
        }
        .navigationTitle(alert.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var spanText: String {
        let span = max(0, alert.lastSeen - alert.firstSeen)
        if span < 60 { return "\(span)s" }
        if span < 3600 { return "\(span / 60)m \(span % 60)s" }
        return "\(span / 3600)h \((span % 3600) / 60)m"
    }

    private var isMatchHot: Bool {
        guard let ip = alert.matchIP else { return false }
        return store.alertHot.severity(for: ip) != nil
    }

    private func absolute(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func dnsMatches(_ ip: String)  -> [DNSEntry]  {
        store.dns.filter { $0.src == ip || $0.answer == ip }
    }
    private func tlsMatches(_ ip: String)  -> [TLSEntry]  {
        store.tls.filter { $0.src == ip || $0.dst == ip }
    }
    private func httpMatches(_ ip: String) -> [HTTPEntry] {
        store.http.filter { $0.src == ip || $0.dst == ip }
    }
}
