// DebugLogController — view-local controller for the M1 debug log
// screen. Owns the connection task, the visible record ring, and the
// connection status pill. M2 replaces this with `SlothStore`; for now
// the controller is private to ContentView's hierarchy.

import Foundation
import Observation
import SlothCore

@MainActor
@Observable
final class DebugLogController {

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case disconnected(reason: String?)
    }

    struct Line: Identifiable, Equatable {
        let id = UUID()
        let typeTag: String
        let ts: Int
        let summary: String
    }

    private static let maxLines = 500

    var profileURI: String
    var state: ConnectionState = .idle
    var lines: [Line] = []
    var lastError: String?

    private var task: Task<Void, Never>?
    private let client: SlothClient

    init(client: SlothClient = SlothClient()) {
        self.client = client
        self.profileURI = ConnectionProfile.load()?.uri ?? "tcp:host.tailnet:7777"
    }

    func connect() {
        guard let profile = ConnectionProfile(uri: profileURI) else {
            lastError = "Invalid URI — expected tcp:HOST:PORT"
            return
        }
        profile.save()
        lastError = nil
        disconnect()
        state = .connecting
        let stream = client.records(for: profile)
        task = Task { [weak self] in
            await self?.consume(stream)
        }
    }

    func disconnect() {
        task?.cancel()
        task = nil
        if case .connected = state { state = .disconnected(reason: nil) }
        if case .connecting = state { state = .idle }
    }

    func clearLog() {
        lines.removeAll()
    }

    private func consume(_ stream: AsyncThrowingStream<SlothRecord, any Error>) async {
        do {
            for try await record in stream {
                append(record)
            }
            state = .disconnected(reason: nil)
        } catch is CancellationError {
            // user-initiated; state already updated by disconnect()
        } catch {
            state = .disconnected(reason: error.localizedDescription)
        }
    }

    private func append(_ record: SlothRecord) {
        if state != .connected { state = .connected }
        lines.append(Line(
            typeTag: record.typeTag,
            ts: record.ts,
            summary: Self.summarize(record)
        ))
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }

    private static func summarize(_ r: SlothRecord) -> String {
        switch r {
        case .dns(let e):
            let answer = e.answer.map { " → \($0)" } ?? ""
            return "\(e.qname) \(e.qtype ?? "")\(answer)"
        case .tls(let e):
            return "\(e.sni ?? "?") \(e.version ?? "") → \(e.dst ?? "?")"
        case .quic(let e):
            return "\(e.sni ?? "?") \(e.version ?? "") → \(e.dst ?? "?")"
        case .http(let e):
            return "\(e.method ?? "") \(e.host ?? "?")\(e.path ?? "")"
        case .ntp(let e):
            return "stratum \(e.stratum.map(String.init) ?? "?") → \(e.dst ?? "?")"
        case .icmp(let e):
            return "type \(e.icmpType.map(String.init) ?? "?") → \(e.dst ?? "?")"
        case .alert(let e):
            return "[\(e.severity.displayName)] \(e.title) ×\(e.hits)"
        case .unknown(let tag, _):
            return "(unknown:\(tag))"
        }
    }
}
