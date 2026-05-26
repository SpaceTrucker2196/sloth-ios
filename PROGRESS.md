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

*(nothing — M2 just landed; pick M3 (AlertsView) or M5 (DNS/TLS/HTTP logs) next)*

---

## Recently landed

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
