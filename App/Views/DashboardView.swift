// DashboardView — M7. iPad-first composite that tiles the four
// primary panels (Alerts, Top hosts, DNS, TLS) into a single
// 2×2 grid. Mirrors sloth's static TUI composite — no pinch,
// no drag, no per-card reorder. iPhone falls back to the existing
// TabView in ContentView.
//
// Each tile embeds the production view (M3–M5) inside its own
// NavigationStack so push destinations (alert detail, host
// detail) still work from within the tile.

import SwiftUI
import SlothCore

struct DashboardView: View {

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                tile(title: "ALERTS",     icon: "exclamationmark.triangle", tint: .alertHotCrit) {
                    NavigationStack { AlertsView() }
                }
                tile(title: "TOP HOSTS",  icon: "globe.americas",           tint: .phosphorTeal) {
                    NavigationStack { TopHostsView() }
                }
            }
            GridRow {
                tile(title: "DNS",        icon: "questionmark.bubble",      tint: .phosphorBright) {
                    NavigationStack { DNSLogView() }
                }
                tile(title: "TLS",        icon: "lock",                     tint: .phosphorTeal) {
                    NavigationStack { TLSLogView() }
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
