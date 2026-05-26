# View specs

One file per top-level SwiftUI view. Each covers:

1. **Data source** — which JSONL record types from the
   [schema][schema] populate this view, and through which
   `SlothStore` ring.
2. **Layout** — the visual hierarchy. Text mock allowed; SwiftUI
   sketches are encouraged.
3. **Graphs** — every chart on the view, with the data source, the
   mark type, and what story it's telling.
4. **Interactions** — taps, swipes, search, filter behaviour.
5. **Severity / colour rules** — how the three-tier alert palette
   applies; cross-panel hot-IP rules; any view-specific theming.
6. **Accessibility** — labels, dynamic type behaviour, reduce-motion
   handling.

[schema]: https://github.com/SpaceTrucker2196/sloth/blob/main/docs/wiki/jsonl-schema.md

## Index (mapped to milestones)

| Milestone | View | File |
|-----------|------|------|
| M3 | Alerts             | [alerts.md](alerts.md) |
| M3 | Alert detail       | [alerts.md](alerts.md) (same spec) |
| M4 | Top hosts          | [top-hosts.md](top-hosts.md) |
| M4 | Top host detail    | [top-hosts.md](top-hosts.md) (same spec) |
| M5 | DNS log            | [dns-log.md](dns-log.md) |
| M5 | TLS log            | [tls-log.md](tls-log.md) |
| M5 | HTTP log           | [http-log.md](http-log.md) |
| M6 | Connections        | [connections.md](connections.md) |
| M7 | Dashboard          | [dashboard.md](dashboard.md) |
| M8 | Settings / Profiles| [settings.md](settings.md) |
| M8 | Diagnostics        | [diagnostics.md](diagnostics.md) |

## Spec template

Every view doc follows this skeleton — keep it terse:

```markdown
# <Name>View

Milestone: M<n>
Status: spec / in progress / implemented

## Data source

Store rings: `store.dnsLog`, `store.alerts`, …
Update cadence: realtime (push from SlothClient) / debounced (250ms)

## Layout

```
… text mock or SwiftUI sketch …
```

## Graphs

- **<Chart name>** — `Chart { LineMark(...) }`. Source: `store.X`.
  Tells the story of: …

## Interactions

- Tap row → push <Detail>View
- Swipe right → …

## Severity / colour

How the three-tier alert palette applies on this view.

## Accessibility

- A11y labels for chart and per-row hue.
- Dynamic type: rows reflow at AX1 and above.
- Reduce-motion: chart animations disabled.
```
