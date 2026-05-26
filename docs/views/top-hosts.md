# TopHostsView

Milestone: M4
Status: spec

## Data source

Aggregator: `TopHostsAggregator` (derives top-N hosts from
`store.connections` + `store.dnsCache`).
Update cadence: 1 Hz aggregation; UI updates on store changes.

## Layout

```
┌──────────────────────────────────────────────────────┐
│  Top hosts                                  ⏱ 1 m    │
│  ┌──────────────────────────────────────────────────┐│
│  │ rx total over the last 60s — stacked area chart  ││  ← BandwidthStackChart
│  │ ████▆▅▄▃▂▁                                       ││
│  └──────────────────────────────────────────────────┘│
│                                                      │
│  📍  dns.google           1.2MB/s ▂▃▅▆▇▇▆▅  120s    │
│  📍  *.cloudflare.com     240KB/s ▁▂▃▄▅▄▃▂  4m12s   │
│  📍  *.apple.com           18KB/s ▁_▁_▁▁▁_  45m     │
│  ⚠   malware.testing.com    4KB/s ▁▁▁▁▁▁▁▁  3m      │  ← CRIT hot
│                                                      │
└──────────────────────────────────────────────────────┘
```

Each row:
- Hostname, brand-coloured (google logo colours, cloudflare red,
  firefox orange) via `Color` extensions defined in
  `Sources/SlothCore/Theme.swift`.
- Current rate (rx + tx combined), formatted like sloth's
  `bw_fmt_rate`.
- Inline **BandwidthSparkline** of the last 30 samples.
- Age (`first_seen` → now).
- If the underlying IP is alert-hot, the leading icon swaps to a
  severity badge and the hostname renders in the alert hue.

Tap → `TopHostDetailView` (push):

```
┌──────────────────────────────────────────────────────┐
│  ← Top hosts                                         │
│                                                      │
│  dns.google      8.8.8.8                             │
│  Owner: Google DNS  •  Region: ARIN (US/CA)          │
│  First seen: 1h 23m ago  •  Connections: 5           │
│                                                      │
│  ┌── tx / rx (last 5 min) ─────────────────────────┐ │  ← BandwidthAreaChart
│  │ ▄▆█▆▄▂▁▂▄▆█▆▄▂▁  (red)                          │ │
│  │ ▁▂▃▂▁_▁▂▃▂▁_▁▂▃  (green)                        │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  ─ DNS qnames seen for this host ─                   │
│  • dns.google              A      4×                 │
│  • dns.google              AAAA   1×                 │
│                                                      │
│  ─ JA3 fingerprints from this host ─                 │
│  • 771,4865-486...        12×  (Chrome / Safari)     │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Graphs

- **BandwidthStackChart** (list header) — `Chart { AreaMark(...) }`
  stacked by host. Top 8 hosts visible; the rest collapse into
  "other". Tells the story of: where is your bandwidth actually
  going?
- **BandwidthSparkline** (per row) — `Chart { LineMark(...) }`
  with axes hidden, heat-graded by value. Reused on
  `TopHostDetailView`, `ConnectionsView` (M6), and `DashboardView`
  (M7).
- **BandwidthAreaChart** (detail view) — `Chart` with two `AreaMark`
  series (tx and rx) over the last 5 minutes. Tells: directionality
  of the conversation.

## Interactions

- Tap row → push detail view.
- Long-press row → context menu: "copy host", "view in DNS log".
- Pull-to-refresh: re-aggregate immediately (skips the 1Hz debounce).

## Severity / colour

If `AlertHotIndex.severity(for: row.ip)` returns non-nil, the leading
icon becomes the alert severity glyph and the hostname renders in
that severity's hue. Otherwise: brand colour from `Theme`.

## Accessibility

- Row a11y label: "Top host. dns.google. 1.2 megabytes per second.
  Connected for 2 minutes."
- Sparkline a11y label: "Bandwidth trend, rising, peak 1.4 megabytes
  per second."
- Dynamic type to AX5; the inline sparkline drops out at AX3+ to
  give the text room (the detail view's larger chart remains).
- Reduce-motion: charts render the final frame without the
  drawing animation.
