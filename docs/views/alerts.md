# AlertsView

Milestone: M3
Status: spec

## Data source

Store ring: `store.alerts` (sorted newest-first by `lastSeen`).
Alert-hot index: `store.alertHot` (cross-panel coloring).
Update cadence: realtime.

## Layout

```
┌──────────────────────────────────────────────────────┐
│  Alerts          [All] [CRIT] [WARN] [LOW]    🔍 ___ │
│  ┌──────────────────────────────────────────────────┐│
│  │ Alerts per minute (last 60m) — stacked by sev    ││  ← AlertFrequencyChart
│  │ ▄▄▄▆█▆▆▄▄▄▂▂▂▂▂▁▁▁_____▁▁▁▁▁                    ││
│  └──────────────────────────────────────────────────┘│
│                                                      │
│  ▤ CRIT  THREAT_DOMAIN     malware.testing.com  4×  │
│  ▤ CRIT  THREAT_IP         192.0.2.66:443       1×  │
│  ▥ WARN  BEACONING         203.0.113.7:443     12×  │
│  ▦ LOW   PORT_SCAN         10.0.0.99            1×  │
│  ▦ LOW   NXDOMAIN_BURST    192.168.1.50         3×  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

Each row:
- Severity stripe down the leading edge (LOW yellow / WARN orange / CRIT red).
- SF Symbol prefix on the severity column for colour-blind operators:
  - LOW: `info.circle`
  - WARN: `exclamationmark.triangle`
  - CRIT: `exclamationmark.octagon`
- Title, detail (truncated to one line; full visible on tap).
- Hit count badge (bold when ≥ 2).
- Relative timestamp on the trailing edge ("2m ago").

Tap → `AlertDetailView` (push):

```
┌──────────────────────────────────────────────────────┐
│  ← Alerts                                            │
│                                                      │
│  CRIT  THREAT_DOMAIN                                 │
│                                                      │
│  192.168.1.5 queried malware.testing.com             │
│  (IOC: malware.testing.com)                          │
│                                                      │
│  Key:        threat-d:malware.testing.com            │
│  Hits:       4                                       │
│  First seen: 22:01:01                                │
│  Last seen:  22:01:09 (8s span)                      │
│                                                      │
│  ─ Flow ─                                            │
│  Match IP:   192.168.1.5:53                          │
│                                                      │
│  ─ Cross-references ─                                │
│  • 192.168.1.5 in DNS log    (4 records)             │
│  • 192.168.1.5 in TLS log    (12 records)            │
└──────────────────────────────────────────────────────┘
```

## Graphs

- **AlertFrequencyChart** — `Chart { BarMark(...) }` stacked by
  severity. X: minute bucket over the last 60 minutes. Y: alert
  count. Colours: LOW yellow, WARN orange, CRIT red. Tells the story
  of: when did the noise spike?

## Interactions

- Filter chips toggle visibility per severity tier.
- Search field is a substring match across title + detail + key.
  Mirrors sloth's `filter.c` semantics.
- Tap row → push `AlertDetailView`.
- Pull to refresh: no-op (data is realtime); show a subtle "live"
  pulse instead.

## Severity / colour

The defining view for the three-tier palette. Establishes the
`Color` extensions everything else reuses:

- `Color.alertHotLow`  — `Color.yellow` in dark mode; `Color(red:0.85, green:0.65, blue:0.0)` in light mode (avoid white-on-light contrast issues).
- `Color.alertHotWarn` — `Color.orange`.
- `Color.alertHotCrit` — `Color.red`.

`A_BOLD` on WARN + CRIT (mirrors sloth's `tui_alert_hot_attr`).

When this view renders an alert with a non-empty `match_ip`, the IP
is registered in `AlertHotIndex` at that severity. Every other view
that renders the same IP picks up the hue.

## Accessibility

- Each row's a11y label: "Critical alert: THREAT_DOMAIN.
  192.168.1.5 queried malware.testing.com. 4 occurrences. Last seen
  2 minutes ago."
- Chart a11y label: "Alert frequency over the last 60 minutes.
  Currently 3 critical, 1 warning, 2 low. Peak 4 alerts per minute
  at 22:01."
- Dynamic type up to AX5; rows reflow with the detail moving to its
  own line.
- `accessibilityReduceMotion` disables the chart's `transition`
  animation but keeps the data fresh.
