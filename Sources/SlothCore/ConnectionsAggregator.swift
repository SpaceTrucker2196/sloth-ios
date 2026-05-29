// ConnectionsAggregator — turns the store's chronological
// `connections` ring into a per-flow snapshot suitable for
// `ConnectionsView`. Sloth emits one record per active flow per
// tick; we dedupe by `(src, dst, proto)`, keep the latest record
// as the row's authoritative state, and collect the tail of RTT
// samples (last `sparklineCapacity`) so the row can paint a small
// trend.
//
// Pure helper — same hermetic-test pattern as `HostAggregator` and
// the M5 `LogStats` family.

import Foundation

/// One row in the connections table.
public struct ConnectionFlow: Sendable, Equatable, Identifiable {

    public let key:       String              // ConnectionEntry.flowKey
    public let latest:    ConnectionEntry     // most-recent record for the key
    public let rttSeries: [Double]            // tail of non-nil rtt_ms samples
    public let recordCount: Int               // # of records contributing to this flow

    public var id: String { key }

    /// Combined byte volume — what the "bandwidth" sort orders by.
    public var totalBytes: Int { latest.rxBytes + latest.txBytes }

    public init(
        key: String,
        latest: ConnectionEntry,
        rttSeries: [Double],
        recordCount: Int
    ) {
        self.key = key
        self.latest = latest
        self.rttSeries = rttSeries
        self.recordCount = recordCount
    }
}

public enum ConnectionsSort: String, Sendable, Equatable, CaseIterable {
    case bandwidth   // rx+tx, descending
    case state       // alphabetical state, then bandwidth
    case rtt         // latest rtt_ms, descending; nils last
    case age         // longest-lived first
}

public enum ConnectionsAggregator {

    /// Build the snapshot. `entries` must be in arrival order (the
    /// store's `connections` ring already is).
    public static func snapshot(
        from entries: [ConnectionEntry],
        sparklineCapacity: Int = 30,
        sort: ConnectionsSort = .bandwidth
    ) -> [ConnectionFlow] {
        guard !entries.isEmpty else { return [] }

        // Single pass: group, track counts, collect RTT tail per key.
        // Insertion order is preserved with a separate `order` array
        // so the output is deterministic when the requested sort puts
        // multiple flows on the same key (e.g. when many flows have
        // identical bandwidth = 0).
        var bucket: [String: Bucket] = [:]
        var order:  [String] = []
        for entry in entries {
            let key = entry.flowKey
            if var b = bucket[key] {
                b.latest = entry
                b.count += 1
                if let rtt = entry.rttMS {
                    b.rttSeries.append(rtt)
                    if b.rttSeries.count > sparklineCapacity {
                        b.rttSeries.removeFirst(b.rttSeries.count - sparklineCapacity)
                    }
                }
                bucket[key] = b
            } else {
                var b = Bucket(latest: entry)
                if let rtt = entry.rttMS { b.rttSeries.append(rtt) }
                bucket[key] = b
                order.append(key)
            }
        }

        let flows: [ConnectionFlow] = order.compactMap { key in
            guard let b = bucket[key] else { return nil }
            return ConnectionFlow(
                key: key,
                latest: b.latest,
                rttSeries: b.rttSeries,
                recordCount: b.count
            )
        }
        return Self.apply(sort: sort, to: flows)
    }

    /// Re-sort without rebucketing. Tests + the view's sort menu use
    /// this when only the sort key changes.
    public static func apply(sort: ConnectionsSort, to flows: [ConnectionFlow]) -> [ConnectionFlow] {
        switch sort {
        case .bandwidth:
            return flows.sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
                return lhs.key < rhs.key
            }
        case .state:
            return flows.sorted { lhs, rhs in
                let ls = lhs.latest.state ?? "~"   // nil → after every named state
                let rs = rhs.latest.state ?? "~"
                if ls != rs { return ls < rs }
                if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
                return lhs.key < rhs.key
            }
        case .rtt:
            return flows.sorted { lhs, rhs in
                switch (lhs.latest.rttMS, rhs.latest.rttMS) {
                case (let l?, let r?):
                    if l != r { return l > r }
                    return lhs.key < rhs.key
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return lhs.key < rhs.key
                }
            }
        case .age:
            return flows.sorted { lhs, rhs in
                let la = lhs.latest.ageS ?? 0
                let ra = rhs.latest.ageS ?? 0
                if la != ra { return la > ra }
                return lhs.key < rhs.key
            }
        }
    }

    private struct Bucket {
        var latest: ConnectionEntry
        var rttSeries: [Double] = []
        var count: Int = 1
    }
}
