# DiagnosticsView

Milestone: M8
Status: spec

## Data source

`OSLog` subsystem queries. The app uses category-tagged `Logger`
calls throughout; this view pulls the last 500 entries from the
local store. **No record content** appears here — only operational
events (connect, disconnect, parse error, profile changed).

## Layout

```
┌──────────────────────────────────────────────────────┐
│  ← Settings           Diagnostics              [↗]   │
│                                                      │
│  22:01:00  client    Connected to 100.64.0.5:8765    │
│  22:01:00  client    TLS 1.3 negotiated… (wait, no)  │
│  22:00:55  client    Disconnected: ECONNREFUSED      │
│  22:00:55  store     Cleared 4 rings on disconnect   │
│  22:00:30  parse     Decode failed: unknown type 'xy'│
│  ...                                                 │
└──────────────────────────────────────────────────────┘
```

The trailing `[↗]` shares the visible log lines as text via the
system share sheet. **The share never includes record content** —
only the diagnostic timestamps and event categories.

## Interactions

- Pull to refresh re-queries OSLog.
- Tap a row → reveal the full message in a sheet.
- Share button → text-only export.

## Severity / colour

- Error rows render in WARN orange.
- "Connected" / "Disconnected" rows use the standard severity tier
  for context (disconnect = WARN; connected = phosphor teal).

## Accessibility

- Row a11y label: "Diagnostic. 22:01:00. Client. Connected to
  100.64.0.5 port 8765."
