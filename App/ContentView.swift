// ContentView — M2 debug surface. Profile entry + status pill + a
// merged scrolling log fed by `SlothStore`. M3 replaces the merged
// log with the dedicated `AlertsView`; per-category log views land
// in M5; the composite dashboard lands in M7.

import SwiftUI
import SlothCore

struct ContentView: View {

    @Environment(SlothStore.self) private var store
    @Environment(\.scenePhase)    private var scenePhase
    @State private var coordinator: ConnectionCoordinator?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let coordinator {
                    ConnectionBar(coordinator: coordinator, store: store)
                } else {
                    ProgressView().padding()
                }
                DebugLogView()
            }
            .navigationTitle("sloth")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if coordinator == nil {
                coordinator = ConnectionCoordinator(store: store)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if case .disconnected = store.connectionState {
                    coordinator?.connect()
                }
            case .background:
                coordinator?.disconnect()
            default:
                break
            }
        }
    }
}

private struct ConnectionBar: View {

    @Bindable var coordinator: ConnectionCoordinator
    let store: SlothStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusPill(state: store.connectionState)
                Spacer()
                if store.recordsReceived > 0 {
                    Text("\(store.recordsReceived) rec")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button(action: coordinator.connect) {
                    Label(buttonLabel, systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            TextField("tcp:HOST:PORT", text: $coordinator.profileURI)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(coordinator.connect)
            if let err = coordinator.parseError ?? store.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var buttonLabel: String {
        switch store.connectionState {
        case .connected, .connecting: return "Reconnect"
        default: return "Connect"
        }
    }
}

private struct StatusPill: View {

    let state: SlothStore.ConnectionState

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
        case .idle:                   return "idle"
        case .connecting:             return "connecting"
        case .connected:              return "connected"
        case .disconnected(let r):    return r.map { "disc: \($0)" } ?? "disconnected"
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

#Preview {
    ContentView()
        .environment(SlothStore())
}
