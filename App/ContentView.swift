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
// Settings + Diagnostics (M8) present as sheets from the connection
// bar's gear icon. M6 adds a Connections tab once sloth emits
// connection JSONL records.

import SwiftUI
import SlothCore

struct ContentView: View {

    @Environment(SlothStore.self)        private var store
    @Environment(ProfileStore.self)      private var profileStore
    @Environment(SlothLog.self)          private var log
    @Environment(\.scenePhase)           private var scenePhase
    @Environment(\.horizontalSizeClass)  private var hSize
    @State private var coordinator: ConnectionCoordinator?
    @State private var showSettings    = false
    @State private var showDiagnostics = false
    @State private var showDiscovery   = false

    var body: some View {
        VStack(spacing: 0) {
            if let coordinator {
                ConnectionBar(
                    coordinator: coordinator,
                    store: store,
                    onDiscover:    { showDiscovery = true },
                    onSettings:    { showSettings = true },
                    onDiagnostics: { showDiagnostics = true }
                )
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
                coordinator = ConnectionCoordinator(
                    store:        store,
                    profileStore: profileStore,
                    log:          log
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                log.info("app", "scene active")
                if case .disconnected = store.connectionState {
                    coordinator?.connect()
                }
            case .background:
                log.info("app", "scene backgrounded — cancelling connect loop")
                coordinator?.disconnect()
            default:
                break
            }
        }
        .onChange(of: profileStore.activeID) { _, _ in
            coordinator?.loadActiveIntoDraft()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(profileStore)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
                .environment(log)
        }
        .sheet(isPresented: $showDiscovery) {
            DiscoveryView()
                .environment(profileStore)
                .environment(log)
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
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { AlertsView() }
                .tabItem { Label("Alerts", systemImage: "exclamationmark.triangle") }
                .badge(severityCount(.crit))

            NavigationStack { ProcessesView() }
                .tabItem { Label("Procs", systemImage: "cpu") }

            NavigationStack { WiFiAPsView() }
                .tabItem { Label("WiFi", systemImage: "wifi") }

            NavigationStack { DevicesView() }
                .tabItem { Label("Devices", systemImage: "rectangle.connected.to.line.below") }

            // Hosts + Flows are reachable from HomeView's "All →"
            // section headers; keeping them off the tab bar avoids the
            // M7 overlap and frees a tab slot.
            NavigationStack { TwinsView() }
                .tabItem { Label("Twins", systemImage: "shield.checkered") }
                .badge(twinCount)

            NavigationStack { InterfacesView() }
                .tabItem { Label("Iface", systemImage: "network") }

            NavigationStack { DNSLogView() }
                .tabItem { Label("DNS", systemImage: "questionmark.bubble") }

            NavigationStack { TLSLogView() }
                .tabItem { Label("TLS", systemImage: "lock") }

            NavigationStack { HTTPLogView() }
                .tabItem { Label("HTTP", systemImage: "globe") }
        }
    }

    /// Count of twin episodes whose severity is WARN or CRIT — what
    /// the operator wants to be paged about. LOW is passive detection
    /// only and would be noisy as a tab badge.
    private var twinCount: Int {
        store.twinEpisodes.values.reduce(0) { acc, e in
            acc + (e.severity == .low ? 0 : 1)
        }
    }

    private func severityCount(_ sev: AlertSeverity) -> Int {
        store.alerts.reduce(0) { $0 + ($1.severity == sev ? 1 : 0) }
    }
}

private struct ConnectionBar: View {

    @Bindable var coordinator: ConnectionCoordinator
    let store: SlothStore
    let onDiscover:    () -> Void
    let onSettings:    () -> Void
    let onDiagnostics: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("tcp:HOST:PORT", text: $coordinator.draftURI)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(coordinator.connect)
            Button(action: onDiscover) {
                Image(systemName: "wifi.router")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Discover sloth on local network")

            Button(action: coordinator.connect) {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel(buttonLabel)

            Menu {
                Button {
                    onDiscover()
                } label: {
                    Label("Discover…", systemImage: "wifi.router")
                }
                Button {
                    onSettings()
                } label: {
                    Label("Profiles…", systemImage: "person.crop.circle")
                }
                Button {
                    onDiagnostics()
                } label: {
                    Label("Diagnostics…", systemImage: "stethoscope")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("More")
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
        .environment(ProfileStore())
        .environment(SlothLog())
}
