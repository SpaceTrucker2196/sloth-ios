# DashboardView (Tufte band composite)

Milestone: v1.x (supersedes the M7 tile grid)
Status: implemented

## Why the redesign

The M7 dashboard tiled six *full interactive views* (filter chips,
search fields, nav bars) into a 3×2 grid. Six sets of chrome, six
scroll views, low data density. sloth's own TUI dashboard
(`src/views/dashboard.c`) does the opposite: fixed bands of dense,
read-only rows — small multiples, inline sparklines, hairline
dividers, drill-in on demand. That layout is Edward Tufte by
construction: maximal data-ink, word-sized graphics, no chartjunk.

This spec ports the band layout to iPad. The iPhone `TabView` is
unchanged.

## Data source

Everything is already on the `SlothStore`:

| Band | Source |
| --- | --- |
| Interfaces + Summary | `ifaces`, `ifaceRx/TxSamples`, counters |
| CRIT alerts | `alerts` filtered to `.crit` |
| Connections | `connections` via `ConnectionsAggregator` |
| Top hosts | `topHosts`, `topHostRx/TxSamples` |
| WiFi / Roaming / Beacons | `wifiAPs`, `probeClients`, `beacons` |
| mDNS / DHCP / SSDP | `mdnsServices`, `dhcpLeases`, `ssdpDevices` |
| ARP / Deauth | `arpEntries`, `deauths` |
| DNS log / ICMP log | `dns`, `icmp` rings |
| Packets | `packets` ring |

Row selection / sorting / staleness is pure `SlothCore` code
(`DashboardRoster`), hermetically tested. Views only render.

## Layout

Vertical band stack inside one `ScrollView`, mirroring the TUI's
vertical order (worst news highest):

```
┌──────────────────────────────────────────────────────────────┐
│ INTERFACES ──────────────────────────────┬ SUMMARY ──────────│
│ en0   ↓1.2 MB/s ▁▂▄▆█  ↑240 KB/s ▁▁▂▃▂   │ ifaces 3   aps 12 │
│ utun4 ↓ 12 KB/s ▁▁▁▂▁  ↑  3 KB/s ▁▁▁▁▁   │ conns 41  dev 18  │
│ CRITICAL ────────────────────────────────┴───────────────────│
│ ▌THREAT_DOMAIN  malware.example.com          4×   18:22:41   │
│ CONNECTIONS ────────────────────────┬ TOP HOSTS ─────────────│
│ 10.0.0.5:443→…  TCP ESTAB  1.2 MB/s │ dns.google  ▂▃▅▆ 1.2MB │
│ WIFI ──────────┬ ROAMING ───────────┬ BEACONS ───────────────│
│ MDNS ──────────┬ DHCP ──────────────┬ SSDP ──────────────────│
│ ARP ───────────────────┬ DEAUTH ────────────────────────────-│
│ DNS ───────────────────┬ ICMP ───────────────────────────────│
│ PACKETS ─────────────────────────────────────────────────────│
└──────────────────────────────────────────────────────────────┘
```

- Bands split 70/30 (iface/summary), 60/40 (conns/hosts), thirds,
  and halves exactly like the TUI's column math.
- Row caps per band keep the whole board ≈ two screenfuls on an
  11" iPad; the packets band is the only unbounded-feeling tail
  and it is capped too (`DashboardRoster.packetTail`).
- File split mirrors sloth: `DashboardView` (orchestrator),
  `DashboardBands` (wide bands), `DashboardGrid` (thirds/halves
  panels), `DashboardPrimitives` (band frame, rows, formatting).

## Tufte rules applied

- **No cards, no fills.** A band is a small-caps title fused into a
  hairline rule (`phosphorDim` at 35% opacity), content below.
  Structure ink is one hairline per band plus one vertical hairline
  per column split.
- **Small multiples.** Per-interface and per-host sparklines are the
  M4 `BandwidthSparkline` at word size (≈ 56×14 pt), axis-free.
- **Direct labeling.** Counts live in the band title
  (`CONNECTIONS · 41`); values sit next to their labels. No legends.
- **Monospaced numerals** (`Font.phosphor`), right-aligned numeric
  columns, so columns of rates read as a table without table rules.
- **Muted layering.** Identity data in `phosphorTeal` / dim; only
  *data-bearing* color: heat-graded rates, three-tier alert hues,
  alert-hot IPs via `AlertHotIndex`, brand hues on hostnames.
- **Dark mode.** The board forces `.dark` and sits on true black —
  the phosphor palette is designed for it and OLED iPads render
  hairlines best there.

## Graphs

- `BandwidthSparkline` (existing) for iface rx/tx and top hosts.
- No pies, no stacked bars on the board — those stay in the
  drill-in views (M5).

## Interactions

- Tap a band title → push the corresponding full view
  (`InterfacesView`, `AlertsView`, `ConnectionsView`,
  `TopHostsView`, `WiFiAPsView`, `LANView`, `DNSLogView`,
  `PacketsView`, …) inside the dashboard's `NavigationStack` —
  the TUI's Enter-to-drill.
- Rows on the board are read-only; no filters, no search. Density
  is the feature.

## Severity / colour

- CRIT band rows: red stripe + bold, mirroring `AlertRowView`.
- When no CRIT alerts exist the band shows one dim quiet row
  ("no critical alerts") so the operator can tell *quiet* from
  *broken*, per the TUI's always-visible CRIT band.
- Cross-panel hot-IP coloring in full force on every band that
  renders an IP.

## Accessibility

- Sparklines keep their a11y trend labels.
- Band titles are headers (`.accessibilityAddTraits(.isHeader)`).
- Color never carries meaning alone: CRIT rows carry the stripe +
  bold, deprecated/flood rows carry a glyph.
- Reduced-motion disables sparkline animation (inherited from
  `BandwidthSparkline`).
