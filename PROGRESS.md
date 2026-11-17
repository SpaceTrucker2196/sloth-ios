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

## Landed

### 2026-11-17 — RF view: GNSS, ADS-B, APRS, rtl_433, Victron
**Commits**: this change
**Touched**: `Sources/SlothCore/{RFRecords,RFRoster,SlothRecord,SlothStore}.swift`; `App/Views/{RFView,DashboardView,DashboardGrid,DashboardPrimitives}.swift`, `App/ContentView.swift`; `docs/views/{rf,README}.md`; `tools/fake-producer.py`; `Tests/SlothCoreTests/RFRecordTests.swift`
**Why**: #14 RF slice. The sloth-rf stream (#15) now fills tables: `gnss_fix`, `adsb_aircraft` and `aprs_station` (a `gone` record removes the row), `rtl433_device` (id read as number or text; readings kept in their native unit), `victron_device` (incl. 2.1.0 AC values). New RF tab on iPhone; `AIRCRAFT | RF` band on the iPad dashboard drills into it. ADS-B emergencies sort first and paint crit.
**Verified**: `make test` exit 0 (258 core tests + app tests), zero warnings. iPhone 17 Pro sim, `-showRF` against both fake producers: GNSS, three aircraft (7700 first, red), two APRS stations, sub-GHz rows render. Victron row and the iPad band covered by tests only, not screenshotted.
**Follow-ups**: #14 still open for `gnss_sky`, `gnss_sat`, `aprs_packet`, `sys_status`, `source_status`, `sensor`, Wi-Fi extras and flow records.

### 2026-11-17 — Second stream for sloth-rf; refused-connect hint
**Commits**: this change
**Touched**: `Sources/SlothCore/{ConnectionHint,ProfileStore,SlothStore}.swift`; `App/ConnectionCoordinator.swift`, `App/Views/{SettingsView,SensorHealthStrip}.swift`; `tools/fake-producer.py` (`--rf`); `Tests/SlothCoreTests/RFStreamTests.swift`
**Why**: #15 — since sloth's #216 cutover (jsonl 2.0.0) GNSS / ADS-B / APRS / rtl_433 / Victron are only on sloth-rf's own socket. A profile now holds an optional RF endpoint; the coordinator runs a second connect loop into the same store with its own connection state, so one daemon down never reads as the other. A refused connect names the sensor-side `--data-socket tcp:… --data-socket-allow-remote` flags. Both loops now back off 1→30 s while failing (they reset before every attempt, so the delay never grew).
**Verified**: `make test` exit 0 (249 core tests + app tests), zero warnings. iPhone 17 Pro sim with two fake producers: Diagnostics shows `RF jsonl 2.3.0` and "RF stream live"; with the RF port closed it shows the refused hint and retries at 1, 2, 4 s.
**Follow-ups**: RF record types still decode to `.unknown` (#14). Profile edits apply on the next Connect, not live.

### 2026-11-17 — Alert lifecycle, sensor health, live alert decode
**Commits**: this change
**Touched**: `Sources/SlothCore/{HealthRecords,SlothRecord,SlothStore}.swift`; `App/Views/{SensorHealthStrip,AlertRowView,AlertsView,DiagnosticsView}.swift`, `App/ContentView.swift`; `tools/fake-producer.py`; `Tests/SlothCoreTests/HealthRecordTests.swift`
**Why**: #16 — sloth's `alert` record carries no `first_seen` / `last_seen`, so every live alert failed to decode and `try?` dropped it. #14 first slice — `alert.create/update/escalate/resolve`, `sensor_health` (per daemon, `jsonl_version`) and `socket_gap` decode and reach the store; escalations now change the shown severity; resolved rows dim with a RESOLVED label; Diagnostics shows the sensor's self-report. A known type that fails to decode is now `.malformed` and counted, not dropped.
**Verified**: `make test` exit 0 (242 core tests + app tests), zero warnings. iPhone 17 Pro sim against the updated fake producer: alert chip shows 3 CRIT / 1 WARN; Diagnostics shows `WIFI jsonl 2.3.0`, the stopped monitor radio and the missing RF stream. Alerts-tab RESOLVED row covered by tests only, not screenshotted.
**Follow-ups**: #14 remaining types (Wi-Fi extras, flows, RF stream records); #15 second endpoint for `sloth-rf`.

### 2026-11-13 — iOS sensor post + fleet radar (producer role)
**Commits**: this change (feat: iOS sensor post + fleet radar)
**Touched**: `Sources/SlothCore/{SensorRecord,SensorBuffer,PostIdentity,PostService,PostClient,FleetStore,FleetRadar}.swift`, `SlothDiscovery.swift`; `App/Sensors/*`; `App/Views/{RadarView,PostView}.swift`; `App/{ContentView,SlothIOSApp}.swift`; `project.yml`, `App/Info.plist`; `MISSION.md`, `AGENTS.md`; `docs/wiki/post-protocol.md`, `docs/views/{radar,post}.md`; `Tests/SlothCoreTests/*`
**Why**: Jeff asked for sloth-ios to also *be* a sloth client — a SIGINT post streaming its radios/sensors — plus a fleet Radar view, with sloth auto-discovering iOS posts. Implemented as the inverse of sloth's data socket: the device serves its own read-only JSONL stream and advertises `_sloth-post._tcp.`; a hub discovers and pulls it. MISSION §1/§2 rewritten for the producer role (still one-way, passive, in-memory, foreground-only).
**Verified**: `swift test` 214/214 green; iPhone 17 Pro simulator build clean (exit 0), new files warning-free.
**Follow-ups**: sloth C-side discovery/consume ([sloth #205](https://github.com/SpaceTrucker2196/sloth/issues/205)); "Access WiFi Information" entitlement for `wifi_self`; real private-radio scan behind `PrivateRadioProbe` (needs jailbreak / Apple-internal signing); on-device render-check of Radar + Post. Tracker: [sloth-ios #13](https://github.com/SpaceTrucker2196/sloth-ios/issues/13).

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
