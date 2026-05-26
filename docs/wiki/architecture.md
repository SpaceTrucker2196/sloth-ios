# Architecture

Two layers, one seam.

## Layers

```
┌─────────────────────────────────────────────────────────────┐
│ App/  (SwiftUI iOS app, generated .xcodeproj via xcodegen)  │
│   SlothIOSApp.swift                                          │
│   ContentView.swift                                          │
│   Views/<Name>View.swift     ← imports SlothCore             │
│   Charts/<Name>.swift                                        │
└─────────────────────────────────────────────────────────────┘
                          ▲ depends on
┌─────────────────────────────────────────────────────────────┐
│ Sources/SlothCore/  (headless Swift Package)                │
│   SlothRecord.swift          ← Codable sum type matching     │
│                                 sloth's JSONL schema         │
│   SlothClient.swift          ← Network.framework NWConnection│
│                                 → AsyncStream<SlothRecord>   │
│   LineReader.swift           ← splits Data on `\n`           │
│   SlothStore.swift           ← @Observable; rings per type   │
│   AlertHotIndex.swift        ← cross-panel severity index    │
│   ConnectionProfile.swift    ← UserDefaults-backed profile   │
│   Theme.swift                ← Color extensions              │
└─────────────────────────────────────────────────────────────┘
```

## Why the split

- `SlothCore` builds on **any platform** with a Swift toolchain
  (Linux CI, macOS CLI, Xcode). `swift test` is hermetic — no
  ncurses, no Network.framework-on-Linux issue (we'll alias the
  transport for Linux tests if needed).
- `App` builds **only** in Xcode. SwiftUI views, app delegate,
  Info.plist all live here.
- Views never own state. They observe `SlothStore` via the
  `@Environment` injection set in `SlothIOSApp.body`.

## Seam: `SlothClient`'s transport

`SlothClient` accepts a `ClientTransport` protocol so tests can
substitute a fake socket that emits canned JSONL bytes:

```swift
protocol ClientTransport: Sendable {
    func receive(...) async throws -> Data
    func cancel()
}

struct NWConnectionTransport: ClientTransport { /* production */ }
struct FakeTransport: ClientTransport { /* tests */ }
```

The transport is the only seam between `SlothCore` and the iOS
networking stack; everything else in `SlothCore` is plain Swift.

## Data flow

```
   Network.framework               Sources/SlothCore             App/
   ───────────────────              ───────────────              ────
   NWConnection.receive   ──►  LineReader.lines  ──►  SlothClient
                                      │                    │
                                      ▼                    ▼
                              SlothRecord.decode    SlothStore.ingest
                                                          │
                                                          ▼
                                                  @Observable change
                                                          │
                                                          ▼
                                            SwiftUI views recompose
```

Every byte path is async/await. The store's `ingest` is
serialised on its own actor so multi-record bursts don't race.

## Where things live

| Concern                    | Goes in                       |
|----------------------------|-------------------------------|
| New record `type`          | `Sources/SlothCore/SlothRecord.swift` |
| New ring buffer            | `Sources/SlothCore/SlothStore.swift`  |
| Network primitives         | `Sources/SlothCore/SlothClient.swift` |
| Aggregation (top hosts, …) | `Sources/SlothCore/<Aggregator>.swift` |
| Theme tweak                | `Sources/SlothCore/Theme.swift`       |
| New view                   | `App/Views/<Name>View.swift`          |
| New chart                  | `App/Charts/<Name>.swift`             |
| New permanent setting      | `Sources/SlothCore/ProfileStore.swift` |
