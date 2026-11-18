// SensorHealthStrip — the sensor's own self-report (`sensor_health`,
// `socket_gap`), one line per daemon. Answers "is sloth able to see",
// which a quiet dashboard cannot: a dead capture thread and a calm
// network look the same in every other view.

import SwiftUI
import SlothCore

struct SensorHealthStrip: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.sensorHealth.isEmpty {
                Text("No sensor_health yet — sloth sends one every 5 min.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.sensorHealth.keys.sorted(), id: \.self) { daemon in
                if let h = store.sensorHealth[daemon] { DaemonLine(health: h) }
            }
            rfLine
            counters
            hostLink
        }
        .font(.caption.monospaced())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    /// The sloth-rf stream: say which state it is in, so empty RF
    /// panels never read as "nothing in the air".
    @ViewBuilder private var rfLine: some View {
        switch store.rfConnectionState {
        case .idle:
            if store.sensorHealth["rf"] == nil {
                Text("RF stream not configured (Settings → profile → RF stream): " +
                     "no GNSS, ADS-B, APRS, rtl_433, Victron.")
                    .foregroundStyle(.secondary)
            }
        case .connecting:
            Text("RF stream connecting…").foregroundStyle(.secondary)
        case .connected:
            Text("RF stream live · \(store.rfRecordsReceived) records")
                .foregroundStyle(.secondary)
        case .disconnected(let reason):
            Text("RF stream down: \(reason ?? "closed by sensor")")
                .foregroundStyle(Color.alertHotWarn)
        }
    }

    /// One line per daemon's host report; the problems in it, if any,
    /// so a hot or under-volted box shows without opening the page.
    @ViewBuilder private var hostLink: some View {
        if !store.hostReports.isEmpty {
            NavigationLink {
                HostView()
            } label: {
                HStack(spacing: 6) {
                    let problems = store.hostReports.values
                        .flatMap { $0.status?.problems ?? [] }
                    Image(systemName: problems.isEmpty ? "cpu" : "exclamationmark.octagon")
                    Text(problems.isEmpty ? "Host & sources" : "Host: " + problems.joined(separator: ", "))
                    Image(systemName: "chevron.right").imageScale(.small)
                }
                .foregroundStyle(hostTint)
            }
        }
    }

    private var hostTint: Color {
        store.hostReports.values.contains { !($0.status?.problems.isEmpty ?? true) }
            ? .alertHotCrit : .accentColor
    }

    @ViewBuilder private var counters: some View {
        let gaps = store.socketDroppedTotal
        let bad  = store.malformedCount
        if gaps > 0 || bad > 0 {
            HStack(spacing: 12) {
                if gaps > 0 {
                    Label("\(gaps) records dropped (app fell behind)",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.alertHotWarn)
                }
                if bad > 0 {
                    Label("\(bad) undecodable", systemImage: "questionmark.diamond")
                        .foregroundStyle(Color.alertHotWarn)
                }
            }
        }
    }
}

private struct DaemonLine: View {

    let health: SensorHealthEntry

    var body: some View {
        let problems = health.problems
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: problems.isEmpty ? "checkmark.circle" : "exclamationmark.octagon")
                    .foregroundStyle(problems.isEmpty ? Color.phosphorTeal : Color.alertHotCrit)
                Text(health.daemonName.uppercased()).bold()
                Text("jsonl \(health.jsonlVersion ?? "?")")
                    .foregroundStyle(versionOK ? Color.secondary : Color.alertHotWarn)
                if health.droppedPackets > 0 {
                    Text("\(health.droppedPackets) pkts dropped").foregroundStyle(.secondary)
                }
            }
            ForEach(problems, id: \.self) { p in
                Text("  " + p).foregroundStyle(Color.alertHotCrit)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The app is written against MAJOR 2; MINOR bumps only add.
    private var versionOK: Bool { health.jsonlMajor.map { $0 == 2 } ?? true }
}
