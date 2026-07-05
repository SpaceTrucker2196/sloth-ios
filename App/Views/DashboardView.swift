// DashboardView — iPad Tufte band composite. Supersedes the M7 tile
// grid: instead of six full interactive views in cards, the board is
// a vertical stack of dense read-only bands mirroring sloth's TUI
// dashboard (`src/views/dashboard.c`), worst news highest:
//
//   Interfaces + Summary
//   CRITICAL (full width, eye level)
//   Connections + Top hosts
//   WiFi | Roaming | Beacons
//   mDNS | DHCP | SSDP
//   ARP | Deauth
//   DNS | ICMP
//   Packets (tail)
//
// Tap a band title to push the full view — the TUI's Enter-to-drill.
// The board forces dark mode on true black; the phosphor palette is
// designed for it. iPhone keeps the TabView in ContentView.
//
// Spec: docs/views/dashboard.md. Band/panel implementations mirror
// sloth's file split: DashboardBands.swift (wide bands),
// DashboardGrid.swift (thirds/halves), DashboardPrimitives.swift
// (band frame + row atoms).

import SwiftUI
import SlothCore

struct DashboardView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    IfaceSummaryBand()
                    CritAlertsBand()
                    ConnsHostsBand()
                    HStack(alignment: .top, spacing: 10) {
                        WiFiPanel(); ColumnRule()
                        RoamingPanel(); ColumnRule()
                        BeaconPanel()
                    }
                    HStack(alignment: .top, spacing: 10) {
                        MDNSPanel(); ColumnRule()
                        DHCPPanel(); ColumnRule()
                        SSDPPanel()
                    }
                    HStack(alignment: .top, spacing: 10) {
                        ARPPanel(); ColumnRule()
                        DeauthPanel()
                    }
                    HStack(alignment: .top, spacing: 10) {
                        DNSLogPanel(); ColumnRule()
                        ICMPLogPanel()
                    }
                    PacketsBand()
                }
                .padding(14)
            }
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DashboardRoute.self, destination: drill)
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func drill(_ route: DashboardRoute) -> some View {
        switch route {
        case .interfaces:  InterfacesView()
        case .alerts:      AlertsView()
        case .connections: ConnectionsView()
        case .topHosts:    TopHostsView()
        case .wifi:        WiFiView()
        case .lan:         LANView()
        case .twins:       TwinsView()
        case .dns:         DNSLogView()
        case .packets:     PacketsView()
        }
    }
}

#Preview {
    DashboardView()
        .environment(SlothStore())
}
