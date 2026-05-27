// LogFilter — pure substring matcher reused by every log view
// (DNS / TLS / HTTP and any future per-type log). Pulled out of the
// views so the matching rule is one place to test.
//
// Semantics mirror sloth's `filter.c` substring match: case-insensitive,
// trimmed, empty query matches everything. The caller supplies the
// list of haystack strings per row; this avoids each view re-implementing
// "lowercase + contains across N fields".

import Foundation

public enum LogFilter {

    /// Returns true if `query` is empty OR every word in `query`
    /// appears (case-insensitive substring) in at least one of the
    /// given `fields`. Multi-word queries are AND-of-words; this
    /// matches the way operators type search ("google 443"
    /// expects to find rows mentioning *both*).
    public static func matches(
        query: String,
        fields: [String?]
    ) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return true }
        let haystacks = fields.compactMap { $0?.lowercased() }
        if haystacks.isEmpty { return false }
        let words = q.split(separator: " ").map(String.init)
        for word in words {
            var hit = false
            for h in haystacks where h.contains(word) {
                hit = true
                break
            }
            if !hit { return false }
        }
        return true
    }
}
