// PostIdentity — stable identity for this device as a sloth sensor
// post. A random UUID minted once and kept in UserDefaults, plus an
// operator-chosen display name and a role. The UUID is the only
// persistent identifier the post exposes; it is not tied to any
// hardware id, so it can be rotated by clearing it.
//
// MISSION (post era) §2(5): connection profiles and this post
// identity are the only state written to disk. No sensor record is
// ever persisted.

import Foundation

public struct PostIdentity: Sendable, Codable, Equatable {

    public enum Role: String, Sendable, Codable, CaseIterable {
        case mobile    // a phone that moves with the operator
        case roaming   // an iPad carried on a sweep
        case fixed     // a device left in place as a static sensor
    }

    public var id: String        // UUID string, stable per install
    public var name: String      // operator-facing, e.g. "Jeff iPhone"
    public var role: Role

    public init(id: String, name: String, role: Role = .mobile) {
        self.id = id
        self.name = name
        self.role = role
    }
}

extension PostIdentity {

    public static let userDefaultsKey = "io.river.sloth.postIdentity.v1"

    /// Load the saved identity, or mint and persist a fresh one. The
    /// default name is deliberately generic; the operator renames it
    /// in Settings.
    public static func loadOrCreate(
        defaultName: String = "sloth post",
        in defaults: UserDefaults = .standard
    ) -> PostIdentity {
        if let data = defaults.data(forKey: userDefaultsKey),
           let found = try? JSONDecoder().decode(PostIdentity.self, from: data) {
            return found
        }
        let fresh = PostIdentity(id: UUID().uuidString, name: defaultName)
        fresh.save(in: defaults)
        return fresh
    }

    public func save(in defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    /// Mint a new UUID, discarding the old identity. Used by a
    /// "rotate post id" control so a post can shed its history.
    public static func rotate(
        keepingNameFrom old: PostIdentity?,
        in defaults: UserDefaults = .standard
    ) -> PostIdentity {
        let fresh = PostIdentity(
            id: UUID().uuidString,
            name: old?.name ?? "sloth post",
            role: old?.role ?? .mobile)
        fresh.save(in: defaults)
        return fresh
    }

    public static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}
