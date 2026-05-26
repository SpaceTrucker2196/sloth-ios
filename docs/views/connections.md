# ConnectionsView

Milestone: M6
Status: spec (blocked on sloth emitting connection records in JSONL)

## Status note

As of M6 planning, the sloth JSONL schema includes records for
DNS, TLS, QUIC, HTTP, NTP, ICMP, and alerts — but **not** active
TCP/UDP connections. The connections panel exists in sloth's TUI
(view `[2]`), but the per-connection state isn't streamed.

M6 either:
- (a) waits on a sloth-side change that adds a `conn` record type to
  the JSONL schema, then implements this view;
- (b) approximates by aggregating per-flow stats from the TLS/QUIC/
  DNS streams (lossy but useful).

Decision deferred to milestone start. File the gap in `PROGRESS.md`.

## Data source (preferred, blocks on sloth)

Store ring: `store.connections` (new ring once schema is extended).

## Layout

```
┌──────────────────────────────────────────────────────┐
│  Connections                       [▤ TCP UDP All]   │
│  Local              → Remote          Pr ST  PID Pr  │
│  192.168.1.5:33445  → 8.8.8.8:443     TCP ESTAB 1234 │
│  192.168.1.5:53210  → 1.1.1.1:53      UDP -     -    │
│  192.168.1.5:22     ← 192.168.1.99…   TCP ESTAB -    │
│                                                      │
│  ┌── RTT (last 30 samples) for selected row ───────┐ │  ← RTTSparkline
│  │ ▂▃▄▃▂▁▂▃▄▆█▆▄▃▂▁▂▃                              │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## Graphs

- **RTTSparkline** — `Chart { LineMark(...) }` for the selected
  connection, last 30 RTT samples. Tells: congestion / path quality.

## Interactions

- Filter chips: TCP / UDP / All.
- Sort: bandwidth / state / RTT / PID.
- Tap row → reveal RTT sparkline + retx count.
- Long-press → context menu: copy local, copy remote.

## Severity / colour

- Remote IPs that match a threat IOC render in CRIT and register
  alert-hot.
- Inbound flows to listening ports (`192.168.1.x:22`) get a
  WARN-orange tint as a "is this expected?" cue.

## Accessibility

- Row a11y: "Connection from local 192.168.1.5 port 33445 to remote
  8.8.8.8 port 443. TCP, established. Process chrome."
