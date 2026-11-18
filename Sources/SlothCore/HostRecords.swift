// Host status and the source inventory (sloth jsonl 1.1.0+, #14).
//
// Upstream contract: sloth `docs/wiki/jsonl-schema.md`, *Host status
// and the source inventory*. Four record types, one batch per 60 s
// carrying a shared `seq`: a `sys_status`, its `sys_sensor` rows, every
// `source_status`, every `receiver_hw`. Both daemons write them, with
// no `daemon` field, so the store keys them on the stream they came in
// on.
//
// A reading the host does not have is absent, never 0, so every field
// past the key is optional.

import Foundation

// MARK: - sys_status

public struct SysStatusEntry: Sendable, Codable, Equatable {
    public let type: String
    public let ts: Int
    public let seq: Int
    public let intervalS: Int?
    public let cpuPct: Double?
    public let cpuIowaitPct: Double?
    /// `low`, `busy`, `high`, `saturated`.
    public let cpuBand: String?
    public let load1: Double?
    public let memTotalKB: Int?
    public let memAvailKB: Int?
    /// `ok`, `low`, `critical`.
    public let memBand: String?
    public let uptimeS: Int?
    public let rssKB: Int?
    public let diskFor: String?
    public let diskFreeMB: Int?
    public let diskTotalMB: Int?
    public let diskBand: String?
    public let tempMaxC: Double?
    public let tempMaxID: String?
    /// `ok`, `warm`, `hot`, `critical`.
    public let tempBand: String?
    /// Absent on a host with no under-voltage alarm node.
    public let undervolt: Int?
    public let sources: Int?
    public let sourcesConfigured: Int?
    public let sourcesOK: Int?
    public let sourcesDown: Int?
    public let receivers: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, seq, load1, undervolt, sources, receivers
        case intervalS         = "interval_s"
        case cpuPct            = "cpu_pct"
        case cpuIowaitPct      = "cpu_iowait_pct"
        case cpuBand           = "cpu_band"
        case memTotalKB        = "mem_total_kb"
        case memAvailKB        = "mem_avail_kb"
        case memBand           = "mem_band"
        case uptimeS           = "uptime_s"
        case rssKB             = "rss_kb"
        case diskFor           = "disk_for"
        case diskFreeMB        = "disk_free_mb"
        case diskTotalMB       = "disk_total_mb"
        case diskBand          = "disk_band"
        case tempMaxC          = "temp_max_c"
        case tempMaxID         = "temp_max_id"
        case tempBand          = "temp_band"
        case sourcesConfigured = "sources_configured"
        case sourcesOK         = "sources_ok"
        case sourcesDown       = "sources_down"
    }

    public init(ts: Int, seq: Int, cpuPct: Double? = nil, cpuBand: String? = nil,
                load1: Double? = nil, memTotalKB: Int? = nil, memAvailKB: Int? = nil,
                memBand: String? = nil, uptimeS: Int? = nil,
                diskFreeMB: Int? = nil, diskTotalMB: Int? = nil, diskBand: String? = nil,
                tempMaxC: Double? = nil, tempBand: String? = nil, undervolt: Int? = nil,
                sourcesOK: Int? = nil, sourcesDown: Int? = nil) {
        self.type = "sys_status"; self.ts = ts; self.seq = seq
        self.intervalS = 60; self.cpuPct = cpuPct; self.cpuIowaitPct = nil
        self.cpuBand = cpuBand; self.load1 = load1
        self.memTotalKB = memTotalKB; self.memAvailKB = memAvailKB; self.memBand = memBand
        self.uptimeS = uptimeS; self.rssKB = nil; self.diskFor = nil
        self.diskFreeMB = diskFreeMB; self.diskTotalMB = diskTotalMB; self.diskBand = diskBand
        self.tempMaxC = tempMaxC; self.tempMaxID = nil; self.tempBand = tempBand
        self.undervolt = undervolt; self.sources = nil; self.sourcesConfigured = nil
        self.sourcesOK = sourcesOK; self.sourcesDown = sourcesDown; self.receivers = nil
    }

    /// Share of memory in use, 0–100. Nil when either figure is absent.
    public var memUsedPct: Double? {
        guard let t = memTotalKB, let a = memAvailKB, t > 0 else { return nil }
        return Double(t - a) / Double(t) * 100
    }

    /// Plain-language host problems: any band past its first step, and
    /// the firmware's under-voltage flag. Empty when the host is fine.
    public var problems: [String] {
        var out: [String] = []
        if undervolt == 1 { out.append("under-voltage") }
        if let b = tempBand, b != "ok" { out.append("temp \(b)") }
        if let b = cpuBand, b == "high" || b == "saturated" { out.append("cpu \(b)") }
        if let b = memBand, b != "ok" { out.append("memory \(b)") }
        if let b = diskBand, b != "ok" { out.append("disk \(b)") }
        if let n = sourcesDown, n > 0 { out.append("\(n) source\(n == 1 ? "" : "s") down") }
        return out
    }
}

// MARK: - sys_sensor

public struct SysSensorEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    public let seq: Int
    /// `temp`, `volt` or `power`.
    public let `class`: String
    public let id: String
    public let label: String?
    public let c: Double?
    public let v: Double?
    public let alarm: Int?
    public let capacity: Int?
    public let status: String?

    public init(ts: Int, seq: Int, class cls: String, id: String, label: String? = nil,
                c: Double? = nil, v: Double? = nil, alarm: Int? = nil,
                capacity: Int? = nil, status: String? = nil) {
        self.type = "sys_sensor"; self.ts = ts; self.seq = seq
        self.class = cls; self.id = id; self.label = label
        self.c = c; self.v = v; self.alarm = alarm
        self.capacity = capacity; self.status = status
    }
}

// MARK: - source_status

public struct SourceStatusEntry: Sendable, Codable, Equatable, Identifiable {

    public enum State: String, Sendable {
        case ok, stale, down
        case notConfigured = "not_configured"
    }

    public let type: String
    public let ts: Int
    public let seq: Int
    public let name: String
    public let kind: String?
    public let flag: String?
    /// Free text so a new state never fails the decode; read through
    /// `stateValue`.
    public let state: String
    public let detail: String?
    public let endpoint: String?
    public let desc: String?
    public let ageS: Int?
    /// `never`, `fresh`, `stale`, `old`.
    public let ageBand: String?
    public let unit: String?
    public let count: Int?
    public let rate: Double?
    public let errors: Int?

    public var id: String { name }
    public var stateValue: State? { State(rawValue: state) }

    enum CodingKeys: String, CodingKey {
        case type, ts, seq, name, kind, flag, state, detail, endpoint, desc
        case unit, count, rate, errors
        case ageS    = "age_s"
        case ageBand = "age_band"
    }

    public init(ts: Int, seq: Int, name: String, kind: String? = nil,
                flag: String? = nil, state: String, detail: String? = nil,
                endpoint: String? = nil, ageS: Int? = nil, ageBand: String? = nil,
                unit: String? = nil, count: Int? = nil, rate: Double? = nil,
                errors: Int? = nil) {
        self.type = "source_status"; self.ts = ts; self.seq = seq
        self.name = name; self.kind = kind; self.flag = flag
        self.state = state; self.detail = detail; self.endpoint = endpoint
        self.desc = nil; self.ageS = ageS; self.ageBand = ageBand
        self.unit = unit; self.count = count; self.rate = rate; self.errors = errors
    }
}

// MARK: - receiver_hw

public struct ReceiverHWEntry: Sendable, Codable, Equatable, Identifiable {
    public let type: String
    public let ts: Int
    public let seq: Int
    /// `usb:1-1.2`, `net:wlan0`, `bt:hci0`.
    public let key: String
    /// `sdr`, `gnss`, `serial`, `wifi`, `bluetooth`, `bluetooth-sniffer`.
    public let kind: String?
    public let bus: String?
    public let usbID: String?
    public let known: Int?
    public let desc: String?
    /// Device-supplied text; sloth bounds it to printable ASCII.
    public let vendor: String?
    public let product: String?
    public let driver: String?
    public let ifaces: String?

    public var id: String { key }

    /// The best name there is: sloth's table, then the device's own
    /// strings, then the driver.
    public var displayName: String {
        if let d = desc, !d.isEmpty { return d }
        let own = [vendor, product].compactMap { $0 }.filter { !$0.isEmpty }
        if !own.isEmpty { return own.joined(separator: " ") }
        return driver ?? key
    }

    enum CodingKeys: String, CodingKey {
        case type, ts, seq, key, kind, bus, known, desc, vendor, product, driver, ifaces
        case usbID = "id"
    }

    public init(ts: Int, seq: Int, key: String, kind: String? = nil, desc: String? = nil,
                vendor: String? = nil, product: String? = nil, driver: String? = nil,
                ifaces: String? = nil) {
        self.type = "receiver_hw"; self.ts = ts; self.seq = seq
        self.key = key; self.kind = kind; self.bus = nil; self.usbID = nil
        self.known = nil; self.desc = desc; self.vendor = vendor
        self.product = product; self.driver = driver; self.ifaces = ifaces
    }
}

// MARK: - One daemon's host report

/// The newest batch from one daemon. A sensor or receiver that left
/// the host is simply not in the next batch, so those two tables are
/// replaced on a new `seq`. Source rows are a fixed set keyed on name
/// and also arrive between batches, so they are replaced per row.
public struct HostReport: Sendable, Equatable {
    public private(set) var seq: Int = 0
    public private(set) var status: SysStatusEntry?
    public private(set) var sensors: [SysSensorEntry] = []
    public private(set) var sources: [String: SourceStatusEntry] = [:]
    public private(set) var receivers: [ReceiverHWEntry] = []

    public init() {}

    /// Sources in the schema's order, configured ones first.
    public var sourceList: [SourceStatusEntry] {
        sources.values.sorted {
            let a = $0.stateValue == .notConfigured, b = $1.stateValue == .notConfigured
            if a != b { return !a }
            return $0.name < $1.name
        }
    }

    private mutating func startBatch(_ newSeq: Int) {
        seq = newSeq
        sensors.removeAll()
        receivers.removeAll()
    }

    private mutating func advance(to newSeq: Int) {
        if newSeq > seq { startBatch(newSeq) }
    }

    /// `sys_status` opens each batch. Any other `seq`, lower included,
    /// starts a new one: a restarted daemon counts from 1 again.
    mutating func apply(_ e: SysStatusEntry) {
        if e.seq != seq { startBatch(e.seq) }
        status = e
    }

    mutating func apply(_ e: SysSensorEntry) {
        advance(to: e.seq)
        guard e.seq == seq else { return }
        sensors.removeAll { $0.id == e.id }
        sensors.append(e)
    }

    mutating func apply(_ e: SourceStatusEntry) { sources[e.name] = e }

    mutating func apply(_ e: ReceiverHWEntry) {
        advance(to: e.seq)
        guard e.seq == seq else { return }
        receivers.removeAll { $0.key == e.key }
        receivers.append(e)
    }
}
