# Host (sensor host and source inventory)

**Issue**: #14 (host status slice)
**File**: `App/Views/HostView.swift`
**Reached from**: Diagnostics → health strip → "Host & sources ›". Debug: `simctl launch … -showHost`.

## Data

sloth `docs/wiki/jsonl-schema.md`, *Host status and the source inventory*.
Both daemons write one batch per 60 s, all rows sharing one `seq`:

| Record | Store | Rule |
|---|---|---|
| `sys_status` | `hostReports[daemon].status` | opens a batch; any other `seq` (a restart counts from 1) starts a new one |
| `sys_sensor` | `hostReports[daemon].sensors` | replaced on a new `seq`: a sensor not in the batch is gone |
| `source_status` | `hostReports[daemon].sources[name]` | replaced per row; also arrives between batches |
| `receiver_hw` | `hostReports[daemon].receivers` | replaced on a new `seq`: an unplugged dongle drops out |
| `sensor` | `hostReports[daemon].radios["kind/iface"]` | the passive sensor registry; change-only, not part of the batch, replaced per row |

The records carry no `daemon` field. The store keys them on the stream
they came in on: `wifi` for the main socket, `rf` for sloth-rf's.

## Layout

One group per daemon, Wi-Fi first:

- **host** — problem rows first (red, octagon icon): under-voltage, any
  band past `ok`, CPU `high`/`saturated`, sources down. Then CPU, memory,
  disk, hottest sensor, uptime, then each `sys_sensor` row.
- **sensors** — the `sensor` registry by kind, then interface: name,
  state (active teal, error red, present/hidden grey), kind · iface,
  and the cumulative `observed` count on the right.
- **sources** — configured first, then by name. State by icon *and*
  hue: ok ✓ teal, stale clock yellow, down ✕ red, not configured − grey,
  not installed (JSONL 2.5.0, sloth-rf: asked for but no SDR on USB at
  start) unplugged-cable amber. Not installed sorts with not configured.
  Endpoint, description and the reader's `detail` under the name; `rate`
  on the right, absent when sloth did not measure one.
- **receivers** — sloth's table name, else the device's own strings,
  else the driver; kind, key and interfaces under it.

The health strip shows one summary line: "Host & sources ›", or the
problems in red when there are any.

## Not shown

`beacon_recall_*` (Wi-Fi daemon only), `load5`/`load15`, `rss_kb`,
per-source `errors` and `reconnects`. No graphs: one batch a minute is
kept, never a history (MISSION §2).
