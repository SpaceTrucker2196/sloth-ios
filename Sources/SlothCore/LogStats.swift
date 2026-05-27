// LogStats — pure aggregations consumed by the M5 chart views.
//
// Two flavours:
//   * `QTypeDistribution.shares(...)` — slice-per-qtype share over the
//     visible DNS window. Drives the SectorMark pie at the top of
//     `DNSLogView`.
//   * `TLSVersionMix.shares(...)` — share-per-version over the visible
//     TLS window. Drives the stacked `BarMark` at the top of
//     `TLSLogView`. We collapse rare versions into "other" so the
//     chart legend stays readable.

import Foundation

/// One pie slice / bar segment.
public struct ShareSlice: Sendable, Equatable, Identifiable {
    public let label: String
    public let count: Int

    public var id: String { label }

    public init(label: String, count: Int) {
        self.label = label
        self.count = count
    }
}

public enum QTypeDistribution {

    /// Group DNS entries by uppercased qtype. "A" / "AAAA" / "PTR" /
    /// "CNAME" / "MX" / "TXT" / "SRV" / "NS" keep their own slices;
    /// everything else collapses to "other".
    public static func shares(_ entries: [DNSEntry]) -> [ShareSlice] {
        guard !entries.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for e in entries {
            let key = canonicalQType(e.qtype)
            counts[key, default: 0] += 1
        }
        return counts
            .map { ShareSlice(label: $0.key, count: $0.value) }
            // Sort: largest slice first, ties alphabetical, "other" last.
            .sorted { lhs, rhs in
                if lhs.label == "other" { return false }
                if rhs.label == "other" { return true }
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.label < rhs.label
            }
    }

    private static let known: Set<String> = [
        "A", "AAAA", "PTR", "CNAME", "MX", "TXT", "SRV", "NS",
    ]

    private static func canonicalQType(_ raw: String?) -> String {
        guard let raw = raw?.uppercased(), !raw.isEmpty else { return "other" }
        return known.contains(raw) ? raw : "other"
    }
}

public enum TLSVersionMix {

    /// Group TLS entries by version label. Buckets:
    ///   "TLS 1.3" / "TLS 1.2" / "TLS 1.1" / "TLS 1.0" / "other".
    /// 1.0 and 1.1 are deprecated; views render those slices in
    /// WARN orange so a downgrade attempt is visible at a glance.
    public static func shares(_ entries: [TLSEntry]) -> [ShareSlice] {
        guard !entries.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for e in entries {
            counts[canonicalVersion(e.version), default: 0] += 1
        }
        return counts
            .map { ShareSlice(label: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                // Always show TLS 1.3 first then descending order to
                // keep the chart's colour order stable across frames.
                versionOrder(lhs.label) < versionOrder(rhs.label)
            }
    }

    /// True when `version` is one of the deprecated tiers (1.0 / 1.1).
    /// Used by the TLS log row to apply WARN orange row tinting.
    public static func isDeprecated(_ version: String?) -> Bool {
        let v = canonicalVersion(version)
        return v == "TLS 1.0" || v == "TLS 1.1"
    }

    private static func canonicalVersion(_ raw: String?) -> String {
        guard let s = raw?.trimmingCharacters(in: .whitespaces), !s.isEmpty
        else { return "other" }
        // Normalise common shapes: "TLS 1.3", "1.3", "TLS1.3" → "TLS 1.3".
        let upper = s.uppercased()
        for tier in ["1.3", "1.2", "1.1", "1.0"] where upper.contains(tier) {
            return "TLS \(tier)"
        }
        return "other"
    }

    private static func versionOrder(_ label: String) -> Int {
        switch label {
        case "TLS 1.3": return 0
        case "TLS 1.2": return 1
        case "TLS 1.1": return 2   // appears in WARN colour
        case "TLS 1.0": return 3   // appears in WARN colour
        default:        return 4
        }
    }
}
