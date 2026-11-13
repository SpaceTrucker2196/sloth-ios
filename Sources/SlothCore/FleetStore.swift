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

    // MARK: - Fleet geometry (triangulation)

    public struct FleetGeometry: Sendable, Equatable {
        public struct PostMarker: Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
            public let x: Double   // ENU east metres from the origin post
            public let y: Double   // ENU north metres
        }
        public struct LocatedContact: Sendable, Equatable, Identifiable {
            public var id: String { addr }
            public let addr: String
            public let x: Double
            public let y: Double
            public let anchors: Int
            public let coarse: Bool
            public let label: String?
        }
        public let posts: [PostMarker]
        public let located: [LocatedContact]
        public let locatedAddrs: Set<String>
    }

    /// Place located posts and any contact heard by 2+ of them on a
    /// local metre grid, origin at the first located post. Needs posts
    /// that share their position (`geo_fix`); a lone post yields empty
    /// geometry. This is the data behind the radar's triangulated
    /// markers.
    public func fleetGeometry(now: Int) -> FleetGeometry {
        let geoPosts = roster.filter { isOnline($0, now: now) && $0.geo != nil }
        guard let origin = geoPosts.first, let o = origin.geo else {
            return FleetGeometry(posts: [], located: [], locatedAddrs: [])
        }
        var markers: [FleetGeometry.PostMarker] = []
        var postENU: [String: (x: Double, y: Double)] = [:]
        for p in geoPosts {
            guard let g = p.geo else { continue }
            let e = GeoProjection.enu(lat: g.lat, lon: g.lon, lat0: o.lat, lon0: o.lon)
            markers.append(.init(id: p.id, name: p.name, x: e.x, y: e.y))
            postENU[p.id] = e
        }
        // addr → every (post, rssi) that heard it.
        var hearers: [String: [(pid: String, rssi: Int)]] = [:]
        for p in geoPosts {
            for c in p.orderedContacts {
                hearers[c.addr, default: []].append((p.id, c.rssi))
            }
        }
        var located: [FleetGeometry.LocatedContact] = []
        var addrs: Set<String> = []
        for (addr, hs) in hearers where hs.count >= 2 {
            let anchors = hs.compactMap { h -> Multilateration.Anchor? in
                guard let e = postENU[h.pid],
                      let d = FleetRadar.approxDistanceMeters(rssi: h.rssi) else { return nil }
                return Multilateration.Anchor(x: e.x, y: e.y, r: d)
            }
            guard let fix = Multilateration.solve(anchors) else { continue }
            let name = geoPosts.compactMap { $0.contacts[addr]?.name }.first
            located.append(.init(addr: addr, x: fix.x, y: fix.y,
                                 anchors: fix.anchors, coarse: fix.coarse, label: name))
            addrs.insert(addr)
        }
        located.sort { $0.addr < $1.addr }
        return FleetGeometry(posts: markers, located: located, locatedAddrs: addrs)
    }

    public func prune(now: Int, hardTTL: Int) {
        for (id, post) in posts where now - post.lastHeard > hardTTL {
            posts.removeValue(forKey: id)
        }
    }

    public func removeAll() { posts.removeAll() }
}
