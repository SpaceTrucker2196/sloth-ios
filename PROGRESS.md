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

*(nothing yet — repo is at pre-M1)*

---

## Recently landed

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
