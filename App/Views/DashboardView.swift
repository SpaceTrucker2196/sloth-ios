// DashboardView — iPad-first composite. M7 shipped a 2×2 grid;
// M6 adds Connections, bumping the layout to 3×2 (Alerts, Top
// hosts, DNS, TLS, Connections, HTTP). Mirrors sloth's static TUI
// composite — no pinch, no drag, no per-card reorder. iPhone falls
// back to the TabView in ContentView.
//
// Each tile embeds the production view (M3–M6) inside its own
// NavigationStack so push destinations (alert detail, host detail,
// flow detail) still work from within the tile.

import SwiftUI
import SlothCore

struct DashboardView: View {

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                tile(title: "ALERTS", icon: "exclamationmark.triangle", tint: .alertHotCrit) {
                    NavigationStack { AlertsView() }
                }
                tile(title: "TOP HOSTS", icon: "globe.americas", tint: .phosphorTeal) {
                    NavigationStack { TopHostsView() }
                }
            }
            GridRow {
                tile(title: "DNS", icon: "questionmark.bubble", tint: .phosphorBright) {
                    NavigationStack { DNSLogView() }
                }
                tile(title: "TLS", icon: "lock", tint: .phosphorTeal) {
                    NavigationStack { TLSLogView() }
                }
            }
            GridRow {
                tile(title: "FLOWS", icon: "point.3.connected.trianglepath.dotted", tint: .phosphorBright) {
                    NavigationStack { ConnectionsView() }
                }
                tile(title: "HTTP", icon: "globe", tint: .phosphorTeal) {
                    NavigationStack { HTTPLogView() }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func tile<C: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        DashboardCard(title: title, systemImage: icon, tint: tint, content: content)
    }
}
