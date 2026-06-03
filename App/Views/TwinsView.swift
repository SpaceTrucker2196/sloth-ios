// TwinsView — evil-twin AP detector readout, built from sloth's
// `twin_episode` snapshot records (`docs/wiki/jsonl-schema.md` plus
// `sloth/docs/wiki/evil-twin-reproducer.md`).
//
// Each row is one detected pair (`ssid, real_bssid, twin_bssid`).
// Severity ladder (sloth-ios's mapping; see TwinEpisodeEntry.severity):
//   * attack_in_progress=1                              → CRIT (red)
//   * attacker_oui ∨ hash_mismatch ∨ swing≥15 dB        → WARN (orange)
//   * passive detection only                            → LOW  (yellow)
//
// Sorted highest-severity first; sub-sorted by twin RSSI (closest
// first — the rogue you can actually see).

import SwiftUI
import SlothCore

struct TwinsView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let rows = sorted(store.twinEpisodes.values)
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "No twin episodes",
                    systemImage: "shield.checkered",
                    description: Text("Sloth's evil-twin detector emits a `twin_episode` record per suspected rogue AP pair per second. An empty list is the desired state.")
                )
            } else {
                List(rows) { episode in
                    TwinRow(episode: episode)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Twins")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sorted(_ values: Dictionary<String, TwinEpisodeEntry>.Values) -> [TwinEpisodeEntry] {
        values.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity.rawValue > rhs.severity.rawValue }
            return lhs.twinRSSI > rhs.twinRSSI    // closer twin first
        }
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
