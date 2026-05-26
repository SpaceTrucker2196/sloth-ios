# sloth-ios — Milestones

Eight milestones from cold clone to feature-complete v1. Each has a
goal sentence, an explicit acceptance bar, and a list of files /
modules it'll touch. Pick the lowest-numbered unblocked milestone.

A milestone is "landed" when:

1. All acceptance criteria are met.
2. `swift test` and `xcodebuild test` both green.
3. Manual run in the simulator confirms the UI behaves as described
   in the per-view spec.
4. `PROGRESS.md` has a landed-entry block with the commit hashes.

---

## M1 — Connection plumbing 🔌

**Goal**: Open a TCP or UNIX-domain connection to a sloth `--data-socket`,
parse newline-delimited JSON into typed `SlothRecord` values, surface
them on a debug screen. End-to-end with no UI design — just proof the
wire works.

**Touches**:
- `Sources/SlothCore/SlothRecord.swift` — sum type for every JSONL
  `type` (dns, tls, quic, http, ntp, icmp, alert). Codable conformance.
- `Sources/SlothCore/LineReader.swift` — async sequence that yields
  `Data` slices split on `\n` from a `Network.framework` connection.
- `Sources/SlothCore/SlothClient.swift` — owns `NWConnection`,
  produces an `AsyncStream<SlothRecord>`. Configurable transport so
  tests substitute a fake `NWConnection`-shaped seam.
- `Sources/SlothCore/ConnectionProfile.swift` — `host:port` value
  type; persisted to `UserDefaults` (the *only* persistence the app
  is allowed to do, per MISSION §2(5)).
- `Tests/SlothCoreTests/LineReaderTests.swift` — feed canned bytes,
  assert lines.
- `Tests/SlothCoreTests/SlothRecordTests.swift` — round-trip every
  record type from the JSONL schema.
- `App/SlothIOSApp.swift` — `@main`.
- `App/ContentView.swift` — connection-profile entry + debug log
  view that streams every parsed record as a row.

**Acceptance**:
- `swift test` covers every record type in the JSONL schema.
- App launches, accepts a `tcp:HOST:PORT` profile in a form, opens
  the connection, and streams records into a scrolling log view.
- Disconnect (server side or airplane mode) surfaces a status pill;
  reconnect on foreground or on user tap.
- No third-party dependencies added.

---

## M2 — `SlothStore` (state surface) 🧠

**Goal**: Replace the M1 debug log with a typed, observable store
that holds the last N records per category in ring buffers matching
sloth's caps. SwiftUI views subscribe; the store is the single
source of truth.

**Touches**:
- `Sources/SlothCore/SlothStore.swift` — `@Observable` class (or
  `ObservableObject` if targeting < iOS 17 ever). One ring per
  record type, plus a derived `alerts` collection sorted by
  `lastSeen`. Thread-safe writes.
- `Sources/SlothCore/AlertHotIndex.swift` — mirror of sloth's
  `tui_alert_hot_*`. `func severity(for ip: String) -> AlertSeverity?`
  with TTL eviction.
- `Tests/SlothCoreTests/SlothStoreTests.swift` — ingest test fixtures
  (record stream from JSON files in `Tests/Fixtures/`), assert ring
  semantics, eviction, alert-hot promotion.
- `App/Views/DebugLogView.swift` — temporarily kept; will be replaced
  by per-category views in M3+.

**Acceptance**:
- Records flow Client → Store → SwiftUI views with no manual wiring
  in each view (it's enough to declare `@Environment(SlothStore.self)`).
- Alert-hot index correctly returns the highest severity within
  `ALERT_HOT_TTL_S` (mirrors sloth's promotion-only semantics).
- Ring sizes match sloth's caps (`MAX_DNS_LOG`, `MAX_TLS_LOG`, etc.).
  Sizes documented in `Sources/SlothCore/RingSizes.swift`.

---

## M3 — Alerts view (three-tier palette) 🚨

**Goal**: First production view. Shows the alerts ring grouped by
severity, with cross-panel hot-IP coloring established for the rest
of the app to reuse.

**Touches**:
- `Sources/SlothCore/Theme.swift` — `Color` extensions:
  `phosphorTeal`, `phosphorAmber`, `alertHotLow` (yellow),
  `alertHotWarn` (orange), `alertHotCrit` (red).
- `App/Views/AlertsView.swift` — list with per-row severity stripe,
  count badge, last-seen relative time, match-IP rendered in alert
  hue. Sort: newest first. Filter chips: All / CRIT / WARN / LOW.
- `App/Views/AlertDetailView.swift` — Navigation destination per row;
  shows full detail, hits, first-seen / last-seen, key, and a "see
  in DNS log" or "see in connections" link when the match-IP matches
  a record in the store.
- `App/Charts/AlertFrequencyChart.swift` — small `BarMark` graph,
  alerts per minute over the last hour, stacked by severity. Visible
  at the top of `AlertsView`.
- `docs/views/alerts.md` — spec already drafted; tighten if needed.

**Acceptance**:
- The three-tier palette is visible: LOW yellow, WARN orange, CRIT red.
  Bold weight on WARN + CRIT, regular on LOW (mirrors sloth's
  `tui_alert_hot_attr`).
- The frequency chart updates as new alerts arrive.
- A match-IP that's hot in any panel renders in its severity hue
  everywhere it appears (preconditions: cross-panel rule wired
  through `AlertHotIndex`).
- `accessibilityReduceMotion` disables chart animation; colour cues
  are accompanied by SF Symbol prefixes (`exclamationmark.triangle`
  for WARN, `exclamationmark.octagon` for CRIT, `info.circle` for LOW)
  so colour-blind operators don't lose information.

---

## M4 — Top hosts + bandwidth sparklines 📈

**Goal**: First view with real graphs. Aggregates connection +
bandwidth data into a "who is this host actually talking to" list,
sorted by total throughput, with an inline tx/rx sparkline per row.

**Touches**:
- `Sources/SlothCore/TopHostsAggregator.swift` — derives top-N hosts
  from the store's `dns` cache + (eventually) `connections` ring.
  Mirrors `src/top_hosts.c` semantics: skip RFC1918, sort by
  `rxRate + txRate + connCount`, snapshot top 32.
- `App/Views/TopHostsView.swift` — list with: hostname (brand-coloured
  if Google / Cloudflare / etc.), owner, age, conn count, total tx/rx
  bytes, inline sparkline.
- `App/Charts/BandwidthSparkline.swift` — `Chart { AreaMark(...) }`
  with hidden axes. Heat-graded line by value (cool phosphor → red).
  Reusable in M6 too.
- `App/Views/TopHostDetailView.swift` — tap a row → host detail with
  a larger time-series chart, related DNS qnames, and the JA3
  fingerprints seen for that host.
- `docs/views/top-hosts.md` — spec.

**Acceptance**:
- Top hosts view stays smooth at 60fps with 32 rows + sparklines on
  an iPhone 12-class device.
- Sparklines visually match sloth's heat-graded TUI sparklines
  (cool → amber → orange → red).
- Brand colouring works (google = logo-colour letters,
  cloudflare = red, firefox = orange).

---

## M5 — DNS, TLS, HTTP logs 📜

**Goal**: Three list-style views with shared filtering scaffolding.
Each renders its ring as a chronological table, with one cross-cutting
filter bar.

**Touches**:
- `App/Views/DNSLogView.swift` — qname, qtype, answer, NXDOMAIN
  highlighting. Threat-hot qnames render in CRIT red.
- `App/Views/TLSLogView.swift` — SNI host, version (TLS 1.0/1.1 in
  WARN orange), 12-char JA3 prefix coloured by hash.
- `App/Views/HTTPLogView.swift` — Host, method, path. Attack-path
  matches render in CRIT.
- `App/Views/FilterBar.swift` — shared filter chip strip ("all / src
  / host / path") + search text field. Lives at the top of all three
  views.
- `App/Charts/QTypeDistribution.swift` — small `SectorMark` pie at
  the top of DNS log: A vs AAAA vs PTR vs other share over the
  visible window.
- `App/Charts/TLSVersionMix.swift` — stacked `BarMark` of TLS 1.3 vs
  1.2 vs older over the visible window. Surfaces downgrade attempts.
- `docs/views/{dns-log,tls-log,http-log}.md` — specs.

**Acceptance**:
- All three views scroll smoothly at the configured ring depths.
- Filter text matches across all per-record fields (sloth's
  `filter.c` semantics).
- The two charts give an at-a-glance "what kind of traffic is this"
  read in under three seconds.

---

## M6 — Connections view + RTT chart 🔗

**Goal**: Active TCP/UDP socket table with per-flow RTT history.

**Touches**:
- `Sources/SlothCore/ConnectionsAggregator.swift` — derives current
  connections from the store. (Depends on sloth emitting connection
  records in the JSONL stream — currently only ports / hosts are in
  there; this milestone surfaces a sloth-side gap if connections
  aren't in JSONL yet. File an issue back to sloth.)
- `App/Views/ConnectionsView.swift` — local → remote, proto, state,
  process, RTT, retx. Sort: bandwidth / state / RTT.
- `App/Charts/RTTSparkline.swift` — per-connection RTT over time.
- `docs/views/connections.md` — spec.

**Acceptance**:
- Connections list updates as sloth emits new connection records.
- RTT sparkline shows the last 30 samples.
- If sloth doesn't emit connection records yet, M6 may block on a
  sloth-side change. Document the gap in `PROGRESS.md` and pick M7
  while that lands.

---

## M7 — Composite dashboard (iPad-first) 🪟

**Goal**: A single view that tiles the alerts, top-hosts, DNS, and
TLS panels into a sloth-TUI-like dashboard. Targets iPad landscape
primarily; falls back to a paginated `TabView` on iPhone.

**Touches**:
- `App/Views/DashboardView.swift` — `Grid` / `LayoutThatFits` adaptive
  layout.
- `App/Views/DashboardCard.swift` — small reusable card wrapper used
  by every tile.
- Uses existing views from M3–M5; no new functional code beyond
  layout.
- `docs/views/dashboard.md` — spec.

**Acceptance**:
- Dashboard renders the four primary panels in one screen on iPad
  landscape (1024×1366 and larger).
- Pinch / drag is disabled; the layout is fixed (matches sloth's
  static composite).
- iPhone fallback: `TabView` with the same panels, ordered by
  importance (Alerts → Top hosts → DNS → TLS → Connections).
- A "system pulse" header chip shows: connection state pill,
  records-per-second counter, total-CRIT count, total-WARN count,
  total-LOW count.

---

## M8 — Polish, profiles, reconnect 🛠

**Goal**: Production-quality lifecycle: foreground/background reconnect,
multiple saved connection profiles, status pill on every screen,
diagnostic log accessible without a debugger.

**Touches**:
- `App/Views/SettingsView.swift` — list of saved profiles, add/edit/
  delete (in `UserDefaults`). Active profile selection.
- `Sources/SlothCore/ProfileStore.swift` — persistence layer.
- `Sources/SlothCore/Reconnector.swift` — exponential-backoff retry
  on disconnect, capped at 30s. Cancelled when the app backgrounds
  (per MISSION §2(4)).
- `App/Views/StatusPill.swift` — connection state indicator visible
  in every view's nav bar.
- `App/Views/DiagnosticsView.swift` — last 500 log lines from `OSLog`,
  exportable via system share sheet to text (not JSONL — never share
  the forensic records themselves, per MISSION §2(5)).

**Acceptance**:
- Killing the network on the phone surfaces a disconnect pill within
  ≤ 2s.
- Reopening the network surfaces the reconnect pill, then "connected"
  within ≤ 5s.
- Background → foreground re-establishes the connection.
- Diagnostics view shows recent logs but no record content.

---

## After M8

These aren't milestones; they're vectors the v1.x line might pursue.
Order by user demand:

- **macOS Catalyst pass** — most views should work; tighten layout.
- **Per-host pin / favourite** — pin a host to a "watch" set; that
  set gets its own top-of-screen band.
- **Snapshot export** — share a Swift Chart screenshot via the system
  share sheet (image only, never the underlying records).
- **iPadOS Stage Manager polish**.
- **Apple TV**? Probably not — out of scope per MISSION §2 (no
  surveillance dashboard for shared spaces).

---

## How to read this list

The numbering implies a sequence. Most milestones are linear
(M4 needs M2; M7 needs M3–M6). But:

- M5 and M6 are independent and can land in either order, or in
  parallel by different agents on different branches.
- M8 polish work can begin as soon as M2 is solid; it doesn't have
  to wait for M7.
- If a milestone hits an external blocker (M6 needs sloth-side
  connection records), file the gap in `PROGRESS.md` and switch to
  the next unblocked one.
