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
        Group {
            if services.isEmpty && leases.isEmpty {
                ContentUnavailableView(
                    "Nothing on the LAN yet",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Sloth emits one `mdns_service` per Bonjour/Zeroconf instance it observes, and one `dhcp_lease` per DHCP lease.")
                )
            } else {
                List {
                    mdnsSection(services)
                    leasesSection(leases)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("LAN")
        .navigationBarTitleDisplayMode(.inline)
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
