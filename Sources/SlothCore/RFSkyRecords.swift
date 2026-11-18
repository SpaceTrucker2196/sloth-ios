// GNSS sky and APRS packet records from sloth-rf (#14).
//
// Upstream contract: sloth `docs/wiki/jsonl-schema.md` rows `gnss_sky`,
// `gnss_sat`, `aprs_packet`; `docs/wiki/gnss.md` *The records* and
// `docs/wiki/aprs.md` *JSONL*. Every figure is absent when unknown,
// never 0 or -1 (`el` / `az` / `cn0` included), so all are optional.

import Foundation

// MARK: - gnss_sky

/// The newest SKY pass's summary. A singleton, change-only on bands.
public struct GNSSSkyEntry: Sendable, Codable, Equatable {
    public let type: String
    public let ts: Int
    public let nsat: Int?
    public let usat: Int?
    public let rows: Int?
    public let overflow: Int?
    public let hdop: Double?
    public let vdop: Double?
    public let pdop: Double?
    public let cn0Mean: Double?
    public let cn0Max: Double?

    enum CodingKeys: String, CodingKey {
        case type, ts, nsat, usat, rows, overflow, hdop, vdop, pdop
        case cn0Mean = "cn0_mean"
        case cn0Max  = "cn0_max"
    }

    public init(ts: Int, nsat: Int? = nil, usat: Int? = nil,
                pdop: Double? = nil, cn0Mean: Double? = nil) {
        self.type = "gnss_sky"; self.ts = ts
        self.nsat = nsat; self.usat = usat; self.rows = nil; self.overflow = nil
        self.hdop = nil; self.vdop = nil; self.pdop = pdop
        self.cn0Mean = cn0Mean; self.cn0Max = nil
    }
}

// MARK: - gnss_sat

/// One satellite in view, keyed `gnssid` + `prn`. A satellite that
/// sets writes nothing: its row stops coming, and the store drops it
/// once its 300 s heartbeat has lapsed twice (`satQuietDrop`).
public struct GNSSSatEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    /// `GPS`, `Galileo`, `GLONASS`, …; `""` when gpsd sent no gnssid.
    public let gnss: String?
    public let gnssid: Int?
    public let svid: Int?
    public let prn: Int
    public let el: Double?
    public let az: Double?
    /// dB-Hz; absent when listed but not tracked.
    public let cn0: Double?
    public let used: Int?
    /// 0 unknown, 1 ok, 2 unhealthy, -1 absent.
    public let health: Int?

    public var id: String { "\(gnssid ?? -1)/\(prn)" }
    public var isUsed: Bool { used == 1 }

    /// Constellation and number, e.g. `Galileo 11`.
    public var label: String {
        if let g = gnss, !g.isEmpty { return "\(g) \(svid ?? prn)" }
        return "PRN \(prn)"
    }

    public init(ts: Int, gnss: String? = nil, gnssid: Int? = nil, svid: Int? = nil,
                prn: Int, el: Double? = nil, az: Double? = nil, cn0: Double? = nil,
                used: Int? = nil, health: Int? = nil) {
        self.type = "gnss_sat"; self.ts = ts
        self.gnss = gnss; self.gnssid = gnssid; self.svid = svid; self.prn = prn
        self.el = el; self.az = az; self.cn0 = cn0; self.used = used; self.health = health
    }
}

// MARK: - aprs_packet

/// One packet Dire Wolf decoded. An event, not a table row: the store
/// keeps a short in-memory tail only (MISSION §2: nothing persisted).
public struct APRSPacketEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    /// sloth's packet count from 1, per process.
    public let seq: Int
    public let utime: Int?
    public let source: String
    /// The station heard on the air: the source, or the digipeater.
    public let heard: String?
    public let direct: Int?
    public let level: String?
    /// APRS101 data type indicator, one byte.
    public let dti: String?
    /// Object or item name, else the source.
    public let name: String?
    public let symbol: String?
    public let lat: Double?
    public let lon: Double?
    public let speedKt: Double?
    public let course: Double?
    public let altM: Double?
    public let status: String?
    public let comment: String?

    public var id: String { "\(seq)/\(ts)" }

    enum CodingKeys: String, CodingKey {
        case type, ts, seq, utime, source, heard, direct, level, dti, name
        case symbol, lat, lon, course, status, comment
        case speedKt = "speed_kt"
        case altM    = "alt_m"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        ts = try c.decode(Int.self, forKey: .ts)
        seq = try c.decode(Int.self, forKey: .seq)
        utime = try c.decodeIfPresent(Int.self, forKey: .utime)
        source = try c.decode(String.self, forKey: .source)
        heard = try c.decodeIfPresent(String.self, forKey: .heard)
        direct = try c.decodeIfPresent(Int.self, forKey: .direct)
        // Dire Wolf's audio level is written as it came (`48(12/9)` or a number).
        level = try c.flexString(.level)
        dti = try c.decodeIfPresent(String.self, forKey: .dti)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lon = try c.decodeIfPresent(Double.self, forKey: .lon)
        speedKt = try c.decodeIfPresent(Double.self, forKey: .speedKt)
        course = try c.decodeIfPresent(Double.self, forKey: .course)
        altM = try c.decodeIfPresent(Double.self, forKey: .altM)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        comment = try c.decodeIfPresent(String.self, forKey: .comment)
    }

    public init(ts: Int, seq: Int, source: String, heard: String? = nil,
                direct: Int? = nil, name: String? = nil, comment: String? = nil) {
        self.type = "aprs_packet"; self.ts = ts; self.seq = seq; self.utime = nil
        self.source = source; self.heard = heard; self.direct = direct
        self.level = nil; self.dti = nil; self.name = name; self.symbol = nil
        self.lat = nil; self.lon = nil; self.speedKt = nil; self.course = nil
        self.altM = nil; self.status = nil; self.comment = comment
    }

    /// `KD0ABC-9`, or `KD0ABC-9 › OBJNAME` for an object or item.
    public var title: String {
        guard let n = name, !n.isEmpty, n != source else { return source }
        return "\(source) › \(n)"
    }
}
