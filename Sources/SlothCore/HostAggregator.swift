// HostAggregator — derives a top-N hosts snapshot from the store's
// rings. Mirrors the shape of sloth's `src/top_hosts.c` with two
// schema-driven substitutions:
//
//   * sloth's TUI uses kernel TCP-info byte counters for rx/tx rates.
//     Those numbers are not in the JSONL stream (only protocol logs +
//     alerts are). We substitute *record rate* — records per minute
//     mentioning this host — as an honest activity proxy.
//   * "Bandwidth bytes" become "record counts" everywhere they show
//     up in the iOS consumer. When sloth grows a `bw` record type the
//     consumer can swap data sources without changing the view
//     hierarchy.
//
// External hosts only: RFC1918, loopback, link-local, multicast, and
// IPv6 link-local addresses are skipped (mirrors `top_hosts.c`).

import Foundation

/// One row in the Top Hosts view.
public struct HostActivity: Sendable, Equatable, Identifiable {
    public let ip: String
    public let hostname: String?           // best-effort from DNS cache
    public let totalRecords: Int
    public let dnsCount: Int
    public let tlsCount: Int
    public let quicCount: Int
    public let httpCount: Int
    public let firstSeen: Int              // epoch s
    public let lastSeen: Int               // epoch s
    public let rateSamples: [Double]       // records-per-minute, oldest first
    public let ja3Fingerprints: [String]   // distinct JA3s seen for this IP

    public var id: String { ip }

    /// Highest recent activity — useful for sorting fallbacks.
    public var recentRate: Double { rateSamples.last ?? 0 }
}

/// Snapshot returned by the aggregator. Sorted by `totalRecords`
/// descending; tied rows fall back to `recentRate`.
public struct TopHostsSnapshot: Sendable, Equatable {
    public let hosts: [HostActivity]
    public let generatedAt: Date

    public static let empty = TopHostsSnapshot(hosts: [], generatedAt: .distantPast)
}

public enum HostAggregator {

    /// Cap snapshot size (mirrors `top_hosts.c`'s `TOP_HOSTS_MAX`).
    public static let topN = 32

    /// Sparkline samples per host (per-minute over the last 30 minutes).
    public static let sparkBins = 30
    public static let sparkBinSeconds: Int = 60

    /// Build a snapshot from the store's rings. Pure function; no
    /// hidden state. Caller decides how often to invoke (the view
    /// uses a 5-second tick like AlertsView).
    @MainActor
    public static func snapshot(
        from store: SlothStore,
        now: Date = Date()
    ) -> TopHostsSnapshot {
        // Build the IP → hostname map from DNS responses. Most-recent
        // wins — last writer of a given IP keeps its qname.
        var hostnames: [String: String] = [:]
        for d in store.dns {
            guard let answer = d.answer, !answer.isEmpty,
                  let qtype = d.qtype, isAddressQType(qtype),
                  isExternal(answer)
            else { continue }
            hostnames[answer] = d.qname
        }

        // Per-IP accumulators.
        var perIP: [String: Accumulator] = [:]

        for d in store.dns {
            // For DNS, the "remote host" is the resolved IP (when there
            // was one). The src is the local resolver / client.
            guard let answer = d.answer, isExternal(answer) else { continue }
            perIP[answer, default: .init(ip: answer)].observe(
                ts: d.ts, type: .dns
            )
        }
        for t in store.tls {
            guard let dst = t.dst, isExternal(dst) else { continue }
            perIP[dst, default: .init(ip: dst)].observe(
                ts: t.ts, type: .tls, ja3: t.ja3
            )
        }
        for q in store.quic {
            guard let dst = q.dst, isExternal(dst) else { continue }
            perIP[dst, default: .init(ip: dst)].observe(
                ts: q.ts, type: .quic
            )
        }
        for h in store.http {
            guard let dst = h.dst, isExternal(dst) else { continue }
            perIP[dst, default: .init(ip: dst)].observe(
                ts: h.ts, type: .http
            )
        }

        // Materialise.
        let nowEpoch = Int(now.timeIntervalSince1970)
        let hosts: [HostActivity] = perIP.values
            .map { $0.materialise(hostname: hostnames[$0.ip], now: nowEpoch) }
            .sorted { lhs, rhs in
                if lhs.totalRecords != rhs.totalRecords {
                    return lhs.totalRecords > rhs.totalRecords
                }
                return lhs.recentRate > rhs.recentRate
            }
            .prefix(topN)
            .map { $0 }

        return TopHostsSnapshot(hosts: hosts, generatedAt: now)
    }

    // MARK: - Internal

    /// Per-IP accumulator. Holds raw ts + per-type counts + JA3 set
    /// during the aggregation pass; `materialise(...)` converts to
    /// the immutable `HostActivity` value type.
    fileprivate struct Accumulator {
        let ip: String
        var dnsCount = 0
        var tlsCount = 0
        var quicCount = 0
        var httpCount = 0
        var firstSeen = Int.max
        var lastSeen  = Int.min
        var rawTimestamps: [Int] = []
        var ja3s: Set<String> = []

        enum Source { case dns, tls, quic, http }

        mutating func observe(ts: Int, type: Source, ja3: String? = nil) {
            switch type {
            case .dns:  dnsCount  += 1
            case .tls:  tlsCount  += 1
            case .quic: quicCount += 1
            case .http: httpCount += 1
            }
            if ts < firstSeen { firstSeen = ts }
            if ts > lastSeen  { lastSeen  = ts }
            rawTimestamps.append(ts)
            if let ja3, !ja3.isEmpty { ja3s.insert(ja3) }
        }

        func materialise(hostname: String?, now: Int) -> HostActivity {
            let samples = HostAggregator.rateSamples(
                timestamps: rawTimestamps,
                now: now
            )
            return HostActivity(
                ip:             ip,
                hostname:       hostname,
                totalRecords:   dnsCount + tlsCount + quicCount + httpCount,
                dnsCount:       dnsCount,
                tlsCount:       tlsCount,
                quicCount:      quicCount,
                httpCount:      httpCount,
                firstSeen:      firstSeen == .max ? now : firstSeen,
                lastSeen:       lastSeen  == .min ? now : lastSeen,
                rateSamples:    samples,
                ja3Fingerprints: ja3s.sorted()
            )
        }
    }

    /// Build the per-minute rate sparkline ending at `now`. One sample
    /// per `sparkBinSeconds` bin, `sparkBins` total, oldest first.
    /// Internal so tests can drive it directly with a tiny timestamp
    /// list rather than going through the full aggregator.
    static func rateSamples(timestamps: [Int], now: Int) -> [Double] {
        let totalSpan = sparkBins * sparkBinSeconds
        let windowStart = now - totalSpan
        var bins = [Int](repeating: 0, count: sparkBins)
        for ts in timestamps {
            guard ts >= windowStart, ts <= now else { continue }
            let offset = ts - windowStart   // 0…totalSpan
            var bin = offset / sparkBinSeconds
            if bin >= sparkBins { bin = sparkBins - 1 }
            bins[bin] += 1
        }
        return bins.map(Double.init)
    }

    /// True if `ip` is an external (publicly-routable) address worth
    /// surfacing on the Top Hosts list. Skips RFC1918, loopback,
    /// link-local, multicast (v4 + v6).
    public static func isExternal(_ ip: String) -> Bool {
        if ip.isEmpty { return false }
        if isIPv6(ip) {
            // ::1 loopback; fe80::/10 link-local; ff00::/8 multicast.
            let lower = ip.lowercased()
            if lower == "::1" { return false }
            if lower.hasPrefix("fe8") || lower.hasPrefix("fe9") ||
               lower.hasPrefix("fea") || lower.hasPrefix("feb") { return false }
            if lower.hasPrefix("ff") { return false }
            return true
        }
        // IPv4
        let parts = ip.split(separator: ".")
        guard parts.count == 4, let a = Int(parts[0]), let b = Int(parts[1])
        else { return false }
        if a == 10 { return false }                              // 10.0.0.0/8
        if a == 127 { return false }                             // loopback
        if a == 169 && b == 254 { return false }                 // link-local
        if a == 172 && (16...31).contains(b) { return false }    // 172.16/12
        if a == 192 && b == 168 { return false }                 // 192.168/16
        if a >= 224 { return false }                             // multicast + reserved
        return true
    }

    private static func isIPv6(_ ip: String) -> Bool {
        // A bare ':' is the minimal IPv6 signature in our records
        // (qname `::1`, addr `2606:4700::1111`, etc.). IPv4 never has
        // a ':' so this is a robust discriminator.
        ip.contains(":")
    }

    private static func isAddressQType(_ qtype: String) -> Bool {
        let q = qtype.uppercased()
        return q == "A" || q == "AAAA"
    }
}
