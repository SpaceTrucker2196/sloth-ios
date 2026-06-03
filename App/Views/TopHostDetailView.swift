// TopHostDetailView — drill-down for a single `top_host` entry.
// Surfaces real byte counters (rx/tx_bytes) and rates that sloth
// computes server-side, plus a tail-derived sparkline and the small
// auxiliary panes (related DNS qnames, JA3 fingerprints) which still
// come from the per-protocol log rings on the iOS side.

import SwiftUI
import Charts
import SlothCore

struct TopHostDetailView: View {

    let host: TopHostEntry

    @Environment(SlothStore.self) private var store

    private var hotSev: AlertSeverity? {
        store.alertHot.severity(for: host.ip)
    }

    var body: some View {
        Form {
            headerSection
            ratesSection
            volumesSection
            if !relatedQNames.isEmpty {
                Section("Recent DNS qnames") {
                    ForEach(relatedQNames, id: \.self) { qname in
                        Text(qname)
                            .font(.caption)
                            .foregroundStyle(Theme.brand(for: qname) ?? .primary)
                    }
                }
            }
            if !ja3Fingerprints.isEmpty {
                Section("JA3 fingerprints observed (\(ja3Fingerprints.count))") {
                    ForEach(ja3Fingerprints, id: \.self) { ja3 in
                        Text(ja3.prefix(20) + (ja3.count > 20 ? "…" : ""))
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.ja3Color(ja3))
                    }
                }
            }
        }
        .navigationTitle(host.hostname?.nilIfEmpty ?? host.ip)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.hostname?.nilIfEmpty ?? host.ip)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(nameTint)
                    HStack(spacing: 6) {
                        Text(host.ip)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                        if let owner = host.owner, !owner.isEmpty {
                            Text("· \(owner)")
                                .font(.subheadline.monospaced())
                                .foregroundStyle(.phosphorTeal)
                        }
                    }
                }
                Spacer()
                if let hot = hotSev {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: hot.symbolName).foregroundStyle(hot.color)
                        Text(hot.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(hot.color)
                    }
                }
            }
        }
    }

    private var ratesSection: some View {
        Section("Bandwidth — last \(store.sizes.topHostSamples)s") {
            BandwidthSparkline(
                samples: combinedSamples,
                tint: hotSev?.color
            )
            .frame(height: 80)
            .padding(.vertical, 4)

            LabeledContent("Current ↓") { Text(formatRate(host.rxRate)).font(.callout.monospacedDigit()) }
            LabeledContent("Current ↑") { Text(formatRate(host.txRate)).font(.callout.monospacedDigit()) }
        }
    }

    private var volumesSection: some View {
        Section("Totals") {
            LabeledContent("Connections") { Text("\(host.connCount)").font(.callout.monospacedDigit()) }
            LabeledContent("Received")    { Text(formatBytes(host.rxBytes)).font(.callout.monospacedDigit()) }
            LabeledContent("Sent")        { Text(formatBytes(host.txBytes)).font(.callout.monospacedDigit()) }
            LabeledContent("First seen")  { Text(absolute(host.firstSeen)) }
            LabeledContent("Last seen")   { Text(absolute(host.lastSeen)) }
        }
    }

    // MARK: - Derived data

    private var nameTint: Color {
        if let hot = hotSev { return hot.color }
        if let brand = Theme.brand(for: host.hostname) { return brand }
        return .primary
    }

    private var combinedSamples: [Double] {
        let rx = store.topHostRxSamples[host.ip] ?? []
        let tx = store.topHostTxSamples[host.ip] ?? []
        return zip(rx, tx).map(+)
    }

    /// DNS qnames that resolved to this IP. Reads the DNS log ring;
    /// O(ring size) scan triggered by view appearance. Newest first,
    /// capped at 8 so a chatty cloud host doesn't blow up the form.
    private var relatedQNames: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for d in store.dns.reversed() {
            guard d.answer == host.ip else { continue }
            if seen.insert(d.qname).inserted {
                out.append(d.qname)
                if out.count >= 8 { break }
            }
        }
        return out
    }

    /// Distinct JA3 fingerprints observed in TLS records destined for
    /// this IP. Same ring-scan pattern as `relatedQNames`.
    private var ja3Fingerprints: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for t in store.tls.reversed() {
            guard t.dst == host.ip, let ja3 = t.ja3, !ja3.isEmpty else { continue }
            if seen.insert(ja3).inserted {
                out.append(ja3)
                if out.count >= 12 { break }
            }
        }
        return out
    }

    // MARK: - Formatters

    private func absolute(_ ts: Int) -> String {
        guard ts > 0 else { return "—" }
        return Date(timeIntervalSince1970: TimeInterval(ts))
            .formatted(date: .abbreviated, time: .standard)
    }

    private func formatRate(_ bps: Double) -> String {
        switch bps {
        case ..<1_000:         return "\(Int(bps.rounded())) B/s"
        case ..<1_000_000:     return String(format: "%.1f KB/s", bps / 1_000)
        case ..<1_000_000_000: return String(format: "%.2f MB/s", bps / 1_000_000)
        default:               return String(format: "%.2f GB/s", bps / 1_000_000_000)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let v = Double(bytes)
        switch v {
        case ..<1_024:                       return "\(bytes) B"
        case ..<(1_024 * 1_024):             return String(format: "%.1f KiB", v / 1_024)
        case ..<(1_024 * 1_024 * 1_024):     return String(format: "%.2f MiB", v / (1_024 * 1_024))
        default:                             return String(format: "%.2f GiB", v / (1_024 * 1_024 * 1_024))
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
