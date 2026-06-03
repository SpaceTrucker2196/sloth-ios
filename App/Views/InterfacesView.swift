// InterfacesView — sloth dashboard "Interfaces" band, mirrored
// (`docs/views/dashboard.md`): one row per interface, current
// rx/tx rate, dB-equivalent sparkline of the last 60 s.
//
// Data source is the `iface` snapshot record (M9). The store
// already maintains per-name rx/tx sample tails alongside the
// latest snapshot — this view just renders them.

import SwiftUI
import SlothCore

struct InterfacesView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        Group {
            let names = store.ifaces.keys.sorted()
            if names.isEmpty {
                ContentUnavailableView(
                    "No interfaces yet",
                    systemImage: "network",
                    description: Text("Sloth emits one `iface` record per interface per second. Records appear as the stream opens.")
                )
            } else {
                List(names, id: \.self) { name in
                    if let iface = store.ifaces[name] {
                        InterfaceRow(
                            iface:     iface,
                            rxSamples: store.ifaceRxSamples[name] ?? [],
                            txSamples: store.ifaceTxSamples[name] ?? []
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Interfaces")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InterfaceRow: View {

    let iface: IFaceEntry
    let rxSamples: [Double]
    let txSamples: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(iface.name)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(.phosphorBright)
                Spacer()
                if let mbps = iface.speedMbps {
                    Text("\(mbps) Mb/s")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let mtu = iface.mtu {
                    Text("MTU \(mtu)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text(formatRate(iface.rxRate))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.phosphorTeal)
                    BandwidthSparkline(samples: rxSamples, tint: .phosphorTeal)
                        .frame(height: 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text(formatRate(iface.txRate))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.alertHotLow)
                    BandwidthSparkline(samples: txSamples, tint: .alertHotLow)
                        .frame(height: 22)
                }
            }
            if iface.rxErrors + iface.rxDrops + iface.txErrors + iface.txDrops > 0 {
                Text("errs rx \(iface.rxErrors)/drops \(iface.rxDrops)  •  tx \(iface.txErrors)/\(iface.txDrops)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.alertHotWarn)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRate(_ bps: Double) -> String {
        let v = bps
        switch v {
        case ..<1_000:        return "\(Int(v.rounded())) B/s"
        case ..<1_000_000:    return String(format: "%.1f KB/s", v / 1_000)
        case ..<1_000_000_000:return String(format: "%.2f MB/s", v / 1_000_000)
        default:              return String(format: "%.2f GB/s", v / 1_000_000_000)
        }
    }
}
