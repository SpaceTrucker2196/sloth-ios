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

sloth-ios is a **mobile dashboard and sensor post** for the passive
network monitor [sloth](https://github.com/SpaceTrucker2196/sloth). It
has two roles, both passive:

1. **Window (consumer).** It connects over a Tailscale tailnet to a
   sloth instance's read-only JSONL data socket and renders the same
   panels sloth shows in its terminal UI — alerts, top hosts, DNS /
   TLS / HTTP logs, connections, devices — as native SwiftUI views
   with Swift Charts graphs.

2. **Post (producer).** It can serve its *own* read-only stream of the
   signals the device's radios and sensors hear — Bluetooth LE
   advertisers, compass and magnetometer, the joined WiFi network,
   coarse position — and advertise itself over Bonjour as
   `_sloth-post._tcp.`. A fleet hub (a sloth instance, or another
   sloth-ios) discovers the post and reads it, exactly like it reads
   any other sloth stream. The Radar view shows the whole fleet's
   contacts at once.

Both roles are one-way. As a window, sloth-ios never commands sloth.
As a post, sloth-ios never accepts commands from a hub — it only
serves. The stream direction flips; the read-only contract does not.

If a single sentence has to survive: **sloth-ios is a window and a
sensor, never a keyboard.**

---

## 2. Rules of engagement (non-negotiable)

These rules mirror sloth's MISSION §2 and adapt them to the mobile
client. They are not preferences. If a proposed change violates any
of them, the change does not land — find another way or close the
issue.

1. **One-way, no verbs — both directions.** As a window, the app
   never writes to a sloth instance: no "clear alerts" RPC, no
   "trigger capture" RPC, no write-back. As a post, the app serves a
   read-only stream and never reads a byte a hub sends: no inbound
   commands, no config pulls, no handshake. Each socket carries
   records in one direction only, the same contract sloth's own data
   socket holds.

2. **Passive sensors only.** The post observes; it never transmits on
   any radio, never pairs, never associates, never probes, never
   injects. BLE is scan-only. The one carve-out any producer may rely
   on is reading the device's own sensors (compass, magnetometer,
   joined-network identity, coarse GPS). A capability that would make
   the device act on a signal, rather than report hearing it, does
   not land.

3. **No telemetry.** No analytics SDKs (Firebase, Mixpanel, Sentry,
   etc.). No crash reporters that phone home. No remote config, no
   feature flags fetched from a server. Sensor records go only to a
   hub the operator runs on their own tailnet — never to any
   Anthropic, Apple-adjacent, or third-party endpoint.

4. **Tailnet-local only.** The window connects to a sloth endpoint the
   operator supplies, reachable over Tailscale (100.64.0.0/10) or the
   LAN. The post advertises `_sloth-post._tcp.` and listens, but only
   on the local link / tailnet, only while in the foreground, and
   only after the operator turns it on. Serving is opt-in and off by
   default. Access control is the operator's (bind scope, Tailscale
   ACLs) — the stream carries no auth of its own, same as sloth's.

5. **No background radios.** When the app is backgrounded, every
   socket closes and every sensor stops — the consumer stream, the
   post's listener, the BLE scan, motion and location. iOS reaps them
   anyway; this rule makes the intent explicit. They restart on
   foregrounding.

6. **No persistence of observations.** The records on either side
   describe real devices and people around the operator. Caching them
   creates a retention problem. Both the consumer store and the post
   buffer are purely in-memory; closing the app discards them.
   Connection profiles and the post's own identity (a random UUID +
   name) MAY be persisted in `UserDefaults`; no record content, ever.

7. **Operator owns the consequences.** sloth-ios shows and reports
   information. What the operator does with it — file an incident,
   reconfigure an AP, walk away — is outside the app's scope. The app
   does not nudge, recommend, or remediate.

If you are tempted to add a feature because it would be useful —
push-notifications-on-CRIT, a "clear alerts" button, a BLE connect to
read a characteristic, writing captures to disk — stop. Either it
breaks a rule above (push needs a server; connecting is not passive;
disk is retention) or it belongs to a different tool.

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
