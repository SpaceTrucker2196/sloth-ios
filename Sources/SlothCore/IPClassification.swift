// IPClassification — small predicate helper: is this IP an external
// (publicly routable) address worth surfacing in the operator UI?
//
// Originally lived on `HostAggregator.isExternal` back when iOS did
// its own top-hosts roll-up. Now that sloth emits a `top_host`
// snapshot the aggregator is gone, but the predicate is still useful
// for ad-hoc filters in other views (e.g. flagging an unexpected
// internal-only flow).
//
// Mirrors sloth's `src/ip_owner.c` filter set:
//   * RFC1918 (10/8, 172.16/12, 192.168/16) → internal
//   * Loopback (127/8, ::1)                 → internal
//   * Link-local (169.254/16, fe80::/10)    → internal
//   * Multicast / reserved (224+, ff::/8)   → internal

import Foundation

public enum IPClassification {

    public static func isExternal(_ ip: String) -> Bool {
        if ip.isEmpty { return false }
        if ip.contains(":") {
            // IPv6
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
        if a == 10 { return false }
        if a == 127 { return false }
        if a == 169 && b == 254 { return false }
        if a == 172 && (16...31).contains(b) { return false }
        if a == 192 && b == 168 { return false }
        if a >= 224 { return false }
        return true
    }
}
