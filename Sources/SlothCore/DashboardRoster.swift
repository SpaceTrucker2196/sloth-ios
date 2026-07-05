// DashboardRoster — pure row-selection helpers for the iPad band
// dashboard. Each band shows a small, deterministic roster: the
// newest / hottest N entries of its table, with stable tie-breaks so
// rows don't jitter between frames when timestamps collide.
//
// Views call these and render; no aggregation happens in view code.

import Foundation

public enum DashboardRoster {

    /// Newest-first roster over any snapshot table. Sorted by
    /// `stamp` descending; ties broken by `id` ascending so two
    /// entries emitted in the same second keep a stable order
    /// (dictionary iteration order is nondeterministic).
    public static func newest<T>(
        _ entries: some Sequence<T>,
        stamp: (T) -> Int,
        id: (T) -> String,
        limit: Int
    ) -> [T] {
        precondition(limit >= 0)
        return entries
            .sorted {
                let (sa, sb) = (stamp($0), stamp($1))
                if sa != sb { return sa > sb }
                return id($0) < id($1)
            }
            .prefix(limit)
            .map { $0 }
    }

    /// CRIT-only alert roster, newest-first by `lastSeen`. The store
    /// already sorts its alerts ring, but the roster re-sorts
    /// defensively — the band must never show stale ordering even if
    /// the caller hands it an unsorted slice.
    public static func critAlerts(
        _ alerts: [AlertEntry],
        limit: Int = 6
    ) -> [AlertEntry] {
        newest(
            alerts.filter { $0.severity == .crit },
            stamp: { $0.lastSeen },
            id: { $0.key ?? $0.title },
            limit: limit
        )
    }

    /// Top hosts by combined rx+tx rate, descending; ties broken by
    /// IP so an all-idle table still lists deterministically.
    public static func topHosts(
        _ table: [String: TopHostEntry],
        limit: Int = 8
    ) -> [TopHostEntry] {
        precondition(limit >= 0)
        return table.values
            .sorted {
                if $0.totalRate != $1.totalRate {
                    return $0.totalRate > $1.totalRate
                }
                return $0.ip < $1.ip
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Tail of the packet ring, newest-first. The ring appends at the
    /// end, so the tail *is* the newest slice — reversed for display.
    public static func packetTail(
        _ ring: [PacketEntry],
        limit: Int = 12
    ) -> [PacketEntry] {
        precondition(limit >= 0)
        return ring.suffix(limit).reversed()
    }

    /// Tail of a log ring (DNS, ICMP, …), newest-first.
    public static func logTail<T>(
        _ ring: [T],
        limit: Int = 6
    ) -> [T] {
        precondition(limit >= 0)
        return ring.suffix(limit).reversed()
    }
}
