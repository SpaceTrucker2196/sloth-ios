// FleetCoordinator — the hub side. Browses for `_sloth-post._tcp.`
// services, opens a read-only `PostClient` stream to each, and funnels
// the decoded `SensorRecord`s into a `FleetStore` that the radar view
// observes. This is what lets one sloth-ios see the whole fleet's
// perspective; a sloth instance does the equivalent server-side.
//
// Lifecycle matches the consumer side: browse + streams run in the
// foreground only, torn down on background.

import Foundation
import Observation
import SlothCore

@MainActor
@Observable
public final class FleetCoordinator {

    public let fleet: FleetStore
    public let peers: PostPeerStore
    public private(set) var browsing = false
    public private(set) var knownPosts: [DiscoveredService] = []

    private let discovery = SlothDiscovery(serviceType: SlothDiscovery.postServiceType)
    private let client = PostClient()
    private var streams: [String: Task<Void, Never>] = [:]
    private var observeTask: Task<Void, Never>?

    public init(fleet: FleetStore = FleetStore(), peers: PostPeerStore = PostPeerStore()) {
        self.fleet = fleet
        self.peers = peers
    }

    public func start() {
        guard !browsing else { return }
        browsing = true
        discovery.start()
        // Poll the discovery roster and open a stream per new service.
        observeTask = Task { @MainActor in
            while !Task.isCancelled {
                // Local-link posts (Bonjour) plus tailnet posts the
                // operator added by address. mDNS stops at the link;
                // the manual list is how a roaming post over Tailscale
                // gets pulled.
                var targets: [String: ConnectionProfile] = [:]
                for svc in discovery.services { targets["bonjour:\(svc.id)"] = svc.profile }
                for p in peers.peers { targets["peer:\(p.uri)"] = p }
                syncStreams(with: targets)
                knownPosts = discovery.services
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    public func stop() {
        browsing = false
        observeTask?.cancel(); observeTask = nil
        discovery.stop()
        for (_, t) in streams { t.cancel() }
        streams.removeAll()
    }

    private func syncStreams(with targets: [String: ConnectionProfile]) {
        let liveKeys = Set(targets.keys)
        // Drop streams whose target vanished.
        for (key, task) in streams where !liveKeys.contains(key) {
            task.cancel(); streams.removeValue(forKey: key)
        }
        // Open a stream for each newly-seen target.
        for (key, profile) in targets where streams[key] == nil {
            streams[key] = openStream(profile)
        }
    }

    private func openStream(_ profile: ConnectionProfile) -> Task<Void, Never> {
        let client = client
        let fleet = fleet
        return Task { @MainActor in
            do {
                for try await rec in client.records(for: profile) {
                    fleet.ingest(rec)
                }
            } catch {
                // Stream dropped; the poll loop reopens if the service
                // is still advertised. Nothing to persist.
            }
        }
    }
}
