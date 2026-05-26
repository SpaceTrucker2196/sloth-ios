# FACTORY.md — Build & Infrastructure Runbook

Operating manual for an agent (or human) bringing sloth-ios up from a
cold clone. Charter in [`MISSION.md`](MISSION.md); pattern in
[`docs/dark-factory.md`](docs/dark-factory.md); working rules in
[`CLAUDE.md`](CLAUDE.md); per-view UI specs in
[`docs/views/`](docs/views/); roadmap in
[`docs/milestones.md`](docs/milestones.md).

This file answers one question: *what do I need to install, build,
test, and ship the app?*

---

## 0. TL;DR

```sh
# macOS, recent Xcode installed (15.0+ for iOS 17 SDK)
git clone https://github.com/SpaceTrucker2196/sloth-ios.git
cd sloth-ios

# 1. Headless core — pure Swift, runs anywhere with a toolchain
swift test                        # must be green

# 2. iOS app — generate the Xcode project from spec, then build
xcodegen generate                 # produces SlothIOS.xcodeproj
xcodebuild -scheme SlothIOS -destination 'platform=iOS Simulator,name=iPhone 15' build
```

If `swift test` is green and `xcodebuild` exits 0 with no warnings,
the factory is operational.

---

## 1. Supported platforms

| Target            | Deployment | Status |
|-------------------|------------|--------|
| iOS               | 17.0+      | primary |
| iPadOS            | 17.0+      | primary (composite dashboard targets this) |
| macOS (Catalyst)  | 14.0+      | stretch, post-M7 |
| visionOS / watchOS / tvOS | —  | out of scope |

The primary form factor is iPhone portrait. iPad landscape gets the
composite dashboard view (M7); split-view multi-tasking is supported.

---

## 2. Toolchain

| Tool       | Minimum   | Why |
|------------|-----------|-----|
| Xcode      | 15.0      | iOS 17 SDK, Swift 5.9, Swift Charts iOS-16-API |
| Swift      | 5.9       | strict concurrency, `Observation` framework |
| xcodegen   | 2.39+     | regenerates `SlothIOS.xcodeproj` from `project.yml` |
| `gh` (cli) | optional  | landing PRs, viewing CI |

`xcodegen` is required because the `.xcodeproj` is **not** checked
in (binary-ish XML merges horribly). The authoritative project spec
is `project.yml`. Regenerate the project after any structural change.

### Install

```sh
# Homebrew on macOS
brew install xcodegen swift-format

# Xcode from the App Store (or developer.apple.com for beta)
xcode-select --install
```

---

## 3. Runtime dependencies

**None outside Apple frameworks.** The app uses:

- SwiftUI (UI)
- Swift Charts (graphs)
- Network.framework (TCP / UNIX-domain sockets)
- Foundation, Combine, Observation
- OSLog (logging — local only, no network egress)

No third-party SPM dependencies by default. If one becomes necessary,
it lands with an explicit MISSION §2 audit recorded in `PROGRESS.md`.

---

## 4. Build matrix

| Command                                        | What you get |
|------------------------------------------------|--------------|
| `swift build`                                  | builds `SlothCore` headless module |
| `swift test`                                   | runs unit tests against `SlothCore` |
| `xcodegen generate`                            | regenerates `SlothIOS.xcodeproj` |
| `xcodebuild -scheme SlothIOS build`            | builds the iOS app |
| `xcodebuild test -scheme SlothIOS …`           | runs the Xcode unit / UI tests |
| `make`                                         | shorthand: regen + build + test |
| `make test`                                    | `swift test` + Xcode unit tests |
| `make clean`                                   | removes `.build/`, `DerivedData/`, generated `.xcodeproj` |

**Hard rules** (from [`CLAUDE.md`](CLAUDE.md)):

- `swift test` must return 0. Never commit a red test.
- `swift build` and `xcodebuild` are **warning-clean**. Treat any new
  warning as a failed build.
- Generated artefacts are never staged: `*.xcodeproj`, `.build/`,
  `DerivedData/`, `*.xcuserdata`, `*.dSYM/`, `.DS_Store`.

---

## 5. Test discipline

- `SlothCore` tests run via `swift test`. Hermetic — no network, no
  filesystem, no terminal.
- The `SlothClient` accepts a pluggable transport (protocol) so tests
  substitute a fake socket that emits canned JSONL bytes.
- App-level UI tests (Xcode test target) cover navigation, selection
  state, and snapshot a few representative renders. Run them with
  `make test` or `xcodebuild test`.
- A bug fix ships with a test that would have caught it.

---

## 6. Running the app

### 6.1 In the simulator

```sh
xcodegen generate
open SlothIOS.xcodeproj
# Pick a simulator (iPhone 15 / iPad Pro 13") and press ⌘R
```

First run: the app opens a connection sheet. Enter the sloth
instance's address as either:

- `unix:/var/run/sloth.sock` (only useful in the simulator on the
  same host)
- `tcp:HOST:PORT` (the normal case; HOST is usually the Tailscale IP
  of the machine running sloth)

The app remembers the most recent profile in `UserDefaults`. No
secrets are stored (the socket has no auth surface; access control
is at the Tailscale ACL level).

### 6.2 On device

Standard Xcode-signed personal-team build is fine for personal use.
TestFlight or App Store distribution is out of scope for the initial
roadmap — this is a tool for the operator, not a published product.

### 6.3 Tailscale setup

See [`docs/wiki/tailscale-setup.md`](docs/wiki/tailscale-setup.md)
for the recommended ACL and bind setup so the iOS device can reach
the sloth instance over the tailnet.

---

## 7. Code layout (where to put things)

| Path                              | Contains |
|-----------------------------------|----------|
| `project.yml`                     | xcodegen spec — authoritative project definition |
| `Package.swift`                   | SPM manifest for the headless `SlothCore` module |
| `Sources/SlothCore/`              | Networking, models, store, alert-hot index, theme |
| `Tests/SlothCoreTests/`           | Hermetic unit tests for the core |
| `App/SlothIOSApp.swift`           | `@main` app entry |
| `App/ContentView.swift`           | root navigation container |
| `App/Views/<Name>View.swift`      | one file per top-level view |
| `App/Charts/<Name>.swift`         | reusable Swift Charts components |
| `App/Resources/Assets.xcassets`   | app icon, accent color |
| `App/Info.plist`                  | bundle metadata |
| `docs/milestones.md`              | the roadmap |
| `docs/views/<name>.md`            | per-view UI specs |
| `docs/wiki/<name>.md`             | concept-oriented knowledge base |

**Hard rules**:

- No new files at repo root. Everything has a home.
- Never `git add -A` / `git add .`. Stage by specific path.
- Don't commit the binary build artefacts (see §4).

---

## 8. Adding work (agent-facing recipes)

### 8.1 Add a view

See [`CLAUDE.md`](CLAUDE.md) "How to add a view" — 5-step checklist:
write the spec, add the SwiftUI file, wire navigation, write the
state test if applicable, build + test before commit.

### 8.2 Add a record type to consume

If sloth adds a new JSONL `type` (e.g. `{"type":"smb",...}`):

1. Add a case to `SlothRecord` in `Sources/SlothCore/SlothRecord.swift`.
2. Decode in `SlothClient.parseLine` and dispatch to the store.
3. Add a ring in `SlothStore` if the records aren't going through an
   existing one.
4. Update or create the consuming view.
5. Test: feed a canned JSONL line into the fake transport, assert
   the store sees it.
6. Reference: the sloth-side schema page at
   `sloth/docs/wiki/jsonl-schema.md`.

### 8.3 Add a chart

1. New `App/Charts/<Name>.swift`. Component takes pure data
   (`[Sample]`), no environment dependency.
2. Use Swift Charts. No third-party chart libs.
3. A11y label describes the trend.
4. Used by exactly one view (most cases) or, if shared, documented
   in the view specs that use it.

---

## 9. Common failures and fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error: no such module 'SlothCore'` | xcodegen not run | `xcodegen generate` |
| `xcodebuild: command not found` | Xcode CLT not installed | `xcode-select --install` |
| Strict concurrency errors on first build | Swift toolchain too old | upgrade Xcode to 15.0+ |
| Simulator app can't reach `tcp:100.x.x.x:...` | Tailscale not on the host running the simulator | install Tailscale on the Mac too; simulators share the host network stack |
| Connection drops every ~30s on a real device | iOS suspended the app while it was background | expected — see MISSION §2(4); reconnect on foreground |
| Generated `.xcodeproj` shows up in `git status` | not in `.gitignore` | should already be; if not, add it and unstage |

---

## 10. Git & release workflow

From [`CLAUDE.md`](CLAUDE.md):

- Branches: work on `main`. No long-running feature branches.
- Commits: imperative subject, blank line, body explaining the *why*,
  `Co-Authored-By` trailer.
- Push after each green commit. Human reviews on GitHub.
- Never `git push --force` to `main`. Never `--no-verify`. Never
  `git reset --hard` without explicit user authorisation.

CI (once configured): `swift test` + `xcodebuild test` on every PR.
Both must be green for merge.

---

## 11. Cold-start sanity loop

```sh
git clone https://github.com/SpaceTrucker2196/sloth-ios.git
cd sloth-ios

swift test                                  # core tests green
xcodegen generate                           # project regenerated
xcodebuild -scheme SlothIOS \
  -destination 'platform=iOS Simulator,name=iPhone 15' build   # warning-clean
open SlothIOS.xcodeproj                     # ⌘R in the simulator
```

If all four succeed, the factory is operational and you can pick the
next milestone from `docs/milestones.md`.

---

## 12. Where to read next

| If you want…                          | Read |
|---------------------------------------|------|
| The non-negotiable charter            | [`MISSION.md`](MISSION.md) |
| The dark-factory pattern              | [`docs/dark-factory.md`](docs/dark-factory.md) |
| Working rules for the repo            | [`CLAUDE.md`](CLAUDE.md) |
| The roadmap                           | [`docs/milestones.md`](docs/milestones.md) |
| Per-view UI specs                     | [`docs/views/README.md`](docs/views/README.md) |
| JSONL record contract (consumer side) | [`docs/wiki/jsonl-protocol.md`](docs/wiki/jsonl-protocol.md) |
| Theme / colours                       | [`docs/wiki/theme.md`](docs/wiki/theme.md) |
| Tailscale setup                       | [`docs/wiki/tailscale-setup.md`](docs/wiki/tailscale-setup.md) |
