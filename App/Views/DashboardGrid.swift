// DashboardGrid — the thirds / halves panels of the iPad Tufte
// dashboard: WiFi | Roaming | Beacons, mDNS | DHCP | SSDP,
// ARP | Deauth, DNS | ICMP. Mirrors sloth's dashboard_grid.c.
//
// Every panel is the same shape: BandTitle + up to N dense rows +
// a QuietRow when the table is empty. `GridPanel` owns that shape;
// the panels below only provide rows.

import SwiftUI
import SlothCore

/// Shared scaffold for the equal-column panels.
struct GridPanel<Rows: View>: View {

    let title: String
    var count: Int?            = nil
    var route: DashboardRoute? = nil
    var tint:  Color           = .phosphorDim
    let quiet: String
    let isEmpty: Bool
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            BandTitle(label: title, count: count, route: route, tint: tint)
            if isEmpty {
                QuietRow(text: quiet)
            } else {
                rows()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private let gridRowCap = 4

// MARK: - RF row (WiFi | Roaming | Beacons)

struct WiFiPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let aps = DashboardRoster.newest(store.wifiAPs.values,
                                         stamp: { $0.ts }, id: { $0.bssid },
                                         limit: gridRowCap)
        GridPanel(title: "WIFI", count: store.wifiAPs.count, route: .wifi,
                  quiet: "no scan results", isEmpty: aps.isEmpty) {
            ForEach(aps) { ap in
                HStack(spacing: 6) {
                    Text(ap.ssid ?? ap.bssid).dashIdentity()
                        .fontWeight(ap.isConnected ? .bold : .regular)
                    Spacer(minLength: 4)
                    if let ch = ap.channel  { Text("ch\(ch)").dashValue() }
                    if let s = ap.signalDBM { SignalText(dbm: s) }
                }
                .lineLimit(1)
            }
        }
    }
}

struct RoamingPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let clients = DashboardRoster.newest(store.probeClients.values,
                                             stamp: { $0.lastSeen }, id: { $0.mac },
                                             limit: gridRowCap)
        GridPanel(title: "ROAMING", count: store.probeClients.count, route: .wifi,
                  quiet: "no probe requests", isEmpty: clients.isEmpty) {
            ForEach(clients) { c in
                HStack(spacing: 6) {
                    Text(c.mac).dashIdentity()
                    Text(c.ssid ?? "(any)").dashValue()
                    Spacer(minLength: 4)
                    if let s = c.signalDBM { SignalText(dbm: s) }
                }
                .lineLimit(1)
            }
        }
    }
}

struct BeaconPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let beacons = DashboardRoster.newest(store.beacons.values,
                                             stamp: { $0.lastSeen }, id: { $0.bssid },
                                             limit: gridRowCap)
        GridPanel(title: "BEACONS", count: store.beacons.count, route: .wifi,
                  quiet: "no beacons heard", isEmpty: beacons.isEmpty) {
            ForEach(beacons) { b in
                HStack(spacing: 6) {
                    Text(b.ssid ?? "(hidden)").dashIdentity()
                    Spacer(minLength: 4)
                    if let ch = b.channel  { Text("ch\(ch)").dashValue() }
                    if let s = b.signalDBM { SignalText(dbm: s) }
                }
                .lineLimit(1)
            }
        }
    }
}

/// Signal strength, heat-graded: -30 dBm is on top of the antenna,
/// -90 dBm is the noise floor.
private struct SignalText: View {
    let dbm: Int
    var body: some View {
        Text("\(dbm)dBm")
            .font(.phosphor(.caption2))
            .foregroundStyle(Color.heat(max(0, min(1, Double(dbm + 90) / 60))))
    }
}

// MARK: - LAN chatter row (mDNS | DHCP | SSDP)

struct MDNSPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let services = DashboardRoster.newest(store.mdnsServices.values,
                                              stamp: { $0.lastSeen }, id: { $0.instance },
                                              limit: gridRowCap)
        GridPanel(title: "MDNS", count: store.mdnsServices.count, route: .lan,
                  quiet: "no bonjour chatter", isEmpty: services.isEmpty) {
            ForEach(services) { s in
                HStack(spacing: 6) {
                    Text(s.instance).dashIdentity().truncationMode(.tail)
                    Spacer(minLength: 4)
                    if let port = s.port { Text(":\(port)").dashValue() }
                }
                .lineLimit(1)
            }
        }
    }
}

struct DHCPPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let leases = DashboardRoster.newest(store.dhcpLeases.values,
                                            stamp: { $0.ts }, id: { $0.ip },
                                            limit: gridRowCap)
        GridPanel(title: "DHCP", count: store.dhcpLeases.count, route: .lan,
                  quiet: "no leases observed", isEmpty: leases.isEmpty) {
            ForEach(leases) { l in
                HStack(spacing: 6) {
                    HotIPText(ip: l.ip, hot: store.alertHot.severity(for: l.ip))
                    Text(l.hostname ?? "—").dashValue().truncationMode(.tail)
                    Spacer(minLength: 4)
                }
                .lineLimit(1)
            }
        }
    }
}

struct SSDPPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let devices = DashboardRoster.newest(store.ssdpDevices.values,
                                             stamp: { $0.lastSeen }, id: { $0.usn },
                                             limit: gridRowCap)
        GridPanel(title: "SSDP", count: store.ssdpDevices.count, route: .lan,
                  quiet: "no upnp announcements", isEmpty: devices.isEmpty) {
            ForEach(devices) { d in
                HStack(spacing: 6) {
                    if let ip = d.ip {
                        HotIPText(ip: ip, hot: store.alertHot.severity(for: ip))
                    }
                    Text(shortKind(d.kind)).dashValue().truncationMode(.tail)
                    Spacer(minLength: 4)
                }
                .lineLimit(1)
            }
        }
    }

    /// "urn:schemas-upnp-org:device:InternetGatewayDevice:1" → the
    /// device segment; anything unparseable passes through.
    private func shortKind(_ kind: String?) -> String {
        guard let kind else { return "—" }
        let parts = kind.split(separator: ":")
        guard parts.count >= 2 else { return kind }
        return String(parts[parts.count - 2])
    }
}

// MARK: - ARP | Deauth (half-height row in the TUI; row-capped here)

struct ARPPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let entries = DashboardRoster.newest(store.arpEntries.values,
                                             stamp: { $0.ts }, id: { $0.id },
                                             limit: gridRowCap)
        GridPanel(title: "ARP", count: store.arpEntries.count, route: .lan,
                  quiet: "no arp traffic", isEmpty: entries.isEmpty) {
            ForEach(entries) { a in
                HStack(spacing: 6) {
                    HotIPText(ip: a.ip, hot: store.alertHot.severity(for: a.ip))
                        .frame(minWidth: 110, alignment: .leading)
                    Text(a.mac).dashValue()
                    Spacer(minLength: 4)
                    if let iface = a.iface { Text(iface).dashStamp() }
                }
                .lineLimit(1)
            }
        }
    }
}

struct DeauthPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let deauths = DashboardRoster.newest(store.deauths.values,
                                             stamp: { $0.lastSeen }, id: { $0.id },
                                             limit: gridRowCap)
        let floods = store.deauths.values.filter(\.isFlood).count
        GridPanel(title: "DEAUTH", count: store.deauths.count, route: .twins,
                  tint: floods > 0 ? .alertHotCrit : .phosphorDim,
                  quiet: "no deauth frames", isEmpty: deauths.isEmpty) {
            ForEach(deauths) { d in
                HStack(spacing: 6) {
                    Text(d.dst).dashIdentity()
                    Text("\(d.count)×").dashValue()
                    if d.isFlood {
                        Text("FLOOD")
                            .font(.phosphor(.caption2, weight: .bold))
                            .foregroundStyle(.alertHotCrit)
                    }
                    Spacer(minLength: 4)
                    Text(DashFormat.clock(d.lastSeen)).dashStamp()
                }
                .lineLimit(1)
            }
        }
    }
}

// MARK: - Log tails (DNS | ICMP)

struct DNSLogPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let tail = DashboardRoster.logTail(store.dns, limit: gridRowCap)
        GridPanel(title: "DNS", count: store.dns.count, route: .dns,
                  quiet: "no queries yet", isEmpty: tail.isEmpty) {
            ForEach(Array(tail.enumerated()), id: \.offset) { _, e in
                HStack(spacing: 6) {
                    // R ⇔ has answer — same rule as DNSLogView.
                    Text((e.answer ?? "").isEmpty ? "Q" : "R").dashStamp()
                    Text(e.qtype ?? "—").dashValue()
                        .frame(width: 44, alignment: .leading)
                    Text(e.qname)
                        .font(.phosphor(.caption2))
                        .foregroundStyle(Theme.brand(for: e.qname) ?? .phosphorTeal)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    if e.rcode == 3 {
                        Text("NX")
                            .font(.phosphor(.caption2, weight: .bold))
                            .foregroundStyle(.alertHotWarn)
                    } else if let answer = e.answer {
                        HotIPText(ip: answer,
                                  hot: store.alertHot.severity(for: answer))
                    }
                }
                .lineLimit(1)
            }
        }
    }
}

struct ICMPLogPanel: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let tail = DashboardRoster.logTail(store.icmp, limit: gridRowCap)
        GridPanel(title: "ICMP", count: store.icmp.count, route: .icmp,
                  quiet: "no icmp traffic", isEmpty: tail.isEmpty) {
            ForEach(Array(tail.enumerated()), id: \.offset) { _, e in
                HStack(spacing: 6) {
                    if let src = e.src {
                        HotIPText(ip: src, hot: store.alertHot.severity(for: src))
                    }
                    Text("→").dashStamp()
                    if let dst = e.dst {
                        HotIPText(ip: dst, hot: store.alertHot.severity(for: dst))
                    }
                    Spacer(minLength: 4)
                    if let t = e.icmpType {
                        Text("type \(t)\(e.code.map { "/\($0)" } ?? "")").dashValue()
                    }
                }
                .lineLimit(1)
            }
        }
    }
}
