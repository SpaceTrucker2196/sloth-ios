// DashboardCard — reusable tile wrapper used by the M7 composite
// dashboard. A thin title bar over arbitrary content; clips to a
// rounded rectangle so each panel reads as a distinct surface in
// the grid.
//
// Per M7 spec: pinch / drag is disabled, the layout is fixed.

import SwiftUI

struct DashboardCard<Content: View>: View {

    let title: String
    var systemImage: String? = nil
    var tint: Color = .secondary
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
