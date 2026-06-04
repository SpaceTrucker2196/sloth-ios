// TwinsView — 802.11 attack-surface readout. Two sections sharing
// one screen because they share the same threat model:
//
//   1. Evil-twin AP pair detections (`twin_episode` records).
//   2. Deauthenticate-frame flows (`deauth` records). A deauth flood
//      is the kick-off move in most evil-twin attacks
//      (`sloth/docs/wiki/evil-twin-reproducer.md`); when it precedes
//      a twin appearing within 5 s, sloth's chain rule tags the twin
//      with `attack_in_progress=1`.
//
// Twin severity ladder (TwinEpisodeEntry.severity):
//   * attack_in_progress=1                              → CRIT (red)
//   * attacker_oui ∨ hash_mismatch ∨ swing≥15 dB        → WARN (orange)
//   * passive detection only                            → LOW  (yellow)
//
// Deauth row severity:
//   * flood = 1   → WARN (orange) — sloth's flood detector hit
//   * count ≥ 10  → LOW  (yellow) — chatter worth noticing
//   * otherwise   → secondary
//
// Twins sort: highest-severity first; sub-sorted by twin RSSI
// (closest first — the rogue you can actually see).
// Deauths sort: floods first, then by frame count desc.

import SwiftUI
import SlothCore

struct TwinsView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let twins   = sortedTwins(store.twinEpisodes.values)
        let deauths = sortedDeauths(store.deauths.values)
        let scans   = sortedScans(store.scans.values)
        Group {
            if twins.isEmpty && deauths.isEmpty && scans.isEmpty {
                ContentUnavailableView(
                    "Nothing to flag",
                    systemImage: "shield.checkered",
                    description: Text("Sloth's evil-twin detector, deauth-flood tracker, and port-scan detector all report empty — the desired state.")
                )
            } else {
                List {
                    Section {
                        if twins.isEmpty {
                            quietRow("No twin pairs")
                        } else {
                            ForEach(twins) { episode in
                                TwinRow(episode: episode)
                            }
                        }
                    } header: {
                        Label("Twin AP pairs (\(twins.count))",
                              systemImage: "shield.checkered")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                    Section {
                        if deauths.isEmpty {
                            quietRow("No deauth flows")
                        } else {
                            ForEach(deauths) { d in
                                DeauthRow(deauth: d)
                            }
                        }
                    } header: {
                        Label("Deauth flows (\(deauths.count))",
                              systemImage: "antenna.radiowaves.left.and.right.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                    Section {
                        if scans.isEmpty {
                            quietRow("No port-scan hits")
                        } else {
                            ForEach(scans) { ScanRow(scan: $0) }
                        }
                    } header: {
                        Label("Port scans (\(scans.count))",
                              systemImage: "magnifyingglass.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Threats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sortedScans(_ values: Dictionary<String, ScanEntry>.Values) -> [ScanEntry] {
        values.sorted { lhs, rhs in
            if lhs.isFlagged != rhs.isFlagged { return lhs.isFlagged && !rhs.isFlagged }
            if lhs.portCount != rhs.portCount { return lhs.portCount > rhs.portCount }
            return lhs.lastSeen > rhs.lastSeen
        }
    }

    private func sortedTwins(_ values: Dictionary<String, TwinEpisodeEntry>.Values) -> [TwinEpisodeEntry] {
        values.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity.rawValue > rhs.severity.rawValue }
            return lhs.twinRSSI > rhs.twinRSSI    // closer twin first
        }
    }

    private func sortedDeauths(_ values: Dictionary<String, DeauthEntry>.Values) -> [DeauthEntry] {
        values.sorted { lhs, rhs in
            if lhs.isFlood != rhs.isFlood { return lhs.isFlood && !rhs.isFlood }
            if lhs.count != rhs.count     { return lhs.count > rhs.count }
            return lhs.lastSeen > rhs.lastSeen
        }
    }

    private func quietRow(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.tertiary)
            .padding(.vertical, 4)
    }
}

private struct DeauthRow: View {

    let deauth: DeauthEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: tierIcon)
                    .foregroundStyle(tierTint)
                Text(deauth.bssid)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(tierTint)
                    .lineLimit(1)
                Spacer()
                if deauth.isFlood {
                    Text("FLOOD")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.alertHotWarn)
                }
                Text("\(deauth.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let src = deauth.src, src != deauth.bssid {
                    labeled("src", src)
                }
                labeled("dst", deauth.dst)
                if let reason = deauth.reason {
                    labeled("rsn", "\(reason)")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var tierIcon: String {
        if deauth.isFlood   { return "exclamationmark.triangle.fill" }
        if deauth.count >= 10 { return "exclamationmark.circle" }
        return "antenna.radiowaves.left.and.right.slash"
    }

    private var tierTint: Color {
        if deauth.isFlood   { return .alertHotWarn }
        if deauth.count >= 10 { return .alertHotLow }
        return .secondary
    }

    private func labeled(_ key: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(key).foregroundStyle(.tertiary)
            Text(value).foregroundStyle(.secondary)
        }
        .font(.caption2.monospaced())
    }
}

private struct ScanRow: View {

    let scan: ScanEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: scan.isFlagged
                      ? "exclamationmark.octagon.fill"
                      : "magnifyingglass.circle")
                    .foregroundStyle(scan.isFlagged ? Color.alertHotCrit : .alertHotLow)
                Text(scan.ip)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(scan.isFlagged ? Color.alertHotCrit : .phosphorBright)
                Spacer()
                Text("\(scan.portCount) ports")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !scan.ports.isEmpty {
                Text(portsSummary)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var portsSummary: String {
        let head = scan.ports.prefix(12).map(String.init).joined(separator: " ")
        let extra = scan.ports.count > 12 ? "  +\(scan.ports.count - 12)" : ""
        return ":\(head)\(extra)"
    }
}

private struct TwinRow: View {

    let episode: TwinEpisodeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundStyle(episode.severity.color)
                Text(episode.ssid)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(episode.severity.color)
                Spacer()
                Text(episode.severity.displayName)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(episode.severity.color)
            }
            grid
            flagsRow
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        switch episode.severity {
        case .crit: return "exclamationmark.octagon.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .low:  return "shield.lefthalf.filled"
        }
    }

    private var grid: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
            GridRow {
                Text("real").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                Text(episode.realBSSID).font(.caption2.monospaced()).foregroundStyle(.phosphorTeal)
                Text("\(episode.realRSSI) dBm").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            GridRow {
                Text("twin").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                Text(episode.twinBSSID).font(.caption2.monospaced()).foregroundStyle(.alertHotCrit)
                Text("\(episode.twinRSSI) dBm").font(.caption2.monospacedDigit()).foregroundStyle(.alertHotCrit)
            }
        }
    }

    @ViewBuilder
    private var flagsRow: some View {
        HStack(spacing: 8) {
            Flag(label: "swing", value: "\(episode.rssiSwingDBM) dB",
                 active: episode.rssiSwingDBM >= 15,
                 tint:   .alertHotWarn)
            if let enc = episode.enc, !enc.isEmpty {
                Flag(label: "enc", value: enc, active: false, tint: .phosphorTeal)
            }
            if episode.attackerOUI != 0 {
                Flag(label: "OUI", value: "Hak5/ESP", active: true, tint: .alertHotWarn)
            }
            if episode.hashMismatch != 0 {
                Flag(label: "IE", value: "mismatch", active: true, tint: .alertHotWarn)
            }
            if episode.attackInProgress != 0 {
                Flag(label: "chain", value: "DEAUTH→twin", active: true, tint: .alertHotCrit)
            }
        }
    }
}

private struct Flag: View {
    let label: String
    let value: String
    let active: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.tertiary)
            Text(value).foregroundStyle(active ? tint : .secondary)
        }
        .font(.caption2.monospacedDigit())
    }
}
