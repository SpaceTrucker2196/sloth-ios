# Theme — Fallout phosphor in SwiftUI

sloth-ios mirrors sloth's TUI palette so an operator running both
side-by-side sees the same hues for the same data.

## Base hues

| Token              | Hex (dark)  | Hex (light) | sloth equivalent  |
|--------------------|-------------|-------------|-------------------|
| `phosphorBright`   | `#00FFAF`   | `#005F3F`   | `CP_BRIGHT` (49)  |
| `phosphorTeal`     | `#00D7AF`   | `#007155`   | `CP_NORMAL` (43)  |
| `phosphorDim`      | `#00875F`   | `#005A3F`   | `CP_DIM` (29)     |
| `phosphorBorder`   | `#00875F`   | `#005A3F`   | `CP_BORDER` (29)  |

Backgrounds: default system background. **Never** introduce row tints
(mirror sloth's hard rule against `CP_PKT_*` row backgrounds).

## Heat gradient

For sparkline cells and severity-by-value cues:

| Token         | xterm | Hex       | Use |
|---------------|-------|-----------|-----|
| `heatLo`      | 241   | `#626262` | idle / no data |
| `heatMid`     | 178   | `#D7AF00` | warm |
| `heatHi`      | 208   | `#FF8700` | hot |
| `heatPeak`    | 196   | `#FF0000` | peak |

`Theme.heat(fraction:)` returns the right token by value, mirroring
`tui_heat()`.

## Alert-hot three-tier palette

The defining palette for cross-panel coloring:

| Token             | Hex (dark)  | Hex (light) | Tier   | Bold? |
|-------------------|-------------|-------------|--------|-------|
| `alertHotLow`     | `#FFD700`   | `#A37100`   | LOW    | no    |
| `alertHotWarn`    | `#FF8700`   | `#C45A00`   | WARN   | yes   |
| `alertHotCrit`    | `#FF0000`   | `#A60000`   | CRIT   | yes   |

Light-mode hexes are tuned for AAA contrast on white backgrounds.

## IP hash palette

8 colours hashed from the IP string the way sloth's `ip_color.c`
does. Same IP → same colour everywhere it appears.

| Slot | Hex (dark)  | Inspiration                  |
|------|-------------|------------------------------|
| 0    | `#00FFD7`   | bright phosphor teal         |
| 1    | `#5FD7D7`   | aged dim phosphor cyan       |
| 2    | `#87FFAF`   | rad-green                    |
| 3    | `#AFFF87`   | mutated lime                 |
| 4    | `#D7AF00`   | amber CRT dial               |
| 5    | `#FFAF5F`   | hazmat orange                |
| 6    | `#D78787`   | faded crimson (Nuka)         |
| 7    | `#87AFD7`   | Vault-Tec blue               |

Light-mode variants of these eight are darker by ~25% so they read
on white.

## Brand colours (hostname highlighting)

| Substring     | Token             |
|---------------|-------------------|
| `google`      | rainbow (per-letter): blue / red / yellow / blue / green / red |
| `firefox`     | `brandFirefox`    (`#FF8700`) |
| `cloudflare`  | `brandCloudflare` (`#FF0000`) |
| `example`     | `brandExample`    (`#808080`) |
| `discord`     | `brandDiscord`    (`#875FFF`) |
| `amazon`      | `brandAmazon`     (`#FFAF00`) |
| `linkedin`    | `brandLinkedIn`   (`#0087AF`) |
| `netflix`     | `brandNetflix`    (`#AF0000`) |
| `spotify`     | `brandSpotify`    (`#00D75F`) |

`Theme.brand(in:)` returns the right token for a hostname. Matching
is case-insensitive substring (mirrors `tui_brand_addstr`).

## Implementation

All of the above lives in `Sources/SlothCore/Theme.swift` as `Color`
extensions and a few small enums:

```swift
public extension Color {
    static let alertHotLow  = Color("AlertHotLow")   // asset-catalog backed
    static let alertHotWarn = Color("AlertHotWarn")
    static let alertHotCrit = Color("AlertHotCrit")
    // …
}

public enum AlertSeverity: Int, Sendable {
    case low = 0, warn = 1, crit = 2

    public var color: Color {
        switch self {
        case .low:  return .alertHotLow
        case .warn: return .alertHotWarn
        case .crit: return .alertHotCrit
        }
    }
    public var isBold: Bool { self != .low }
    public var symbol: String {
        switch self {
        case .low:  return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .crit: return "exclamationmark.octagon"
        }
    }
}
```

The asset-catalog backing lets light/dark variants live in
`Assets.xcassets`.

## Accessibility

- **Never rely on colour alone.** Every severity hue is also
  encoded as an SF Symbol (`info.circle` / `triangle` / `octagon`)
  and as a bold weight transition.
- High-contrast mode: dark-mode hexes get a `.opacity(1.0)` and the
  symbols get `.fontWeight(.heavy)`.
