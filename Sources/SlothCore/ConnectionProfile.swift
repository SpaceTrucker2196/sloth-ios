// ConnectionProfile — addressing for a sloth `--data-socket` endpoint.
//
// MISSION §2(5): the only allowed persistence in this app is the
// connection profile in `UserDefaults`. No record content is ever
// stored to disk.
//
// Accepted URI forms:
//   tcp:HOST:PORT            — HOST is hostname or IPv4 literal
//   tcp:[v6-host]:PORT       — IPv6 literal in brackets
// UNIX-domain sockets (`unix:/path`) are listed in the wire spec but
// not reachable from iOS sandboxing; they're left out of M1.

import Foundation

public struct ConnectionProfile: Sendable, Codable, Equatable, Hashable {

    public var host: String
    public var port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    /// Parses `tcp:HOST:PORT` or `tcp:[v6]:PORT`. Returns nil on
    /// malformed input — callers surface a form-validation error.
    public init?(uri: String) {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let schemeEnd = trimmed.firstIndex(of: ":"),
              trimmed[trimmed.startIndex..<schemeEnd] == "tcp"
        else { return nil }

        let rest = trimmed[trimmed.index(after: schemeEnd)...]
        let (hostPart, portPart): (String, String)

        if rest.first == "[" {
            guard let close = rest.firstIndex(of: "]") else { return nil }
            let after = rest.index(after: close)
            guard after < rest.endIndex, rest[after] == ":" else { return nil }
            hostPart = String(rest[rest.index(after: rest.startIndex)..<close])
            portPart = String(rest[rest.index(after: after)...])
        } else {
            guard let lastColon = rest.lastIndex(of: ":") else { return nil }
            hostPart = String(rest[rest.startIndex..<lastColon])
            portPart = String(rest[rest.index(after: lastColon)...])
        }

        guard !hostPart.isEmpty,
              let port = UInt16(portPart), port > 0
        else { return nil }

        self.host = hostPart
        self.port = port
    }

    public var uri: String {
        host.contains(":") ? "tcp:[\(host)]:\(port)" : "tcp:\(host):\(port)"
    }
}

// MARK: - UserDefaults persistence

extension ConnectionProfile {

    /// Key the profile is stored under in `UserDefaults`. Public so
    /// integration tests can target the same key with a custom suite.
    public static let userDefaultsKey = "io.river.sloth.connectionProfile.v1"

    public static func load(from defaults: UserDefaults = .standard) -> ConnectionProfile? {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(ConnectionProfile.self, from: data)
    }

    public func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    public static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}
