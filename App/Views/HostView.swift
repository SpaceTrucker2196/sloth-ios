// HostView — the sensor host's own state and its source inventory
// (#14): `sys_status`, `source_status`, `sys_sensor`, `receiver_hw`,
// one section group per daemon. Answers "which radios is sloth reading,
// and is the box itself OK" — a hot Pi or a dead dongle looks like a
// quiet network everywhere else.

import SwiftUI
import SlothCore

struct HostView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        List {
            if store.hostReports.isEmpty {
                Text("No host report yet. sloth sends one every 60 s.")
                    .foregroundStyle(.secondary)
            }
            // Wi-Fi first: the main sensor, then sloth-rf.
            ForEach(store.hostReports.keys.sorted(by: >), id: \.self) { daemon in
                if let r = store.hostReports[daemon] {
                    DaemonHostSections(daemon: daemon, report: r)
                }
            }
        }
        .font(.callout)
        .navigationTitle("Host")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DaemonHostSections: View {

    let daemon: String
    let report: HostReport

    var body: some View {
        Section("\(daemon.uppercased()) · host") {
            if let s = report.status { SysStatusRows(status: s) }
            ForEach(report.sensors) { SysSensorRow(sensor: $0) }
        }
        if !report.sources.isEmpty {
            Section("\(daemon.uppercased()) · sources") {
                ForEach(report.sourceList) { SourceRow(source: $0) }
            }
        }
        if !report.receivers.isEmpty {
            Section("\(daemon.uppercased()) · receivers") {
                ForEach(report.receivers) { ReceiverRow(hw: $0) }
            }
        }
    }
}

private struct SysStatusRows: View {

    let status: SysStatusEntry

    var body: some View {
        ForEach(status.problems, id: \.self) { p in
            Label(p, systemImage: "exclamationmark.octagon")
                .foregroundStyle(Color.alertHotCrit)
                .bold()
        }
        LabeledContent("CPU", value: cpu)
        LabeledContent("Memory", value: memory)
        if let free = status.diskFreeMB, let total = status.diskTotalMB {
            LabeledContent("Disk", value: "\(free / 1024) of \(total / 1024) GB free · \(status.diskBand ?? "?")")
        }
        if let t = status.tempMaxC {
            LabeledContent("Hottest", value: String(format: "%.1f °C · %@", t, status.tempBand ?? "?"))
        }
        if let up = status.uptimeS {
            LabeledContent("Uptime", value: Duration.seconds(up).formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2)))
        }
    }

    private var cpu: String {
        let pct = status.cpuPct.map { String(format: "%.0f%%", $0) } ?? "—"
        let load = status.load1.map { String(format: " · load %.2f", $0) } ?? ""
        return "\(pct) \(status.cpuBand ?? "")\(load)"
    }

    private var memory: String {
        guard let used = status.memUsedPct else { return "—" }
        return String(format: "%.0f%% used · %@", used, status.memBand ?? "?")
    }
}

private struct SysSensorRow: View {

    let sensor: SysSensorEntry

    var body: some View {
        LabeledContent {
            Text(value).monospacedDigit()
                .foregroundStyle(sensor.alarm == 1 ? Color.alertHotCrit : Color.primary)
        } label: {
            Text(sensor.label ?? sensor.id)
            Text(sensor.id).font(.caption.monospaced())
        }
    }

    private var value: String {
        if let c = sensor.c { return String(format: "%.1f °C", c) }
        var parts: [String] = []
        if let v = sensor.v { parts.append(String(format: "%.2f V", v)) }
        if let cap = sensor.capacity { parts.append("\(cap)%") }
        if let s = sensor.status { parts.append(s) }
        if sensor.alarm == 1 { parts.append("ALARM") }
        if sensor.alarm == 0, parts.isEmpty { parts.append("no alarm") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

private struct SourceRow: View {

    let source: SourceStatusEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(source.name).bold(source.stateValue == .down)
                    Text(source.state.replacingOccurrences(of: "_", with: " "))
                        .font(.caption).foregroundStyle(tint)
                }
                if let line = subline {
                    Text(line).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let r = source.rate {
                Text(String(format: "%.1f %@/s", r, source.unit ?? ""))
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Shape as well as hue (AGENTS.md: never colour alone).
    private var icon: String {
        switch source.stateValue {
        case .ok?:            return "checkmark.circle"
        case .stale?:         return "clock"
        case .down?:          return "xmark.octagon"
        case .notConfigured?: return "minus.circle"
        case nil:             return "questionmark.circle"
        }
    }

    private var tint: Color {
        switch source.stateValue {
        case .ok?:    return .phosphorTeal
        case .stale?: return .alertHotLow
        case .down?:  return .alertHotCrit
        default:      return .secondary
        }
    }

    private var subline: String? {
        let parts = [source.endpoint, source.desc, source.detail]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct ReceiverRow: View {

    let hw: ReceiverHWEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hw.displayName)
            Text([hw.kind, hw.key, hw.ifaces].compactMap { $0 }.filter { !$0.isEmpty }
                    .joined(separator: " · "))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
