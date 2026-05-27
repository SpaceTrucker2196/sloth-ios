// AlertsView — M3, first production view.
//
// Layout (top → bottom):
//   1. Severity filter chips ([All] [CRIT] [WARN] [LOW])
//   2. Search field (substring match against title + detail + key)
//   3. AlertFrequencyChart — alerts/minute over last 60m, stacked by sev
//   4. List of alerts (newest first), severity-coloured rows
//   5. Empty state when no alerts have arrived
//
// All filtering / search is client-side over `SlothStore.alerts`.

import SwiftUI
import SlothCore

struct AlertsView: View {

    @Environment(SlothStore.self) private var store

    @State private var search: String = ""
    @State private var visibleSeverities: Set<AlertSeverity> = Set(AlertSeverity.allCases)

    /// Re-bucket on a 5-second cadence so the chart x-axis advances
    /// even when no new alerts are arriving. Cheap; `AlertBucketing`
    /// is a single pass over the alerts ring.
    @State private var tick: Date = Date()
    private let tickPublisher = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            filterStrip
            searchField
            chartSection
            Divider()
            listSection
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(tickPublisher) { tick = $0 }
    }

    // MARK: - Filter chips

    private var filterStrip: some View {
        HStack(spacing: 8) {
            FilterChip(label: "All", isOn: visibleSeverities == Set(AlertSeverity.allCases)) {
                visibleSeverities = Set(AlertSeverity.allCases)
            }
            ForEach(AlertSeverity.allCases.reversed(), id: \.self) { sev in
                FilterChip(
                    label: sev.displayName,
                    tint:  sev.color,
                    isOn:  visibleSeverities.contains(sev)
                ) {
                    toggle(sev)
                }
            }
            Spacer()
            countsLabel
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func toggle(_ sev: AlertSeverity) {
        // Tapping a single chip when "All" is active narrows to just
        // that chip; tapping it again re-broadens to All. Multi-select
        // works via additional chip taps.
        if visibleSeverities == Set(AlertSeverity.allCases) {
            visibleSeverities = [sev]
        } else if visibleSeverities.contains(sev) {
            visibleSeverities.remove(sev)
            if visibleSeverities.isEmpty {
                visibleSeverities = Set(AlertSeverity.allCases)
            }
        } else {
            visibleSeverities.insert(sev)
        }
    }

    private var countsLabel: some View {
        let totals = severityCounts(store.alerts)
        return HStack(spacing: 6) {
            countDot(totals[.crit] ?? 0, color: .alertHotCrit)
            countDot(totals[.warn] ?? 0, color: .alertHotWarn)
            countDot(totals[.low]  ?? 0, color: .alertHotLow)
        }
    }

    private func countDot(_ n: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(n)").font(.caption2.monospacedDigit())
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("title, detail, key…", text: $search)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Chart

    private var chartSection: some View {
        let buckets = AlertBucketing.buckets(from: store.alerts, now: tick)
        return AlertFrequencyChart(buckets: buckets, windowMinutes: 60)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    // MARK: - List

    private var listSection: some View {
        let rows = filtered
        return Group {
            if rows.isEmpty {
                emptyState
            } else {
                List(rows, id: \.identityKey) { alert in
                    NavigationLink {
                        AlertDetailView(alert: alert)
                    } label: {
                        AlertRowView(alert: alert, isHot: isHot(alert))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            store.alerts.isEmpty ? "Nothing on fire" : "No matches",
            systemImage: store.alerts.isEmpty ? "checkmark.shield" : "magnifyingglass",
            description: Text(
                store.alerts.isEmpty
                ? "Sloth hasn't flagged anything yet — alerts show up here as they fire."
                : "No alerts match the current filters."
            )
        )
    }

    // MARK: - Derived

    private var filtered: [AlertEntry] {
        var rows = store.alerts.filter { visibleSeverities.contains($0.severity) }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            rows = rows.filter { a in
                a.title.lowercased().contains(q) ||
                (a.detail?.lowercased().contains(q) ?? false) ||
                (a.key?.lowercased().contains(q) ?? false)
            }
        }
        return rows
    }

    private func isHot(_ alert: AlertEntry) -> Bool {
        guard let ip = alert.matchIP else { return false }
        return store.alertHot.severity(for: ip) != nil
    }

    private func severityCounts(_ alerts: [AlertEntry]) -> [AlertSeverity: Int] {
        var out: [AlertSeverity: Int] = [:]
        for a in alerts { out[a.severity, default: 0] += 1 }
        return out
    }
}

// MARK: - Filter chip primitive

private struct FilterChip: View {
    let label: String
    var tint:  Color = .accentColor
    let isOn:  Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.monospaced())
                .fontWeight(isOn ? .bold : .regular)
                .foregroundStyle(isOn ? .white : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isOn ? tint : Color.clear)
                        .overlay(Capsule().stroke(tint, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Identity for List

private extension AlertEntry {
    /// Stable identifier so the same alert key doesn't get re-created
    /// in the List when its hits/lastSeen change.
    var identityKey: String { key ?? "\(title)#\(firstSeen)" }
}
