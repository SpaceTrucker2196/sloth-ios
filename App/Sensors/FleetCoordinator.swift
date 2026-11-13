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
    public private(set) var browsing = false
    public private(set) var knownPosts: [DiscoveredService] = []

    private let discovery = SlothDiscovery(serviceType: SlothDiscovery.postServiceType)
    private let client = PostClient()
    private var streams: [String: Task<Void, Never>] = [:]
    private var observeTask: Task<Void, Never>?

    public init(fleet: FleetStore = FleetStore()) {
        self.fleet = fleet
    }

    public func start() {
        guard !browsing else { return }
        browsing = true
        discovery.start()
        // Poll the discovery roster and open a stream per new service.
        observeTask = Task { @MainActor in
            while !Task.isCancelled {
                syncStreams(with: discovery.services)
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

    private func syncStreams(with services: [DiscoveredService]) {
        let liveIDs = Set(services.map(\.id))
        // Drop streams whose service vanished.
        for (id, task) in streams where !liveIDs.contains(id) {
            task.cancel(); streams.removeValue(forKey: id)
        }
        // Open a stream for each newly-seen service.
        for svc in services where streams[svc.id] == nil {
            streams[svc.id] = openStream(svc)
        }
    }

    private func openStream(_ svc: DiscoveredService) -> Task<Void, Never> {
        let profile = svc.profile
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
