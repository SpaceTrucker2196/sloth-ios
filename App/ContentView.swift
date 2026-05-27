// ContentView — top-level root. Connection chrome stays at the top.
// The content area picks between two shapes by horizontal size class:
//
//   .regular  → `DashboardView` (M7: iPad-first composite, 2×2 grid)
//   .compact  → `TabView` (M3–M5: Alerts / Hosts / DNS / TLS / HTTP)
//
// The `SystemPulseChip` (M7) sits between the connection bar and the
// content so the operator sees the live rec/s + tier counts from
// every screen.
//
// M6 adds a Connections tab once sloth emits connection JSONL records.

import SwiftUI
import SlothCore

struct ContentView: View {

    @Environment(SlothStore.self)        private var store
    @Environment(\.scenePhase)           private var scenePhase
    @Environment(\.horizontalSizeClass)  private var hSize
    @State private var coordinator: ConnectionCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            if let coordinator {
                ConnectionBar(coordinator: coordinator, store: store)
                SystemPulseChip(
                    state:           store.connectionState,
                    recordsReceived: store.recordsReceived,
                    critCount:       severityCount(.crit),
                    warnCount:       severityCount(.warn),
                    lowCount:        severityCount(.low)
                )
            } else {
                ProgressView().padding()
            }
            content
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

    @ViewBuilder
    private var content: some View {
        if hSize == .regular {
            DashboardView()
        } else {
            phoneTabs
        }
    }

    private var phoneTabs: some View {
        TabView {
            NavigationStack { AlertsView() }
                .tabItem { Label("Alerts", systemImage: "exclamationmark.triangle") }
                .badge(severityCount(.crit))

            NavigationStack { TopHostsView() }
                .tabItem { Label("Hosts", systemImage: "globe.americas") }

            NavigationStack { DNSLogView() }
                .tabItem { Label("DNS", systemImage: "questionmark.bubble") }

            NavigationStack { TLSLogView() }
                .tabItem { Label("TLS", systemImage: "lock") }

            NavigationStack { HTTPLogView() }
                .tabItem { Label("HTTP", systemImage: "globe") }
        }
    }

    private func severityCount(_ sev: AlertSeverity) -> Int {
        store.alerts.reduce(0) { $0 + ($1.severity == sev ? 1 : 0) }
    }
}

private struct ConnectionBar: View {

    @Bindable var coordinator: ConnectionCoordinator
    let store: SlothStore

    var body: some View {
        HStack(spacing: 8) {
            TextField("tcp:HOST:PORT", text: $coordinator.profileURI)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(coordinator.connect)
            Button(action: coordinator.connect) {
                Label(buttonLabel, systemImage: "antenna.radiowaves.left.and.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(alignment: .bottomLeading) {
            if let err = coordinator.parseError ?? store.lastError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
            }
        }
        .background(.bar)
    }

    private var buttonLabel: String {
        switch store.connectionState {
        case .connected, .connecting: return "Reconnect"
        default: return "Connect"
        }
    }
}

#Preview {
    ContentView()
        .environment(SlothStore())
}
