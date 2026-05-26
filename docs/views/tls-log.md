# TLSLogView

Milestone: M5
Status: spec

## Data source

Store ring: `store.tlsLog`.
Update cadence: realtime.

## Layout

```
┌──────────────────────────────────────────────────────┐
│  TLS                                          🔍 ___ │
│  ┌──────────────────────────────────────────────────┐│
│  │ Version mix (last 5min) — stacked bar            ││  ← TLSVersionMix
│  │ ████████████████░░░  TLS 1.3                     ││
│  │ ████░░░░░░░░░░░░░░░  TLS 1.2                     ││
│  │ ▓░░░░░░░░░░░░░░░░░░  TLS 1.0  ← WARN             ││
│  └──────────────────────────────────────────────────┘│
│  19:42:01  TLS 1.3  google.com         deadbeefcafe │
│  19:42:02  TLS 1.3  api.github.com     771,4865-…   │
│  19:42:03  TLS 1.2  legacy-iot.local   e7d705a3286e │
│  19:42:03  TLS 1.0  weak-cipher.test   …             │  ← WARN row
└──────────────────────────────────────────────────────┘
```

## Graphs

- **TLSVersionMix** — `Chart { BarMark(...) }` stacked. Tells: how
  much of your traffic is on deprecated TLS? Surfaces downgrade
  patterns at a glance.

## Interactions

- Search: substring against SNI host + src + JA3 prefix.
- Tap row → detail with full JA3, src/dst IPs, and a "known
  fingerprint?" panel referencing a small embedded table of common
  client fingerprints (Chrome, Safari, Firefox, common bots).

## Severity / colour

- TLS 1.0 / 1.1 rows render in WARN orange.
- Hosts that match a threat-domain IOC pick up CRIT.
- JA3 prefixes use the IP-palette hash so the same JA3 always shows
  the same colour (cross-host correlation cue).

## Accessibility

- Per-row a11y: "TLS 1.3 to google dot com. JA3 starts dead beef …"
- Chart a11y: "TLS version mix. 80% TLS 1.3, 18% TLS 1.2, 2% TLS 1.0."
