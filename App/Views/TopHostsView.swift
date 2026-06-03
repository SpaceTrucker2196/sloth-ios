// TopHostsView — reads sloth's `top_host` snapshot directly.
//
// Sloth's `src/top_hosts.c` is the authoritative source: it filters
// for external-routable IPs, attaches the owner tag from
// `src/ip_owner.c`, and emits one record per active entry per tick.
// The iOS store replaces in place by IP and appends to a per-IP rate
// tail so this view can paint a sparkline without recomputing
// anything.
//
// Sort: combined live byte rate (rx + tx), descending. Hosts that
// stop being emitted by sloth simply stop appearing in the snapshot
// table — there's no client-side eviction policy.

import SwiftUI
import Charts
import SlothCore

struct TopHostsView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let hosts = sortedHosts
        Group {
            if hosts.isEmpty {
                ContentUnavailableView(
                    "No top hosts yet",
                    systemImage: "globe.americas",
                    description: Text("Sloth emits one `top_host` record per active external destination per second. Records appear as the stream opens.")
                )
            } else {
                List {
                    Section {
                        BandwidthMixChart(hosts: hosts.prefix(5).map { $0 },
                                          rxSamples: store.topHostRxSamples,
                                          txSamples: store.topHostTxSamples)
                            .frame(height: 100)
                            .listRowSeparator(.hidden)
                    } header: {
                        Text("Combined rate — top 5, last \(store.sizes.topHostSamples)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        ForEach(hosts) { host in
                            NavigationLink {
                                TopHostDetailView(host: host)
                            } label: {
                                TopHostRow(
                                    host:       host,
                                    rxSamples:  store.topHostRxSamples[host.ip] ?? [],
                                    txSamples:  store.topHostTxSamples[host.ip] ?? [],
                                    hotSev:     store.alertHot.severity(for: host.ip)
                                )
                            }
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("\(hosts.count) external hosts").font(.caption)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Top hosts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedHosts: [TopHostEntry] {
        store.topHosts.values.sorted { lhs, rhs in
            if lhs.totalRate != rhs.totalRate { return lhs.totalRate > rhs.totalRate }
            if lhs.connCount != rhs.connCount { return lhs.connCount > rhs.connCount }
            return lhs.ip < rhs.ip
        }
    }
}

// MARK: - Row

private struct TopHostRow: View {

    let host:       TopHostEntry
    let rxSamples:  [Double]
    let txSamples:  [Double]
    let hotSev:     AlertSeverity?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: leadingIcon)
                .foregroundStyle(leadingTint)
                .imageScale(.small)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.callout)
                    .fontWeight(hotSev?.prefersBold == true ? .semibold : .regular)
                    .foregroundStyle(nameTint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(host.ip)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let owner = host.owner, !owner.isEmpty {
                        Text("· \(owner)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.phosphorTeal)
                    }
                }
                Text(rateLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                BandwidthSparkline(samples: combinedSamples, tint: hotSev?.color)
                    .frame(width: 90, height: 24)
                Text("\(host.connCount) conn")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var combinedSamples: [Double] {
        zip(rxSamples, txSamples).map(+)
    }

    private var displayName: String {
        host.hostname?.nilIfEmpty ?? host.ip
    }

    private var nameTint: Color {
        if let hot = hotSev                            { return hot.color }
        if let brand = Theme.brand(for: host.hostname) { return brand    }
        return .primary
    }

    private var leadingIcon: String {
        if hotSev != nil               { return "flame.fill" }
        if host.hostname != nil        { return "globe" }
        return "questionmark.diamond"
    }

    private var leadingTint: Color {
        hotSev?.color ?? .secondary
    }

    private var rateLine: String {
        "↓ \(formatRate(host.rxRate))  ↑ \(formatRate(host.txRate))"
    }

    private var a11y: String {
        var parts: [String] = [displayName]
        parts.append("\(host.connCount) connections")
        parts.append("receiving \(formatRate(host.rxRate))")
        parts.append("sending \(formatRate(host.txRate))")
        if let hot = hotSev { parts.append("flagged \(hot.displayName)") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Aggregate chart

/// Per-host combined-rate area chart for the top N. Reads the
/// per-IP rate sample tails that the store already maintains —
/// nothing aggregates here, the data is already shaped.
private struct BandwidthMixChart: View {

    let hosts: [TopHostEntry]
    let rxSamples: [String: [Double]]
    let txSamples: [String: [Double]]

    var body: some View {
        let points = makePoints()
        Chart(points) { point in
            AreaMark(
                x: .value("Bin", point.bin),
                y: .value("B/s", point.value)
            )
            .foregroundStyle(by: .value("Host", point.label))
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(position: .bottom, spacing: 4)
    }

    private struct Point: Identifiable {
        let id = UUID()
        let bin: Int
        let label: String
        let value: Double
    }

    private func makePoints() -> [Point] {
        var out: [Point] = []
        for h in hosts {
            let rx = rxSamples[h.ip] ?? []
            let tx = txSamples[h.ip] ?? []
            let combined = zip(rx, tx).map(+)
            let label = h.hostname?.nilIfEmpty ?? h.ip
            for (i, v) in combined.enumerated() {
                out.append(Point(bin: i, label: label, value: v))
            }
        }
        return out
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// File-private bytes/sec → human-readable. Mirrors the formatter
/// in `InterfacesView`; small enough that duplicating beats hoisting
/// to a shared helper file (three call sites, three lines each).
fileprivate func formatRate(_ bps: Double) -> String {
    switch bps {
    case ..<1_000:         return "\(Int(bps.rounded())) B/s"
    case ..<1_000_000:     return String(format: "%.1f KB/s", bps / 1_000)
    case ..<1_000_000_000: return String(format: "%.2f MB/s", bps / 1_000_000)
    default:               return String(format: "%.2f GB/s", bps / 1_000_000_000)
    }
}
