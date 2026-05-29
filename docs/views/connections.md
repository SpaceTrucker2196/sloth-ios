# ConnectionsView

Milestone: M6
Status: implemented (dark until sloth emits `connections` JSONL —
[sloth#5](https://github.com/SpaceTrucker2196/sloth/issues/5))

## Data source

Store ring: `store.connections` (new in M6; `RingSizes.connections`
default 2048).
Aggregator: `ConnectionsAggregator.snapshot(from:sparklineCapacity:sort:)`
— groups by `(src, dst, proto)`, latest record wins as the row's
authoritative state, last 30 non-nil `rtt_ms` values form the
sparkline.
Update cadence: realtime (every `SlothClient` record routes through
`SlothStore.ingest(_:)` → the ring → the aggregator on next
`body` evaluation).

## Layout

```
┌──────────────────────────────────────────────────────┐
│  Connections                              ⇅ Sort     │
│  [All] [TCP] [UDP]    🔍 src, dst, state…            │
│  ↔ 10.0.0.5:33445 → 1.1.1.1:443                      │
│    ESTABLISHED  ⏱ 12 ms  ↕ 14.5 KiB         ▂▃▄▆█▆▃ │
│  ↔ 10.0.0.5:53210 → 8.8.8.8:53                       │
│    UDP          ↕ 1.2 KiB                            │
│  ↔ 10.0.0.5:22   → 192.168.1.99:60123                │
│    ESTABLISHED  ⏱ 4 ms   ↕ 0 B               ▁▂▁     │
└──────────────────────────────────────────────────────┘
```

Each row:
- Protocol glyph (left arrows for TCP, dotted radio for UDP) tinted
  by protocol family (TCP teal, UDP bright phosphor).
- `src` → `dst` monospaced; tier hue if the src or dst IP is hot.
- Sub-row: state badge (TCP only), `⏱ rtt_ms`, `↕ rx+tx bytes`.
- Trailing inline `RTTSparkline` (64×28pt) when there are samples.

Tap → `ConnectionDetailView` push.

## Graphs

- **RTTSparkline** — `Chart { LineMark(...) }` over the last 30
  non-nil `rtt_ms` samples for the flow. Hidden axes; heat-graded
  by value relative to the local peak. Mirrors the M4
  `BandwidthSparkline` pattern.

## Interactions

- Proto chips: All / TCP / UDP.
- Search field: substring match across `src` / `dst` / `state`.
- Sort menu (toolbar): Bandwidth (default) / State / RTT / Age.
- Tap row → push `ConnectionDetailView` with the larger sparkline
  and full metric grid.

## Severity / colour

- Alert-hot src / dst IPs render in their tier hue via
  `AlertHotIndex`. Mirrors the DNS / TLS / HTTP rules.
- No view-local rules beyond the cross-panel index — sloth's alert
  pipeline is the source of truth.

## Accessibility

- Each row: `"<proto> <src> to <dst> <state>, <n> ms RTT."`
- Sparkline label: `"RTT trend over the last <n> samples. Latest <x>
  ms, peak <y> ms."`
- Reduce-motion disables the sparkline's ease-out animation.

## Forward compatibility

- `state`, `rtt_ms`, `retx`, `age_s` are all optional per the sloth
  spec. UDP flows omit `state` / `rtt_ms` / `retx`. The view shows
  what's present; nothing is required beyond `ts`, `src`, `dst`,
  `proto`, `rx_bytes`, `tx_bytes`.
- The aggregator dedups by `(src, dst, proto)` only — no flow-id
  required.
