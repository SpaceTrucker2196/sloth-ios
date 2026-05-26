# Wiki index

Concept-oriented knowledge base for sloth-ios. Per-view UI specs
live in [`../views/`](../views/) — those are the source of truth for
"what does each screen do?". The wiki is the source of truth for
cross-cutting concepts: theme, networking protocol, architecture,
deployment.

## Start here

- [architecture.md](architecture.md) — module layout (`SlothCore` /
  `App`) and the seams between them.
- [jsonl-protocol.md](jsonl-protocol.md) — wire format from the
  consumer's perspective (the schema definition lives in the sloth
  repo).
- [theme.md](theme.md) — Fallout phosphor palette translated to
  SwiftUI `Color`.
- [tailscale-setup.md](tailscale-setup.md) — how to deploy
  sloth-server + sloth-ios on a tailnet.

## Maintenance

- [log.md](log.md) — append-only record of wiki operations.
- Page names: lowercase with hyphens.
- Cross-link concepts with `[[wiki-link]]` or relative paths.
