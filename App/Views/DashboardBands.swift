// DashboardBands — the wide bands of the iPad Tufte dashboard:
// Interfaces + Summary, the CRIT alerts band, Connections + Top
// hosts, and the Packets tail. Mirrors sloth's dashboard_bands.c.
// The thirds / halves panels live in DashboardGrid.swift.

import SwiftUI
import SlothCore

// MARK: - Interfaces (flex) + Summary (fixed right column)

struct IfaceSummaryBand: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                BandTitle(label: "INTERFACES", count: store.ifaces.count,
                          route: .interfaces)
                if store.ifaces.isEmpty {
                    QuietRow(text: "no iface records yet")
                } else {
                    ForEach(store.ifaces.keys.sorted(), id: \.self) { name in
                        if let iface = store.ifaces[name] {
                            IfaceRow(
                                iface: iface,
                                rx: store.ifaceRxSamples[name] ?? [],
                                tx: store.ifaceTxSamples[name] ?? []
                            )
                        }
                    }
                }
            }
            ColumnRule()
            SummaryPanel()
                .frame(width: 190)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct IfaceRow: View {

    let iface: IFaceEntry
    let rx: [Double]
    let tx: [Double]

    var body: some View {
        HStack(spacing: 8) {
            Text(iface.name)
                .font(.phosphor(.caption2, weight: .semibold))
                .foregroundStyle(.phosphorBright)
                .frame(width: 64, alignment: .leading)
            Text("↓" + DashFormat.rate(iface.rxRate))
                .dashValue()
                .frame(width: 76, alignment: .trailing)
            BandwidthSparkline(samples: rx, tint: .phosphorTeal)
                .frame(width: 64, height: 13)
            Text("↑" + DashFormat.rate(iface.txRate))
                .dashValue()
                .frame(width: 76, alignment: .trailing)
            BandwidthSparkline(samples: tx, tint: .alertHotLow)
                .frame(width: 64, height: 13)
            if iface.rxErrors + iface.rxDrops + iface.txErrors + iface.txDrops > 0 {
                Text("errs \(iface.rxErrors + iface.txErrors)/drops \(iface.rxDrops + iface.txDrops)")
                    .font(.phosphor(.caption2))
                    .foregroundStyle(.alertHotWarn)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }
}

/// Right column of the top band — the TUI's stats panel: one glance
/// tells the operator how much of the network sloth currently sees.
private struct SummaryPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BandTitle(label: "SUMMARY")
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                row("conns",   store.connections.isEmpty ? 0
                             : ConnectionsAggregator.snapshot(from: store.connections).count)
                row("hosts",   store.topHosts.count)
                row("devices", store.devices.count)
                row("procs",   store.processes.count)
                row("aps",     store.beacons.count + store.wifiAPs.count)
                row("alerts",  store.alerts.count)
            }
        }
    }

    private func row(_ label: String, _ value: Int) -> some View {
        GridRow {
            Text(label).dashStamp()
            Text("\(value)")
                .font(.phosphor(.caption2, weight: .semibold))
                .foregroundStyle(value > 0 ? .phosphorTeal : Color.phosphorDim)
                .gridColumnAlignment(.trailing)
        }
    }
}

// MARK: - CRIT alerts (full width, eye level)

struct CritAlertsBand: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let crits = DashboardRoster.critAlerts(store.alerts)
        VStack(alignment: .leading, spacing: 4) {
            BandTitle(label: "CRITICAL", count: crits.count, route: .alerts,
                      tint: crits.isEmpty ? .phosphorDim : .alertHotCrit)
            if crits.isEmpty {
                QuietRow(text: "no critical alerts")
            } else {
                ForEach(Array(crits.enumerated()), id: \.offset) { _, alert in
                    CritRow(alert: alert)
                }
            }
        }
    }
}

private struct CritRow: View {

    let alert: AlertEntry

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.alertHotCrit).frame(width: 3, height: 12)
            Text(alert.title)
                .font(.phosphor(.caption2, weight: .bold))
                .foregroundStyle(.alertHotCrit)
            if let detail = alert.detail {
                Text(detail).dashValue().truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if alert.hits > 1 {
                Text("\(alert.hits)×").dashValue()
            }
            if let ip = alert.matchIP {
                HotIPText(ip: ip, hot: .crit)
            }
            Text(DashFormat.clock(alert.lastSeen)).dashStamp()
        }
        .lineLimit(1)
    }
}

// MARK: - Connections (flex) + Top hosts (fixed right column)

struct ConnsHostsBand: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let flows = Array(ConnectionsAggregator
            .snapshot(from: store.connections).prefix(8))
        let hosts = DashboardRoster.topHosts(store.topHosts)
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                BandTitle(label: "CONNECTIONS", count: flows.count,
                          route: .connections)
                if flows.isEmpty {
                    QuietRow(text: "no flows on the wire")
                } else {
                    ForEach(flows) { FlowRow(flow: $0) }
                }
            }
            ColumnRule()
            VStack(alignment: .leading, spacing: 3) {
                BandTitle(label: "TOP HOSTS", count: hosts.count,
                          route: .topHosts)
                if hosts.isEmpty {
                    QuietRow(text: "no external hosts yet")
                } else {
                    // Heat is relative to the *panel's* max (per the
                    // charts convention), not each row's own peak —
                    // so ink intensity ranks the hosts at a glance
                    // and only the busiest rows run hot.
                    let panelMax = hosts.map(\.totalRate).max() ?? 0
                    ForEach(hosts) { host in
                        TopHostRow(
                            host: host,
                            samples: summedSamples(for: host.ip),
                            tint: panelMax > 0
                                ? Color.heat(host.totalRate / panelMax)
                                : .heatLo
                        )
                    }
                }
            }
            .frame(width: 330)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// rx + tx tails are appended in lockstep on each `top_host`
    /// snapshot; the board shows their sum (one trace per host).
    private func summedSamples(for ip: String) -> [Double] {
        let rx = store.topHostRxSamples[ip] ?? []
        let tx = store.topHostTxSamples[ip] ?? []
        if tx.isEmpty { return rx }
        if rx.isEmpty { return tx }
        return zip(rx, tx).map(+)
    }
}

private struct FlowRow: View {

    @Environment(SlothStore.self) private var store
    let flow: ConnectionFlow

    var body: some View {
        HStack(spacing: 6) {
            HotIPText(ip: flow.latest.src,
                      hot: store.alertHot.severity(for: flow.latest.src))
                .frame(minWidth: 130, alignment: .leading)
            Text("→").dashStamp()
            HotIPText(ip: flow.latest.dst,
                      hot: store.alertHot.severity(for: flow.latest.dst))
                .frame(minWidth: 130, alignment: .leading)
            Text(flow.latest.proto.rawValue.uppercased()).dashStamp()
            if let state = flow.latest.state {
                Text(state).dashValue()
            }
            Spacer(minLength: 4)
            if let rtt = flow.latest.rttMS {
                Text(String(format: "%.0fms", rtt)).dashValue()
            }
            Text("↓" + DashFormat.bytes(flow.latest.rxBytes)).dashValue()
            Text("↑" + DashFormat.bytes(flow.latest.txBytes)).dashValue()
        }
        .lineLimit(1)
    }
}

private struct TopHostRow: View {

    @Environment(SlothStore.self) private var store
    let host: TopHostEntry
    let samples: [Double]
    let tint: Color

    var body: some View {
        let hot = store.alertHot.severity(for: host.ip)
        HStack(spacing: 6) {
            Text(host.hostname ?? host.ip)
                .font(.phosphor(.caption2,
                                weight: (hot == .warn || hot == .crit) ? .bold : .regular))
                .foregroundStyle(hot?.color ?? Theme.brand(for: host.hostname) ?? .phosphorTeal)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            BandwidthSparkline(samples: samples, tint: tint)
                .frame(width: 64, height: 13)
            Text(DashFormat.rate(host.totalRate))
                .dashValue()
                .frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
    }
}

// MARK: - Packets tail (full width, bottom)

struct PacketsBand: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let tail = DashboardRoster.packetTail(store.packets)
        VStack(alignment: .leading, spacing: 3) {
            BandTitle(label: "PACKETS", count: store.packets.count,
                      route: .packets)
            if tail.isEmpty {
                QuietRow(text: "no packets on the wire")
            } else {
                ForEach(Array(tail.enumerated()), id: \.offset) { _, pkt in
                    PacketRowLine(pkt: pkt)
                }
            }
        }
    }
}

private struct PacketRowLine: View {

    @Environment(SlothStore.self) private var store
    let pkt: PacketEntry

    var body: some View {
        HStack(spacing: 6) {
            Text(DashFormat.clock(pkt.ts)).dashStamp()
            HotIPText(ip: endpoint(pkt.src, pkt.srcPort),
                      hot: store.alertHot.severity(for: pkt.src))
                .frame(minWidth: 150, alignment: .leading)
            Text("→").dashStamp()
            HotIPText(ip: endpoint(pkt.dst, pkt.dstPort),
                      hot: store.alertHot.severity(for: pkt.dst))
                .frame(minWidth: 150, alignment: .leading)
            Text(pkt.proto?.uppercased() ?? "—").dashStamp()
            Text("\(pkt.len)B").dashValue()
            if let info = pkt.info {
                Text(info).dashValue().truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    private func endpoint(_ ip: String, _ port: Int?) -> String {
        guard let port else { return ip }
        return "\(ip):\(port)"
    }
}
