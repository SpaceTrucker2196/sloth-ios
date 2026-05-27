// ProfileStore — multiple saved `ConnectionProfile`s with an
// "active" selection. Persisted under a single JSON-encoded
// `UserDefaults` key, per MISSION §2(5) (the only persistence
// the app does — the profile, never any record content).
//
// The legacy single-profile key written by `ConnectionProfile.save()`
// is upgraded into the new list on first load so operators who
// upgraded from M1 don't lose their profile.

import Foundation
import Observation

/// A user-labelled wrapper around a `ConnectionProfile`. The id is
/// stable across edits — caller's `update(_:)` mutates by id, not by
/// host/port — so SwiftUI list identity holds when the user renames.
public struct NamedProfile: Sendable, Codable, Equatable, Hashable, Identifiable {

    public let id: UUID
    public var name: String
    public var profile: ConnectionProfile

    public init(id: UUID = UUID(), name: String, profile: ConnectionProfile) {
        self.id = id
        self.name = name
        self.profile = profile
    }
}

@MainActor
@Observable
public final class ProfileStore {

    public static let userDefaultsKey       = "io.river.sloth.profiles.v1"
    public static let activeIDUserDefaultsKey = "io.river.sloth.profiles.activeID.v1"

    public private(set) var profiles: [NamedProfile] = []
    public private(set) var activeID: UUID?

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public var activeProfile: NamedProfile? {
        guard let id = activeID else { return profiles.first }
        return profiles.first { $0.id == id }
    }

    @discardableResult
    public func add(name: String, profile: ConnectionProfile) -> NamedProfile {
        let p = NamedProfile(name: name, profile: profile)
        profiles.append(p)
        if activeID == nil { activeID = p.id }
        persist()
        return p
    }

    public func update(_ profile: NamedProfile) {
        guard let i = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[i] = profile
        persist()
    }

    public func remove(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeID == id {
            activeID = profiles.first?.id
        }
        persist()
    }

    public func setActive(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeID = id
        persist()
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let list = try? JSONDecoder().decode([NamedProfile].self, from: data) {
            profiles = list
        } else if let legacy = ConnectionProfile.load(from: defaults) {
            // Upgrade path from M1's single-profile key. We don't
            // remove the legacy key — re-running an older build with
            // the same defaults still finds it.
            let p = NamedProfile(name: legacy.host, profile: legacy)
            profiles = [p]
        } else {
            profiles = []
        }

        if let raw = defaults.string(forKey: Self.activeIDUserDefaultsKey),
           let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            activeID = id
        } else {
            activeID = profiles.first?.id
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
        if let id = activeID {
            defaults.set(id.uuidString, forKey: Self.activeIDUserDefaultsKey)
        } else {
            defaults.removeObject(forKey: Self.activeIDUserDefaultsKey)
        }
    }
}
