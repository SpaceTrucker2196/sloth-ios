# sloth-ios

A read-only iOS / iPadOS dashboard for [sloth](https://github.com/SpaceTrucker2196/sloth),
the passive network monitor. Subscribes to a sloth instance's JSONL
data socket over a Tailscale tailnet and renders the same panels
sloth shows in its terminal UI — built in SwiftUI, with Swift Charts
graphs for bandwidth, alert frequency, DNS qtype distribution, and
JA3 fingerprint tallies.

```
┌────────────────────────────────────────┐
│ sloth-ios                              │
│                                        │
│  📡  192.168.1.50  ●  TLS 1.3          │
│                                        │
│  ┌─ Critical alerts ──── 2 ─────────┐  │
│  │ THREAT_DOMAIN  malware.testing.. │  │
│  │ THREAT_IP      192.0.2.66:443    │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌─ Top hosts ────────────── 1m ────┐  │
│  │ dns.google     ▂▃▅▆▇ 1.2MB/s    │  │
│  │ *.cloudflare   ▁▂▃▄▅   240KB/s  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  [Alerts] [DNS] [TLS] [Top] [Conns]   │
└────────────────────────────────────────┘
```

## Status

Pre-M1. Repo scaffolding only. See [`docs/milestones.md`](docs/milestones.md)
for the roadmap.

## Cold start (for agents and humans)

1. Read [`MISSION.md`](MISSION.md) — the non-negotiable charter.
2. Read [`CLAUDE.md`](CLAUDE.md) — working rules and Swift conventions.
3. Read [`FACTORY.md`](FACTORY.md) — what to install, how to build, how to test.
4. Read [`docs/milestones.md`](docs/milestones.md) — pick the next open milestone.
5. Skim [`PROGRESS.md`](PROGRESS.md) — what's in flight, what just landed.

## Relationship to the sloth repo

sloth-ios is a **consumer** of the JSONL stream sloth emits. The
contract is documented at
[`sloth/docs/wiki/jsonl-schema.md`](https://github.com/SpaceTrucker2196/sloth/blob/main/docs/wiki/jsonl-schema.md).
Changes to that schema land in the sloth repo first; this repo
follows.

## Hard rules (mirror of sloth's MISSION §2)

- **Read-only.** This app never writes to a network. It never sends
  packets, never triggers captures on the sloth server, never clears
  alerts, never configures anything.
- **Tailnet-only by default.** No public endpoints. The user supplies
  the bind address of their sloth instance (typically a Tailscale
  100.x.x.x IP).
- **No telemetry.** No analytics, no crash reporters that phone home,
  no remote config.

If you're building a feature and it requires the app to *send*
something to *anything*, stop and read MISSION.md §2 again.

## License

See repo root (will follow sloth's license once chosen).
