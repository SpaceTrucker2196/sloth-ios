// TopHostDetailView — push destination from TopHostsView. Larger
// sparkline, per-protocol record breakdown, JA3 fingerprints observed
// for this host, and recent DNS qnames that resolved to this IP.

import SwiftUI
import Charts
import SlothCore

struct TopHostDetailView: View {

    let host: HostActivity

    @Environment(SlothStore.self) private var store

    private var hotSev: AlertSeverity? {
        store.alertHot.severity(for: host.ip)
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host.hostname ?? host.ip)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(nameTint)
                        Text(host.ip)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let hot = hotSev {
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: hot.symbolName)
                                .foregroundStyle(hot.color)
                            Text(hot.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(hot.color)
                        }
                    }
                }
            }

            Section("Activity (records / min, last 30 min)") {
                BandwidthSparkline(
                    samples: host.rateSamples,
                    tint: hotSev?.color
                )
                .frame(height: 80)
                .padding(.vertical, 4)

                LabeledContent("Total records", value: "\(host.totalRecords)")
                LabeledContent("First seen", value: absolute(host.firstSeen))
                LabeledContent("Last seen",  value: absolute(host.lastSeen))
            }

            Section("Per-protocol breakdown") {
                ProtocolBreakdownRow(label: "DNS",  count: host.dnsCount,  total: host.totalRecords)
                ProtocolBreakdownRow(label: "TLS",  count: host.tlsCount,  total: host.totalRecords)
                ProtocolBreakdownRow(label: "QUIC", count: host.quicCount, total: host.totalRecords)
                ProtocolBreakdownRow(label: "HTTP", count: host.httpCount, total: host.totalRecords)
            }

            if !host.ja3Fingerprints.isEmpty {
                Section("JA3 fingerprints (\(host.ja3Fingerprints.count))") {
                    ForEach(host.ja3Fingerprints, id: \.self) { ja3 in
                        Text(ja3.prefix(20) + (ja3.count > 20 ? "…" : ""))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            let qnames = relatedQNames
            if !qnames.isEmpty {
                Section("Recent DNS qnames") {
                    ForEach(qnames, id: \.self) { qname in
                        Text(qname)
                            .font(.caption)
                            .foregroundStyle(brandTint(for: qname) ?? .primary)
                    }
                }
            }
        }
        .navigationTitle(host.hostname ?? host.ip)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var nameTint: Color {
        if let hot = hotSev { return hot.color }
        if let brand = Theme.brand(for: host.hostname) { return brand }
        return .primary
    }

    private func brandTint(for hostname: String) -> Color? {
        Theme.brand(for: hostname)
    }

    private func absolute(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        return date.formatted(date: .abbreviated, time: .standard)
    }

    /// Distinct qnames in the DNS ring whose answer matches this host's
    /// IP. Newest first; capped at 8 so the section doesn't blow up
    /// the form on a chatty cloud host.
    private var relatedQNames: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for d in store.dns.reversed() {
            guard d.answer == host.ip else { continue }
            guard !seen.contains(d.qname) else { continue }
            seen.insert(d.qname)
            out.append(d.qname)
            if out.count >= 8 { break }
        }
        return out
    }
}

private struct ProtocolBreakdownRow: View {
    let label: String
    let count: Int
    let total: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.callout.monospaced())
                .frame(width: 56, alignment: .leading)
            ProgressView(value: total == 0 ? 0 : Double(count) / Double(total))
                .progressViewStyle(.linear)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
