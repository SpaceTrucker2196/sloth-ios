# PROGRESS.md — Agent activity log

A warm-start view of the repo: what's in flight, what just landed,
what was decided. Companion to [`MISSION.md`](MISSION.md) (the
charter, slow-moving) and [`docs/wiki/log.md`](docs/wiki/log.md)
(wiki edits only).

**Who writes here**: every agent that lands a non-trivial change.
**When**: at the end of a working session, before pushing the
commits that close out the work.
**Where to read first**: top of the file. Newest entries at the top
of their section.

---

## Format

Each landed entry:

```
### YYYY-MM-DD — short title
**Commits**: <hash1>, <hash2>
**Touched**: paths or modules
**Why**: one to three sentences on what motivated the change
**Follow-ups**: open work this exposed, if any
```

Each in-progress entry:

```
### <short title>
**Owner**: agent name + session (or human)
**Started**: YYYY-MM-DD
**Goal**: one sentence
**Status**: free text — where it is right now
**Blockers**: if any
**Next concrete step**: what the next agent picking it up should do
```

When an in-progress item lands, **move** it (do not duplicate). Add
the commit hashes.

---

## In progress

*(nothing — M8 just landed; the v1.0 line is feature-complete pending M6.)*

**M6 blocker**: tracked upstream as
[sloth #5](https://github.com/SpaceTrucker2196/sloth/issues/5). Pick
M6 back up once sloth emits a `connections` JSONL record.

---

## Recently landed

### 2026-05-27 — M8: Polish, profiles, reconnect
**Commits**: *(this entry lands with the commit)*
**Touched**:
- `Sources/SlothCore/ProfileStore.swift` — `@MainActor @Observable`
  list of `NamedProfile`s (`UUID + label + ConnectionProfile`)
  with an `activeID`. Persisted to `UserDefaults` under a single
  JSON-encoded key (per MISSION §2(5), the only thing this app
  ever writes to disk). First-load upgrades the M1 single-profile
  key so operators who came up from M1 don't lose their entry.
- `Sources/SlothCore/Reconnector.swift` — actor with exponential
  backoff (1 s → 30 s cap, ×2). Sleeper is injectable so tests
  drive deterministic timing. `reset()` after a successful
  connect drops the delay back to `initialDelay`.
- `Sources/SlothCore/SlothLog.swift` — `@MainActor @Observable`
  in-memory ring (cap 500) mirrored to `os.Logger` so entries
  also land in Console.app / `log stream`. Carries project
  metadata only — connection events, parse errors, backoff,
  scene lifecycle. **Never** carries record content
  (MISSION §2(5)); the share-sheet export is plain text, not
  JSONL.
- `App/ConnectionCoordinator.swift` — now drives a connect-retry
  loop. On stream end (clean or error) it waits the current
  `Reconnector` delay, then redials. Cancels cleanly when the
  Task is cancelled on `.background`. Pulls the active profile
  from `ProfileStore`; commits a new URI to the store on user
  Connect.
- `App/Views/SettingsView.swift` — list of saved profiles with
  tap-to-activate / swipe-to-delete / swipe-to-edit. "Add
  profile" opens a sheet-mounted `ProfileEditor` that parses
  `tcp:HOST:PORT` before saving. Footer reiterates the no-record-
  persistence rule.
- `App/Views/DiagnosticsView.swift` — recent log lines with a
  per-level filter strip and a share-as-text menu that exports
  the visible window via `ShareLink`. `Clear log` is a
  destructive button on the same menu (the underlying log is
  in-memory so this is fine; no record forensic record is
  destroyed).
- `App/ContentView.swift` — connection bar gains an
  `ellipsis.circle` menu (Profiles… / Diagnostics…) presenting
  the two new screens as sheets. The bar also passes the new
  `ProfileStore` + `SlothLog` to the coordinator. Scene-phase
  transitions are logged.
- `App/SlothIOSApp.swift` — `@State` for `SlothStore`,
  `ProfileStore`, and `SlothLog`; all three injected into the
  environment so every view can `@Environment(...)` per
  CLAUDE.md.

**Tests**: 16 new (115 total, all green).
- `ProfileStoreTests` — add / remove (active vs non-active),
  setActive, update preserves id, persistence round-trip via a
  scoped `UserDefaults` suite, legacy M1 single-profile upgrade
  path.
- `ReconnectorTests` — backoff progression (1, 2, 4, 8, 16, 30),
  reset behaviour, custom initial / multiplier, propagated
  sleeper error.
- `SlothLogTests` — level / category / message round-trip, ring
  cap eviction, clear, export text shape.

**Verification**:
- `swift test` — 115/115 green.
- `xcodebuild build` — iPhone 17 Pro and iPad Pro 13-inch (M5)
  simulators both clean.
- Manual: iPhone shows the new ellipsis menu in the connection
  bar; iPad dashboard composite still renders with the menu on
  the bar above. Saved-profile UI verified via the simulator.

**Why**: M8 closes the production-quality lifecycle gap.
Multi-profile lets an operator switch sloth instances without
re-typing the URI. Exponential-backoff retry survives
flaky-network handoffs without burning battery on a tight loop.
OSLog diagnostics let a remote operator capture "what just
happened" without attaching a debugger.

**Follow-ups**:
- M6 (Connections + RTT) is the remaining milestone, still gated
  on sloth emitting a `connections` JSONL record. Tracked upstream
  as [sloth #5](https://github.com/SpaceTrucker2196/sloth/issues/5).
- Adjacent v1.x vectors per the milestones doc: macOS Catalyst
  pass, per-host pin, Stage Manager polish.

### 2026-05-27 — M7: Composite dashboard (iPad-first)
**Commits**: *(this entry lands with the commit)*
**Touched**:
- `App/Views/DashboardView.swift` — 2×2 `Grid` of `DashboardCard`s
  tiling Alerts / Top hosts / DNS / TLS. Each tile embeds its
  production view (M3 / M4 / M5) inside its own `NavigationStack`
  so push destinations (alert detail, host detail) still work
  from within the tile.
- `App/Views/DashboardCard.swift` — reusable card wrapper. Thin
  title bar (icon + label) over a rounded-rectangle content area
  with a quaternary border. Static; no pinch / drag (per spec).
- `App/Views/SystemPulseChip.swift` — at-a-glance health bar.
  Shows status pill + `rec/s` readout (1-second sampled delta of
  `recordsReceived`) + one dot+count per severity tier
  (CRIT / WARN / LOW). Visible on every screen — slots between
  the connection bar and the content area.
- `App/ContentView.swift` — switches on `horizontalSizeClass`:
  `.regular` (iPad, large iPhone landscape) → `DashboardView`,
  `.compact` (iPhone) → existing TabView. Connection bar
  compacted to a single row (text field + connect button) since
  the system-pulse chip now carries the status pill.

**Verification**:
- `swift test` — 99/99 green (no new SlothCore code).
- `xcodebuild build` on iPhone 17 Pro simulator — clean.
- `xcodebuild build` on iPad Pro 13-inch (M5) simulator — clean.
- Manual on iPad portrait: dashboard renders the four tiles
  with their empty states, system pulse shows `idle / 0.0/s /
  0 0 0`. iPhone retains the 5-tab TabView with the same pulse
  chip above the tabs.

**Why**: M7 is the payoff of M3–M5. The same alerts / hosts /
log views the operator scrolls separately on iPhone tile into a
single iPad screen, mirroring sloth's static TUI composite —
one glance answers "what is on this network right now". The
system-pulse chip carries the TUI's header row so the operator
gets live rec/s + tier counts from every screen.

**Follow-ups**:
- M6 (Connections + RTT) is still gated on sloth emitting a
  `connections` JSONL record. When that lands, add a fifth tile
  to the dashboard grid (3×2 layout, or move Top hosts adjacent
  to Connections so the flow → host correlation reads left-to-
  right).
- M8 (Polish / multi-profile / reconnect) is unblocked next.
  StatusPill on every nav bar is partially done by the
  `SystemPulseChip`; the rest of M8 (saved profiles, OSLog
  diagnostics view, exponential-backoff `Reconnector`) is open.

### 2026-05-27 — M5: DNS, TLS, HTTP log views
**Commits**: *(this entry lands with the commit)*
**Touched**:
- `Sources/SlothCore/LogFilter.swift` — pure substring matcher,
  case-insensitive, multi-word AND, applied across a caller-
  supplied list of haystack fields. Mirrors sloth's `filter.c`
  semantics.
- `Sources/SlothCore/LogStats.swift` — `QTypeDistribution.shares`
  (slice-per-qtype with "other" rollup for the DNS pie) +
  `TLSVersionMix.shares` (TLS version share with stable colour
  order across frames + `isDeprecated(...)` for the 1.0 / 1.1
  WARN tinting).
- `Tests/SlothCoreTests/LogFilterTests.swift` — 15 hermetic tests
  covering empty / case-insensitive / multi-word substring +
  qtype canonicalisation + TLS version canonicalisation + the
  deprecated flag. 99/99 total `swift test` green.
- `App/Views/FilterBar.swift` — reusable chip strip + search
  field. Generic over a `Hashable` chip id; caller supplies the
  chip labels + tints. Owns no filtering itself, just rendering.
- `App/Views/DNSLogView.swift` — Q / R direction chips, qtype
  pie at the top, list with brand-coloured qnames, NXDOMAIN
  highlighting, alert-hot src / answer IPs taking on their tier
  hue via `AlertHotIndex`.
- `App/Views/TLSLogView.swift` — "TLS 1.0 / 1.1" filter chip,
  the stacked version-mix bar, JA3 prefix coloured by hash so
  the same JA3 across hosts pops as a correlation cue. WARN tint
  on deprecated tiers without waiting for an alert.
- `App/Views/HTTPLogView.swift` — GET / POST / Other chips, no
  chart (HTTP today is dominated by captive-portal noise; a
  method-distribution chart would be uninformative). Row-side
  heuristic that highlights classic recon paths (`.git/`,
  `.env`, `/wp-admin`, …) in CRIT red *before* sloth flags them.
- `App/Charts/QTypeDistributionChart.swift` — donut summary at
  the top of `DNSLogView`. Stable per-qtype colour. Annotations
  on slice; legend hidden. Animation disabled under
  `accessibilityReduceMotion`.
- `App/Charts/TLSVersionMixChart.swift` — stacked horizontal
  `BarMark`, single bar visualising proportions. WARN tint on
  TLS 1.0 / 1.1 segments. Custom legend below with hit counts.
- `App/Theme.swift` — adds `Theme.ja3Color(_:)` (hash → 8-colour
  warm-leaning phosphor palette) + an `extension ShapeStyle
  where Self == Color` so `foregroundStyle(.alertHotWarn)` and
  friends resolve. Without that, the dot-shorthand only sees
  SwiftUI's built-ins and the rows fail to compile.
- `App/ContentView.swift` — `DebugLogView` tab dropped; the
  TabView is now Alerts / Hosts / DNS / TLS / HTTP.
- `App/Views/DebugLogView.swift` — **deleted**. Its M2 → M3
  bridge job is done; the per-category views replace its three
  ring sources.

**Verification**:
- `swift test` — 99/99 green (84 pre-existing + 15 new
  LogFilter / LogStats).
- `xcodebuild build` on iPhone 17 Pro simulator — zero errors.
- Manual: launches to the Alerts tab; tab bar shows all five
  tabs with their SF Symbols (`exclamationmark.triangle`,
  `globe.americas`, `questionmark.bubble`, `lock`, `globe`).
  Each per-log tab shows its empty state ("No DNS records",
  "No TLS handshakes", "No HTTP traffic") with explanatory
  text until traffic flows.

**Why**: M5 turns the merged debug log into three operator-
ready surfaces, each with its own filter axes and its own
summary chart. The cross-panel hot-IP coloring established in
M3 is now wired through DNS / TLS / HTTP rows too — an IP
flagged in any alert renders in the alert's tier hue everywhere
it appears, mirroring sloth's `tui_alert_hot_*` rule.

**Follow-ups**:
- The HTTP attack-path heuristic is a small client-side cue,
  not a replacement for sloth's `HTTP_ATTACK_PATH` alert. When
  sloth emits that alert the row's CRIT tint comes through the
  `AlertHotIndex` path; the heuristic acts before the alert
  fires.
- M6 (Connections + RTT) may block on a sloth-side `connections`
  JSONL record; file the gap there when picking up M6.

### 2026-05-27 — M4: TopHostsView + activity sparklines + protocol stack chart
**Commits**: *(this entry lands with the commit)*
**Touched**:
- `Sources/SlothCore/HostAggregator.swift` — pure aggregator that
  turns the store's rings into a `TopHostsSnapshot` (top 32 external
  hosts by record count). Skips RFC1918, loopback, link-local,
  multicast (v4 + v6) so the list focuses on external traffic, per
  `src/top_hosts.c`. Per-IP per-minute sparkline samples (30 bins ×
  60s). Hostname resolved via the store's DNS cache (most-recent
  A/AAAA answer wins). JA3 set collected from TLS records.
  **Schema substitution**: sloth's JSONL emits protocol logs but
  no byte counters; rate samples are therefore *records / minute*
  rather than *bytes / minute*. When sloth grows a `bw` record the
  data source can swap without UI changes.
- `Tests/SlothCoreTests/HostAggregatorTests.swift` — 14 hermetic
  tests covering external/internal IP discrimination (v4 + v6
  edges, 172.16/12 boundary), per-minute bucketing,
  out-of-window drop, per-protocol merging, sort order,
  `topN` cap.
- `App/Theme.swift` — `Theme.brand(for: hostname)` lookup table
  (cloudflare/google/firefox/cloudflare/etc.) mirroring sloth's
  `tui_brand_addstr`. Order matters in the table — longer needles
  first so `cloudflare` wins over a hypothetical `cloud`.
- `App/Charts/BandwidthSparkline.swift` — reusable inline chart.
  Pure `[Double]` series; heat-grades the trace by value when no
  caller-tint is given (`Color.heat` from M3). Hidden axes; fits
  any frame. Will be reused by M6 connections (RTT) and M7
  composite dashboard. `accessibilityReduceMotion` respected.
- `App/Views/TopHostsView.swift` — the new tab. Top section is a
  `ProtocolStackChart` (stacked `AreaMark`s for TLS/QUIC/DNS/HTTP
  shares across hosts so the operator sees "what kind of traffic
  is this" at a glance). Below: list of hosts with a per-row
  sparkline, brand-coloured hostname when known, alert-hot
  override (flame.fill + severity tier hue) when the hot index
  flags the row's IP.
- `App/Views/TopHostDetailView.swift` — push destination. Larger
  sparkline, per-protocol breakdown bars, JA3 fingerprint list,
  recent qnames that resolved to this IP.
- `App/ContentView.swift` — Hosts tab added between Alerts and
  Debug.

**Verification**:
- `swift test` — 84/84 green (70 pre-existing + 14 new HostAggregator).
- `xcodebuild build` on iPhone 17 Pro simulator — zero errors, the
  one irrelevant AppIntents metadata note.
- Manual: launches with three tabs (Alerts / Hosts / Debug). Hosts
  tab shows the empty state ("No external hosts yet") with the
  filter rationale until traffic flows.

**Why**: M4 ships the second production view and lands two
load-bearing pieces the next milestones inherit: a reusable
`BandwidthSparkline` (M6 uses it for RTT, M7 for dashboard tiles)
and the hostname brand-colouring helper (M5 logs apply it to SNI
and HTTP host columns). Spec called for "bandwidth bytes" but
sloth doesn't emit byte counters in JSONL — substituted
records-per-minute as an honest activity proxy. Documented the
substitution prominently so it doesn't become a hidden lie.

**Follow-ups**:
- **sloth-side schema gap**: per-host or per-conn byte counters in
  the JSONL stream would let this view show real bandwidth instead
  of record rate. File an issue on the sloth repo when picking
  this up.
- Brand table is hardcoded; would be nicer as a JSON resource that
  reloads without a rebuild. Low priority — operator preferences
  rarely change.
- The `ProtocolStackChart` weights bins by each host's per-protocol
  share rather than tracking per-protocol bins independently. Loses
  fidelity when a host's mix changes mid-window. Trade-off accepted
  to keep `HostActivity` small (15 floats per host vs. 60).

### 2026-05-27 — M3: AlertsView + three-tier palette + frequency chart
**Commits**: *(this entry lands with the commit)*
**Touched**:
- `Sources/SlothCore/AlertBucketing.swift` — pure-Swift bucketing helper
  that turns `[AlertEntry]` into `[AlertFrequencyBucket]` (per-minute
  counts split by severity over a window). Bucketing key is `lastSeen`,
  weight = 1 per entry (sloth doesn't emit per-hit timestamps).
- `Tests/SlothCoreTests/AlertBucketingTests.swift` — 8 hermetic tests
  covering empty input, window edges (in vs out, exactly on edge),
  zero-window, same-minute same-sev collapse, same-minute different-sev
  split, different-minute split, mixed three-tier spread.
- `App/Theme.swift` — SwiftUI `Color` extensions for the three-tier
  alert palette (`.alertHotLow/Warn/Crit`), phosphor base hues, and
  the heat gradient (`Color.heat(fraction)` mirrors sloth's `tui_heat`).
  Adds `AlertSeverity.color` extension. SlothCore stays SwiftUI-free
  per CLAUDE.md — Theme lives in `App/`.
- `App/Charts/AlertFrequencyChart.swift` — Swift Chart `BarMark`
  stacked by severity, last 60 minutes. X-axis domain anchored to the
  full window so empty buckets still leave space. `.accessibilityLabel`
  describes the trend. `accessibilityReduceMotion` disables the
  ease-out animation.
- `App/Views/AlertRowView.swift` — list row primitive. Leading 4-pt
  severity stripe + SF Symbol prefix (info.circle / triangle / octagon)
  + tier label + title + hit-count badge (×N when ≥ 2) + relative
  time + optional second-line detail + optional match-IP badge
  (`flame.fill` when the IP is currently hot, `network` otherwise).
- `App/Views/AlertsView.swift` — the M3 view itself. Filter chips
  (All / CRIT / WARN / LOW, with smart toggle semantics), search
  field (substring against title + detail + key), the frequency chart,
  the scrollable list. Empty states for "no alerts" vs "no matches".
  Tick timer re-buckets every 5 s so the x-axis advances even when no
  new alerts arrive.
- `App/Views/AlertDetailView.swift` — push destination. Severity
  header, full title + detail, first/last seen + computed span,
  identity (key + match-IP coloured if hot), cross-reference counts
  from `store.dns`/`tls`/`http` for the match-IP.
- `App/ContentView.swift` — rewritten around a `TabView`: Alerts
  (default tab, with a CRIT count badge) + Debug (the existing
  merged log; M5 replaces it). Connection bar + status pill stay at
  the top of every tab as global chrome.

**Verification**:
- `swift test` — 70/70 green (62 pre-existing + 8 new AlertBucketing).
- `xcodebuild build` on `iPhone 17 Pro` simulator — zero warnings,
  zero errors (one irrelevant AppIntents metadata note that's not
  actionable).
- `xcodebuild test` — 1/1 iOS smoke test passes; SlothCore suite is
  driven through `swift test` independently.
- Manual: launched on the iOS-17 simulator. Alerts tab shows the
  empty state ("Nothing on fire") with the badge at 0 and the
  frequency chart at full-width with an empty 60-minute axis. Debug
  tab is unchanged from M2.

**Why**: M3 is the first production view. It establishes the
three-tier palette as a load-bearing concept (severity stripe + SF
Symbol + bold weight on WARN/CRIT + cross-panel hot-IP coloring), the
Swift Charts pattern (pure bucketing helper feeding a declarative
`Chart` view), and the tab-as-feature-unit scaffold every following
milestone slots into. The `flame.fill` glyph on hot IPs gives a
preview of what M4–M6 panels will lean on when they render IPs that
the alert-hot index has flagged.

**Follow-ups**:
- M4 (top hosts + bandwidth sparklines) and M5 (DNS/TLS/HTTP logs)
  are both unblocked. M4 builds on the `Color.heat(_:)` helper this
  commit introduced.
- The cross-reference counts in `AlertDetailView` recompute every
  body render — a single pass over the DNS/TLS/HTTP rings. Fine at
  current ring caps (≤ 1024 each); revisit if a profiler ever flags
  it.
- `AlertEntry.identityKey` falls back to `"title#firstSeen"` when
  `key` is nil — alerts without a key won't dedup in the List. sloth
  always populates `key` per the schema, so this is defensive only.

### 2026-05-26 — M2: SlothStore (state surface)
**Commits**: *(this entry lands with the commit)*
**Touched**:
- `Sources/SlothCore/RingSizes.swift` — public `RingSizes` value type
  with per-record-type caps (dns 1024, tls 1024, quic 512, http 1024,
  ntp 128, icmp 256, alerts 128). Defaults are best-effort against
  sloth's `MAX_*_LOG`; the actual sloth caps should be cross-checked
  and the defaults updated if they drift.
- `Sources/SlothCore/AlertHotIndex.swift` — `@MainActor` IP → severity
  cross-panel index with promotion-only semantics within the TTL
  window (default 300 s). Higher-severity alerts promote; same-sev
  refreshes the TTL; lower-sev within the window is dropped; once
  expired, the entry reverts to whatever the next alert says. Handles
  `[v6]:port`, `ip:port`, bare IP, bare v6 in `bareIP(_:)` so callers
  can lookup with whatever representation the source view has.
- `Sources/SlothCore/SlothStore.swift` — `@MainActor @Observable`
  single source of truth. Per-type rings, alert dedup by
  `key ?? title` (mirrors sloth's TUI: one row per alert key with
  a hit count, not one row per occurrence), alerts sorted
  newest-first by `lastSeen`, an `unknownCount` for forward-compat,
  `connectionState`, `recordsReceived`, `lastError`. `ingest(_:)`
  for single records; `ingest(stream:)` drives the lifecycle off
  a `SlothClient.records(for:)` stream. `reset()` wipes everything
  (including the hot index) on profile switch.
- `App/SlothIOSApp.swift` — owns `@State private var store = SlothStore()`
  and injects via `.environment(store)`. Every view now uses
  `@Environment(SlothStore.self)` per CLAUDE.md (no `@StateObject`
  for cross-view state).
- `App/ConnectionCoordinator.swift` — `@Observable` view-local
  coordinator that holds the editable URI buffer and owns the
  client task; connection state lives on the store now. Replaces
  the M1 `DebugLogController`.
- `App/ContentView.swift` — rewired against the store. `ConnectionBar`
  reads `store.connectionState` + `store.recordsReceived` + the
  coordinator's URI binding.
- `App/Views/DebugLogView.swift` — merged log view (every ring +
  alerts, sorted by ts desc) that bridges M2 → M3+. Will be replaced
  by `AlertsView` (M3), per-category log views (M5), etc. Bold
  weight on WARN+CRIT severity rows already wired through here so
  the per-view spec from M3 can lift the same conventions.
- `Tests/SlothCoreTests/AlertHotIndexTests.swift` — 13 tests:
  `bareIP` normalisation across v4/v6/bracketed/portless, promotion-
  only across all severity transitions, TTL refresh on same-sev,
  expiry, post-expiry re-write, ignore on missing `match_ip`.
  Includes a deterministic `TestClock` so TTL tests are hermetic.
- `Tests/SlothCoreTests/SlothStoreTests.swift` — 12 tests covering
  per-type ring routing + caps, alert dedup-by-key (with title
  fallback), newest-first sort by `lastSeen`, alert-cap eviction,
  alert-hot wiring on alert ingest, `reset()` semantics, and the
  `ingest(stream:)` lifecycle (state transitions on success +
  error propagation through `lastError`).

**Verification**:
- `swift test` — 62/62 green (4 pre-existing + 29 from M1 + 25 from M2).
- `xcodebuild build`/`test` on `iPhone 17 Pro` simulator: clean,
  zero warnings, `SlothIOSAppTests` smoke passes.
- Manual: installed + launched on the iOS-17 simulator; cold-start
  UI renders identically to M1 (status pill, URI field, empty-state).
  Internally everything now flows Client → Store → SwiftUI views.

**Why**: M1 proved the wire works. M2 puts a typed state surface
between the wire and the UI so every future view can subscribe
without per-view plumbing. The promotion-only `AlertHotIndex` is
the load-bearing piece for M3's three-tier palette: every other
view that renders an IP looks it up via the index and inherits the
hot severity hue from whichever alert promoted it.

**Follow-ups**:
- Ring caps should be cross-checked against sloth's `app.h` (or
  wherever the canonical `MAX_*_LOG` constants live). Drift is not
  a correctness break (rings just hold ±N records vs. the TUI) but
  matching the TUI exactly is the point.
- M3 (`AlertsView`) and M5 (DNS/TLS/HTTP log views) are now both
  unblocked. Pick either; they share no surface.
- The `DebugLogView` is intentional scaffolding; delete it as
  per-category views replace each of its ring sources.

### 2026-05-26 — M1: Connection plumbing
**Commits**: *(see git log; this paragraph lands with that commit)*
**Touched**:
- `Sources/SlothCore/SlothRecord.swift` — Codable sum type for the
  seven sloth JSONL `type` values (`dns`, `tls`, `quic`, `http`,
  `ntp`, `icmp`, `alert`) plus a forward-compat `unknown(type:, ts:)`
  case. Per-type sub-structs decode only the fields sloth-ios needs
  today; unknown keys are ignored.
- `Sources/SlothCore/LineReader.swift` — actor-isolated newline
  framer that buffers across chunk boundaries, trims CRLF
  defensively, and exposes a `lines(from:)` adapter that wraps a
  byte-chunk `AsyncThrowingStream` as a line `AsyncThrowingStream`.
- `Sources/SlothCore/ConnectionProfile.swift` — value type with
  `tcp:HOST:PORT` parsing (incl. `[v6]:PORT`), URI round-trip, and
  `UserDefaults` save/load. Only persistence in the app per MISSION
  §2(5).
- `Sources/SlothCore/SlothClient.swift` — `SlothTransport` protocol
  seam (so tests inject a deterministic in-memory transport),
  `NetworkTransport` default backed by `NWConnection`, and a
  `SlothClient` that wires bytes → frame → JSON decode →
  `SlothRecord` stream. Garbled lines are skipped, not fatal.
- `Tests/SlothCoreTests/{LineReaderTests,SlothRecordTests,SlothClientTests,ConnectionProfileTests}.swift`
  — 29 new hermetic tests covering chunk-split framing, every record
  type round-trip, the forward-compat envelope, profile parsing/
  persistence, and a full transport-fed pipe.
- `App/DebugLogController.swift` — `@Observable` view-local
  controller (per-CLAUDE.md "`@StateObject` for view-local only";
  using the iOS-17 `@Observable` + `@State` equivalent). Owns the
  records ring (500-line cap), connection state, and the active
  Task. Pre-M2 stand-in for `SlothStore`.
- `App/ContentView.swift` — connection-bar (status pill, URI field,
  Connect button) + scrolling log list. View body well under 60
  lines; children extracted (`ConnectionBar`, `StatusPill`,
  `DebugLogList`, `LogRow`). Reconnects on `scenePhase == .active`,
  cancels on `.background`.
- `project.yml` — excluded `App/Tests/**` from the `SlothIOS` target
  (it was getting compiled into the app), and gave `SlothIOSTests`
  its own auto-generated Info.plist + bundle id so the unit-test
  bundle code-signs cleanly.
- `Makefile` — `iPhone 15` was the hardcoded destination, but only
  iPhone 17-class simulators are installed on this Mac; bumped to
  `iPhone 17 Pro`.

**Verification**:
- `swift test` — 33/33 green (4 pre-existing AlertSeverity + 29 new).
- `xcodebuild ... build` — clean, zero warnings.
- `xcodebuild ... test` — `SlothIOSAppTests` smoke passes on
  `iPhone 17 Pro` simulator.
- Manual: installed and launched the app on the iOS-17 simulator;
  cold-start UI renders correctly (status pill `idle`, URI field
  pre-populated with default, empty-state placeholder). End-to-end
  wire validation against a real sloth instance is up to the
  operator — `cfprefsd` caches `UserDefaults` aggressively, so
  injecting a profile from outside the running sim isn't a clean
  smoke path.

**Why**: M1 is the wire-proof milestone. Before any UI design work,
we needed end-to-end evidence that bytes off the sloth `--data-socket`
parse into typed records. The transport seam matters as much as the
codec — every milestone past M1 substitutes a fixture transport in
its tests, so this layout is load-bearing.

**Follow-ups**:
- M2 is unblocked: replace the in-process `DebugLogController` ring
  with `SlothStore` (per-type rings + `AlertHotIndex`).
- The per-record field set in `SlothRecord` is a best-effort
  interpretation of the sloth schema page; if sloth's writer uses
  different JSON keys than guessed (e.g. `qname` vs `name`), update
  the `CodingKeys` mapping. Decoding ignores unknown keys, so older
  agents pulling future sloth fields stays safe.
- Wire-level e2e in the iOS simulator should be folded into a
  `xcodebuild test` UI test once M2 lands a stable on-screen
  surface to assert against.

### 2026-05-26 — Initial repo scaffolding
**Commits**: *(initial commit)*
**Touched**: `README.md`, `MISSION.md`, `CLAUDE.md`, `FACTORY.md`,
`PROGRESS.md`, `.gitignore`, `Makefile`, `project.yml`,
`Package.swift`, `docs/milestones.md`, `docs/dark-factory.md`,
`docs/views/*`, `docs/wiki/*`, `Sources/SlothCore/*` (stubs),
`Tests/SlothCoreTests/*` (stubs), `App/*` (stubs)
**Why**: Sloth (the C99 passive network monitor) now emits a
read-only JSONL stream over TCP via `--data-socket tcp:HOST:PORT`.
This repo is the iOS / iPadOS client that consumes that stream over
a Tailscale tailnet and renders the same panels sloth shows in its
terminal UI, in SwiftUI, with Swift Charts graphs. The initial
commit is dark-factory scaffolding: charter, working rules, build
runbook, milestone roadmap, per-view UI specs, project skeleton.
No working app yet — pre-M1.
**Follow-ups**: M1 (Connection plumbing) is the first concrete
build target; see `docs/milestones.md`.

---

## Open follow-ups (not yet owned)

All milestones M1–M8 from [`docs/milestones.md`](docs/milestones.md)
are open. Pick the next unblocked one. Each milestone names its
acceptance criteria; the agent owns moving it from Open → In
progress → Landed.

Adjacent work that isn't on the milestone track:

- **CI** — GitHub Actions workflow that runs `swift test` and
  `xcodebuild test` on every PR. Useful after M1 lands a real test
  surface. Lift from `sloth/.github/workflows/ci.yml`.
- **App icon + accent colour** — placeholder for now; design pass
  once the first screens are stable (post-M3).
- **macOS Catalyst** — stretch goal post-M7. Most SwiftUI views
  should "just work"; the composite dashboard may need iPad-like
  layout adjustments.
- **TestFlight / App Store distribution** — out of scope for now;
  this is a tool for the operator, not a published product.
