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

*(nothing — local-network discovery (Bonjour) just landed dark; v1.0 + first v1.x polish are out.)*

**Dark-on-producer features** awaiting sloth-side work:
- **Connections view (M6)** — populates when sloth emits
  `{"type":"connections", …}` JSONL lines
  ([sloth #5](https://github.com/SpaceTrucker2196/sloth/issues/5)).
- **Local-network discovery** — populates when sloth publishes
  `_sloth._tcp.` via Bonjour (no upstream issue yet; see
  [`docs/wiki/discovery.md`](docs/wiki/discovery.md) for the
  expected contract).

---

## Current state (2026-07-05)

- Read-only SwiftUI dashboard for sloth's JSONL data socket; all v1.0
  milestones (M1-M8) shipped on the consumer side.
- `swift test` 193/193 green; iPad Pro 13-inch (M5) + iPhone 17 Pro
  simulator builds warning-clean.
- iPad dashboard is the Tufte band layout (2026-07-04), superseding the
  M7 tile grid; band titles drill into the full views; ICMPLogView
  closed the last non-navigable panel.
- Launch auto-connects the saved active profile; named profiles +
  exponential-backoff reconnect (M8); Bonjour discovery UI shipped dark
  and lights up when sloth #29 (mDNS publish) closes.
- Ring caps cross-checked against sloth's canonical `include/sloth.h`
  constants (2026-07-05); the `connections` ring intentionally stays
  larger (flow history for RTT sparklines).
- `tools/fake-producer.py` is checked in for repeatable render checks
  without a live sloth.
- Upstream sloth #5 (connection records) is closed — the M6 Flows band
  should populate against a current sloth build; an end-to-end run over
  the tailnet is still pending.

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

---

Completed-phase history: see docs/progress-archive.md (append-only).
