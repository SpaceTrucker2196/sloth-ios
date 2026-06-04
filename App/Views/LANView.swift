// LANView — passive-observation panels grouped by sloth's dashboard
// mid-band (`docs/views/dashboard.md`): mDNS services + DHCP leases
// in a single screen.
//
// Both are pure snapshot tables; the iOS store replaces in place by
// natural key and nothing else aggregates. mDNS rows are grouped by
// service type so an operator scanning for "what AirPlay devices are
// here" sees the whole `_airplay._tcp` cluster together.

import SwiftUI
import SlothCore

struct LANView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let services = sortedServices
        let leases   = sortedLeases
        let arps     = sortedARP
        let ssdp     = sortedSSDP
        let nbns     = sortedNBNS
        Group {
            if services.isEmpty && leases.isEmpty &&
               arps.isEmpty && ssdp.isEmpty && nbns.isEmpty {
                ContentUnavailableView(
                    "Nothing on the LAN yet",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Sloth emits per-second snapshots of every LAN table (mDNS, DHCP, ARP, SSDP, NetBIOS) as it observes them.")
                )
            } else {
                List {
                    mdnsSection(services)
                    leasesSection(leases)
                    arpSection(arps)
                    ssdpSection(ssdp)
                    nbnsSection(nbns)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("LAN")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func arpSection(_ entries: [ARPEntry]) -> some View {
        Section {
            if entries.isEmpty {
                quietRow("No ARP entries")
            } else {
                ForEach(entries) { ARPRow(arp: $0) }
            }
        } header: {
            Label("ARP table (\(entries.count))", systemImage: "list.bullet.indent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func ssdpSection(_ entries: [SSDPDeviceEntry]) -> some View {
        Section {
            if entries.isEmpty {
                quietRow("No SSDP / UPnP devices")
            } else {
                ForEach(entries) { SSDPRow(svc: $0) }
            }
        } header: {
            Label("SSDP / UPnP (\(entries.count))", systemImage: "tv.and.hifispeaker.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func nbnsSection(_ entries: [NBNSNameEntry]) -> some View {
        Section {
            if entries.isEmpty {
                quietRow("No NetBIOS names")
            } else {
                ForEach(entries) { NBNSRow(name: $0) }
            }
        } header: {
            Label("NetBIOS (\(entries.count))", systemImage: "pc")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var sortedARP: [ARPEntry] {
        store.arpEntries.values.sorted { $0.ip < $1.ip }
    }
    private var sortedSSDP: [SSDPDeviceEntry] {
        store.ssdpDevices.values.sorted { lhs, rhs in
            (lhs.kind ?? "") < (rhs.kind ?? "")
        }
    }
    private var sortedNBNS: [NBNSNameEntry] {
        store.nbnsNames.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    @ViewBuilder
    private func mdnsSection(_ services: [MDNSServiceEntry]) -> some View {
        Section {
            if services.isEmpty {
                quietRow("No mDNS services")
            } else {
                ForEach(services) { svc in
                    MDNSRow(svc: svc)
                }
            }
        } header: {
            Label("mDNS services (\(services.count))", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func leasesSection(_ leases: [DHCPLeaseEntry]) -> some View {
        Section {
            if leases.isEmpty {
                quietRow("No DHCP leases")
            } else {
                ForEach(leases) { lease in
                    DHCPRow(lease: lease)
                }
            }
        } header: {
            Label("DHCP leases (\(leases.count))", systemImage: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    /// Group by service type (`_airplay._tcp`, etc.), then by instance
    /// name within each group. Sloth's instance string already carries
    /// the type, so we extract it client-side for the grouping key.
    private var sortedServices: [MDNSServiceEntry] {
        store.mdnsServices.values.sorted { lhs, rhs in
            let ls = lhs.service ?? ""
            let rs = rhs.service ?? ""
            if ls != rs { return ls < rs }
            return lhs.instance.localizedCaseInsensitiveCompare(rhs.instance) == .orderedAscending
        }
    }

    private var sortedLeases: [DHCPLeaseEntry] {
        store.dhcpLeases.values.sorted { lhs, rhs in
            // Hosts with known names first, then by IP.
            switch (lhs.hostname?.nilIfEmpty, rhs.hostname?.nilIfEmpty) {
            case (nil, _?): return false
            case (_?, nil): return true
            default:
                if let lh = lhs.hostname, let rh = rhs.hostname, lh != rh {
                    return lh.localizedCaseInsensitiveCompare(rh) == .orderedAscending
                }
                return lhs.ip < rhs.ip
            }
        }
    }

    private func quietRow(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.tertiary)
            .padding(.vertical, 4)
    }
}

private struct MDNSRow: View {

    let svc: MDNSServiceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(svc.instance)
                .font(.caption.monospaced())
                .foregroundStyle(.phosphorBright)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                if let s = svc.service, !s.isEmpty {
                    Text(s)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.phosphorTeal)
                }
                if let h = svc.host, !h.isEmpty {
                    Text(h)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if let ip = svc.ip, !ip.isEmpty,
                   let port = svc.port, port > 0 {
                    Text("\(ip):\(port)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DHCPRow: View {

    let lease: DHCPLeaseEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: hasHostname ? "desktopcomputer" : "questionmark.diamond")
                .foregroundStyle(hasHostname ? Color.phosphorBright : .secondary)
                .imageScale(.small)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(lease.hostname?.nilIfEmpty ?? lease.ip)
                    .font(.callout.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if lease.hostname?.nilIfEmpty != nil {
                    Text(lease.ip)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(expiryText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(expiryTint)
        }
        .padding(.vertical, 4)
    }

    /// Friendly remaining-lease label. `expire = 0` means sloth picked
    /// up the lease via a renewal and never saw the original term.
    private var expiryText: String {
        guard lease.expire > 0 else { return "—" }
        let remaining = lease.expire - Int(Date().timeIntervalSince1970)
        if remaining <= 0 { return "expired" }
        switch remaining {
        case ..<3600:    return "\(remaining / 60)m"
        case ..<86_400:  return "\(remaining / 3600)h"
        default:         return "\(remaining / 86_400)d"
        }
    }

    private var hasHostname: Bool { lease.hostname?.nilIfEmpty != nil }

    private var expiryTint: Color {
        guard lease.expire > 0 else { return .gray }   // matches .tertiary visually but is a Color
        let remaining = lease.expire - Int(Date().timeIntervalSince1970)
        if remaining <= 0    { return .alertHotWarn }
        if remaining < 3600  { return .alertHotLow }
        return .secondary
    }
}

private struct ARPRow: View {

    let arp: ARPEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.grid.cross")
                .imageScale(.small).foregroundStyle(Color.phosphorTeal)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(arp.ip)
                    .font(.callout.monospaced())
                    .foregroundStyle(.phosphorBright)
                Text(arp.mac)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let iface = arp.iface, !iface.isEmpty {
                Text(iface)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SSDPRow: View {

    let svc: SSDPDeviceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let kind = svc.kind?.nilIfEmpty {
                Text(kind)
                    .font(.caption.monospaced())
                    .foregroundStyle(.phosphorBright)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("(unknown)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let ip = svc.ip, !ip.isEmpty {
                    Text(ip).font(.caption2.monospaced()).foregroundStyle(.phosphorTeal)
                }
                if let nts = svc.nts, !nts.isEmpty {
                    Text(nts).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
                Spacer()
                if let loc = svc.location, !loc.isEmpty {
                    Text(loc)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NBNSRow: View {

    let name: NBNSNameEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pc")
                .imageScale(.small).foregroundStyle(Color.phosphorBright)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.name)
                    .font(.callout.monospaced())
                    .foregroundStyle(.phosphorBright)
                HStack(spacing: 6) {
                    Text(name.ip)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let s = name.suffix, !s.isEmpty {
                        Text("[0x\(s)]")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
