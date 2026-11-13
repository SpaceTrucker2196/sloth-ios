// SensorRecord — producer-side JSONL records the iOS SIGINT post emits.
//
// The read-only consumer path (`SlothRecord`) is what this app reads
// *from* a sloth instance. `SensorRecord` is the inverse: the records
// this device *produces* as a sloth sensor post. A fleet hub (sloth,
// or another sloth-ios) discovers the post over Bonjour
// (`_sloth-post._tcp.`), connects, and reads these records off the
// post's own read-only stream socket — the same one-way contract
// sloth's `--data-socket` uses, pointed the other direction.
//
// Envelope matches sloth's JSONL schema: `{ "type": <tag>, "ts":
// <unix-seconds>, "post": <uuid>, ... }`. Keys are snake_case to line
// up with the rest of the sloth stream. Every record carries `post`
// so a hub reading several posts can attribute each contact.
//
// Privacy: iOS never exposes real hardware MACs to a sandboxed app.
// BLE peers are the opaque `CBPeripheral.identifier` UUID, not a MAC.
// `wifi_self` / `geo_fix` are gated behind explicit opt-in in the app
// layer; this type only defines the shape.

import Foundation

public enum SensorRecord: Sendable, Equatable {
    case iosPost(IOSPostEntry)
    case bleContact(BLEContactEntry)
    case imuSample(IMUSampleEntry)
    case geoFix(GeoFixEntry)
    case wifiSelf(WiFiSelfEntry)
    case radioScan(RadioScanEntry)

    public var ts: Int {
        switch self {
        case .iosPost(let e):    return e.ts
        case .bleContact(let e): return e.ts
        case .imuSample(let e):  return e.ts
        case .geoFix(let e):     return e.ts
        case .wifiSelf(let e):   return e.ts
        case .radioScan(let e):  return e.ts
        }
    }

    public var post: String {
        switch self {
        case .iosPost(let e):    return e.post
        case .bleContact(let e): return e.post
        case .imuSample(let e):  return e.post
        case .geoFix(let e):     return e.post
        case .wifiSelf(let e):   return e.post
        case .radioScan(let e):  return e.post
        }
    }

    public var typeTag: String {
        switch self {
        case .iosPost:    return "ios_post"
        case .bleContact: return "ble_contact"
        case .imuSample:  return "imu_sample"
        case .geoFix:     return "geo_fix"
        case .wifiSelf:   return "wifi_self"
        case .radioScan:  return "radio_scan"
        }
    }
}

// MARK: - Entries

/// Heartbeat + identity for the post itself. A hub keys its fleet
/// roster on `post` and shows the post offline when heartbeats stop.
public struct IOSPostEntry: Sendable, Equatable, Codable {
    public var type = "ios_post"
    public var ts: Int
    public var post: String
    public var name: String
    public var role: String        // "mobile" | "fixed" | "roaming"
    public var platform: String    // "ios" | "ipados"
    public var appVer: String
    public var battery: Double?    // 0...1, nil if unknown
    public var charging: Bool?
    public var uptimeS: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, post, name, role, platform
        case appVer = "app_ver", battery, charging
        case uptimeS = "uptime_s"
    }

    public init(ts: Int, post: String, name: String, role: String = "mobile",
                platform: String = "ios", appVer: String,
                battery: Double? = nil, charging: Bool? = nil, uptimeS: Int? = nil) {
        self.ts = ts; self.post = post; self.name = name; self.role = role
        self.platform = platform; self.appVer = appVer; self.battery = battery
        self.charging = charging; self.uptimeS = uptimeS
    }
}

/// A BLE advertiser the post heard. `addr` is the stable opaque
/// identifier iOS hands the app (not a hardware MAC). `rssi` drives
/// radar range.
public struct BLEContactEntry: Sendable, Equatable, Codable {
    public var type = "ble_contact"
    public var ts: Int
    public var post: String
    public var addr: String
    public var addrType: String    // "opaque" on iOS
    public var name: String?
    public var rssi: Int
    public var txPower: Int?
    public var services: [String]
    public var vendor: String?
    public var count: Int          // adv frames seen this window

    enum CodingKeys: String, CodingKey {
        case type, ts, post, addr
        case addrType = "addr_type"
        case name, rssi
        case txPower = "tx_power"
        case services, vendor, count
    }

    public init(ts: Int, post: String, addr: String, addrType: String = "opaque",
                name: String? = nil, rssi: Int, txPower: Int? = nil,
                services: [String] = [], vendor: String? = nil, count: Int = 1) {
        self.ts = ts; self.post = post; self.addr = addr; self.addrType = addrType
        self.name = name; self.rssi = rssi; self.txPower = txPower
        self.services = services; self.vendor = vendor; self.count = count
    }
}

/// Magnetometer + attitude. `headingDeg` is the compass heading; the
/// radar uses it to orient contacts when the post reports a bearing.
public struct IMUSampleEntry: Sendable, Equatable, Codable {
    public var type = "imu_sample"
    public var ts: Int
    public var post: String
    public var headingDeg: Double?
    public var fieldMagUT: Double?   // total magnetic field magnitude, microtesla
    public var fieldX: Double?
    public var fieldY: Double?
    public var fieldZ: Double?
    public var pitchDeg: Double?
    public var rollDeg: Double?
    public var yawDeg: Double?

    enum CodingKeys: String, CodingKey {
        case type, ts, post
        case headingDeg = "heading_deg"
        case fieldMagUT = "field_mag_uT"
        case fieldX = "field_x", fieldY = "field_y", fieldZ = "field_z"
        case pitchDeg = "pitch_deg", rollDeg = "roll_deg", yawDeg = "yaw_deg"
    }

    public init(ts: Int, post: String, headingDeg: Double? = nil,
                fieldMagUT: Double? = nil, fieldX: Double? = nil,
                fieldY: Double? = nil, fieldZ: Double? = nil,
                pitchDeg: Double? = nil, rollDeg: Double? = nil, yawDeg: Double? = nil) {
        self.ts = ts; self.post = post; self.headingDeg = headingDeg
        self.fieldMagUT = fieldMagUT; self.fieldX = fieldX; self.fieldY = fieldY
        self.fieldZ = fieldZ; self.pitchDeg = pitchDeg; self.rollDeg = rollDeg
        self.yawDeg = yawDeg
    }
}

/// Coarse position fix. Opt-in only; a fixed post may pin a static
/// location instead of streaming GPS.
public struct GeoFixEntry: Sendable, Equatable, Codable {
    public var type = "geo_fix"
    public var ts: Int
    public var post: String
    public var lat: Double
    public var lon: Double
    public var altM: Double?
    public var hAccM: Double?
    public var courseDeg: Double?
    public var speedMPS: Double?

    enum CodingKeys: String, CodingKey {
        case type, ts, post, lat, lon
        case altM = "alt_m", hAccM = "h_acc_m"
        case courseDeg = "course_deg", speedMPS = "speed_mps"
    }

    public init(ts: Int, post: String, lat: Double, lon: Double, altM: Double? = nil,
                hAccM: Double? = nil, courseDeg: Double? = nil, speedMPS: Double? = nil) {
        self.ts = ts; self.post = post; self.lat = lat; self.lon = lon
        self.altM = altM; self.hAccM = hAccM; self.courseDeg = courseDeg
        self.speedMPS = speedMPS
    }
}

/// The one WiFi network the post is joined to. `ssid`/`bssid` are nil
/// unless the app holds the entitlement + location permission iOS
/// requires to read them.
public struct WiFiSelfEntry: Sendable, Equatable, Codable {
    public var type = "wifi_self"
    public var ts: Int
    public var post: String
    public var ssid: String?
    public var bssid: String?
    public var rssi: Int?
    public var band: String?

    enum CodingKeys: String, CodingKey { case type, ts, post, ssid, bssid, rssi, band }

    public init(ts: Int, post: String, ssid: String? = nil, bssid: String? = nil,
                rssi: Int? = nil, band: String? = nil) {
        self.ts = ts; self.post = post; self.ssid = ssid; self.bssid = bssid
        self.rssi = rssi; self.band = band
    }
}

/// Best-effort nearby-AP scan via private radio APIs. On a stock
/// (non-jailbroken) iOS sandbox this comes back `available: false`
/// with a reason and an empty list — the app layer never fabricates
/// APs it could not actually observe.
public struct RadioScanEntry: Sendable, Equatable, Codable {
    public var type = "radio_scan"
    public var ts: Int
    public var post: String
    public var available: Bool
    public var reason: String?
    public var aps: [ScannedAP]

    public struct ScannedAP: Sendable, Equatable, Codable {
        public var bssid: String
        public var ssid: String?
        public var rssi: Int
        public var channel: Int?
        public var band: String?
        public init(bssid: String, ssid: String? = nil, rssi: Int,
                    channel: Int? = nil, band: String? = nil) {
            self.bssid = bssid; self.ssid = ssid; self.rssi = rssi
            self.channel = channel; self.band = band
        }
    }

    enum CodingKeys: String, CodingKey { case type, ts, post, available, reason, aps }

    public init(ts: Int, post: String, available: Bool, reason: String? = nil,
                aps: [ScannedAP] = []) {
        self.ts = ts; self.post = post; self.available = available
        self.reason = reason; self.aps = aps
    }
}

// MARK: - Codable (envelope dispatch)

extension SensorRecord: Codable {
    private enum EnvelopeKey: String, CodingKey { case type }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: EnvelopeKey.self)
        let tag = try c.decode(String.self, forKey: .type)
        switch tag {
        case "ios_post":    self = .iosPost(try IOSPostEntry(from: decoder))
        case "ble_contact": self = .bleContact(try BLEContactEntry(from: decoder))
        case "imu_sample":  self = .imuSample(try IMUSampleEntry(from: decoder))
        case "geo_fix":     self = .geoFix(try GeoFixEntry(from: decoder))
        case "wifi_self":   self = .wifiSelf(try WiFiSelfEntry(from: decoder))
        case "radio_scan":  self = .radioScan(try RadioScanEntry(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "unknown sensor record type \(tag)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .iosPost(let e):    try e.encode(to: encoder)
        case .bleContact(let e): try e.encode(to: encoder)
        case .imuSample(let e):  try e.encode(to: encoder)
        case .geoFix(let e):     try e.encode(to: encoder)
        case .wifiSelf(let e):   try e.encode(to: encoder)
        case .radioScan(let e):  try e.encode(to: encoder)
        }
    }

    /// Encode as one newline-terminated JSONL line, ready for the
    /// post's stream socket. Returns nil only if encoding fails
    /// (never, for these value types).
    public func jsonlLine(encoder: JSONEncoder = SensorRecord.lineEncoder) -> Data? {
        guard var data = try? encoder.encode(self) else { return nil }
        data.append(0x0A)   // '\n'
        return data
    }

    /// Shared encoder: compact, stable key order off for speed. sloth
    /// consumers are key-order independent (JSON objects).
    public static let lineEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
}
