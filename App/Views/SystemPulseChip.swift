// SystemPulseChip — at-a-glance health bar shown above every
// screen. Mirrors sloth's TUI header: connection state pill,
// records-per-second readout, and one dot+count per severity tier.
//
// M7 spec: "shows connection state pill, records-per-second
// counter, total-CRIT count, total-WARN count, total-LOW count".
//
// rec/s samples the store's `recordsReceived` delta once per second
// from a `.task` loop. The loop must read the store (a reference)
// rather than a captured parameter, and the clock must not live on
// the view struct: under live load the chip re-renders many times a
// second, and a `Timer.publish` stored in a struct property is
// re-created (and its 1 s tick reset) on every render — the readout
// sat at 0.0/s exactly when records were flowing.

import SwiftUI
import SlothCore

struct SystemPulseChip: View {

    let state: SlothStore.ConnectionState
    let critCount: Int
    let warnCount: Int
    let lowCount:  Int

    @Environment(SlothStore.self) private var store
    @State private var ratePerSecond: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(state: state)
            Text(stateLabel)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            rateView
            Spacer(minLength: 8)
            tierDot(count: critCount, tint: .alertHotCrit, label: "CRIT")
            tierDot(count: warnCount, tint: .alertHotWarn, label: "WARN")
            tierDot(count: lowCount,  tint: .alertHotLow,  label: "LOW")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .task {
            var last = store.recordsReceived
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let now = store.recordsReceived
                ratePerSecond = Double(now - last)
                last = now
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y)
    }

    private var rateView: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
            Text(String(format: "%.1f/s", ratePerSecond))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func tierDot(count: Int, tint: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .accessibilityLabel("\(count) \(label) alerts")
    }

    private var stateLabel: String {
        switch state {
        case .idle:                return "idle"
        case .connecting:          return "connecting"
        case .connected:           return "live"
        // One word: the reason is the toast's (#20), and here it wrapped
        // to seven lines and pushed the content down.
        case .disconnected: return "down"
        }
    }

    private var a11y: String {
        let rate = String(format: "%.1f", ratePerSecond)
        return "\(stateLabel), \(rate) records per second, " +
               "\(critCount) critical, \(warnCount) warning, \(lowCount) low alerts"
    }
}

private struct StatusDot: View {
    let state: SlothStore.ConnectionState

    var body: some View {
        Circle().fill(tint).frame(width: 8, height: 8)
    }

    private var tint: Color {
        switch state {
        case .idle:         return .secondary
        case .connecting:   return .yellow
        case .connected:    return .green
        case .disconnected: return .red
        }
    }
}
