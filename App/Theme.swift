// Theme — SwiftUI Color extensions for the three-tier alert palette,
// heat gradient, and phosphor base hues. Mirrors sloth's TUI palette
// so an operator running both side-by-side sees the same hues for the
// same data.
//
// Per CLAUDE.md, Theme code lives in App/ (not Sources/SlothCore) so
// the headless package stays SwiftUI-free.

import SwiftUI
import SlothCore

extension Color {

    // ── Three-tier alert palette ────────────────────────────────
    // Hexes pulled from docs/wiki/theme.md. We use the system colours
    // directly — they adapt to dark/light mode without an asset
    // catalog round-trip and have first-class accessibility metadata.

    static let alertHotLow  = Color.yellow
    static let alertHotWarn = Color.orange
    static let alertHotCrit = Color.red

    // ── Phosphor base hues ──────────────────────────────────────

    static let phosphorBright = Color(red: 0.00, green: 1.00, blue: 0.685)  // #00FFAF
    static let phosphorTeal   = Color(red: 0.00, green: 0.843, blue: 0.685) // #00D7AF
    static let phosphorDim    = Color(red: 0.00, green: 0.529, blue: 0.373) // #00875F

    // ── Heat gradient (cool → amber → orange → red) ─────────────

    static let heatLo   = Color(red: 0.384, green: 0.384, blue: 0.384) // #626262
    static let heatMid  = Color(red: 0.843, green: 0.686, blue: 0.00)  // #D7AF00
    static let heatHi   = Color(red: 1.00,  green: 0.529, blue: 0.00)  // #FF8700
    static let heatPeak = Color(red: 1.00,  green: 0.00,  blue: 0.00)  // #FF0000

    /// Pick a heat-graded colour for a 0…1 fraction. Mirrors sloth's
    /// `tui_heat(double frac)` thresholds.
    static func heat(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.15: return .heatLo
        case ..<0.40: return .heatMid
        case ..<0.70: return .heatHi
        default:      return .heatPeak
        }
    }
}

extension AlertSeverity {

    /// SwiftUI colour for this severity. Source-of-truth mapping; every
    /// view that paints an alert tier reads from here, never inlines.
    var color: Color {
        switch self {
        case .low:  return .alertHotLow
        case .warn: return .alertHotWarn
        case .crit: return .alertHotCrit
        }
    }
}

// MARK: - ShapeStyle dot-shorthand

// Makes `foregroundStyle(.alertHotWarn)` (and friends) resolve to the
// project's Color extensions. Without this, the dot-shorthand only
// reaches SwiftUI's built-in ShapeStyle members (`.red`, `.secondary`,
// etc.) and the typo-looking "type 'ShapeStyle' has no member
// 'alertHotWarn'" appears at every call site.
extension ShapeStyle where Self == Color {
    static var alertHotLow:    Color { .alertHotLow }
    static var alertHotWarn:   Color { .alertHotWarn }
    static var alertHotCrit:   Color { .alertHotCrit }
    static var phosphorBright: Color { .phosphorBright }
    static var phosphorTeal:   Color { .phosphorTeal }
    static var phosphorDim:    Color { .phosphorDim }
}

/// Brand-name hostname colouring. Case-insensitive substring match,
/// mirroring sloth's `tui_brand_addstr`. Returns `nil` for hostnames
/// with no brand match — callers fall back to their default tint.
enum Theme {

    static func brand(for hostname: String?) -> Color? {
        guard let h = hostname?.lowercased(), !h.isEmpty else { return nil }
        for (needle, color) in brandTable {
            if h.contains(needle) { return color }
        }
        return nil
    }

    /// Deterministic colour for a JA3 hex string. Same JA3 → same
    /// colour everywhere (cross-host correlation cue, mirrors
    /// sloth's hash-coloured JA3 prefixes). Empty / nil → secondary.
    static func ja3Color(_ ja3: String?) -> Color {
        guard let s = ja3, !s.isEmpty else { return .secondary }
        var hash: UInt64 = 5_381
        for byte in s.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return ja3Palette[Int(hash % UInt64(ja3Palette.count))]
    }

    /// 8-colour phosphor palette mirroring sloth's IP hash slots
    /// (docs/wiki/theme.md). Warm-leaning so JA3 tags don't clash
    /// with the alert tier hues when both appear in the same row.
    private static let ja3Palette: [Color] = [
        Color(red: 0.00,  green: 1.00,  blue: 0.843), // #00FFD7
        Color(red: 0.373, green: 0.843, blue: 0.843), // #5FD7D7
        Color(red: 0.529, green: 1.00,  blue: 0.686), // #87FFAF
        Color(red: 0.686, green: 1.00,  blue: 0.529), // #AFFF87
        Color(red: 0.843, green: 0.686, blue: 0.00),  // #D7AF00
        Color(red: 1.00,  green: 0.686, blue: 0.373), // #FFAF5F
        Color(red: 0.843, green: 0.529, blue: 0.529), // #D78787
        Color(red: 0.529, green: 0.686, blue: 0.843), // #87AFD7
    ]

    /// Order matters: longer / more-specific needles first so
    /// `cloudflare` wins over a hypothetical `cloud`.
    private static let brandTable: [(String, Color)] = [
        ("cloudflare", Color(red: 1.00, green: 0.00, blue: 0.00)),  // #FF0000
        ("google",     Color(red: 0.00, green: 0.529, blue: 1.00)), // #0087FF (logo blue)
        ("firefox",    Color(red: 1.00, green: 0.529, blue: 0.00)), // #FF8700
        ("mozilla",    Color(red: 1.00, green: 0.529, blue: 0.00)),
        ("example",    Color(red: 0.50, green: 0.50, blue: 0.50)),  // #808080
        ("github",     Color(red: 0.50, green: 0.50, blue: 0.50)),
        ("discord",    Color(red: 0.529, green: 0.373, blue: 1.00)),// #875FFF
        ("facebook",   Color(red: 0.00, green: 0.373, blue: 1.00)),
        ("spotify",    Color(red: 0.00, green: 0.843, blue: 0.373)),// #00D75F
        ("whatsapp",   Color(red: 0.00, green: 0.843, blue: 0.373)),
        ("twitch",     Color(red: 0.686, green: 0.373, blue: 1.00)),// #AF5FFF
        ("amazon",     Color(red: 1.00, green: 0.686, blue: 0.00)), // #FFAF00
        ("linkedin",   Color(red: 0.00, green: 0.529, blue: 0.686)),// #0087AF
        ("microsoft",  Color(red: 0.00, green: 0.529, blue: 0.686)),
        ("netflix",    Color(red: 0.686, green: 0.00, blue: 0.00)), // #AF0000
        ("reddit",     Color(red: 1.00, green: 0.373, blue: 0.00)), // #FF5F00
        ("instagram",  Color(red: 0.843, green: 0.373, blue: 0.686)),// #D75FAF
        ("tiktok",     Color(red: 0.843, green: 0.373, blue: 0.686)),
    ]
}
