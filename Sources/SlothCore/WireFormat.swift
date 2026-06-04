// WireFormat — pure detector for sloth's `--out-format` settings.
//
// Sloth 1.4+ ships three line encodings for `--data-socket`:
//   * jsonl  — newline-delimited JSON, what this consumer parses
//   * cef    — ArcSight CEF, one record per line (`CEF:0|sloth-net|…`)
//   * syslog — RFC 5424 (`<134>1 <ts> <host> sloth <pid> <type> [sd] <json>`)
//
// The iOS app only parses JSONL. When an operator configures sloth
// with `--out-format cef` (or `syslog`) and points the iOS app at
// the same socket, every line fails to decode and the screen stays
// empty. The consumer can't transparently parse CEF / syslog (that
// would double its surface area), so the next best thing is to
// detect the mismatch on the first non-JSONL line and surface a
// precise diagnostic — "the producer is emitting CEF; set
// --out-format jsonl" beats a silent empty view.
//
// The detector is byte-level and conservative: it inspects the first
// few bytes of a line and returns `.unknown` rather than guessing
// when nothing matches.

import Foundation

public enum WireFormat: String, Sendable, Equatable, CaseIterable {
    case jsonl
    case cef
    case syslog
    case unknown

    /// Best-effort classification of a single line of bytes (no
    /// trailing newline — `LineReader` already strips it). Empty
    /// input returns `.unknown`.
    public static func sniff(_ data: Data) -> WireFormat {
        guard let first = data.first else { return .unknown }
        // JSON: top-level objects start with `{`; arrays with `[`.
        // Sloth always emits objects but accept arrays defensively.
        if first == 0x7B || first == 0x5B { return .jsonl }
        // RFC 5424 syslog framing starts with `<PRI>` (e.g. `<134>1 `).
        if first == 0x3C { return .syslog }
        // CEF: every line literally starts `CEF:` (case-sensitive per
        // the ArcSight spec).
        if data.starts(with: cefPrefix) { return .cef }
        return .unknown
    }

    /// Operator-facing label for the diagnostic surface.
    public var displayName: String {
        switch self {
        case .jsonl:   return "JSONL"
        case .cef:     return "CEF"
        case .syslog:  return "syslog (RFC 5424)"
        case .unknown: return "unknown"
        }
    }

    private static let cefPrefix = Data([0x43, 0x45, 0x46, 0x3A])   // "CEF:"
}
