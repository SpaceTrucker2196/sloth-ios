// HomeView — at-a-glance home screen mirroring sloth's dashboard
// top row (`docs/views/dashboard.md`): the "Connections" panel on
// the left and the "Top hosts" panel on the right, split 60/40.
//
// On iPhone (compact horizontal size class) the two panels stack
// vertically; iPad still gets `DashboardView` from `ContentView`
// (which already composes both as part of its 3×2 grid).
//
// Each section's trailing "All" button pushes the corresponding
// full-featured view (`TopHostsView`, `ConnectionsView`) for filter
// / sort / drill-down. Row taps push the per-host / per-flow
// detail views directly.

import SwiftUI
import SlothCore

struct HomeView: View {

    @Environment(SlothStore.self) private var store

    @State private var tick: Date = Date()
    private let tickPublisher = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            HomeTopHostsSection(tick: tick)
            HomeConnectionsSection()
        }
        .listStyle(.plain)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(tickPublisher) { tick = $0 }
    }
}

// MARK: - Top hosts section

private struct HomeTopHostsSection: View {

    @Environment(SlothStore.self) private var store
    let tick: Date

    /// Cap mirrors what fits comfortably above the fold on iPhone
    /// without pushing the connections list off-screen.
    private let visibleCount = 6

    var body: some View {
        let snap = HostAggregator.snapshot(from: store, now: tick)
        Section {
            if snap.hosts.isEmpty {
                emptyRow
            } else {
                ForEach(snap.hosts.prefix(visibleCount)) { host in
                    NavigationLink {
                        TopHostDetailView(host: host)
                    } label: {
                        HomeHostRow(
                            host:   host,
                            hotSev: store.alertHot.severity(for: host.ip)
                        )
                    }
                }
            }
        } header: {
            HomeSectionHeader(
                title: "Top hosts",
                systemImage: "globe.americas",
                trailing: "All"
            ) {
                TopHostsView()
            }
        }
    }

    private var emptyRow: some View {
        Text("No external hosts yet — DNS / TLS / HTTP / QUIC traffic populates this list.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

// MARK: - Connections section

private struct HomeConnectionsSection: View {

    @Environment(SlothStore.self) private var store

    private let visibleCount = 10

    var body: some View {
        let flows = ConnectionsAggregator
            .snapshot(from: store.connections, sort: .bandwidth)
            .prefix(visibleCount)
        Section {
            if flows.isEmpty {
                emptyRow
            } else {
                ForEach(Array(flows)) { flow in
                    NavigationLink {
                        ConnectionDetailView(flow: flow)
                    } label: {
                        HomeConnectionRow(
                            flow:   flow,
                            srcHot: store.alertHot.severity(for: flow.latest.src),
                            dstHot: store.alertHot.severity(for: flow.latest.dst)
                        )
                    }
                }
            }
        } header: {
            HomeSectionHeader(
                title: "Connections",
                systemImage: "point.3.connected.trianglepath.dotted",
                trailing: "All"
            ) {
                ConnectionsView()
            }
        }
    }

    private var emptyRow: some View {
        Text("No active flows — `connections` records show up here as sloth emits them.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

// MARK: - Section header with "All →" trailing link

private struct HomeSectionHeader<Destination: View>: View {

    let title: String
    let systemImage: String
    let trailing: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        HStack(spacing: 6) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            NavigationLink(trailing, destination: destination)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.phosphorTeal)
        }
        .textCase(nil)
    }
}

// MARK: - Compact rows

private struct HomeHostRow: View {

    let host: HostActivity
    let hotSev: AlertSeverity?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: leadingIcon)
                .foregroundStyle(leadingTint)
                .imageScale(.small)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.hostname ?? host.ip)
                    .font(.callout)
                    .fontWeight(hotSev?.prefersBold == true ? .semibold : .regular)
                    .foregroundStyle(nameTint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(host.ip)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            BandwidthSparkline(
                samples: host.rateSamples,
                tint:    hotSev?.color
            )
            .frame(width: 64, height: 22)

            Text("\(host.totalRecords)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private var nameTint: Color {
        if let hot = hotSev                            { return hot.color }
        if let brand = Theme.brand(for: host.hostname) { return brand    }
        return .primary
    }

    private var leadingIcon: String {
        if hotSev != nil            { return "flame.fill" }
        if host.hostname != nil     { return "globe" }
        return "questionmark.diamond"
    }

    private var leadingTint: Color {
        hotSev?.color ?? .secondary
    }
}

private struct HomeConnectionRow: View {

    let flow:   ConnectionFlow
    let srcHot: AlertSeverity?
    let dstHot: AlertSeverity?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: protoIcon)
                .foregroundStyle(protoTint)
                .imageScale(.small)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(flow.latest.src)
                        .foregroundStyle(srcHot?.color ?? .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(flow.latest.dst)
                        .foregroundStyle(dstHot?.color ?? .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption.monospaced())

                HStack(spacing: 8) {
                    if let state = flow.latest.state {
                        Text(state)
                    }
                    Text(formatBytes(flow.totalBytes))
                    if let rtt = flow.latest.rttMS {
                        Text(String(format: "%.0fms", rtt))
                    }
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            RTTSparkline(samples: flow.rttSeries)
                .frame(width: 56, height: 22)
        }
        .padding(.vertical, 2)
    }

    private var protoIcon: String {
        switch flow.latest.proto {
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "dot.radiowaves.left.and.right"
        }
    }

    private var protoTint: Color {
        switch flow.latest.proto {
        case .tcp: return .phosphorTeal
        case .udp: return .phosphorBright
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(SlothStore())
}
