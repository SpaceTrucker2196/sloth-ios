# Wiki log

Append-only record of wiki operations. Newest entries at the bottom.

---

## 2026-05-26 — Initial wiki

**Source**: scaffolded along with the rest of the repo.

**Created pages**:

- [index.md](index.md) — table of contents.
- [architecture.md](architecture.md) — module / file layout.
- [jsonl-protocol.md](jsonl-protocol.md) — consumer-side wire format
  reference; points back to the canonical schema in the sloth repo.
- [theme.md](theme.md) — Fallout phosphor palette as SwiftUI `Color`.
- [tailscale-setup.md](tailscale-setup.md) — operator deployment
  recipe.

**Notes**:

- Per-view UI specs live in `docs/views/`; the wiki is concepts only.
- Source-of-truth for the JSONL schema is
  [`sloth/docs/wiki/jsonl-schema.md`](https://github.com/SpaceTrucker2196/sloth/blob/main/docs/wiki/jsonl-schema.md);
  the consumer-side page here is a lightweight reference + Swift
  decoding sketch.
