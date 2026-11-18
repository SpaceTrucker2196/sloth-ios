// RF records from the sloth-rf daemon's stream (jsonl 2.x, #14 / #15).
//
// Upstream contract: sloth `docs/wiki/jsonl-schema.md`, *State
// snapshot record types*, rows `gnss_fix`, `adsb_aircraft`,
// `aprs_station`, `rtl433_device`, `victron_device`; per-source pages
// `docs/wiki/{gnss,adsb,aprs,rtl433,victron}.md`.
//
// All five are change-only snapshots with a 300 s heartbeat. Every
// figure is omitted when unknown (never 0), so every field past the
// key is optional. `gnss_sky`, `gnss_sat` and `aprs_packet` are in
// RFSkyRecords.swift.

import Foundation

extension KeyedDecodingContainer {
    /// A value sloth writes "as written" (a JSON string or a number),
    /// read as text so either spelling decodes.
    func flexString(_ key: Key) throws -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return String(d) }
        return nil
    }
}

// MARK: - GNSS

/// The `--gps` receiver's newest fix. A singleton.
public struct GNSSFixEntry: Sendable, Codable, Equatable {
    public let type: String
    public let ts: Int
    public let src: String?
    /// 0 unknown, 1 none, 2 2D, 3 3D.
    public let mode: Int?
    public let nsat: Int?
    public let usat: Int?
    public let hdop: Double?
    public let lat: Double?
    public let lon: Double?
    public let altM: Double?
    public let speedMps: Double?
    public let trackDeg: Double?
    /// Receiver minus host wall clock, ms. Coarse; no PPS.
    public let timeOffMs: Int?
    /// u-blox jamming indicator, -1 absent.
    public let jam: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, mode, nsat, usat, hdop, lat, lon, jam
        case altM      = "alt_m"
        case speedMps  = "speed_mps"
        case trackDeg  = "track_deg"
        case timeOffMs = "time_off_ms"
    }

    public init(ts: Int, mode: Int? = nil, usat: Int? = nil, nsat: Int? = nil,
                hdop: Double? = nil, lat: Double? = nil, lon: Double? = nil,
                altM: Double? = nil, jam: Int? = nil) {
        self.type = "gnss_fix"; self.ts = ts; self.src = nil
        self.mode = mode; self.nsat = nsat; self.usat = usat; self.hdop = hdop
        self.lat = lat; self.lon = lon; self.altM = altM
        self.speedMps = nil; self.trackDeg = nil; self.timeOffMs = nil
        self.jam = jam
    }

    public var modeName: String {
        switch mode {
        case 3?: return "3D"
        case 2?: return "2D"
        case 1?: return "no fix"
        default: return "unknown"
        }
    }
}

// MARK: - ADS-B

/// One aircraft the `--adsb` decoder lists, keyed by `hex`.
public struct ADSBAircraftEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    public let hex: String
    /// `live`, or `gone` once when unheard for 60 s.
    public let state: String?
    public let flight: String?
    public let squawk: String?
    public let category: String?
    /// `none`, `general`, `lifeguard`, `minfuel`, `nordo`, `unlawful`,
    /// `downed`, `reserved`; `""` when the decoder never sent it.
    public let emergency: String?
    public let onGround: Int?
    public let altBaro: Double?
    public let gs: Double?
    public let track: Double?
    public let lat: Double?
    public let lon: Double?
    public let rssi: Double?
    public let messages: Int?
    public let lastSeen: Int?

    public var id: String { hex }
    public var isGone: Bool { state == "gone" }
    /// A real emergency, not `none` / absent.
    public var hasEmergency: Bool {
        guard let e = emergency, !e.isEmpty else { return false }
        return e != "none"
    }

    enum CodingKeys: String, CodingKey {
        case type, ts, hex, state, flight, squawk, category, emergency
        case gs, track, lat, lon, rssi, messages
        case onGround = "on_ground"
        case altBaro  = "alt_baro"
        case lastSeen = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type      = try c.decode(String.self, forKey: .type)
        ts        = try c.decode(Int.self, forKey: .ts)
        hex       = try c.decode(String.self, forKey: .hex)
        state     = try c.decodeIfPresent(String.self, forKey: .state)
        flight    = try c.decodeIfPresent(String.self, forKey: .flight)
        squawk    = try c.flexString(.squawk)
        category  = try c.decodeIfPresent(String.self, forKey: .category)
        emergency = try c.decodeIfPresent(String.self, forKey: .emergency)
        onGround  = try c.decodeIfPresent(Int.self, forKey: .onGround)
        altBaro   = try c.decodeIfPresent(Double.self, forKey: .altBaro)
        gs        = try c.decodeIfPresent(Double.self, forKey: .gs)
        track     = try c.decodeIfPresent(Double.self, forKey: .track)
        lat       = try c.decodeIfPresent(Double.self, forKey: .lat)
        lon       = try c.decodeIfPresent(Double.self, forKey: .lon)
        rssi      = try c.decodeIfPresent(Double.self, forKey: .rssi)
        messages  = try c.decodeIfPresent(Int.self, forKey: .messages)
        lastSeen  = try c.decodeIfPresent(Int.self, forKey: .lastSeen)
    }

    public init(ts: Int, hex: String, state: String? = "live",
                flight: String? = nil, squawk: String? = nil,
                emergency: String? = nil, altBaro: Double? = nil,
                gs: Double? = nil, lat: Double? = nil, lon: Double? = nil) {
        self.type = "adsb_aircraft"; self.ts = ts; self.hex = hex
        self.state = state; self.flight = flight; self.squawk = squawk
        self.category = nil; self.emergency = emergency; self.onGround = nil
        self.altBaro = altBaro; self.gs = gs; self.track = nil
        self.lat = lat; self.lon = lon; self.rssi = nil
        self.messages = nil; self.lastSeen = nil
    }
}

// MARK: - APRS

/// One APRS station (a packet's `source`), keyed by `call`.
public struct APRSStationEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    public let call: String
    /// `live`, or `gone` once when unheard for 3600 s.
    public let state: String?
    public let packets: Int?
    public let lastSeen: Int?
    public let heardDirect: Int?
    public let symbol: String?
    public let lat: Double?
    public let lon: Double?
    public let speedKt: Double?
    public let altM: Double?
    public let status: String?
    public let comment: String?

    public var id: String { call }
    public var isGone: Bool { state == "gone" }

    enum CodingKeys: String, CodingKey {
        case type, ts, call, state, packets, symbol, lat, lon, status, comment
        case lastSeen    = "last_seen"
        case heardDirect = "heard_direct"
        case speedKt     = "speed_kt"
        case altM        = "alt_m"
    }

    public init(ts: Int, call: String, state: String? = "live",
                packets: Int? = nil, heardDirect: Int? = nil,
                lat: Double? = nil, lon: Double? = nil, comment: String? = nil) {
        self.type = "aprs_station"; self.ts = ts; self.call = call
        self.state = state; self.packets = packets; self.lastSeen = nil
        self.heardDirect = heardDirect; self.symbol = nil
        self.lat = lat; self.lon = lon; self.speedKt = nil; self.altM = nil
        self.status = nil; self.comment = comment
    }
}

// MARK: - rtl_433

/// One sub-GHz device rtl_433 decoded, keyed by `model` + `id`.
/// Readings go out under the unit they arrived in and are never
/// converted, so both temperature spellings are kept.
public struct RTL433DeviceEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    public let model: String
    /// "As written": an integer id arrives as a number, others as text.
    public let deviceID: String
    public let msgs: Int?
    public let lastSeen: Int?
    public let channel: String?
    public let freqMHz: Double?
    public let rssi: Double?
    public let batteryOK: Double?
    public let temperatureC: Double?
    public let temperatureF: Double?
    public let humidity: Double?

    public var id: String { model + "/" + deviceID }

    enum CodingKeys: String, CodingKey {
        case type, ts, model, msgs, channel, rssi, humidity
        case deviceID     = "id"
        case lastSeen     = "last_seen"
        case freqMHz      = "freq_mhz"
        case batteryOK    = "battery_ok"
        case temperatureC = "temperature_C"
        case temperatureF = "temperature_F"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type         = try c.decode(String.self, forKey: .type)
        ts           = try c.decode(Int.self, forKey: .ts)
        model        = try c.decode(String.self, forKey: .model)
        guard let d  = try c.flexString(.deviceID) else {
            throw DecodingError.keyNotFound(CodingKeys.deviceID,
                .init(codingPath: c.codingPath, debugDescription: "rtl433_device without id"))
        }
        deviceID     = d
        msgs         = try c.decodeIfPresent(Int.self, forKey: .msgs)
        lastSeen     = try c.decodeIfPresent(Int.self, forKey: .lastSeen)
        channel      = try c.flexString(.channel)
        freqMHz      = try c.decodeIfPresent(Double.self, forKey: .freqMHz)
        rssi         = try c.decodeIfPresent(Double.self, forKey: .rssi)
        batteryOK    = try c.decodeIfPresent(Double.self, forKey: .batteryOK)
        temperatureC = try c.decodeIfPresent(Double.self, forKey: .temperatureC)
        temperatureF = try c.decodeIfPresent(Double.self, forKey: .temperatureF)
        humidity     = try c.decodeIfPresent(Double.self, forKey: .humidity)
    }

    public init(ts: Int, model: String, deviceID: String,
                temperatureC: Double? = nil, humidity: Double? = nil,
                batteryOK: Double? = nil) {
        self.type = "rtl433_device"; self.ts = ts
        self.model = model; self.deviceID = deviceID
        self.msgs = nil; self.lastSeen = nil; self.channel = nil
        self.freqMHz = nil; self.rssi = nil; self.batteryOK = batteryOK
        self.temperatureC = temperatureC; self.temperatureF = nil
        self.humidity = humidity
    }
}

// MARK: - Victron

/// One Victron device row (sloth-va's output), keyed by `mac`.
/// Values are sticky upstream: a record without one does not erase it.
public struct VictronDeviceEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    public let mac: String
    public let model: String?
    public let lastSeen: Int?
    public let rssi: Double?
    public let voltageV: Double?
    public let currentA: Double?
    public let powerW: Double?
    public let socPct: Double?
    public let ttgMin: Double?
    public let temperatureC: Double?
    public let acVoltageV: Double?
    public let acCurrentA: Double?
    public let acApparentVA: Double?
    public let deviceState: String?

    public var id: String { mac }

    enum CodingKeys: String, CodingKey {
        case type, ts, mac, model, rssi
        case lastSeen     = "last_seen"
        case voltageV     = "voltage_v"
        case currentA     = "current_a"
        case powerW       = "power_w"
        case socPct       = "soc_pct"
        case ttgMin       = "ttg_min"
        case temperatureC = "temperature_c"
        case acVoltageV   = "ac_voltage_v"
        case acCurrentA   = "ac_current_a"
        case acApparentVA = "ac_apparent_va"
        case deviceState  = "device_state"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type         = try c.decode(String.self, forKey: .type)
        ts           = try c.decode(Int.self, forKey: .ts)
        mac          = try c.decode(String.self, forKey: .mac)
        model        = try c.flexString(.model)
        lastSeen     = try c.decodeIfPresent(Int.self, forKey: .lastSeen)
        rssi         = try c.decodeIfPresent(Double.self, forKey: .rssi)
        voltageV     = try c.decodeIfPresent(Double.self, forKey: .voltageV)
        currentA     = try c.decodeIfPresent(Double.self, forKey: .currentA)
        powerW       = try c.decodeIfPresent(Double.self, forKey: .powerW)
        socPct       = try c.decodeIfPresent(Double.self, forKey: .socPct)
        ttgMin       = try c.decodeIfPresent(Double.self, forKey: .ttgMin)
        temperatureC = try c.decodeIfPresent(Double.self, forKey: .temperatureC)
        acVoltageV   = try c.decodeIfPresent(Double.self, forKey: .acVoltageV)
        acCurrentA   = try c.decodeIfPresent(Double.self, forKey: .acCurrentA)
        acApparentVA = try c.decodeIfPresent(Double.self, forKey: .acApparentVA)
        deviceState  = try c.flexString(.deviceState)
    }

    public init(ts: Int, mac: String, model: String? = nil,
                voltageV: Double? = nil, socPct: Double? = nil,
                acVoltageV: Double? = nil) {
        self.type = "victron_device"; self.ts = ts; self.mac = mac
        self.model = model; self.lastSeen = nil; self.rssi = nil
        self.voltageV = voltageV; self.currentA = nil; self.powerW = nil
        self.socPct = socPct; self.ttgMin = nil; self.temperatureC = nil
        self.acVoltageV = acVoltageV; self.acCurrentA = nil
        self.acApparentVA = nil; self.deviceState = nil
    }
}
