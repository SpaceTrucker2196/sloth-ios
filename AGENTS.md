# sloth-ios — agent instructions

Repo-local rules for any coding agent (Claude Code, Copilot, Codex).
Build/infra runbook lives in `FACTORY.md`; charter in `MISSION.md`;
roadmap in `docs/milestones.md`.

## What sloth-ios is

An iOS / iPadOS dashboard and passive sensor post for the
[sloth](https://github.com/SpaceTrucker2196/sloth) passive network
monitor. Connects over a Tailscale tailnet to sloth's read-only JSONL
data socket and renders the same panels sloth shows in its terminal
UI — in SwiftUI, with Swift Charts graphs.

As a **post** it also serves its own read-only stream of what the
device's radios and sensors hear (BLE advertisers, magnetometer,
joined WiFi, coarse GPS), advertised over Bonjour as
`_sloth-post._tcp.`. A sloth instance or another sloth-ios discovers
the post and reads it the same way this app reads sloth. The Radar
view shows the whole fleet. Both roles are one-way and passive — see
`MISSION.md` §2. Producer code lives in `Sources/SlothCore`
(`SensorRecord`, `SensorBuffer`, `PostService`, `PostClient`,
`FleetStore`, `FleetRadar`, `PostIdentity`) and `App/Sensors/`.

## Architecture

- `Sources/SlothCore/` — headless Swift package. Networking, models,
  state store. Builds + tests with `swift build` / `swift test` on any
  platform with a Swift toolchain. No UIKit / no SwiftUI in this layer.
- `App/` — SwiftUI iOS app. Imports `SlothCore`. Generated into an
  `.xcodeproj` from `project.yml` via `xcodegen`.
- `Tests/SlothCoreTests/` — unit tests for the core. Hermetic; no
  network, no filesystem.
- `docs/views/<name>.md` — per-view UI specs (data, layout, graphs,
  interactions).
- `docs/wiki/` — concept pages (theme, jsonl protocol consumer side,
  tailscale setup, architecture).

## Discipline

- **Tests must pass.** `swift test` returns 0. `make test` returns 0
  (wraps `swift test` + Xcode unit tests once the app target exists).
  Never commit a red test.
- **Builds must be warning-clean.** `swift build` and `xcodebuild
  build` both produce zero warnings. `-warnings-as-errors` is on.
- **Strict concurrency.** `Sources/SlothCore` uses
  `-strict-concurrency=complete`. No `nonisolated(unsafe)`. Cross-actor
  state is `Sendable` or doesn't cross.
- **No third-party UI / networking dependencies** unless an SPM package
  is added with an explicit MISSION.md §2 audit. Apple frameworks only
  by default: SwiftUI, Swift Charts, Network, Foundation, Combine,
  Observation.
- **No mocks of real-data interfaces in production code.** Fakes belong
  in `Tests/`. `SlothClient` is configurable so tests can substitute a
  fake socket transport.

## Conventions

- **Commit messages.** Imperative subject line, blank line, optional
  body explaining the *why*. End with the `Co-Authored-By` trailer if
  an agent landed the change.
- **Branches.** Work on `main`. No long-running feature branches.
- **Pushes.** Push after each green commit. The user reviews on GitHub.
- **`git add` specific files.** **Never** `git add -A` or `git add .`.
  Generated artefacts (`*.xcodeproj`, `DerivedData/`, `.build/`,
  `*.xcuserdata`, `*.dSYM/`, `.DS_Store`) must never be staged.

## SwiftUI conventions

- **Views are small.** A `View` body over ~60 lines wants a child view.
  Extract aggressively.
- **State lives in `SlothStore`.** Views observe; views don't own data.
  The store is the single source of truth for everything off the wire.
- **No `@StateObject` for cross-view state.** That's `@Environment` /
  `@EnvironmentObject` / the store. `@StateObject` is for view-local
  controllers only.
- **Theme via `Color` extensions.** The Fallout phosphor palette
  (`phosphorTeal`, `phosphorAmber`, `alertHotLow/Warn/Crit`) is defined
  in `Sources/SlothCore/Theme.swift`. Views import it; they don't
  hardcode hex.
- **Cross-panel hot-IP coloring.** When an IP appears in an alert,
  every view rendering that IP paints it in the alert's severity hue
  (mirrors sloth's `tui_alert_hot_*`). Mechanism: `AlertHotIndex` in
  `SlothCore`; views look up sev and pick the `Color`.
- **Severity hues match sloth's TUI:** LOW → `alertHotLow` (yellow),
  WARN → `alertHotWarn` (orange), CRIT → `alertHotCrit` (red).
- **Bold on WARN + CRIT.** LOW does not bold. Mirrors the TUI rule.
- **Reduced-motion respect.** Sparklines animate by default;
  `accessibilityReduceMotion` disables the animation. Never disable
  color cues for accessibility — replace hue with shape (icon prefix)
  instead.

## Charts conventions

- Use **Swift Charts** (iOS 16+). No alternative chart libraries.
- Sparklines are `Chart { LineMark(...) }` with axes hidden and domain
  clamped to the panel's time window.
- Heat-grade lines by value the way sloth's `tui_heat` does — cool
  phosphor for idle, amber → orange → red toward the panel's max.
- Charts always have an a11y label describing the trend ("Bandwidth to
  dns.google over the last 60 seconds, peak 1.2 megabytes per second").

## Hard "don't"s

- Don't run destructive git ops (`reset --hard`, `push --force`, branch
  delete) without explicit user authorisation.
- Don't add new files at repo root — everything has a home.
- Don't commit `*.xcodeproj` (generated by xcodegen), `DerivedData/`,
  `.build/`, `*.xcuserdata`, `*.dSYM/`, or `.DS_Store`.
- Don't bypass git hooks (`--no-verify`) unless explicitly asked.
- Don't add a feature that crosses any rule in `MISSION.md` §2.
  Particularly: no push notifications, no "clear alerts" button, no
  persisting forensic records.
- Don't pull in a third-party dependency without an explicit MISSION
  audit recorded in `PROGRESS.md`.

## How to add a view

1. Add a per-view spec to `docs/views/<name>.md` (template in
   `docs/views/README.md`). Describe data sources (record types from
   the [JSONL schema][schema]), layout, graphs, interactions.
2. Add `App/Views/<Name>View.swift`. Body under ~60 lines; extract
   children as needed.
3. Wire it into the top-level navigation in `App/ContentView.swift`
   (or whichever container view owns the navigation root).
4. Add a `Tests/SlothCoreTests/<Name>StateTests.swift` if the view has
   non-trivial filter / sort / selection state. Hermetic — feed the
   store from a fixture, assert.
5. `swift test` clean + a manual run in the simulator before
   committing.

[schema]: https://github.com/SpaceTrucker2196/sloth/blob/main/docs/wiki/jsonl-schema.md

## How to add a record type to consume

If sloth adds a new JSONL `type` (e.g. `{"type":"smb",...}`):

1. Add a case to `SlothRecord` in `Sources/SlothCore/SlothRecord.swift`.
2. Decode in `SlothClient.parseLine` and dispatch to the store.
3. Add a ring in `SlothStore` if the records aren't going through an
   existing one.
4. Update or create the consuming view.
5. Test: feed a canned JSONL line into the fake transport, assert the
   store sees it.
6. Reference: the sloth-side schema page at
   `sloth/docs/wiki/jsonl-schema.md`.

## Style

- Terse, technical, no marketing language in code or docs.
- Comments explain *why*, never *what* (the code shows what).
- Swift naming follows Apple's API design guidelines. Types are
  upper-camel; values and methods are lower-camel.
- Avoid `Any`. Avoid stringly-typed dispatch. The JSONL record types
  are a sum type (`enum SlothRecord`) discriminated by `type`.
- Errors at boundaries only (network I/O, JSON parsing). Trust internal
  code.

## When you don't know

- Read the per-view spec for the view you're touching.
- Read the JSONL schema in the sloth repo for the record contract.
- Read the existing Swift in `Sources/SlothCore` for the established
  patterns.
- If a sloth schema field is missing or unclear, that's a *sloth* bug —
  file it there, not here.

## User context

User: Jeff Kunzelman (`SpaceTrucker2196` on GitHub). Operates the
companion sloth repo on the same Mac. Primary deployment path is
Tailscale → sloth instance → this iOS app.

## Token / Cost Ledger

The owner bills from `LEDGER.md` (exact, never estimated). After every
substantive commit: run `~/.claude/billing/ledger.py --append --summary
"<desc>"`, then commit `LEDGER.md` as its own `chore(ledger): <sha>`
commit. Never hand-author, estimate, or rewrite rows (append-only); if
the script can't produce a row, stop and surface it. See
`ledger.py --help` for flags (`--dry-run`, `--commit <sha>`).

Energy (optional, read-only): `~/.claude/billing/ledger.py --energy-total` estimates the rough datacenter kWh behind the whole ledger; `--energy` adds a per-row estimate. Order-of-magnitude only.
