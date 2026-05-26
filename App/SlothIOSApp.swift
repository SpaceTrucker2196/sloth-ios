// SlothIOSApp — @main entry. Owns the shared `SlothStore` and
// injects it into the SwiftUI environment so every view can observe
// records via `@Environment(SlothStore.self)` per CLAUDE.md.

import SwiftUI
import SlothCore

@main
struct SlothIOSApp: App {

    @State private var store = SlothStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
