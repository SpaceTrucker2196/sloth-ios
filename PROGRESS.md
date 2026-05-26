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

*(nothing — M1 just landed; pick M2 next)*

---

## Recently landed

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
