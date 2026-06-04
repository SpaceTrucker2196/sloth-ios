// WiFiView — the WiFi panel, mirroring sloth's TUI mid-band cluster.
// Six sections in one screen:
//
//   1. APs               — `beacon` snapshot (existing behaviour)
//   2. Nearby clients    — `probe_client` rows, with the cumulative
//                          `pnl_client` SSID list merged by MAC
//   3. Associations      — `assoc` station↔AP pairings
//   4. Handshakes        — `eapol` 4-way handshake observations
//                          (complete handshakes + PMKID captures are
//                          attack-capable signals)
//   5. Channels          — `channel_summary` AP / assoc counts
//   6. MAC correlations  — `seqnum_correlation` likely-same-NIC pairs
//
// Each section emits a count in its header and falls back to a
// muted "nothing yet" row when empty so the structure of the screen
// stays stable as data flows in.

import SwiftUI
import SlothCore

struct WiFiView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let beacons = sortedBeacons
        Group {
            if isEmpty {
                ContentUnavailableView(
                    "No WiFi records yet",
                    systemImage: "wifi",
                    description: Text("Sloth emits per-second snapshots of every WiFi table once 802.11 monitor mode is active.")
                )
            } else {
                List {
                    section("APs",
                            count:  beacons.count,
                            symbol: "wifi") {
                        ForEach(beacons) { BeaconRow(beacon: $0) }
                    }
                    section("Nearby clients",
                            count:  store.probeClients.count,
                            symbol: "antenna.radiowaves.left.and.right") {
                        ForEach(sortedProbeClients) { p in
                            NearbyClientRow(
                                probe: p,
                                pnl:   store.pnlClients[p.mac]
                            )
                        }
                    }
                    section("Associations",
                            count:  store.assocs.count,
                            symbol: "link") {
                        ForEach(sortedAssocs) { AssocRow(assoc: $0) }
                    }
                    section("Handshakes",
                            count:  store.eapols.count,
                            symbol: "key.horizontal") {
                        ForEach(sortedEAPOLs) { EAPOLRow(eapol: $0) }
                    }
                    section("Channels",
                            count:  store.channelSummaries.count,
                            symbol: "dial.medium") {
                        ForEach(sortedChannels) { ChannelRow(summary: $0) }
                    }
                    section("MAC correlations",
                            count:  store.seqnumCorrelations.count,
                            symbol: "arrow.triangle.merge") {
                        ForEach(sortedCorrelations) { CorrelationRow(c: $0) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("WiFi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isEmpty: Bool {
        store.beacons.isEmpty && store.probeClients.isEmpty &&
        store.assocs.isEmpty  && store.eapols.isEmpty &&
        store.channelSummaries.isEmpty && store.seqnumCorrelations.isEmpty
    }

    private var sortedBeacons: [BeaconEntry] {
        store.beacons.values.sorted { lhs, rhs in
            let ls = lhs.signalDBM ?? -200
            let rs = rhs.signalDBM ?? -200
            if ls != rs { return ls > rs }
            return (lhs.ssid ?? "") < (rhs.ssid ?? "")
        }
    }
    private var sortedProbeClients: [ProbeClientEntry] {
        store.probeClients.values.sorted { lhs, rhs in
            let ls = lhs.signalDBM ?? -200
            let rs = rhs.signalDBM ?? -200
            if ls != rs { return ls > rs }
            return lhs.lastSeen > rhs.lastSeen
        }
    }
    private var sortedAssocs: [AssocEntry] {
        store.assocs.values.sorted { $0.lastSeen > $1.lastSeen }
    }
    private var sortedEAPOLs: [EAPOLEntry] {
        store.eapols.values.sorted { (lhs: EAPOLEntry, rhs: EAPOLEntry) -> Bool in
            // Complete handshakes first; PMKID-bearing next; then by recency.
            if lhs.isComplete != rhs.isComplete { return lhs.isComplete && !rhs.isComplete }
            if lhs.hasPMKIDFlag != rhs.hasPMKIDFlag { return lhs.hasPMKIDFlag && !rhs.hasPMKIDFlag }
            return lhs.eventTS > rhs.eventTS
        }
    }
    private var sortedChannels: [ChannelSummaryEntry] {
        store.channelSummaries.values.sorted { $0.channel < $1.channel }
    }
    private var sortedCorrelations: [SeqnumCorrelationEntry] {
        store.seqnumCorrelations.values.sorted { $0.dtMS < $1.dtMS } // tighter pairs first
    }

    @ViewBuilder
    private func section<C: View>(
        _ title: String,
        count: Int,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        Section {
            if count == 0 {
                Text("none").font(.caption.monospaced()).foregroundStyle(.tertiary)
            } else {
                content()
            }
        } header: {
            Label("\(title) (\(count))", systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }
}

// MARK: - Existing AP row (lifted from the previous WiFiAPsView)

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
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                if let ch = beacon.channel {
                    Text("ch \(ch)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
                if let enc = beacon.enc, !enc.isEmpty {
                    Text(enc).font(.caption2.monospaced()).foregroundStyle(encTint(enc))
                }
                if let phy = beacon.phy, !phy.isEmpty {
                    Text("802.11\(phy)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
            }
            if let swing = beacon.rssiSwing60s, swing > 0 {
                Label("\(swing) dB swing 60s",
                      systemImage: swing >= 15 ? "exclamationmark.triangle" : "waveform.path")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(swing >= 15 ? .alertHotWarn : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var displaySSID: String {
        let s = beacon.ssid?.trimmingCharacters(in: .whitespaces) ?? ""
        return s.isEmpty ? "(hidden)" : s
    }
}

// MARK: - New rows

private struct NearbyClientRow: View {

    let probe: ProbeClientEntry
    let pnl:   PNLClientEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: pnl?.isRandomMAC == true ? "questionmark.diamond" : "iphone")
                    .imageScale(.small)
                    .foregroundStyle(pnl?.isRandomMAC == true ? Color.secondary : .phosphorBright)
                Text(probe.mac)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(.phosphorBright)
                Spacer()
                if let sig = probe.signalDBM {
                    Text("\(sig) dBm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(signalTint(sig))
                }
            }
            HStack(spacing: 8) {
                if let ch = probe.channel {
                    Text("ch \(ch)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
                Text("\(probe.frameCount) fr")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                if let osfp = pnl?.osFP, !osfp.isEmpty {
                    Text("·  \(osfp)")
                        .font(.caption2.monospaced()).foregroundStyle(.phosphorTeal)
                }
                if pnl?.isRandomMAC == true {
                    Text("·  randomised")
                        .font(.caption2.monospaced()).foregroundStyle(.alertHotLow)
                }
            }
            if let ssids = pnl?.ssids, !ssids.isEmpty {
                Text(pnlSummary(ssids))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let probedSSID = probe.ssid?.nilIfEmpty {
                Text("PNL: \(probedSSID)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func pnlSummary(_ ssids: [String]) -> String {
        let head = ssids.prefix(4).joined(separator: ", ")
        let extra = ssids.count > 4 ? "  +\(ssids.count - 4)" : ""
        return "PNL: \(head)\(extra)"
    }
}

private struct AssocRow: View {

    let assoc: AssocEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(assoc.ssid?.nilIfEmpty ?? "(unknown)")
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(.phosphorBright)
                Spacer()
                if let sig = assoc.signalDBM {
                    Text("\(sig) dBm").font(.caption.monospacedDigit())
                        .foregroundStyle(signalTint(sig))
                }
            }
            HStack(spacing: 8) {
                Text(assoc.staMAC)
                    .font(.caption2.monospaced()).foregroundStyle(.phosphorTeal)
                Text("↔").font(.caption2).foregroundStyle(.tertiary)
                Text(assoc.bssid)
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                Spacer()
                if assoc.staRandom != 0 {
                    Text("RND").font(.caption2.weight(.bold)).foregroundStyle(.alertHotLow)
                }
                if let ch = assoc.channel {
                    Text("ch \(ch)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EAPOLRow: View {

    let eapol: EAPOLEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tierIcon)
                .foregroundStyle(tierTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(eapol.ssid?.nilIfEmpty ?? "(unknown)")
                    .font(.callout.monospaced())
                    .foregroundStyle(tierTint)
                Text("\(eapol.staMAC) ↔ \(eapol.bssid)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(tierTint)
                Text("M\(eapol.msgNum)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var tierIcon: String {
        if eapol.isComplete   { return "lock.shield.fill" }
        if eapol.hasPMKIDFlag { return "key.fill" }
        return "key.horizontal"
    }
    private var tierTint: Color {
        if eapol.isComplete   { return .alertHotWarn }
        if eapol.hasPMKIDFlag { return .alertHotLow }
        return .secondary
    }
    private var label: String {
        if eapol.isComplete   { return "COMPLETE" }
        if eapol.hasPMKIDFlag { return "PMKID" }
        return "partial"
    }
}

private struct ChannelRow: View {

    let summary: ChannelSummaryEntry

    var body: some View {
        HStack(spacing: 8) {
            Text("ch \(summary.channel)")
                .font(.callout.monospaced().weight(.semibold))
                .foregroundStyle(.phosphorBright)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if let top = summary.topSSID?.nilIfEmpty {
                    Text(top).font(.caption.monospaced()).foregroundStyle(.phosphorTeal)
                        .lineLimit(1).truncationMode(.middle)
                }
                HStack(spacing: 6) {
                    Text("\(summary.apCount) APs")
                    Text("·")
                    Text("\(summary.assocCount) assoc")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            }
            Spacer()
            if let sig = summary.bestSignal {
                Text("\(sig) dBm").font(.caption.monospacedDigit())
                    .foregroundStyle(signalTint(sig))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CorrelationRow: View {

    let c: SeqnumCorrelationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(c.macA).font(.caption.monospaced()).foregroundStyle(.phosphorTeal)
                Text("≈").font(.caption2).foregroundStyle(.tertiary)
                Text(c.macB).font(.caption.monospaced()).foregroundStyle(.phosphorTeal)
                Spacer()
                if c.macARandom != 0 || c.macBRandom != 0 {
                    Text("RND").font(.caption2.weight(.bold)).foregroundStyle(.alertHotLow)
                }
            }
            HStack(spacing: 8) {
                Text("gap \(c.gap)")
                Text("·")
                Text("dt \(c.dtMS) ms")
                Text("·")
                Text("\(c.aCount)/\(c.bCount) fr")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shared tints

fileprivate func signalTint(_ dbm: Int) -> Color {
    switch dbm {
    case -50...0:     return .phosphorBright
    case -65 ... -51: return .phosphorTeal
    case -80 ... -66: return .alertHotWarn
    default:          return .alertHotCrit
    }
}

fileprivate func encTint(_ enc: String) -> Color {
    switch enc.uppercased() {
    case "WPA3":               return .phosphorBright
    case "WPA2", "WPA":        return .phosphorTeal
    case "WEP", "OPEN", "OPN": return .alertHotCrit
    default:                   return .secondary
    }
}

fileprivate extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
