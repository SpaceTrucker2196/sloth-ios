# The dark-factory pattern (consumer side)

This repo operates under the same pattern as
[sloth](https://github.com/SpaceTrucker2196/sloth) —
**Level 5 agent autonomy** within the bounds of
[`MISSION.md`](../MISSION.md) §2. The pattern itself is described in
detail in the companion repo:

→ [`sloth/docs/dark-factory.md`](https://github.com/SpaceTrucker2196/sloth/blob/main/docs/dark-factory.md)

Read it once; this page is the sloth-ios adaptation, not a
duplicate.

---

## What's the same

- **Mission is in-tree** as `MISSION.md`. The agent applies the
  §2 rules unilaterally — they're not negotiable per feature.
- **Working rules** are in `CLAUDE.md`. The agent uses them to make
  code-level decisions without asking.
- **Cold start works.** A fresh clone, a fresh machine, an agent
  that has never seen the project — should be able to run
  `swift test && xcodegen generate && xcodebuild build` and be
  productive.
- **Append-only history.** Branches are short; pushes happen after
  green commits; the human reviews on GitHub.
- **PROGRESS.md tracks who's doing what**, even (especially) when
  the "who" is a non-deterministic agent.

## What's different from sloth

| Dimension      | sloth                          | sloth-ios |
|----------------|--------------------------------|-----------|
| Language       | C99                            | Swift 5.9+ |
| Test driver    | `make test`                    | `swift test` + `xcodebuild test` |
| Build artefact | one binary                     | one iOS app bundle + headless SPM module |
| Distribution   | self-built / `make install`    | personal-team or TestFlight (out-of-scope for v1) |
| Network role   | **observer** (reads pcap)      | **consumer** (reads sloth's JSONL stream) |
| Test fakes     | `fake_platform.c`              | `FakeTransport.swift` |

The networking-role flip matters: sloth is constrained never to
*write* to the network it monitors. sloth-ios is constrained never
to *write* to sloth. The rule is the same shape ("read-only"), the
boundary is a different layer.

## When to decide vs escalate

- **Code-level decisions** (file layout, names, refactor, view
  composition): agent decides.
- **Anything that changes `MISSION.md` §2**: stop and ask the user.
- **Anything that breaks the JSONL contract** sloth emits: this is
  a sloth-side problem; file it in the sloth repo, not here.
- **Anything that touches the user's machine outside the repo**
  (Tailscale config, code signing, certificate provisioning): ask.

When uncertain, write the proposed approach as an entry in the
**In progress** section of `PROGRESS.md` with the next concrete
step. The user reviews and either greenlights or redirects.
