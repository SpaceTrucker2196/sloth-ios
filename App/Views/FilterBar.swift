// FilterBar — shared chip strip + search field used by every log
// view (DNS / TLS / HTTP today; more as new logs land). Chips are
// caller-supplied so each log view chooses its own labels (e.g. DNS
// uses "All|Q|R"; TLS could use version tiers; HTTP could use
// methods). The search field binds to a `@Binding` so the parent
// view owns the query.

import SwiftUI

struct FilterBar<ChipID: Hashable & Sendable>: View {

    struct Chip: Identifiable {
        let id: ChipID
        let label: String
        var tint: Color = .accentColor
    }

    let chips: [Chip]
    @Binding var selection: ChipID
    @Binding var query: String
    var placeholder: String = "search…"

    var body: some View {
        VStack(spacing: 0) {
            chipStrip
            searchField
            Divider()
        }
        .background(.bar)
    }

    private var chipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        selection = chip.id
                    } label: {
                        Text(chip.label)
                            .font(.caption.monospaced())
                            .fontWeight(chip.id == selection ? .bold : .regular)
                            .foregroundStyle(chip.id == selection ? .white : chip.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(chip.id == selection ? chip.tint : Color.clear)
                                    .overlay(Capsule().stroke(chip.tint, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
