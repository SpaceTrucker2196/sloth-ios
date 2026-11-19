// ErrorToast — connection errors as a toast under the connection bar
// (#20). Each new message shows for a few seconds, then fades; a tap
// hides it at once. It sits over the content, never over the bar, so a
// failing sensor cannot block the picker that switches away from it.

import SwiftUI

struct ErrorToast: View {

    /// The current error, nil when there is none. A new non-nil value
    /// shows the toast again.
    let message: String?
    var seconds: Double = 5

    @State private var shown: String?
    @State private var hideTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let text = shown {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.alertHotCrit.opacity(0.92)))
                    .shadow(radius: 4, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .onTapGesture { hide() }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Dismiss")
            }
            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.25), value: shown)
        .onChange(of: message, initial: true) { _, new in show(new) }
    }

    private func show(_ text: String?) {
        hideTask?.cancel()
        shown = text
        guard text != nil else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { shown = nil }
        }
    }

    private func hide() {
        hideTask?.cancel()
        shown = nil
    }
}
