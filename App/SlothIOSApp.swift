// SlothIOSApp — @main entry. Owns the SlothStore environment object
// (added in M2). For now this is a bare scaffold so the app target
// compiles and runs to the placeholder ContentView.

import SwiftUI
import SlothCore

@main
struct SlothIOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
