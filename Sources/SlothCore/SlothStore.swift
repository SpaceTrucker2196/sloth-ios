// SlothStore — single source of truth for everything that came off
// the sloth `--data-socket` wire.
//
// Views observe `SlothStore` via `@Environment(SlothStore.self)`;
// they do not own data and never call back into `SlothClient`
// directly. The store owns:
//
//   * one fixed-size ring per known record type (caps in `RingSizes`)
//   * a derived `alerts` collection keyed by alert `key`, sorted
//     newest-first by `lastSeen`
//   * the cross-panel `AlertHotIndex` (promotion-only IP → severity)
//   * a connection lifecycle for the active client task
//
// Strict-concurrency: the store is `@MainActor` isolated. `ingest(_:)`
// is intended to be called from a `Task` consuming a
// `SlothClient.records(for:)` stream — see `ingest(stream:)`.

import Foundation
import Observation

@MainActor
@Observable
public final class SlothStore {

    public enum ConnectionState: Sendable, Equatable {
        case idle
        case connecting
        case connected
        case disconnected(reason: String?)
    }

    // Per-type rings. Newest record at the end; oldest at the front.
    // Views that want newest-first reverse on read.
    public private(set) var dns:  [DNSEntry]  = []
    public private(set) var tls:  [TLSEntry]  = []
    public private(set) var quic: [QUICEntry] = []
    public private(set) var http: [HTTPEntry] = []
    public private(set) var ntp:  [NTPEntry]  = []
    public private(set) var icmp: [ICMPEntry] = []

    /// Connections ring (M6). Sloth emits one record per active flow
    /// per emit-tick; the `ConnectionsAggregator` dedups by
    /// `(src, dst, proto)` and keeps a per-flow RTT sample series
    /// from the tail of this ring.
    public private(set) var connections: [ConnectionEntry] = []

    /// Alerts ring. Keyed by `entry.key ?? entry.title` so successive
    /// hits for the same alert replace (and refresh) the prior row —
    /// the TUI shows one row per key with a hit count, not one row
    /// per occurrence. Sorted newest-first by `lastSeen`.
    public private(set) var alerts: [AlertEntry] = []

    /// Count of records whose `type` we didn't recognise. Surfaced
    /// in diagnostics so a sloth-side schema bump is visible to the
    /// operator without breaking ingest.
    public private(set) var unknownCount: Int = 0

    public private(set) var recordsReceived: Int = 0
    public private(set) var connectionState: ConnectionState = .idle
    public private(set) var lastError: String?

    public let sizes:    RingSizes
    public let alertHot: AlertHotIndex

    public init(
        sizes:    RingSizes     = .default,
        alertHot: AlertHotIndex? = nil
    ) {
        // Defaulting `alertHot` to `AlertHotIndex()` directly at the
        // parameter site trips a Swift 5.10 IRGen crash (signal 11)
        // when SlothStore is `@MainActor @Observable`. Constructing
        // inside the body sidesteps it and is otherwise identical.
        self.sizes    = sizes
        self.alertHot = alertHot ?? AlertHotIndex()
    }

    // MARK: - Ingest

    public func ingest(_ record: SlothRecord) {
        switch record {
        case .dns  (let e): append(e, into: \.dns,  cap: sizes.dns)
        case .tls  (let e): append(e, into: \.tls,  cap: sizes.tls)
        case .quic (let e): append(e, into: \.quic, cap: sizes.quic)
        case .http (let e): append(e, into: \.http, cap: sizes.http)
        case .ntp  (let e): append(e, into: \.ntp,  cap: sizes.ntp)
        case .icmp        (let e): append(e, into: \.icmp,        cap: sizes.icmp)
        case .alert       (let e): ingestAlert(e)
        case .connections (let e): append(e, into: \.connections, cap: sizes.connections)
        case .unknown:             unknownCount += 1
        }
        recordsReceived += 1
        if connectionState != .connected { connectionState = .connected }
    }

    /// Drive the store from a `SlothClient` stream. Returns when the
    /// stream finishes (cleanly or with error). Cancellation of the
    /// owning task terminates the loop.
    public func ingest(
        stream: AsyncThrowingStream<SlothRecord, any Error>
    ) async {
        lastError = nil
        connectionState = .connecting
        do {
            for try await record in stream {
                ingest(record)
            }
            connectionState = .disconnected(reason: nil)
        } catch is CancellationError {
            connectionState = .idle
        } catch {
            let reason = error.localizedDescription
            lastError = reason
            connectionState = .disconnected(reason: reason)
        }
    }

    /// Reset all rings and counters. Used by tests and (eventually)
    /// by an operator-facing "clear log" gesture if one is ever
    /// added — MISSION §2 forbids a "clear alerts" button, but a
    /// hard reset on profile-switch is fine.
    public func reset() {
        dns.removeAll()
        tls.removeAll()
        quic.removeAll()
        http.removeAll()
        ntp.removeAll()
        icmp.removeAll()
        alerts.removeAll()
        connections.removeAll()
        unknownCount = 0
        recordsReceived = 0
        connectionState = .idle
        lastError = nil
        alertHot.clear()
    }

    // MARK: - Internals

    private func append<T>(_ value: T, into keyPath: ReferenceWritableKeyPath<SlothStore, [T]>, cap: Int) {
        self[keyPath: keyPath].append(value)
        let overflow = self[keyPath: keyPath].count - cap
        if overflow > 0 {
            self[keyPath: keyPath].removeFirst(overflow)
        }
    }

    private func ingestAlert(_ entry: AlertEntry) {
        alertHot.note(entry)
        let key = entry.key ?? entry.title
        if let i = alerts.firstIndex(where: { ($0.key ?? $0.title) == key }) {
            alerts.remove(at: i)
        }
        alerts.append(entry)
        alerts.sort { $0.lastSeen > $1.lastSeen }
        let overflow = alerts.count - sizes.alerts
        if overflow > 0 {
            alerts.removeLast(overflow)
        }
    }
}
