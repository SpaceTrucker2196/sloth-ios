// AlertHotIndex — cross-panel "this IP is hot" lookup.
//
// Mirrors sloth's `tui_alert_hot_*` mechanism: when an alert fires
// with a non-empty `match_ip`, the IP becomes hot at the alert's
// severity for `ALERT_HOT_TTL_S` seconds. Every view that renders
// that IP (DNS log, TLS log, top hosts, connections, …) paints it
// in the alert's severity hue for the duration of the window.
//
// Promotion-only semantics: while an IP is live in the index, a
// later alert at a *lower* severity does not downgrade it. A later
// alert at the same-or-higher severity refreshes the TTL.

import Foundation

@MainActor
public final class AlertHotIndex {

    /// Wall-clock window an IP stays hot after its most recent alert.
    /// 5 minutes mirrors the default TUI dwell; bump via the
    /// initialiser for tests or for operator-tuned deployments.
    public static let defaultTTL: TimeInterval = 300

    private struct Entry {
        let severity: AlertSeverity
        let expiresAt: Date
    }

    private var index: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        ttl: TimeInterval = AlertHotIndex.defaultTTL,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.ttl = ttl
        self.now = now
    }

    /// Register an alert. Caller passes the alert's `match_ip`
    /// verbatim (with or without a port); the index normalises to
    /// a bare IP so cross-panel lookups match regardless of how
    /// the IP appears in a given record.
    public func note(_ alert: AlertEntry) {
        guard let raw = alert.matchIP, !raw.isEmpty else { return }
        note(matchIP: raw, severity: alert.severity)
    }

    public func note(matchIP raw: String, severity: AlertSeverity) {
        let key = Self.bareIP(raw)
        let nowDate = now()
        let expiry  = nowDate.addingTimeInterval(ttl)

        if let existing = index[key], existing.expiresAt > nowDate {
            let winning = existing.severity.max(severity)
            index[key] = Entry(severity: winning, expiresAt: expiry)
        } else {
            index[key] = Entry(severity: severity, expiresAt: expiry)
        }
    }

    /// Severity for `ip` if it's currently hot, else nil. Expired
    /// entries return nil but stay in the map until the next purge —
    /// callers shouldn't care, and lazy eviction keeps lookups O(1).
    public func severity(for ip: String) -> AlertSeverity? {
        let key = Self.bareIP(ip)
        guard let entry = index[key], entry.expiresAt > now() else { return nil }
        return entry.severity
    }

    /// Drop expired entries. The store wires this into ingest to keep
    /// the map small over long sessions; tests call it directly.
    public func purgeExpired() {
        let nowDate = now()
        index = index.filter { $0.value.expiresAt > nowDate }
    }

    /// Drop *all* entries regardless of expiry. Used on profile
    /// switch / store reset — a different sloth means a different
    /// threat surface.
    public func clear() {
        index.removeAll(keepingCapacity: false)
    }

    /// Number of *live* (unexpired) entries. Exposed for tests; not
    /// load-bearing for views.
    public var liveCount: Int {
        let nowDate = now()
        return index.values.lazy.filter { $0.expiresAt > nowDate }.count
    }

    /// Strip a `:port` suffix from a `match_ip` so cross-panel
    /// lookups work whether the caller has the bare IP or `ip:port`.
    /// Handles `[v6]:port`; for unbracketed strings with multiple
    /// colons, treats the whole string as a bare v6 address.
    public static func bareIP(_ s: String) -> String {
        if s.first == "[", let close = s.firstIndex(of: "]") {
            return String(s[s.index(after: s.startIndex)..<close])
        }
        let colons = s.reduce(0) { $1 == ":" ? $0 + 1 : $0 }
        if colons == 1, let c = s.firstIndex(of: ":") {
            let rhs = s[s.index(after: c)...]
            if !rhs.isEmpty, rhs.allSatisfy(\.isNumber) {
                return String(s[s.startIndex..<c])
            }
        }
        return s
    }
}
