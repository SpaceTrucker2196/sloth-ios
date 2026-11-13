// FleetRadar — pure geometry for the radar view. Turns a contact's
// signal strength (and optional bearing) into a polar position on a
// unit disc, so the view layer only draws points it is handed.
//
// Range model: RSSI is mapped to a normalized radius in 0...1 by a
// simple linear fit between a "right on top of you" reference and a
// "barely heard" floor. It is NOT a metric distance — BLE RSSI is far
// too noisy for that — it is a monotonic "closer vs farther" ordering,
// which is all a radar needs.
//
// Bearing: when the producing post reports a compass heading and a
// contact carries a relative bearing, the blip is placed at that
// angle. Absent a real bearing, the contact's stable `addr` is hashed
// to a fixed angle so it doesn't jump frame to frame.

import Foundation

public struct RadarBlip: Sendable, Equatable, Identifiable {
    public let id: String
    public let range: Double     // 0 (centre) ... 1 (rim)
    public let angleDeg: Double  // 0 = up/north, clockwise
    public let rssi: Int
    public let label: String?

    /// Cartesian position on a unit disc centred at origin, y up.
    /// angle 0 => (0, +range). Clockwise positive.
    public var x: Double { range * sin(angleDeg * .pi / 180) }
    public var y: Double { range * cos(angleDeg * .pi / 180) }

    public init(id: String, range: Double, angleDeg: Double, rssi: Int, label: String? = nil) {
        self.id = id
        self.range = range
        self.angleDeg = angleDeg
        self.rssi = rssi
        self.label = label
    }
}

public enum FleetRadar {

    /// RSSI (dBm) considered point-blank — radius 0.
    public static let rssiNear: Double = -30
    /// RSSI (dBm) considered the audible floor — radius 1.
    public static let rssiFar: Double = -100

    /// Map an RSSI to a 0...1 radius. Clamped at both ends.
    public static func range(forRSSI rssi: Int) -> Double {
        let r = Double(rssi)
        let t = (rssiNear - r) / (rssiNear - rssiFar)
        return min(1, max(0, t))
    }

    /// Deterministic angle in [0, 360) for a contact id, so a blip
    /// without a real bearing holds a stable position across frames.
    public static func stableAngle(for id: String) -> Double {
        // FNV-1a over the id's UTF-8, folded to a degree.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Double(hash % 360)
    }

    /// Place one BLE contact. `bearingDeg`, when supplied, overrides
    /// the hashed angle (e.g. post reports a directional estimate).
    public static func blip(for c: BLEContactEntry, bearingDeg: Double? = nil) -> RadarBlip {
        RadarBlip(
            id: c.addr,
            range: range(forRSSI: c.rssi),
            angleDeg: bearingDeg ?? stableAngle(for: c.addr),
            rssi: c.rssi,
            label: c.name)
    }

    /// Place every contact in a buffer snapshot.
    public static func blips(for contacts: [BLEContactEntry]) -> [RadarBlip] {
        contacts.map { blip(for: $0) }
    }
}
