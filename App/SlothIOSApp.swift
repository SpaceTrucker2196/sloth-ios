// SlothIOSApp — @main entry. Owns the shared `SlothStore`,
// `ProfileStore`, and `SlothLog`, injecting each into the SwiftUI
// environment so every view reads from `@Environment(...)` per
// CLAUDE.md.
//
// Forces dark mode app-wide — sloth's TUI is phosphor-on-black and
// the consumer should match. Sets the global font to the phosphor
// monospaced face (FiraCode if registered, SF Mono otherwise) so
// every view inherits the same TUI-on-a-phone aesthetic without
// per-view font modifiers.

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
                .environment(\.font, .phosphor())
                .tint(.phosphorBright)
                .preferredColorScheme(.dark)
        }
    }
}
