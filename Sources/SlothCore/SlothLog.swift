// SlothLog — in-process diagnostic log surfaced by the M8
// `DiagnosticsView`. Mirrors entries to `os.Logger` so they also
// appear in Console.app / `log stream`, and keeps the last N lines
// in-memory for the operator-facing list.
//
// What this log DOES carry: connection events ("connect attempt to
// host.tailnet:7777", "disconnect after 47 records"), parse errors,
// backoff delays, app lifecycle transitions.
//
// What this log NEVER carries: record content (DNS qnames, IPs,
// SNIs, paths, ja3, etc.). MISSION §2(5) — the diagnostics export
// is text, never JSONL. Call sites pass project metadata only.

import Foundation
import Observation
import os

@MainActor
@Observable
public final class SlothLog {

    public enum Level: String, Sendable, Equatable, CaseIterable {
        case debug, info, warn, error
    }

    public struct Line: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let level: Level
        public let category: String
        public let message: String

        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            level: Level,
            category: String,
            message: String
        ) {
            self.id = id
            self.timestamp = timestamp
            self.level = level
            self.category = category
            self.message = message
        }
    }

    public private(set) var lines: [Line] = []
    public let cap: Int

    private let subsystem = "io.river.sloth.ios"
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public init(cap: Int = 500) {
        self.cap = cap
    }

    public func debug(_ category: String = "app", _ message: String) {
        append(.init(level: .debug, category: category, message: message))
    }
    public func info(_ category: String = "app", _ message: String) {
        append(.init(level: .info,  category: category, message: message))
    }
    public func warn(_ category: String = "app", _ message: String) {
        append(.init(level: .warn,  category: category, message: message))
    }
    public func error(_ category: String = "app", _ message: String) {
        append(.init(level: .error, category: category, message: message))
    }

    public func clear() { lines.removeAll() }

    /// Plain-text snapshot for the system share sheet. Stable schema
    /// (ISO-ish time, padded level, category, message) so an operator
    /// can grep / diff the export.
    public func exportAsText() -> String {
        lines.map { line in
            "\(formatter.string(from: line.timestamp)) " +
            "\(line.level.rawValue.uppercased().padding(toLength: 5, withPad: " ", startingAt: 0)) " +
            "[\(line.category)] \(line.message)"
        }.joined(separator: "\n")
    }

    // MARK: - Internal

    private func append(_ line: Line) {
        lines.append(line)
        if lines.count > cap {
            lines.removeFirst(lines.count - cap)
        }
        mirror(line)
    }

    private func mirror(_ line: Line) {
        let logger = Logger(subsystem: subsystem, category: line.category)
        let msg = line.message
        switch line.level {
        case .debug: logger.debug("\(msg, privacy: .public)")
        case .info:  logger.info ("\(msg, privacy: .public)")
        case .warn:  logger.warning("\(msg, privacy: .public)")
        case .error: logger.error("\(msg, privacy: .public)")
        }
    }
}
