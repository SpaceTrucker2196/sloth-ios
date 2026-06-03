// ProcessesView — per-process bandwidth attribution. Reads sloth's
// `process` snapshot directly: one record per active PID per ≈ 1 s
// tick, synthesised on the producer side from the `connections`
// stream so the consumer never has to join flows to PIDs.
//
// Sort: combined live rate (rx + tx), descending. Sloth's "unresolved
// flows" bucket (pid = -1) is pinned to the bottom regardless of
// rate — surfacing it among real processes would be misleading.

import SwiftUI
import SlothCore

struct ProcessesView: View {

    @Environment(SlothStore.self) private var store

    var body: some View {
        let rows = sortedProcesses
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "No process records",
                    systemImage: "cpu",
                    description: Text("Sloth emits one `process` record per active PID per second once flow→PID attribution is online.")
                )
            } else {
                List(rows) { proc in
                    ProcessRow(
                        proc:      proc,
                        rxSamples: store.processRxSamples[proc.pid] ?? [],
                        txSamples: store.processTxSamples[proc.pid] ?? []
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Processes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedProcesses: [ProcessEntry] {
        store.processes.values.sorted { lhs, rhs in
            // Pin unresolved bucket below every real process.
            if lhs.isUnresolved != rhs.isUnresolved { return !lhs.isUnresolved }
            if lhs.totalRate != rhs.totalRate { return lhs.totalRate > rhs.totalRate }
            if lhs.connCount != rhs.connCount { return lhs.connCount > rhs.connCount }
            return lhs.pid < rhs.pid
        }
    }
}

private struct ProcessRow: View {

    let proc:      ProcessEntry
    let rxSamples: [Double]
    let txSamples: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: proc.isUnresolved ? "questionmark.circle" : "cpu")
                    .foregroundStyle(headlineTint)
                Text(displayName)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(headlineTint)
                    .lineLimit(1)
                if !proc.isUnresolved {
                    Text("pid \(proc.pid)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(formatRate(proc.totalRate))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(rateTint(proc.totalRate))
            }
            HStack(spacing: 12) {
                Label(formatRate(proc.rxRate), systemImage: "arrow.down")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.phosphorTeal)
                Label(formatRate(proc.txRate), systemImage: "arrow.up")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.alertHotLow)
                Spacer()
                BandwidthSparkline(
                    samples: zip(rxSamples, txSamples).map(+),
                    tint: nil   // heat-graded so spikes stand out
                )
                .frame(width: 90, height: 22)
            }
            HStack(spacing: 8) {
                Label("\(proc.connCount) conn", systemImage: "link")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                if proc.tcpCount > 0 {
                    Text("tcp \(proc.tcpCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.phosphorTeal)
                }
                if proc.udpCount > 0 {
                    Text("udp \(proc.udpCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.phosphorBright)
                }
                if !proc.ports.isEmpty {
                    Text(portsSummary)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var headlineTint: Color {
        proc.isUnresolved ? .secondary : .phosphorBright
    }

    private var displayName: String {
        let name = proc.proc?.trimmingCharacters(in: .whitespaces) ?? ""
        if proc.isUnresolved { return name.isEmpty ? "(unresolved)" : name }
        return name.isEmpty ? "pid \(proc.pid)" : name
    }

    /// Show at most the first 6 ports so chatty processes (browsers,
    /// dev servers) don't blow the row wider than the screen.
    private var portsSummary: String {
        let head = proc.ports.prefix(6).map(String.init).joined(separator: " ")
        let suffix = proc.ports.count > 6 ? " +\(proc.ports.count - 6)" : ""
        return ":\(head)\(suffix)"
    }

    /// Visual hint for "this process is using real bandwidth".
    /// Thresholds are bytes/sec; cool below 100 KB/s, amber above
    /// 1 MB/s, red above 10 MB/s.
    private func rateTint(_ bps: Double) -> Color {
        switch bps {
        case ..<100_000:    return .secondary
        case ..<1_000_000:  return .phosphorBright
        case ..<10_000_000: return .alertHotWarn
        default:            return .alertHotCrit
        }
    }
}

/// File-private bytes/sec → human-readable. Same shape as the
/// equivalent helpers in TopHostsView / InterfacesView — kept local
/// rather than hoisted; three call sites, three small lines.
fileprivate func formatRate(_ bps: Double) -> String {
    switch bps {
    case ..<1_000:         return "\(Int(bps.rounded())) B/s"
    case ..<1_000_000:     return String(format: "%.1f KB/s", bps / 1_000)
    case ..<1_000_000_000: return String(format: "%.2f MB/s", bps / 1_000_000)
    default:               return String(format: "%.2f GB/s", bps / 1_000_000_000)
    }
}
