# DNSLogView

Milestone: M5
Status: spec

## Data source

Store ring: `store.dnsLog`.
Update cadence: realtime.

## Layout

```
┌──────────────────────────────────────────────────────┐
│  DNS                              [All|Q|R]   🔍 ___ │
│  ┌──────────────────────────────────────────────────┐│
│  │ qtype distribution (last 60s)                    ││  ← QTypeDistribution
│  │  A:50%  AAAA:30%  PTR:10%  other:10%             ││
│  └──────────────────────────────────────────────────┘│
│  18:16:40  R  A     google.com           142.250.… │
│  18:16:40  Q  AAAA  reddit.com           —           │
│  18:16:40  R  A     ghost.local          NXDOMAIN    │
│  18:16:40  R  A     malware.testing.com  93.184.…  ← │  ← CRIT hot
└──────────────────────────────────────────────────────┘
```

## Graphs

- **QTypeDistribution** — `Chart { SectorMark(...) }`. Slice per
  qtype over the visible window. Visible above the list.

## Interactions

- Filter chips: All / Q / R.
- Search: substring against qname + src + answer.
- Tap row → bottom-sheet with the raw JSONL record + cross-refs to
  TLS log / connections.

## Severity / colour

- NXDOMAIN answers render in WARN orange.
- Threat-hot qnames render in CRIT red; the src IP picks up CRIT
  via `AlertHotIndex`.
- Brand colouring applies to qnames the way sloth's
  `tui_brand_addstr` does.

## Accessibility

- Per-row a11y: "DNS response. A record for google dot com.
  Answer 142 dot 250 …"
- Chart a11y describes the dominant qtype.
