// ContentView — M1 debug surface. Profile entry + status pill + a
// scrolling log of every record arriving over the wire. M2 replaces
// the log with per-category panels backed by `SlothStore`.

import SwiftUI
import SlothCore

struct ContentView: View {
    @State private var controller = DebugLogController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConnectionBar(controller: controller)
                DebugLogList(lines: controller.lines)
            }
            .navigationTitle("sloth")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if case .disconnected = controller.state { controller.connect() }
            case .background:
                controller.disconnect()
            default:
                break
            }
        }
    }
}

private struct ConnectionBar: View {
    @Bindable var controller: DebugLogController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusPill(state: controller.state)
                Spacer()
                Button(action: controller.connect) {
                    Label(buttonLabel, systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            TextField("tcp:HOST:PORT", text: $controller.profileURI)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(controller.connect)
            if let err = controller.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var buttonLabel: String {
        switch controller.state {
        case .connected, .connecting: return "Reconnect"
        default: return "Connect"
        }
    }
}

private struct StatusPill: View {
    let state: DebugLogController.ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(label).font(.caption.monospaced())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(.quaternary))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection \(label)")
    }

    private var label: String {
        switch state {
        case .idle:                       return "idle"
        case .connecting:                 return "connecting"
        case .connected:                  return "connected"
        case .disconnected(let reason):   return reason.map { "disc: \($0)" } ?? "disconnected"
        }
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

private struct DebugLogList: View {
    let lines: [DebugLogController.Line]

    var body: some View {
        if lines.isEmpty {
            ContentUnavailableView(
                "No records",
                systemImage: "waveform.path.ecg",
                description: Text("Records appear here once the sloth socket starts streaming.")
            )
        } else {
            ScrollViewReader { proxy in
                List(lines) { line in
                    LogRow(line: line).id(line.id)
                }
                .listStyle(.plain)
                .onChange(of: lines.count) { _, _ in
                    if let last = lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

private struct LogRow: View {
    let line: DebugLogController.Line

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(line.typeTag.uppercased())
                .font(.caption2.monospaced().weight(.semibold))
                .frame(width: 44, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(line.summary)
                .font(.callout.monospaced())
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }
}

#Preview {
    ContentView()
}
