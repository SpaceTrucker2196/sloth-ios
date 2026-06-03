// DevicesView — LAN inventory built from sloth's `device` snapshot
// records. One row per MAC. Sources bitmask shows which subsystem(s)
// observed the device (ARP / DHCP / mDNS / WiFi assoc / probe).
//
// Sloth's `device.sources` is a `DEV_SRC_*` bitmask; the iOS view
// reproduces the same icons without depending on the producer's
// exact bit assignment — we render whatever it sends, even when new
// bits land before this client is updated.

import SwiftUI
import SlothCore

struct DevicesView: View {

    @Environment(SlothStore.self) private var store

    @State private var query: String = ""

    var body: some View {
        let rows = filtered(store.devices.values)
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "No devices yet",
                    systemImage: "rectangle.connected.to.line.below",
                    description: Text("Hosts your sloth instance sees on the LAN (ARP, DHCP, mDNS, WiFi association) show up here as snapshot records arrive.")
                )
            } else {
                List(rows) { device in
                    DeviceRow(
                        device: device,
                        hotSev: device.ip.flatMap(store.alertHot.severity(for:))
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filtered(_ values: Dictionary<String, DeviceEntry>.Values) -> [DeviceEntry] {
        let sorted = values.sorted { lhs, rhs in
            // APs first, then most-recently-seen.
            if lhs.isAP != rhs.isAP { return lhs.isAP > rhs.isAP }
            return lhs.lastSeen > rhs.lastSeen
        }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { d in
            LogFilter.matches(
                query:  query,
                fields: [d.mac, d.ip, d.hostname, d.vendor, d.lastSSID].compactMap { $0 }
            )
        }
    }
}

private struct DeviceRow: View {

    let device: DeviceEntry
    let hotSev: AlertSeverity?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: leadingIcon)
                .foregroundStyle(leadingTint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.callout.monospaced())
                    .fontWeight(hotSev?.prefersBold == true ? .semibold : .regular)
                    .foregroundStyle(nameTint)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(device.mac)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let v = device.vendor, !v.isEmpty {
                        Text("· \(v)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                HStack(spacing: 8) {
                    if let ssid = device.lastSSID, !ssid.isEmpty {
                        Label(ssid, systemImage: "wifi")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.phosphorTeal)
                    }
                    if let sig = device.signalDBM {
                        Label("\(sig) dBm", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(signalTint(sig))
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if device.isAP != 0 {
                    Text("AP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.alertHotLow)
                }
                Text(relativeAge(device.lastSeen))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        device.hostname?.nilIfEmpty ?? device.ip?.nilIfEmpty ?? device.mac
    }

    private var nameTint: Color {
        if let hot = hotSev                              { return hot.color }
        if let brand = Theme.brand(for: device.hostname) { return brand    }
        return .primary
    }

    private var leadingIcon: String {
        if hotSev != nil      { return "flame.fill" }
        if device.isAP != 0   { return "wifi.router" }
        if let h = device.hostname, !h.isEmpty { return "desktopcomputer" }
        return "questionmark.diamond"
    }

    private var leadingTint: Color {
        if let hot = hotSev { return hot.color }
        if device.isAP != 0 { return .alertHotLow }
        return .secondary
    }

    private func signalTint(_ dbm: Int) -> Color {
        switch dbm {
        case -50...0:    return .phosphorBright
        case -65 ... -51: return .phosphorTeal
        case -80 ... -66: return .alertHotWarn
        default:          return .alertHotCrit
        }
    }

    private func relativeAge(_ epoch: Int) -> String {
        guard epoch > 0 else { return "—" }
        let secs = max(0, Int(Date().timeIntervalSince1970) - epoch)
        switch secs {
        case 0..<60:    return "\(secs)s"
        case 60..<3600: return "\(secs / 60)m"
        default:        return "\(secs / 3600)h"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
