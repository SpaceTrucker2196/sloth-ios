// WiFiAPsView — visible 802.11 access points built from sloth's
// `beacon` snapshot records (`docs/wiki/jsonl-schema.md`).
//
// Each row shows SSID / BSSID / channel / encryption / live RSSI.
// The RSSI swing in the last 60 s is rendered as a tiny bar — the
// same dB-swing number `twin_episode.rssi_swing_dbm` watches, so an
// AP about to be flagged as the rogue half of a twin shows the
// signal in this view first.
//
// Sort: signal first (loudest = closest), then alphabetical by SSID.

import SwiftUI
import SlothCore

struct WiFiAPsView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let rows = sorted(store.beacons.values)
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "No beacons yet",
                    systemImage: "wifi",
                    description: Text("Sloth emits one `beacon` record per visible AP per second when 802.11 monitor mode is active.")
                )
            } else {
                List(rows) { beacon in
                    BeaconRow(beacon: beacon)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("WiFi APs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sorted(_ values: Dictionary<String, BeaconEntry>.Values) -> [BeaconEntry] {
        values.sorted { lhs, rhs in
            // Loudest first; ties broken alphabetically.
            let ls = lhs.signalDBM ?? -200
            let rs = rhs.signalDBM ?? -200
            if ls != rs { return ls > rs }
            return (lhs.ssid ?? "") < (rhs.ssid ?? "")
        }
    }
}

private struct BeaconRow: View {

    let beacon: BeaconEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displaySSID)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(.phosphorBright)
                    .lineLimit(1)
                Spacer()
                if let sig = beacon.signalDBM {
                    Text("\(sig) dBm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(signalTint(sig))
                }
            }
            HStack(spacing: 8) {
                Text(beacon.bssid)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                if let ch = beacon.channel {
                    Text("ch \(ch)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                if let enc = beacon.enc, !enc.isEmpty {
                    Text(enc)
                        .font(.caption2.monospaced())
                        .foregroundStyle(encTint(enc))
                }
                if let phy = beacon.phy, !phy.isEmpty {
                    Text("802.11\(phy)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 8) {
                if let v = beacon.vendor, !v.isEmpty {
                    Text(v)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                if let swing = beacon.rssiSwing60s, swing > 0 {
                    Label("\(swing) dB swing 60s",
                          systemImage: swing >= 15 ? "exclamationmark.triangle" : "waveform.path")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(swing >= 15 ? .alertHotWarn : .secondary)
                }
                Spacer()
                Text("\(beacon.frameCount) fr")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var displaySSID: String {
        let s = beacon.ssid?.trimmingCharacters(in: .whitespaces) ?? ""
        return s.isEmpty ? "(hidden)" : s
    }

    private func signalTint(_ dbm: Int) -> Color {
        switch dbm {
        case -50...0:    return .phosphorBright
        case -65 ... -51: return .phosphorTeal
        case -80 ... -66: return .alertHotWarn
        default:          return .alertHotCrit
        }
    }

    private func encTint(_ enc: String) -> Color {
        switch enc.uppercased() {
        case "WPA3":               return .phosphorBright
        case "WPA2", "WPA":        return .phosphorTeal
        case "WEP", "OPEN", "OPN": return .alertHotCrit
        default:                   return .secondary
        }
    }
}
