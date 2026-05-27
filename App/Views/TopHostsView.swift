// TopHostsView — M4. List of the most-active external hosts pulled
// from the store's rings via `HostAggregator`. Each row carries an
// inline activity sparkline (`BandwidthSparkline`); tapping pushes
// `TopHostDetailView`. Top-of-list a stacked-area chart shows the
// aggregate activity over the last 30 minutes split by protocol so
// the operator can see "is this DNS noise, TLS browsing, or QUIC
// streaming?" at a glance.

import SwiftUI
import Charts
import SlothCore

struct TopHostsView: View {

    @Environment(SlothStore.self) private var store

    @State private var tick: Date = Date()
    private let tickPublisher = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        let snap = HostAggregator.snapshot(from: store, now: tick)
        Group {
            if snap.hosts.isEmpty {
                ContentUnavailableView(
                    "No external hosts yet",
                    systemImage: "globe.americas",
                    description: Text(
                        "Hosts your network is talking to show up here as records arrive. " +
                        "RFC1918 / loopback / multicast addresses are skipped."
                    )
                )
            } else {
                List {
                    Section {
                        ProtocolStackChart(hosts: snap.hosts)
                            .frame(height: 90)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12,
                                                       bottom: 8, trailing: 12))
                            .listRowSeparator(.hidden)
                    } header: {
                        Text("Aggregate activity, last 30 minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        ForEach(snap.hosts) { host in
                            NavigationLink {
                                TopHostDetailView(host: host)
                            } label: {
                                TopHostRow(host: host, hotSev: store.alertHot.severity(for: host.ip))
                            }
                        }
                    } header: {
                        Text("\(snap.hosts.count) hosts").font(.caption)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Top hosts")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(tickPublisher) { tick = $0 }
    }
}

// MARK: - Row

private struct TopHostRow: View {
    let host: HostActivity
    let hotSev: AlertSeverity?

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
                HStack(spacing: 6) {
                    Text(host.ip)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let hot = hotSev {
                        Text(hot.displayName)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(hot.color)
                    }
                }
            }

            Spacer(minLength: 8)

            BandwidthSparkline(
                samples: host.rateSamples,
                tint: hotSev?.color
            )
            .frame(width: 90, height: 28)

            Text("\(host.totalRecords)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var displayName: String {
        host.hostname ?? host.ip
    }

    private var nameTint: Color {
        if let hot = hotSev          { return hot.color }
        if let brand = Theme.brand(for: host.hostname) { return brand }
        return .primary
    }

    private var leadingIcon: String {
        if hotSev != nil               { return "flame.fill" }
        if host.hostname != nil        { return "globe" }
        return "questionmark.diamond"
    }

    private var leadingTint: Color {
        if let hot = hotSev { return hot.color }
        return .secondary
    }

    private var a11y: String {
        var parts: [String] = []
        parts.append(displayName)
        parts.append("\(host.totalRecords) records observed")
        if let hot = hotSev { parts.append("Flagged \(hot.displayName) by alert engine") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Aggregate chart

private struct ProtocolStackChart: View {
    let hosts: [HostActivity]

    var body: some View {
        // Sum the per-bin samples across hosts, split by source
        // protocol via per-protocol record counts. We re-bin from
        // the per-host totals since the per-protocol per-bin data
        // isn't held by HostActivity (would balloon storage); the
        // overall shape across protocols is preserved by weighting
        // each host's bins by its per-protocol share of total.
        let series = aggregateSeries(hosts: hosts)
        Chart(series) { point in
            AreaMark(
                x: .value("Bin", point.bin),
                y: .value("Count", point.count)
            )
            .foregroundStyle(by: .value("Protocol", point.proto))
            .interpolationMethod(.monotone)
        }
        .chartForegroundStyleScale([
            "TLS":  Color.phosphorBright,
            "QUIC": Color.alertHotLow,
            "DNS":  Color.phosphorTeal,
            "HTTP": Color.alertHotWarn,
        ])
        .chartLegend(position: .bottom, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(["TLS","QUIC","DNS","HTTP"], id: \.self) { label in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(legendColor(for: label))
                            .frame(width: 6, height: 6)
                        Text(label)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private func legendColor(for label: String) -> Color {
        switch label {
        case "TLS":  return .phosphorBright
        case "QUIC": return .alertHotLow
        case "DNS":  return .phosphorTeal
        case "HTTP": return .alertHotWarn
        default:     return .secondary
        }
    }

    private struct Point: Identifiable {
        let id = UUID()
        let bin: Int
        let proto: String
        let count: Double
    }

    private func aggregateSeries(hosts: [HostActivity]) -> [Point] {
        let bins = HostAggregator.sparkBins
        var out: [Point] = []
        for proto in ["TLS","QUIC","DNS","HTTP"] {
            for i in 0..<bins {
                var sum: Double = 0
                for h in hosts {
                    guard i < h.rateSamples.count else { continue }
                    let total = max(h.totalRecords, 1)
                    let share: Double
                    switch proto {
                    case "TLS":  share = Double(h.tlsCount)  / Double(total)
                    case "QUIC": share = Double(h.quicCount) / Double(total)
                    case "DNS":  share = Double(h.dnsCount)  / Double(total)
                    case "HTTP": share = Double(h.httpCount) / Double(total)
                    default:     share = 0
                    }
                    sum += h.rateSamples[i] * share
                }
                out.append(Point(bin: i, proto: proto, count: sum))
            }
        }
        return out
    }
}
