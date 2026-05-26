# sloth-ios — Mission

This file is the standing charter for the agent (human or LLM)
operating this repo. Read it before you write a line of code. It
tells you *why* sloth-ios exists, *what it must never become*, and
*where to go next*.

This repo is run as a **dark factory** — Level 5 agent autonomy. The
agent writes the code, writes the tests, runs the review. The human
is the customer and final acceptance reviewer. See
[`docs/dark-factory.md`](docs/dark-factory.md) for the pattern.

Operating rules live in [`CLAUDE.md`](CLAUDE.md). Per-view UI specs
live in [`docs/views/`](docs/views/). The roadmap lives in
[`docs/milestones.md`](docs/milestones.md). This file is the mission,
not the manual.

---

## 1. Mission

sloth-ios is a **read-only mobile dashboard** for the passive network
monitor [sloth](https://github.com/SpaceTrucker2196/sloth). It
connects over a Tailscale tailnet to a sloth instance's read-only
JSONL data socket and renders the same panels sloth shows in its
terminal UI — alerts, top hosts, DNS / TLS / HTTP logs, connections,
devices — as native SwiftUI views with Swift Charts graphs.

The goal is not to control sloth from a phone. The goal is to *see*
what sloth sees, with a phone-shaped UX, from anywhere on the
tailnet.

If a single sentence has to survive: **sloth-ios is a window, not a
keyboard.**

---

## 2. Rules of engagement (non-negotiable)

These rules mirror sloth's MISSION §2 and adapt them to the mobile
client. They are not preferences. If a proposed change violates any
of them, the change does not land — find another way or close the
issue.

1. **Read-only over the wire.** The app never sends data to a sloth
   instance. The TCP / UNIX-domain socket on the server is one-way
   by contract; this client must respect that. No "clear alerts" RPC.
   No "trigger capture" RPC. No write-back. The only TCP traffic the
   app initiates is the initial `connect()` — after that, the socket
   is read-only.

2. **No telemetry.** No analytics SDKs (Firebase, Mixpanel, Sentry,
   etc.). No crash reporters that phone home. No remote config. No
   feature flags fetched from a server. The app's network surface is
   exactly one endpoint: the user's sloth instance.

3. **Tailnet-only by default.** Connection profiles default to
   reachability over Tailscale (100.64.0.0/10). The app does not
   open ports, does not run a Bonjour responder, does not advertise
   itself. The user supplies the bind address of their sloth
   instance.

4. **No background network access.** When the app is backgrounded,
   the socket is closed. iOS will reap it anyway when the app is
   suspended; this rule just makes the intent explicit. Reconnect
   happens on foregrounding.

5. **No persistence of forensic data.** The JSONL records sloth emits
   describe other people's network activity. Caching that on the
   phone creates a data-retention problem. The store is purely
   in-memory; closing the app discards it. Connection profiles
   (host:port) MAY be persisted in `UserDefaults`; nothing else.

6. **Operator owns the consequences.** sloth-ios shows information.
   What the operator does with that information — file an incident,
   reconfigure an AP, walk away — is outside the app's scope. The
   app does not nudge, recommend, or remediate.

If you are tempted to add a feature because it would be useful —
push-notifications-on-CRIT, "clear alerts" button, sharing a chart to
iMessage — stop. Either the feature violates a rule above (push
needs a server; sharing leaks forensic data) or it belongs to a
different tool.

---

## 3. Where the project is right now

**Pre-M1.** The repository is scaffolding only: dark-factory spec
files, milestone roadmap, per-view UI specs, project skeleton.
No working app yet. The agent's first concrete task is M1 — see
[`docs/milestones.md`](docs/milestones.md).

Platforms: iOS 17+ and iPadOS 17+ as the deployment target.
macOS Catalyst is in scope as a stretch goal but not a constraint
on M1–M7. visionOS, watchOS, tvOS are explicitly out of scope.

Language: Swift 5.9+ with strict concurrency. SwiftUI for all UI.
Swift Charts for graphs (built-in iOS 16+, so available).
Network.framework for the JSONL stream (no third-party networking).

---

## 4. Direction

In rough priority order — not a sprint plan, a sense of where the
gravity is:

1. **Fidelity to the sloth TUI.** When a user has both sloth (in a
   terminal) and sloth-ios (on a phone) open at the same time, the
   data should match record-for-record within the poll-cadence
   window. Mismatches are bugs.

2. **Read-only contract first.** Every networking change must
   reaffirm rule §2(1). When in doubt, the answer is "we don't send
   that."

3. **Graphs that actually inform.** Don't add a Swift Chart because
   it's pretty. Add it where the eye reads a sparkline faster than
   it reads a number — bandwidth over time, alert frequency,
   distribution of DNS qtypes, JA3 cluster sizes. Decorative charts
   are a smell.

4. **Operator ergonomics.** The dashboard exists to answer "is
   anything on fire?" in two seconds. The CRIT-alerts band lands at
   the top of the screen on every entry path. Cross-panel hot-IP
   coloring follows the same severity tier the TUI uses (yellow →
   orange → red).

5. **Test discipline.** Headless `SlothCore` SPM module is fully
   unit-tested via `swift test`. View logic (selection state,
   filtering, sort) is testable via SwiftUI snapshot or
   `ViewInspector` (TBD per milestone). Networking has a fake socket
   for hermetic tests.

What is **out of scope**, regardless of how interesting:

- Push notifications for any alert level (requires a server).
- Local notifications driven by the in-app stream (battery cost,
  retention concerns; defer to user discretion).
- Background fetch (rule §2(4)).
- Sharing forensic records via iMessage / Mail / AirDrop (rule §2(5)).
- A "clear alerts" button (rule §2(1)).
- A "trigger pcap export" button (rule §2(1)).
- Custom JSONL field injection — the schema is sloth's contract; we
  only consume.
- macOS Catalyst polish before M7 ships.

---

## 5. How to operate the repo (cold start)

The expectation is that you can resume from zero: a fresh clone, no
memory of prior conversations, no tribal knowledge. If something is
needed and not in-tree, that's a defect — fix it as part of your
work.

1. Read [`CLAUDE.md`](CLAUDE.md) — operating manual: Swift
   conventions, SwiftUI rules, build discipline, hard don'ts.
2. Read [`docs/dark-factory.md`](docs/dark-factory.md) once, so you
   know the autonomy contract you're operating under.
3. Run `make test` (or `swift test` for just the core). Both must be
   green before you change a line. If either is red on `main`, fix
   that first.
4. Read [`docs/views/README.md`](docs/views/README.md) for the
   per-view spec template, then skim the views relevant to the
   milestone you're picking up.
5. Look at recent commits (`git log --oneline -30`) to see cadence
   and the *kind* of change that lands here.
6. Pick the next thing from [`docs/milestones.md`](docs/milestones.md)
   or from open issues. Land it as one commit per logical change,
   imperative subject, body explaining *why*, `Co-Authored-By`
   trailer.

When you are unsure whether a feature is in scope, apply the test
from §2: **does this change require the app to send anything to
anything, or to retain forensic data across launches?** If yes, it's
out. If no, it's worth considering on the merits.

---

## 6. The one-line summary you can quote

> sloth-ios is a read-only mobile window onto a passive network
> monitor: it watches, it never speaks.

Anything you build on top of this codebase must still be describable
by that sentence. If it isn't, you've built a different app — fork
it and give it a different name.
