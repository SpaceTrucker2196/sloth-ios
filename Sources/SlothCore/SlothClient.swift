// SlothClient — wire-level consumer for a sloth `--data-socket`.
//
// The client owns the byte path (transport → newline framer → JSON
// decoder) and emits a stream of typed `SlothRecord` values. The
// transport is injectable so tests can substitute a deterministic
// in-memory seam without touching `Network.framework`.
//
// Per docs/wiki/jsonl-protocol.md:
//   * A garbled JSON line is dropped, not fatal — sloth's writer
//     never emits invalid JSON, so a bad line is wire corruption and
//     losing one record is preferable to tearing down the stream.
//     M8 wires an OSLog surface; until then the drop is silent.
//   * `connect()` failures and mid-stream disconnects surface as the
//     stream finishing with an error; the caller retries (M8 will
//     wrap this in a backoff `Reconnector`).
//   * iOS reaps the socket on background; the caller cancels the
//     stream and re-opens on foreground.

import Foundation
import Network

// MARK: - Transport seam

public protocol SlothTransport: Sendable {
    /// Open a connection and yield raw byte chunks as they arrive.
    /// Finishes normally on clean disconnect, with an error on
    /// connect failure or mid-stream loss. The caller terminates the
    /// stream (cancel/onTermination) to close the socket.
    func bytes(for profile: ConnectionProfile) -> AsyncThrowingStream<Data, any Error>
}

// MARK: - Errors

public enum SlothClientError: Error, Sendable, Equatable {
    case invalidPort(UInt16)
}

// MARK: - Default transport (Network.framework)

public struct NetworkTransport: SlothTransport {

    public init() {}

    public func bytes(
        for profile: ConnectionProfile
    ) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream<Data, any Error> { continuation in
            guard let port = NWEndpoint.Port(rawValue: profile.port) else {
                continuation.finish(throwing: SlothClientError.invalidPort(profile.port))
                return
            }
            let host = NWEndpoint.Host(profile.host)
            // includePeerToPeer = true ensures iOS surfaces the
            // "Local Network" permission prompt for LAN / .local
            // targets. Without it a first-launch connect to a private
            // IPv4 (or *.local) silently fails until the operator
            // opens Discovery (which also triggers the prompt).
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let box  = NWConnectionBox(
                NWConnection(host: host, port: port, using: params)
            )
            let queue = DispatchQueue(label: "io.river.sloth.transport")

            box.conn.stateUpdateHandler = { state in
                switch state {
                case .failed(let err):
                    continuation.finish(throwing: err)
                case .waiting(let err):
                    // Path can't be established (no route, refused).
                    // Don't sit in `waiting` forever; surface and let
                    // the caller decide whether to retry.
                    continuation.finish(throwing: err)
                case .cancelled:
                    continuation.finish()
                default:
                    break
                }
            }

            continuation.onTermination = { _ in
                box.conn.cancel()
            }

            Self.pump(box: box, continuation: continuation)
            box.conn.start(queue: queue)
        }
    }

    private static func pump(
        box: NWConnectionBox,
        continuation: AsyncThrowingStream<Data, any Error>.Continuation
    ) {
        box.conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                continuation.yield(data)
            }
            if let error {
                continuation.finish(throwing: error)
                return
            }
            if isComplete {
                continuation.finish()
                return
            }
            Self.pump(box: box, continuation: continuation)
        }
    }
}

/// `NWConnection` is callback-driven and queue-confined, but the
/// SDK doesn't yet declare it `Sendable`. Wrapping it in a tiny box
/// makes the safety contract explicit: we only touch it from the
/// connection's own dispatch queue.
private final class NWConnectionBox: @unchecked Sendable {
    let conn: NWConnection
    init(_ conn: NWConnection) { self.conn = conn }
}

// MARK: - Client

public struct SlothClient: Sendable {

    private let transport: any SlothTransport

    public init(transport: any SlothTransport = NetworkTransport()) {
        self.transport = transport
    }

    /// Stream of parsed records for a profile. The stream finishes
    /// normally when the server closes, or with an error on transport
    /// failure. Garbled JSON lines are skipped (not fatal).
    ///
    /// `onWireFormatMismatch` (optional) fires the first time a
    /// dropped line classifies as a non-JSONL format (CEF / RFC 5424
    /// syslog). Set by callers that want to surface a misconfigured
    /// `--out-format` on the producer side (sloth 1.4+); pass nil to
    /// preserve the previous silent-drop behaviour.
    public func records(
        for profile: ConnectionProfile,
        onWireFormatMismatch: (@Sendable (WireFormat) -> Void)? = nil
    ) -> AsyncThrowingStream<SlothRecord, any Error> {
        let chunks = transport.bytes(for: profile)
        let lines  = LineReader.lines(from: chunks)
        return AsyncThrowingStream<SlothRecord, any Error> { continuation in
            let task = Task {
                let decoder = JSONDecoder()
                var mismatchSurfaced = false
                do {
                    for try await line in lines {
                        if line.isEmpty { continue }
                        if let record = try? decoder.decode(SlothRecord.self, from: line) {
                            continuation.yield(record)
                            continue
                        }
                        // Decode failed. If the caller wants a hint,
                        // sniff the line and fire once per stream when
                        // we recognise a non-JSONL format.
                        if !mismatchSurfaced, let handler = onWireFormatMismatch {
                            let fmt = WireFormat.sniff(line)
                            if fmt == .cef || fmt == .syslog {
                                mismatchSurfaced = true
                                handler(fmt)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
