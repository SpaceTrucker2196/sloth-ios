// DiagnosticsView — M8. Last 500 in-process log lines, filterable by
// level, exportable via the system share sheet as plain text.
//
// MISSION §2(5): records themselves never go through this view —
// the export is project metadata only (connection events, parse
// errors, backoff delays, lifecycle transitions).

import SwiftUI
import SlothCore

struct DiagnosticsView: View {

    @Environment(SlothLog.self) private var log
    @Environment(\.dismiss)     private var dismiss

    @State private var minLevel: SlothLog.Level = .info

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                levelStrip
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No log entries",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Connection events and parse errors land here.")
                    )
                } else {
                    List(filtered) { line in
                        LogRow(line: line)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        ShareLink(item: log.exportAsText()) {
                            Label("Share as text", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            log.clear()
                        } label: {
                            Label("Clear log", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var levelStrip: some View {
        HStack(spacing: 8) {
            ForEach(SlothLog.Level.allCases, id: \.self) { lvl in
                Button {
                    minLevel = lvl
                } label: {
                    Text(lvl.rawValue.uppercased())
                        .font(.caption.monospaced())
                        .fontWeight(minLevel == lvl ? .bold : .regular)
                        .foregroundStyle(minLevel == lvl ? .white : levelTint(lvl))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(minLevel == lvl ? levelTint(lvl) : Color.clear)
                                .overlay(Capsule().stroke(levelTint(lvl), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(filtered.count) / \(log.lines.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var filtered: [SlothLog.Line] {
        let threshold = order(minLevel)
        return log.lines.filter { order($0.level) >= threshold }
                        .reversed()  // newest-first display
    }

    private func order(_ lvl: SlothLog.Level) -> Int {
        switch lvl {
        case .debug: return 0
        case .info:  return 1
        case .warn:  return 2
        case .error: return 3
        }
    }

    private func levelTint(_ lvl: SlothLog.Level) -> Color {
        switch lvl {
        case .debug: return .secondary
        case .info:  return .phosphorTeal
        case .warn:  return .alertHotWarn
        case .error: return .alertHotCrit
        }
    }
}

private struct LogRow: View {

    let line: SlothLog.Line

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(timeFormatter.string(from: line.timestamp))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .leading)
            Text(line.level.rawValue.uppercased())
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, alignment: .leading)
            Text(line.category)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(line.message)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch line.level {
        case .debug: return .secondary
        case .info:  return .phosphorTeal
        case .warn:  return .alertHotWarn
        case .error: return .alertHotCrit
        }
    }
}

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()
