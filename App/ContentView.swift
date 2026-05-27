// ContentView — connection chrome stays at the top, content area is
// a `TabView`. M5 brings the tab roster to its post-`DebugLogView`
// shape:
//
//   Alerts — M3
//   Hosts  — M4
//   DNS    — M5
//   TLS    — M5
//   HTTP   — M5
//
// M6 adds Connections; M7 composites the lot into a single
// `DashboardView` that becomes tab 1.

import SwiftUI
import SlothCore

struct ContentView: View {

    @Environment(SlothStore.self) private var store
    @Environment(\.scenePhase)    private var scenePhase
    @State private var coordinator: ConnectionCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            if let coordinator {
                ConnectionBar(coordinator: coordinator, store: store)
            } else {
                ProgressView().padding()
            }
            TabView {
                NavigationStack { AlertsView() }
                    .tabItem {
                        Label("Alerts", systemImage: "exclamationmark.triangle")
                    }
                    .badge(critBadge)

                NavigationStack { TopHostsView() }
                    .tabItem {
                        Label("Hosts", systemImage: "globe.americas")
                    }

                NavigationStack { DNSLogView() }
                    .tabItem {
                        Label("DNS", systemImage: "questionmark.bubble")
                    }

                NavigationStack { TLSLogView() }
                    .tabItem {
                        Label("TLS", systemImage: "lock")
                    }

                NavigationStack { HTTPLogView() }
                    .tabItem {
                        Label("HTTP", systemImage: "globe")
                    }
            }
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

    /// Surface unresolved CRIT alerts on the Alerts tab — the
    /// "something is on fire" cue without needing to be on that tab.
    /// 0 → no badge.
    private var critBadge: Int {
        store.alerts.filter { $0.severity == .crit }.count
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
