// FleetStore — observable roster of every sloth sensor post the hub
// is reading, with each post's latest sensor state. This is the model
// behind the radar view: "the entire fleet's perspective" is the
// union of what every post currently hears.
//
// A hub (sloth-ios acting as the fleet viewer) discovers posts over
// Bonjour, opens a read-only stream to each, decodes `SensorRecord`
// lines, and funnels them here via `ingest`. The store is the single
// source of truth; the radar view observes it.
//
// Purely in-memory. A post that stops heartbeating past `offlineTTL`
// is marked offline but kept on the roster until explicitly pruned,
// so the radar shows a dimmed last-known rather than a vanishing act.

import Foundation
import Observation

public struct FleetPost: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var role: String
    public var platform: String
    public var lastHeard: Int
    public var battery: Double?
    public var headingDeg: Double?
    public var fieldMagUT: Double?
    public var wifiSSID: String?
    public var geo: (lat: Double, lon: Double)?
    public var contacts: [String: BLEContactEntry]
    public var contactOrder: [String]

    public init(id: String, name: String, role: String, platform: String, lastHeard: Int) {
        self.id = id; self.name = name; self.role = role
        self.platform = platform; self.lastHeard = lastHeard
        self.battery = nil; self.headingDeg = nil; self.fieldMagUT = nil
        self.wifiSSID = nil; self.geo = nil
        self.contacts = [:]; self.contactOrder = []
    }

    public var orderedContacts: [BLEContactEntry] {
        contactOrder.compactMap { contacts[$0] }
    }

    public static func == (lhs: FleetPost, rhs: FleetPost) -> Bool {
        lhs.id == rhs.id && lhs.lastHeard == rhs.lastHeard &&
        lhs.contactOrder == rhs.contactOrder && lhs.name == rhs.name
    }
}

@MainActor
@Observable
public final class FleetStore {

    /// Seconds without a heartbeat before a post is considered offline.
    public let offlineTTL: Int
    /// Per-post contact cap, mirroring the post-side buffer.
    public let maxContactsPerPost: Int

    public private(set) var posts: [String: FleetPost] = [:]

    public init(offlineTTL: Int = 30, maxContactsPerPost: Int = 256) {
        self.offlineTTL = offlineTTL
        self.maxContactsPerPost = maxContactsPerPost
    }

    /// Posts sorted by name for stable list identity.
    public var roster: [FleetPost] {
        posts.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func isOnline(_ post: FleetPost, now: Int) -> Bool {
        now - post.lastHeard <= offlineTTL
    }

    // MARK: - Ingest

    public func ingest(_ rec: SensorRecord) {
        let pid = rec.post
        var post = posts[pid] ?? FleetPost(
            id: pid, name: pid, role: "mobile", platform: "ios", lastHeard: rec.ts)
        post.lastHeard = max(post.lastHeard, rec.ts)

        switch rec {
        case .iosPost(let e):
            post.name = e.name
            post.role = e.role
            post.platform = e.platform
            post.battery = e.battery
        case .imuSample(let e):
            post.headingDeg = e.headingDeg
            post.fieldMagUT = e.fieldMagUT
        case .wifiSelf(let e):
            post.wifiSSID = e.ssid
        case .geoFix(let e):
            post.geo = (e.lat, e.lon)
        case .radioScan:
            break
        case .bleContact(let e):
            if post.contacts[e.addr] == nil {
                post.contactOrder.append(e.addr)
                if post.contactOrder.count > maxContactsPerPost {
                    let evict = post.contactOrder.removeFirst()
                    post.contacts.removeValue(forKey: evict)
                }
            }
            post.contacts[e.addr] = e
        }
        posts[pid] = post
    }

    /// Radar blips for a single post.
    public func blips(forPost id: String) -> [RadarBlip] {
        guard let post = posts[id] else { return [] }
        return FleetRadar.blips(for: post.orderedContacts)
    }

    /// The fleet-wide radar: every online post's contacts, blip id
    /// namespaced by post so two posts hearing the same device render
    /// as two blips (each at its own range).
    public func fleetBlips(now: Int) -> [RadarBlip] {
        var out: [RadarBlip] = []
        for post in roster where isOnline(post, now: now) {
            for c in post.orderedContacts {
                let base = FleetRadar.blip(for: c)
                out.append(RadarBlip(
                    id: "\(post.id)/\(base.id)",
                    range: base.range,
                    angleDeg: base.angleDeg,
                    rssi: base.rssi,
                    distanceM: base.distanceM,
                    label: base.label))
            }
        }
        return out
    }

    public func prune(now: Int, hardTTL: Int) {
        for (id, post) in posts where now - post.lastHeard > hardTTL {
            posts.removeValue(forKey: id)
        }
    }

    public func removeAll() { posts.removeAll() }
}
