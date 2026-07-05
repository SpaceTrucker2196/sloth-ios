# ICMPLogView

Milestone: v1.x (dashboard drill-in follow-up)
Status: implemented

## Data source

`icmp` records from the `SlothStore.icmp` ring (cap 256). Fields
consumed: `ts`, `src`, `dst`, `itype`, `code`. The wire subset
carries no `is_v6` flag; family is inferred from the address
literal (`:` ⇒ v6) by `ICMPClassify.isV6`.

## Layout

Same shape as the M5 log views: `FilterBar` (category chips +
search) over a plain scrolling list, newest first.

Row:

```
⇄  Echo Req      192.168.1.1 → 192.168.1.5        type 8/0   18:22:41
```

- Leading SF Symbol per category (echo `dot.radiowaves.left.and.right`,
  error `exclamationmark.triangle`, discovery `antenna.radiowaves.left.and.right`,
  other `circle.dotted`).
- Display name from `ICMPClassify.name(for:)` — mirrors sloth's
  `icmp_log.c` `desc_v4` / `desc_v6` tables exactly.
- src / dst take alert-hot hues via `AlertHotIndex`.

## Filter axes

- Category chips: All / Echo / Errors / Discovery
  (`ICMPClassify.Category`). Errors tint WARN orange — an
  unreachable storm should read as trouble at chip level.
- Search: substring across src, dst, display name (`LogFilter`).

## Graphs

None. ICMP volume is low and the packets band already carries the
liveness cue; a chart here would be chartjunk.

## Interactions

- Reached from the iPad dashboard's ICMP panel title and the
  iPhone tab bar (More overflow).
- Rows are read-only; no detail push (an ICMP record has no more
  fields than the row already shows).

## Severity / colour

- Error-category rows render their name in WARN orange without
  waiting for an alert (same client-side cue pattern as the HTTP
  recon-path highlight).
- Alert-hot src/dst IPs paint in tier hue, bold on WARN+CRIT.

## Accessibility

- Row a11y label: "<name>, from <src> to <dst>, type <t> code <c>".
- Category never rides on color alone — the leading glyph carries it.
