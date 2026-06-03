// DiscoveryView — sheet listing Bonjour-discovered sloth instances
// on the local network. Tap → store as a `NamedProfile` in
// `ProfileStore`, activate it, dismiss.
//
// Browsing starts when the sheet appears and stops on dismiss so we
// only hold a `NetServiceBrowser` for the duration of the picker.

import SwiftUI
import SlothCore

struct DiscoveryView: View {

    @Environment(ProfileStore.self) private var profiles
    @Environment(SlothLog.self)     private var log
    @Environment(\.dismiss)         private var dismiss

    @State private var discovery = SlothDiscovery()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Discover")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            discovery.stop()
                            discovery.start()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Rescan")
                    }
                }
        }
        .onAppear {
            discovery.start()
            log.info("discovery", "started Bonjour browse for \(SlothDiscovery.serviceType)")
        }
        .onDisappear {
            discovery.stop()
            log.info("discovery", "stopped Bonjour browse")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch discovery.state {
        case .failed(let reason):
            ContentUnavailableView(
                "Discovery failed",
                systemImage: "wifi.exclamationmark",
                description: Text(reason)
            )
        default:
            if discovery.services.isEmpty {
                browsingPlaceholder
            } else {
                List(discovery.services) { svc in
                    row(svc)
                }
                .listStyle(.plain)
            }
        }
    }

    private var browsingPlaceholder: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Looking for sloth instances…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Sloth instances need to advertise \(SlothDiscovery.serviceType) on the local network for this list to populate. " +
                 "Bonjour publishing isn't yet part of the sloth producer — meanwhile, dismiss this sheet and type the address into the URI field, e.g. `tcp:slothbox.local:8765` or `tcp:100.x.y.z:8765` for a Tailscale tailnet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ svc: DiscoveredService) -> some View {
        Button {
            pick(svc)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.phosphorTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(svc.name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(svc.profile.uri)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let ver = svc.txt["version"] {
                        Text("sloth \(ver)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ svc: DiscoveredService) {
        let profile = svc.profile
        if let existing = profiles.profiles.first(where: { $0.profile == profile }) {
            profiles.setActive(existing.id)
            log.info("discovery", "selected existing profile \(existing.name)")
        } else {
            let saved = profiles.add(name: svc.name, profile: profile)
            profiles.setActive(saved.id)
            log.info("discovery", "saved new profile \(saved.name) → \(profile.uri)")
        }
        dismiss()
    }
}
