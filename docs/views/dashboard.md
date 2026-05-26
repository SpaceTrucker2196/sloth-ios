# DashboardView (composite)

Milestone: M7
Status: spec

## Data source

Reuses the data sources of the M3–M5 views via `SlothStore`.
Update cadence: realtime; this view does no new aggregation.

## Layout

iPad landscape (≥ 1024px wide):

```
┌──────────────────────────────────────────────────────────────────────┐
│ ●  sloth-ios     100.64.0.5:8765      1247 rec/s    🚨 2 ⚠ 3 i 5    │
├─────────────────────────────────────┬────────────────────────────────┤
│ Critical alerts                     │ Top hosts                      │
│  ▤ CRIT THREAT_DOMAIN  4×           │  dns.google     1.2MB/s ▂▃▅▆▇ │
│  ▤ CRIT THREAT_IP      1×           │  *.cloudflare   240KB/s ▁▂▃▄▅ │
├─────────────────────────────────────┼────────────────────────────────┤
│ DNS log              [pie qtypes]   │ TLS log         [stack vers]   │
│  18:16  R  A    google.com   142… │  19:42  TLS 1.3  google.com    │
│  18:16  Q  AAAA reddit.com   —    │  19:42  TLS 1.3  github.com    │
│  18:16  R  A    ghost.local  NX!  │  19:42  TLS 1.0  iot.local  ⚠  │
├─────────────────────────────────────┴────────────────────────────────┤
│ Connections                                                          │
│  192.168.1.5:33445 → 8.8.8.8:443           TCP ESTAB 1.2MB/s        │
└──────────────────────────────────────────────────────────────────────┘
```

iPhone fallback: `TabView` with the same panels.

## Graphs

Inherits charts from the embedded panels — `AlertFrequencyChart`
(M3), `BandwidthSparkline` (M4), `QTypeDistribution` (M5),
`TLSVersionMix` (M5).

## Interactions

- Tap any panel header → push to that panel's full view.
- Pinch / drag disabled; the layout is fixed.

## Severity / colour

- The status pill in the header shows the highest current severity
  with the matching hue (any CRIT → red pill; else any WARN → orange;
  else any LOW → yellow; else green).
- Cross-panel hot-IP coloring is in full force: a CRIT-flagged IP
  paints red in alerts, top hosts, DNS log, and connections
  simultaneously.

## Accessibility

- The composite is meant for a tablet; iPhone falls back to `TabView`.
- Each panel inside the dashboard has the same a11y label it has as
  a standalone view.
- The status pill is the first a11y element, so VoiceOver users hit
  it on entry.
