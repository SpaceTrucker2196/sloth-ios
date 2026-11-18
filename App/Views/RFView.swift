// RFView — the sloth-rf stream's tables: GNSS fix, ADS-B aircraft,
// APRS stations, rtl_433 sensors, Victron devices. Read-only, one
// section per source; a section with no rows is hidden so a sensor
// without that decoder does not show an empty heading.
//
// Spec: docs/views/rf.md. Records arrive only on the RF stream
// (profile → RF stream), so an empty view names that first.

import SwiftUI
import SlothCore

struct RFView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        List {
            if isEmpty {
                RFEmptyState(rfState: store.rfConnectionState)
            }
            if store.gnssFix != nil || store.gnssSky != nil {
                Section("GNSS") {
                    if let fix = store.gnssFix { GNSSRow(fix: fix) }
                    if store.gnssSky != nil || !store.gnssSats.isEmpty {
                        NavigationLink { SkyView() } label: { SkySummaryRow() }
                    }
                }
            }
            if !store.aircraft.isEmpty {
                Section("Aircraft · \(store.aircraft.count)") {
                    ForEach(RFRoster.aircraft(store.aircraft.values)) { AircraftRow(a: $0) }
                }
            }
            if !store.aprsStations.isEmpty {
                Section("APRS · \(store.aprsStations.count)") {
                    ForEach(RFRoster.newest(store.aprsStations.values) { $0.lastSeen ?? $0.ts }) {
                        APRSRow(s: $0)
                    }
                }
            }
            if !store.aprsPackets.isEmpty {
                Section("APRS packets · newest \(min(store.aprsPackets.count, 10))") {
                    ForEach(store.aprsPackets.suffix(10).reversed()) { APRSPacketRow(p: $0) }
                }
            }
            if !store.rtl433Devices.isEmpty {
                Section("Sub-GHz sensors · \(store.rtl433Devices.count)") {
                    ForEach(RFRoster.newest(store.rtl433Devices.values) { $0.lastSeen ?? $0.ts }) {
                        RTL433Row(d: $0)
                    }
                }
            }
            if !store.victronDevices.isEmpty {
                Section("Victron · \(store.victronDevices.count)") {
                    ForEach(RFRoster.newest(store.victronDevices.values) { $0.lastSeen ?? $0.ts }) {
                        VictronRow(v: $0)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("RF")
    }

    private var isEmpty: Bool {
        store.gnssFix == nil && store.gnssSky == nil && store.aircraft.isEmpty && store.aprsStations.isEmpty
            && store.rtl433Devices.isEmpty && store.victronDevices.isEmpty
    }
}

private struct RFEmptyState: View {
    let rfState: SlothStore.ConnectionState
    var body: some View {
        switch rfState {
        case .connected:
            Text("RF stream live. No GNSS, aircraft, APRS, sub-GHz or Victron rows yet.")
                .foregroundStyle(.secondary)
        default:
            Text("No RF stream. Add the sensor's sloth-rf address in Settings → profile → RF stream.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct GNSSRow: View {
    let fix: GNSSFixEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(fix.modeName).bold()
                if let u = fix.usat { Text("\(u) sats used") }
                if let h = fix.hdop, h > 0 { Text("HDOP \(h, specifier: "%.1f")") }
            }
            if let lat = fix.lat, let lon = fix.lon {
                Text("\(lat, specifier: "%.5f"), \(lon, specifier: "%.5f")")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            if let j = fix.jam, j >= 64 {
                Label("jamming indicator \(j)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(j >= 128 ? Color.alertHotCrit : Color.alertHotWarn)
            }
        }
        .font(.callout.monospaced())
    }
}

private struct AircraftRow: View {
    let a: ADSBAircraftEntry
    var body: some View {
        HStack {
            if a.hasEmergency {
                Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(Color.alertHotCrit)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(callsign ?? a.hex)
                    .bold(a.hasEmergency)
                    .foregroundStyle(a.hasEmergency ? Color.alertHotCrit : .primary)
                Text([callsign == nil ? nil : a.hex, a.squawk.map { "sq \($0)" }, a.hasEmergency ? a.emergency : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(a.onGround == 1 ? "ground" : a.altBaro.map { "\(Int($0)) ft" } ?? "—")
                if let gs = a.gs { Text("\(Int(gs)) kt").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .font(.callout.monospaced())
        .accessibilityElement(children: .combine)
    }

    /// The hex is the title when there is no callsign; do not repeat it.
    private var callsign: String? { a.flight.flatMap { $0.isEmpty ? nil : $0 } }
}

private struct APRSRow: View {
    let s: APRSStationEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.call).bold()
                if let c = s.comment ?? s.status, !c.isEmpty {
                    Text(c).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(s.heardDirect == 1 ? "direct" : "via digi")
                if let n = s.packets { Text("\(n) pkts").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .font(.callout.monospaced())
        .accessibilityElement(children: .combine)
    }
}

private struct RTL433Row: View {
    let d: RTL433DeviceEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.model).lineLimit(1)
                Text("id \(d.deviceID)" + (d.channel.map { " · ch \($0)" } ?? ""))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(reading)
            if let b = d.batteryOK, b < 0.5 {
                Image(systemName: "battery.25").foregroundStyle(Color.alertHotWarn)
                    .accessibilityLabel("battery low")
            }
        }
        .font(.callout.monospaced())
        .accessibilityElement(children: .combine)
    }

    /// Native unit only — sloth never converts, neither do we.
    private var reading: String {
        var parts: [String] = []
        if let c = d.temperatureC { parts.append(String(format: "%.1f°C", c)) }
        if let f = d.temperatureF { parts.append(String(format: "%.1f°F", f)) }
        if let h = d.humidity { parts.append("\(Int(h))%") }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }
}

private struct VictronRow: View {
    let v: VictronDeviceEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(v.model ?? v.mac).lineLimit(1)
                Text(v.mac).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let volt = v.voltageV { Text(String(format: "%.2f V", volt)) }
                if let soc = v.socPct { Text("\(Int(soc))%").font(.caption) }
                if let ac = v.acVoltageV { Text(String(format: "AC %.0f V", ac)).font(.caption) }
            }
        }
        .font(.callout.monospaced())
        .accessibilityElement(children: .combine)
    }
}
