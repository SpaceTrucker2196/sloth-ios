// SlothIOSApp — @main entry. Owns the shared `SlothStore`,
// `ProfileStore`, and `SlothLog`, injecting each into the SwiftUI
// environment so every view reads from `@Environment(...)` per
// CLAUDE.md.

import SwiftUI
import SlothCore

@main
struct SlothIOSApp: App {

    @State private var store        = SlothStore()
    @State private var profiles     = ProfileStore()
    @State private var log          = SlothLog()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(profiles)
                .environment(log)
        }
    }
}
