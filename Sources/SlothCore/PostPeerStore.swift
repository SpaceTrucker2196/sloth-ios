// PostPeerStore — the operator's saved list of sensor-post endpoints
// to pull directly, by address, for posts that Bonjour can't reach.
//
// Bonjour discovery (`_sloth-post._tcp.`) only crosses the local link.
// A post that reports home over cellular + Tailscale is not on the
// hub's link, so the hub must dial it by its tailnet address
// (`tcp:100.x.y.z:PORT`). This store holds those addresses; the
// `FleetCoordinator` opens a stream to each alongside the ones it
// discovers locally.
//
// Persistence is allowed under MISSION §2(6): this is connection
// config (host:port), never record content.

import Foundation
import Observation

@MainActor
@Observable
public final class PostPeerStore {

    public static let userDefaultsKey = "io.river.sloth.postPeers.v1"

    public private(set) var peers: [ConnectionProfile]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let saved = try? JSONDecoder().decode([ConnectionProfile].self, from: data) {
            self.peers = saved
        } else {
            self.peers = []
        }
    }

    /// Add a peer from a `tcp:HOST:PORT` URI. Returns false on a
    /// malformed address or an exact duplicate.
    @discardableResult
    public func add(uri: String) -> Bool {
        guard let profile = ConnectionProfile(uri: uri) else { return false }
        return add(profile)
    }

    @discardableResult
    public func add(_ profile: ConnectionProfile) -> Bool {
        guard !peers.contains(profile) else { return false }
        peers.append(profile)
        persist()
        return true
    }

    public func remove(_ profile: ConnectionProfile) {
        peers.removeAll { $0 == profile }
        persist()
    }

    public func remove(atOffsets offsets: IndexSet) {
        // Array.remove(atOffsets:) is a SwiftUI extension; SlothCore
        // has no SwiftUI, so filter by index directly.
        peers = peers.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(peers) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
