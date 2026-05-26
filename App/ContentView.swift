// ContentView — root view. At pre-M1 this is a placeholder that
// explains the cold-start state. M1 replaces it with the connection-
// profile entry + the debug log; M7 wraps the dashboard composite.

import SwiftUI
import SlothCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.tint)

            Text("sloth-ios")
                .font(.title.weight(.semibold))

            Text("pre-M1 scaffolding")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("SlothCore v\(SlothCoreInfo.version)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            Spacer()

            Text(
                "Next milestone: open a tcp:HOST:PORT connection to a sloth\n" +
                "instance and stream the JSONL records into a debug log.\n" +
                "See docs/milestones.md — M1."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .padding(.top, 64)
    }
}

#Preview {
    ContentView()
}
