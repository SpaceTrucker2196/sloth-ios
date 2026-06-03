// SlothRecord — Codable sum type for every sloth JSONL record.
//
// Envelope: { "type": "<type>", "ts": <unix-seconds>, ... }
// See docs/wiki/jsonl-protocol.md for the consumer-side contract and
// link to sloth's authoritative schema page.
//
// Forward-compat:
//   * Unknown `type` values decode to `.unknown(type:, ts:)`, not an
//     error — sloth may grow new record types.
//   * Unknown keys inside known records are ignored (Codable default).
//
// Each sub-struct lists *only* the fields sloth-ios currently consumes.
// Fields are optional where the upstream record can legally omit them
// (e.g. DNS response with no answer, ICMP without a payload). When a
// new field is needed, add it as optional and ignore older streams.

import Foundation

public enum SlothRecord: Sendable, Equatable {
    case dns(DNSEntry)
    case tls(TLSEntry)
    case quic(QUICEntry)
    case http(HTTPEntry)
    case ntp(NTPEntry)
    case icmp(ICMPEntry)
    case alert(AlertEntry)
    case connections(ConnectionEntry)
    case iface(IFaceEntry)
    case device(DeviceEntry)
    case beacon(BeaconEntry)
    case twinEpisode(TwinEpisodeEntry)
    case topHost(TopHostEntry)
    case process(ProcessEntry)
    case deauth(DeauthEntry)
    case mdnsService(MDNSServiceEntry)
    case dhcpLease(DHCPLeaseEntry)
    case unknown(type: String, ts: Int)

    public var ts: Int {
        switch self {
        case .dns        (let e): return e.ts
        case .tls        (let e): return e.ts
        case .quic       (let e): return e.ts
        case .http       (let e): return e.ts
        case .ntp        (let e): return e.ts
        case .icmp       (let e): return e.ts
        case .alert      (let e): return e.ts
        case .connections(let e): return e.ts
        case .iface      (let e): return e.ts
        case .device     (let e): return e.ts
        case .beacon     (let e): return e.ts
        case .twinEpisode(let e): return e.ts
        case .topHost    (let e): return e.ts
        case .process    (let e): return e.ts
        case .deauth     (let e): return e.ts
        case .mdnsService(let e): return e.ts
        case .dhcpLease  (let e): return e.ts
        case .unknown(_, let ts): return ts
        }
    }

    public var typeTag: String {
        switch self {
        case .dns:         return "dns"
        case .tls:         return "tls"
        case .quic:        return "quic"
        case .http:        return "http"
        case .ntp:         return "ntp"
        case .icmp:        return "icmp"
        case .alert:       return "alert"
        case .connections: return "connections"
        case .iface:       return "iface"
        case .device:      return "device"
        case .beacon:      return "beacon"
        case .twinEpisode: return "twin_episode"
        case .topHost:     return "top_host"
        case .process:     return "process"
        case .deauth:      return "deauth"
        case .mdnsService: return "mdns_service"
        case .dhcpLease:   return "dhcp_lease"
        case .unknown(let t, _): return t
        }
    }
}

extension SlothRecord {
    /// Two-field envelope shared by the decode discriminator path and
    /// the `.unknown` re-encode path. Both need `type`; `.unknown`
    /// re-encode also needs `ts` so round-tripping a future record
    /// preserves its timestamp.
    fileprivate enum EnvelopeKey: String, CodingKey { case type, ts }
}

extension SlothRecord: Decodable {
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: EnvelopeKey.self)
        let tag = try c.decode(String.self, forKey: .type)
        switch tag {
        case "dns":   self = .dns  (try DNSEntry  (from: decoder))
        case "tls":   self = .tls  (try TLSEntry  (from: decoder))
        case "quic":  self = .quic (try QUICEntry (from: decoder))
        case "http":  self = .http (try HTTPEntry (from: decoder))
        case "ntp":   self = .ntp  (try NTPEntry  (from: decoder))
        case "icmp":  self = .icmp (try ICMPEntry (from: decoder))
        case "alert":       self = .alert      (try AlertEntry      (from: decoder))
        case "connections": self = .connections(try ConnectionEntry (from: decoder))
        case "iface":       self = .iface      (try IFaceEntry      (from: decoder))
        case "device":      self = .device     (try DeviceEntry     (from: decoder))
        case "beacon":      self = .beacon     (try BeaconEntry     (from: decoder))
        case "twin_episode":self = .twinEpisode(try TwinEpisodeEntry(from: decoder))
        case "top_host":    self = .topHost    (try TopHostEntry    (from: decoder))
        case "process":     self = .process    (try ProcessEntry    (from: decoder))
        case "deauth":      self = .deauth     (try DeauthEntry     (from: decoder))
        case "mdns_service":self = .mdnsService(try MDNSServiceEntry(from: decoder))
        case "dhcp_lease":  self = .dhcpLease  (try DHCPLeaseEntry  (from: decoder))
        default:
            let ts = try c.decode(Int.self, forKey: .ts)
            self = .unknown(type: tag, ts: ts)
        }
    }
}

extension SlothRecord: Encodable {
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .dns  (let e): try e.encode(to: encoder)
        case .tls  (let e): try e.encode(to: encoder)
        case .quic (let e): try e.encode(to: encoder)
        case .http (let e): try e.encode(to: encoder)
        case .ntp  (let e): try e.encode(to: encoder)
        case .icmp (let e): try e.encode(to: encoder)
        case .alert      (let e): try e.encode(to: encoder)
        case .connections(let e): try e.encode(to: encoder)
        case .iface      (let e): try e.encode(to: encoder)
        case .device     (let e): try e.encode(to: encoder)
        case .beacon     (let e): try e.encode(to: encoder)
        case .twinEpisode(let e): try e.encode(to: encoder)
        case .topHost    (let e): try e.encode(to: encoder)
        case .process    (let e): try e.encode(to: encoder)
        case .deauth     (let e): try e.encode(to: encoder)
        case .mdnsService(let e): try e.encode(to: encoder)
        case .dhcpLease  (let e): try e.encode(to: encoder)
        case .unknown(let t, let ts):
            var c = encoder.container(keyedBy: EnvelopeKey.self)
            try c.encode(t,  forKey: .type)
            try c.encode(ts, forKey: .ts)
        }
    }
}

// MARK: - Record types

public struct DNSEntry: Sendable, Codable, Equatable {
    public var type: String { "dns" }
    public let ts: Int
    public let src: String?
    public let qname: String
    public let qtype: String?
    public let answer: String?
    public let rcode: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, qname, qtype, answer, rcode
    }

    public init(ts: Int, src: String? = nil, qname: String,
                qtype: String? = nil, answer: String? = nil,
                rcode: Int? = nil) {
        self.ts = ts; self.src = src; self.qname = qname
        self.qtype = qtype; self.answer = answer; self.rcode = rcode
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts     = try c.decode(Int.self,    forKey: .ts)
        self.src    = try c.decodeIfPresent(String.self, forKey: .src)
        self.qname  = try c.decode(String.self, forKey: .qname)
        self.qtype  = try c.decodeIfPresent(String.self, forKey: .qtype)
        self.answer = try c.decodeIfPresent(String.self, forKey: .answer)
        self.rcode  = try c.decodeIfPresent(Int.self,    forKey: .rcode)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,    forKey: .ts)
        try c.encodeIfPresent(src,    forKey: .src)
        try c.encode(qname, forKey: .qname)
        try c.encodeIfPresent(qtype,  forKey: .qtype)
        try c.encodeIfPresent(answer, forKey: .answer)
        try c.encodeIfPresent(rcode,  forKey: .rcode)
    }
}

public struct TLSEntry: Sendable, Codable, Equatable {
    public var type: String { "tls" }
    public let ts: Int
    public let src: String?
    public let dst: String?
    public let sni: String?
    public let version: String?
    public let ja3: String?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, sni, version, ja3
    }

    public init(ts: Int, src: String? = nil, dst: String? = nil,
                sni: String? = nil, version: String? = nil,
                ja3: String? = nil) {
        self.ts = ts; self.src = src; self.dst = dst
        self.sni = sni; self.version = version; self.ja3 = ja3
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts      = try c.decode(Int.self, forKey: .ts)
        self.src     = try c.decodeIfPresent(String.self, forKey: .src)
        self.dst     = try c.decodeIfPresent(String.self, forKey: .dst)
        self.sni     = try c.decodeIfPresent(String.self, forKey: .sni)
        self.version = try c.decodeIfPresent(String.self, forKey: .version)
        self.ja3     = try c.decodeIfPresent(String.self, forKey: .ja3)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts, forKey: .ts)
        try c.encodeIfPresent(src,     forKey: .src)
        try c.encodeIfPresent(dst,     forKey: .dst)
        try c.encodeIfPresent(sni,     forKey: .sni)
        try c.encodeIfPresent(version, forKey: .version)
        try c.encodeIfPresent(ja3,     forKey: .ja3)
    }
}

public struct QUICEntry: Sendable, Codable, Equatable {
    public var type: String { "quic" }
    public let ts: Int
    public let src: String?
    public let dst: String?
    public let sni: String?
    public let version: String?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, sni, version
    }

    public init(ts: Int, src: String? = nil, dst: String? = nil,
                sni: String? = nil, version: String? = nil) {
        self.ts = ts; self.src = src; self.dst = dst
        self.sni = sni; self.version = version
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts      = try c.decode(Int.self, forKey: .ts)
        self.src     = try c.decodeIfPresent(String.self, forKey: .src)
        self.dst     = try c.decodeIfPresent(String.self, forKey: .dst)
        self.sni     = try c.decodeIfPresent(String.self, forKey: .sni)
        self.version = try c.decodeIfPresent(String.self, forKey: .version)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts, forKey: .ts)
        try c.encodeIfPresent(src,     forKey: .src)
        try c.encodeIfPresent(dst,     forKey: .dst)
        try c.encodeIfPresent(sni,     forKey: .sni)
        try c.encodeIfPresent(version, forKey: .version)
    }
}

public struct HTTPEntry: Sendable, Codable, Equatable {
    public var type: String { "http" }
    public let ts: Int
    public let src: String?
    public let dst: String?
    public let host: String?
    public let method: String?
    public let path: String?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, host, method, path
    }

    public init(ts: Int, src: String? = nil, dst: String? = nil,
                host: String? = nil, method: String? = nil,
                path: String? = nil) {
        self.ts = ts; self.src = src; self.dst = dst
        self.host = host; self.method = method; self.path = path
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts     = try c.decode(Int.self, forKey: .ts)
        self.src    = try c.decodeIfPresent(String.self, forKey: .src)
        self.dst    = try c.decodeIfPresent(String.self, forKey: .dst)
        self.host   = try c.decodeIfPresent(String.self, forKey: .host)
        self.method = try c.decodeIfPresent(String.self, forKey: .method)
        self.path   = try c.decodeIfPresent(String.self, forKey: .path)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts, forKey: .ts)
        try c.encodeIfPresent(src,    forKey: .src)
        try c.encodeIfPresent(dst,    forKey: .dst)
        try c.encodeIfPresent(host,   forKey: .host)
        try c.encodeIfPresent(method, forKey: .method)
        try c.encodeIfPresent(path,   forKey: .path)
    }
}

public struct NTPEntry: Sendable, Codable, Equatable {
    public var type: String { "ntp" }
    public let ts: Int
    public let src: String?
    public let dst: String?
    public let stratum: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, stratum
    }

    public init(ts: Int, src: String? = nil, dst: String? = nil,
                stratum: Int? = nil) {
        self.ts = ts; self.src = src; self.dst = dst; self.stratum = stratum
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts      = try c.decode(Int.self, forKey: .ts)
        self.src     = try c.decodeIfPresent(String.self, forKey: .src)
        self.dst     = try c.decodeIfPresent(String.self, forKey: .dst)
        self.stratum = try c.decodeIfPresent(Int.self,    forKey: .stratum)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts, forKey: .ts)
        try c.encodeIfPresent(src,     forKey: .src)
        try c.encodeIfPresent(dst,     forKey: .dst)
        try c.encodeIfPresent(stratum, forKey: .stratum)
    }
}

public struct ICMPEntry: Sendable, Codable, Equatable {
    public var type: String { "icmp" }
    public let ts: Int
    public let src: String?
    public let dst: String?
    public let icmpType: Int?
    public let code: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, code
        case icmpType = "itype"
    }

    public init(ts: Int, src: String? = nil, dst: String? = nil,
                icmpType: Int? = nil, code: Int? = nil) {
        self.ts = ts; self.src = src; self.dst = dst
        self.icmpType = icmpType; self.code = code
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts       = try c.decode(Int.self, forKey: .ts)
        self.src      = try c.decodeIfPresent(String.self, forKey: .src)
        self.dst      = try c.decodeIfPresent(String.self, forKey: .dst)
        self.icmpType = try c.decodeIfPresent(Int.self,    forKey: .icmpType)
        self.code     = try c.decodeIfPresent(Int.self,    forKey: .code)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts, forKey: .ts)
        try c.encodeIfPresent(src,      forKey: .src)
        try c.encodeIfPresent(dst,      forKey: .dst)
        try c.encodeIfPresent(icmpType, forKey: .icmpType)
        try c.encodeIfPresent(code,     forKey: .code)
    }
}

public struct AlertEntry: Sendable, Codable, Equatable {
    public var type: String { "alert" }
    public let ts: Int
    public let title: String
    public let detail: String?
    public let key: String?
    public let hits: Int
    public let firstSeen: Int
    public let lastSeen: Int
    public let matchIP: String?
    public let sev: Int

    public var severity: AlertSeverity {
        AlertSeverity(rawValue: sev) ?? .low
    }

    enum CodingKeys: String, CodingKey {
        case type, ts, title, detail, key, hits, sev
        case firstSeen = "first_seen"
        case lastSeen  = "last_seen"
        case matchIP   = "match_ip"
    }

    public init(ts: Int, title: String, detail: String? = nil,
                key: String? = nil, hits: Int = 1,
                firstSeen: Int, lastSeen: Int,
                matchIP: String? = nil, sev: Int) {
        self.ts = ts; self.title = title; self.detail = detail
        self.key = key; self.hits = hits
        self.firstSeen = firstSeen; self.lastSeen = lastSeen
        self.matchIP = matchIP; self.sev = sev
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts        = try c.decode(Int.self,    forKey: .ts)
        self.title     = try c.decode(String.self, forKey: .title)
        self.detail    = try c.decodeIfPresent(String.self, forKey: .detail)
        self.key       = try c.decodeIfPresent(String.self, forKey: .key)
        self.hits      = try c.decodeIfPresent(Int.self,    forKey: .hits) ?? 1
        self.firstSeen = try c.decode(Int.self,    forKey: .firstSeen)
        self.lastSeen  = try c.decode(Int.self,    forKey: .lastSeen)
        self.matchIP   = try c.decodeIfPresent(String.self, forKey: .matchIP)
        self.sev       = try c.decode(Int.self,    forKey: .sev)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,        forKey: .ts)
        try c.encode(title,     forKey: .title)
        try c.encodeIfPresent(detail, forKey: .detail)
        try c.encodeIfPresent(key,    forKey: .key)
        try c.encode(hits,      forKey: .hits)
        try c.encode(firstSeen, forKey: .firstSeen)
        try c.encode(lastSeen,  forKey: .lastSeen)
        try c.encodeIfPresent(matchIP, forKey: .matchIP)
        try c.encode(sev,       forKey: .sev)
    }
}

// MARK: - Connections (M6)

/// One JSONL record per active TCP/UDP flow. Schema mirrors the
/// prompt added to `sloth/PROGRESS.md` (closing sloth#5): per-tick
/// snapshot keyed by `(src, dst, proto)`. The producer emits one
/// record per active flow per emit-tick; sloth-ios dedups by the
/// natural tuple and keeps a small RTT sample series for the
/// sparkline.
///
/// Optional fields per the spec:
///   * `state` is TCP-only; omit for UDP.
///   * `rtt_ms` may be omitted for UDP or when sloth has no sample.
///   * `retx` is TCP-only.
///   * `age_s` may be omitted in the first sloth pass — the consumer
///     can compute age from the earliest record it sees for the
///     tuple if needed.
public struct ConnectionEntry: Sendable, Codable, Equatable {

    public enum Proto: String, Sendable, Codable, Equatable {
        case tcp, udp
    }

    public var type: String { "connections" }
    public let ts: Int
    public let src: String
    public let dst: String
    public let proto: Proto
    public let state: String?
    public let rttMS: Double?
    public let retx: Int?
    public let rxBytes: Int
    public let txBytes: Int
    public let ageS: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, proto, state, retx
        case rttMS    = "rtt_ms"
        case rxBytes  = "rx_bytes"
        case txBytes  = "tx_bytes"
        case ageS     = "age_s"
    }

    public init(
        ts: Int,
        src: String,
        dst: String,
        proto: Proto,
        state: String? = nil,
        rttMS: Double? = nil,
        retx:  Int?    = nil,
        rxBytes: Int = 0,
        txBytes: Int = 0,
        ageS:    Int? = nil
    ) {
        self.ts = ts
        self.src = src
        self.dst = dst
        self.proto = proto
        self.state = state
        self.rttMS = rttMS
        self.retx  = retx
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.ageS    = ageS
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts       = try c.decode(Int.self,    forKey: .ts)
        self.src      = try c.decode(String.self, forKey: .src)
        self.dst      = try c.decode(String.self, forKey: .dst)
        self.proto    = try c.decode(Proto.self,  forKey: .proto)
        self.state    = try c.decodeIfPresent(String.self, forKey: .state)
        self.rttMS    = try c.decodeIfPresent(Double.self, forKey: .rttMS)
        self.retx     = try c.decodeIfPresent(Int.self,    forKey: .retx)
        self.rxBytes  = try c.decodeIfPresent(Int.self,    forKey: .rxBytes) ?? 0
        self.txBytes  = try c.decodeIfPresent(Int.self,    forKey: .txBytes) ?? 0
        self.ageS     = try c.decodeIfPresent(Int.self,    forKey: .ageS)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,  forKey: .type)
        try c.encode(ts,    forKey: .ts)
        try c.encode(src,   forKey: .src)
        try c.encode(dst,   forKey: .dst)
        try c.encode(proto, forKey: .proto)
        try c.encodeIfPresent(state, forKey: .state)
        try c.encodeIfPresent(rttMS, forKey: .rttMS)
        try c.encodeIfPresent(retx,  forKey: .retx)
        try c.encode(rxBytes, forKey: .rxBytes)
        try c.encode(txBytes, forKey: .txBytes)
        try c.encodeIfPresent(ageS, forKey: .ageS)
    }

    /// Stable tuple-key the aggregator / `AlertHotIndex` use to
    /// dedupe and look up flow rows.
    public var flowKey: String {
        "\(src)→\(dst)/\(proto.rawValue)"
    }
}

// MARK: - Snapshot records (M9)

// Sloth's `--data-socket` re-emits every view-backing table once per
// poll tick (≈ 1 Hz) — one record per active entry per tick. These
// types are snapshot records: consumers key them by the natural
// identity field below and replace prior state on each tick. When an
// entry ages out of sloth's source table its records simply stop
// arriving (no explicit "closed" sentinel). See sloth's
// `docs/wiki/jsonl-schema.md` § "State snapshot record types".

/// `iface` — one entry per network interface visible to sloth. Holds
/// totals plus current rx/tx rates (bytes/sec, float).
public struct IFaceEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "iface" }
    public let ts: Int
    public let name: String
    public let rxBytes: Int
    public let txBytes: Int
    public let rxPackets: Int
    public let txPackets: Int
    public let rxErrors: Int
    public let rxDrops: Int
    public let txErrors: Int
    public let txDrops: Int
    public let rxRate: Double
    public let txRate: Double
    public let mtu: Int?
    public let speedMbps: Int?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case type, ts, name, mtu
        case rxBytes   = "rx_bytes"
        case txBytes   = "tx_bytes"
        case rxPackets = "rx_packets"
        case txPackets = "tx_packets"
        case rxErrors  = "rx_errors"
        case rxDrops   = "rx_drops"
        case txErrors  = "tx_errors"
        case txDrops   = "tx_drops"
        case rxRate    = "rx_rate"
        case txRate    = "tx_rate"
        case speedMbps = "speed_mbps"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts        = try c.decode(Int.self,    forKey: .ts)
        self.name      = try c.decode(String.self, forKey: .name)
        self.rxBytes   = try c.decodeIfPresent(Int.self,    forKey: .rxBytes)   ?? 0
        self.txBytes   = try c.decodeIfPresent(Int.self,    forKey: .txBytes)   ?? 0
        self.rxPackets = try c.decodeIfPresent(Int.self,    forKey: .rxPackets) ?? 0
        self.txPackets = try c.decodeIfPresent(Int.self,    forKey: .txPackets) ?? 0
        self.rxErrors  = try c.decodeIfPresent(Int.self,    forKey: .rxErrors)  ?? 0
        self.rxDrops   = try c.decodeIfPresent(Int.self,    forKey: .rxDrops)   ?? 0
        self.txErrors  = try c.decodeIfPresent(Int.self,    forKey: .txErrors)  ?? 0
        self.txDrops   = try c.decodeIfPresent(Int.self,    forKey: .txDrops)   ?? 0
        self.rxRate    = try c.decodeIfPresent(Double.self, forKey: .rxRate)    ?? 0
        self.txRate    = try c.decodeIfPresent(Double.self, forKey: .txRate)    ?? 0
        self.mtu       = try c.decodeIfPresent(Int.self,    forKey: .mtu)
        self.speedMbps = try c.decodeIfPresent(Int.self,    forKey: .speedMbps)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,      forKey: .type)
        try c.encode(ts,        forKey: .ts)
        try c.encode(name,      forKey: .name)
        try c.encode(rxBytes,   forKey: .rxBytes)
        try c.encode(txBytes,   forKey: .txBytes)
        try c.encode(rxPackets, forKey: .rxPackets)
        try c.encode(txPackets, forKey: .txPackets)
        try c.encode(rxErrors,  forKey: .rxErrors)
        try c.encode(rxDrops,   forKey: .rxDrops)
        try c.encode(txErrors,  forKey: .txErrors)
        try c.encode(txDrops,   forKey: .txDrops)
        try c.encode(rxRate,    forKey: .rxRate)
        try c.encode(txRate,    forKey: .txRate)
        try c.encodeIfPresent(mtu,       forKey: .mtu)
        try c.encodeIfPresent(speedMbps, forKey: .speedMbps)
    }
}

/// `device` — one entry per host sloth has seen on the LAN (ARP,
/// DHCP, mDNS, WiFi association — `sources` is a bitmask of
/// `DEV_SRC_*` from the producer side).
public struct DeviceEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "device" }
    public let ts: Int
    public let mac: String
    public let ip: String?
    public let hostname: String?
    public let vendor: String?
    public let lastSSID: String?
    public let isAP: Int
    public let signalDBM: Int?
    public let probeCount: Int
    public let sources: Int
    public let lastSeen: Int

    public var id: String { mac }

    enum CodingKeys: String, CodingKey {
        case type, ts, mac, ip, hostname, vendor, sources
        case lastSSID   = "last_ssid"
        case isAP       = "is_ap"
        case signalDBM  = "signal_dbm"
        case probeCount = "probe_count"
        case lastSeen   = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.mac        = try c.decode(String.self, forKey: .mac)
        self.ip         = try c.decodeIfPresent(String.self, forKey: .ip)
        self.hostname   = try c.decodeIfPresent(String.self, forKey: .hostname)
        self.vendor     = try c.decodeIfPresent(String.self, forKey: .vendor)
        self.lastSSID   = try c.decodeIfPresent(String.self, forKey: .lastSSID)
        self.isAP       = try c.decodeIfPresent(Int.self,    forKey: .isAP)       ?? 0
        self.signalDBM  = try c.decodeIfPresent(Int.self,    forKey: .signalDBM)
        self.probeCount = try c.decodeIfPresent(Int.self,    forKey: .probeCount) ?? 0
        self.sources    = try c.decodeIfPresent(Int.self,    forKey: .sources)    ?? 0
        self.lastSeen   = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)   ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(mac,  forKey: .mac)
        try c.encodeIfPresent(ip,        forKey: .ip)
        try c.encodeIfPresent(hostname,  forKey: .hostname)
        try c.encodeIfPresent(vendor,    forKey: .vendor)
        try c.encodeIfPresent(lastSSID,  forKey: .lastSSID)
        try c.encode(isAP,       forKey: .isAP)
        try c.encodeIfPresent(signalDBM, forKey: .signalDBM)
        try c.encode(probeCount, forKey: .probeCount)
        try c.encode(sources,    forKey: .sources)
        try c.encode(lastSeen,   forKey: .lastSeen)
    }
}

/// `beacon` — one entry per WiFi AP observed in 802.11 beacon frames.
/// Many fields exist upstream (`docs/wiki/jsonl-schema.md`); the iOS
/// view only surfaces a useful subset for now.
public struct BeaconEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "beacon" }
    public let ts: Int
    public let bssid: String
    public let ssid: String?
    public let signalDBM: Int?
    public let channel: Int?
    public let enc: String?
    public let vendor: String?
    public let phy: String?
    public let lastSeen: Int
    public let frameCount: Int
    public let rssiMin60s: Int?
    public let rssiMax60s: Int?

    public var id: String { bssid }

    /// Convenience: the dB swing in the last 60 s — the same number
    /// `twin_episode.rssi_swing_dbm` watches for an evil twin.
    public var rssiSwing60s: Int? {
        guard let mn = rssiMin60s, let mx = rssiMax60s, mn != 0, mx != 0 else { return nil }
        return mx - mn
    }

    enum CodingKeys: String, CodingKey {
        case type, ts, bssid, ssid, channel, enc, vendor, phy
        case signalDBM  = "signal_dbm"
        case lastSeen   = "last_seen"
        case frameCount = "frame_count"
        case rssiMin60s = "rssi_min_60s"
        case rssiMax60s = "rssi_max_60s"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.bssid      = try c.decode(String.self, forKey: .bssid)
        self.ssid       = try c.decodeIfPresent(String.self, forKey: .ssid)
        self.signalDBM  = try c.decodeIfPresent(Int.self,    forKey: .signalDBM)
        self.channel    = try c.decodeIfPresent(Int.self,    forKey: .channel)
        self.enc        = try c.decodeIfPresent(String.self, forKey: .enc)
        self.vendor     = try c.decodeIfPresent(String.self, forKey: .vendor)
        self.phy        = try c.decodeIfPresent(String.self, forKey: .phy)
        self.lastSeen   = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)   ?? 0
        self.frameCount = try c.decodeIfPresent(Int.self,    forKey: .frameCount) ?? 0
        self.rssiMin60s = try c.decodeIfPresent(Int.self,    forKey: .rssiMin60s)
        self.rssiMax60s = try c.decodeIfPresent(Int.self,    forKey: .rssiMax60s)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,  forKey: .type)
        try c.encode(ts,    forKey: .ts)
        try c.encode(bssid, forKey: .bssid)
        try c.encodeIfPresent(ssid,      forKey: .ssid)
        try c.encodeIfPresent(signalDBM, forKey: .signalDBM)
        try c.encodeIfPresent(channel,   forKey: .channel)
        try c.encodeIfPresent(enc,       forKey: .enc)
        try c.encodeIfPresent(vendor,    forKey: .vendor)
        try c.encodeIfPresent(phy,       forKey: .phy)
        try c.encode(lastSeen,   forKey: .lastSeen)
        try c.encode(frameCount, forKey: .frameCount)
        try c.encodeIfPresent(rssiMin60s, forKey: .rssiMin60s)
        try c.encodeIfPresent(rssiMax60s, forKey: .rssiMax60s)
    }
}

/// `twin_episode` — sloth's evil-twin detector emits one record per
/// suspected rogue AP pair per poll. The pair is identified by
/// `(ssid, real_bssid, twin_bssid)`. `attack_in_progress=1` means the
/// chain rule tainted `twin_bssid` (a DEAUTH flood was observed
/// within 5 s of the twin appearing) — that is the highest-severity
/// signal in the record.
public struct TwinEpisodeEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "twin_episode" }
    public let ts: Int
    public let ssid: String
    public let realBSSID: String
    public let twinBSSID: String
    public let enc: String?
    public let realRSSI: Int
    public let twinRSSI: Int
    public let rssiSwingDBM: Int
    public let attackInProgress: Int
    public let attackerOUI: Int
    public let hashMismatch: Int

    public var id: String { "\(ssid)|\(realBSSID)|\(twinBSSID)" }

    /// Mapping to the iOS three-tier alert palette:
    ///   * attack_in_progress=1            → crit
    ///   * any of attacker_oui / hash_mismatch / swing≥15 dB → warn
    ///   * otherwise (passive detection only)               → low
    public var severity: AlertSeverity {
        if attackInProgress != 0 { return .crit }
        if attackerOUI != 0 || hashMismatch != 0 || rssiSwingDBM >= 15 { return .warn }
        return .low
    }

    enum CodingKeys: String, CodingKey {
        case type, ts, ssid, enc
        case realBSSID        = "real_bssid"
        case twinBSSID        = "twin_bssid"
        case realRSSI         = "real_rssi"
        case twinRSSI         = "twin_rssi"
        case rssiSwingDBM     = "rssi_swing_dbm"
        case attackInProgress = "attack_in_progress"
        case attackerOUI      = "attacker_oui"
        case hashMismatch     = "hash_mismatch"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts               = try c.decode(Int.self,    forKey: .ts)
        self.ssid             = try c.decode(String.self, forKey: .ssid)
        self.realBSSID        = try c.decode(String.self, forKey: .realBSSID)
        self.twinBSSID        = try c.decode(String.self, forKey: .twinBSSID)
        self.enc              = try c.decodeIfPresent(String.self, forKey: .enc)
        self.realRSSI         = try c.decodeIfPresent(Int.self,    forKey: .realRSSI)     ?? 0
        self.twinRSSI         = try c.decodeIfPresent(Int.self,    forKey: .twinRSSI)     ?? 0
        self.rssiSwingDBM     = try c.decodeIfPresent(Int.self,    forKey: .rssiSwingDBM) ?? 0
        self.attackInProgress = try c.decodeIfPresent(Int.self,    forKey: .attackInProgress) ?? 0
        self.attackerOUI      = try c.decodeIfPresent(Int.self,    forKey: .attackerOUI)  ?? 0
        self.hashMismatch     = try c.decodeIfPresent(Int.self,    forKey: .hashMismatch) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(ssid, forKey: .ssid)
        try c.encode(realBSSID, forKey: .realBSSID)
        try c.encode(twinBSSID, forKey: .twinBSSID)
        try c.encodeIfPresent(enc, forKey: .enc)
        try c.encode(realRSSI,         forKey: .realRSSI)
        try c.encode(twinRSSI,         forKey: .twinRSSI)
        try c.encode(rssiSwingDBM,     forKey: .rssiSwingDBM)
        try c.encode(attackInProgress, forKey: .attackInProgress)
        try c.encode(attackerOUI,      forKey: .attackerOUI)
        try c.encode(hashMismatch,     forKey: .hashMismatch)
    }
}

/// `top_host` — sloth's own top-hosts roll-up. Replaces the iOS
/// `HostAggregator` (which used to reconstruct an equivalent table
/// from the per-protocol log rings). Carries fields the consumer
/// couldn't compute on its own:
///   * `owner`        — CDN / cloud / ASN tag from sloth's
///                      `src/ip_owner.c` table
///   * `rx_bytes` / `tx_bytes` — real cumulative byte counters
///   * `rx_rate`  / `tx_rate`  — kernel-derived bytes/sec
///
/// Cadence: one record per active entry per ≈ 1 s tick. iOS replaces
/// the entry in `SlothStore.topHosts` on each tick and appends the
/// current rate to a small per-IP sample tail so the view can still
/// draw a sparkline.
public struct TopHostEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "top_host" }
    public let ts: Int
    public let ip: String
    public let hostname: String?
    public let owner: String?
    public let firstSeen: Int
    public let lastSeen: Int
    public let connCount: Int
    public let rxRate: Double
    public let txRate: Double
    public let rxBytes: Int
    public let txBytes: Int

    public var id: String { ip }

    /// Combined live byte rate — the primary sort key for the view.
    public var totalRate: Double { rxRate + txRate }

    enum CodingKeys: String, CodingKey {
        case type, ts, ip, hostname, owner
        case firstSeen = "first_seen"
        case lastSeen  = "last_seen"
        case connCount = "conn_count"
        case rxRate    = "rx_rate"
        case txRate    = "tx_rate"
        case rxBytes   = "rx_bytes"
        case txBytes   = "tx_bytes"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts        = try c.decode(Int.self,    forKey: .ts)
        self.ip        = try c.decode(String.self, forKey: .ip)
        self.hostname  = try c.decodeIfPresent(String.self, forKey: .hostname)
        self.owner     = try c.decodeIfPresent(String.self, forKey: .owner)
        self.firstSeen = try c.decodeIfPresent(Int.self,    forKey: .firstSeen) ?? 0
        self.lastSeen  = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)  ?? 0
        self.connCount = try c.decodeIfPresent(Int.self,    forKey: .connCount) ?? 0
        self.rxRate    = try c.decodeIfPresent(Double.self, forKey: .rxRate)    ?? 0
        self.txRate    = try c.decodeIfPresent(Double.self, forKey: .txRate)    ?? 0
        self.rxBytes   = try c.decodeIfPresent(Int.self,    forKey: .rxBytes)   ?? 0
        self.txBytes   = try c.decodeIfPresent(Int.self,    forKey: .txBytes)   ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(ip,   forKey: .ip)
        try c.encodeIfPresent(hostname, forKey: .hostname)
        try c.encodeIfPresent(owner,    forKey: .owner)
        try c.encode(firstSeen, forKey: .firstSeen)
        try c.encode(lastSeen,  forKey: .lastSeen)
        try c.encode(connCount, forKey: .connCount)
        try c.encode(rxRate,    forKey: .rxRate)
        try c.encode(txRate,    forKey: .txRate)
        try c.encode(rxBytes,   forKey: .rxBytes)
        try c.encode(txBytes,   forKey: .txBytes)
    }
}

/// `process` — sloth's per-PID bandwidth-attribution roll-up. A
/// synthesis record aggregated from the `connections` stream on the
/// producer side, so the iOS client gets "which process is making
/// the noise" without re-implementing the aggregation.
///
/// `pid = -1` is sloth's "unresolved bucket" — flows it couldn't
/// attach to a live process (closed sockets, kernel threads, etc.).
public struct ProcessEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "process" }
    public let ts: Int
    public let pid: Int
    public let proc: String?
    public let ppid: Int?
    public let depth: Int?
    public let connCount: Int
    public let tcpCount: Int
    public let udpCount: Int
    public let txBytes: Int
    public let rxBytes: Int
    public let txRate: Double
    public let rxRate: Double
    public let ports: [Int]

    public var id: Int { pid }

    /// Combined live byte rate — primary sort key for the view.
    public var totalRate: Double { rxRate + txRate }

    /// `true` for sloth's unresolved-flows bucket; the view sorts it
    /// to the bottom and labels it explicitly.
    public var isUnresolved: Bool { pid < 0 }

    enum CodingKeys: String, CodingKey {
        case type, ts, pid, proc, ppid, depth, ports
        case connCount = "conn_count"
        case tcpCount  = "tcp_count"
        case udpCount  = "udp_count"
        case txBytes   = "tx_bytes"
        case rxBytes   = "rx_bytes"
        case txRate    = "tx_rate"
        case rxRate    = "rx_rate"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts        = try c.decode(Int.self, forKey: .ts)
        self.pid       = try c.decode(Int.self, forKey: .pid)
        self.proc      = try c.decodeIfPresent(String.self, forKey: .proc)
        self.ppid      = try c.decodeIfPresent(Int.self,    forKey: .ppid)
        self.depth     = try c.decodeIfPresent(Int.self,    forKey: .depth)
        self.connCount = try c.decodeIfPresent(Int.self,    forKey: .connCount) ?? 0
        self.tcpCount  = try c.decodeIfPresent(Int.self,    forKey: .tcpCount)  ?? 0
        self.udpCount  = try c.decodeIfPresent(Int.self,    forKey: .udpCount)  ?? 0
        self.txBytes   = try c.decodeIfPresent(Int.self,    forKey: .txBytes)   ?? 0
        self.rxBytes   = try c.decodeIfPresent(Int.self,    forKey: .rxBytes)   ?? 0
        self.txRate    = try c.decodeIfPresent(Double.self, forKey: .txRate)    ?? 0
        self.rxRate    = try c.decodeIfPresent(Double.self, forKey: .rxRate)    ?? 0
        self.ports     = try c.decodeIfPresent([Int].self,  forKey: .ports)     ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(pid,  forKey: .pid)
        try c.encodeIfPresent(proc,  forKey: .proc)
        try c.encodeIfPresent(ppid,  forKey: .ppid)
        try c.encodeIfPresent(depth, forKey: .depth)
        try c.encode(connCount, forKey: .connCount)
        try c.encode(tcpCount,  forKey: .tcpCount)
        try c.encode(udpCount,  forKey: .udpCount)
        try c.encode(txBytes,   forKey: .txBytes)
        try c.encode(rxBytes,   forKey: .rxBytes)
        try c.encode(txRate,    forKey: .txRate)
        try c.encode(rxRate,    forKey: .rxRate)
        try c.encode(ports,     forKey: .ports)
    }
}

/// `deauth` — one entry per (bssid, dst) frame flow sloth has seen
/// in 802.11 deauthenticate frames. `flood = 1` means sloth's
/// deauth detector classified this as an active flood (the same
/// signal `twin_episode.attack_in_progress` chains off of); `count`
/// is the total observed frame count for the pair.
public struct DeauthEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "deauth" }
    public let ts: Int
    public let src: String?
    public let dst: String
    public let bssid: String
    public let reason: Int?
    public let subtype: Int?
    public let firstSeen: Int
    public let lastSeen: Int
    public let count: Int
    public let flood: Int

    public var id: String { "\(bssid)|\(dst)" }

    /// `true` if sloth's detector classified this pair as an active
    /// flood. The view escalates the row hue to WARN/CRIT on this.
    public var isFlood: Bool { flood != 0 }

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, bssid, reason, subtype, count, flood
        case firstSeen = "first_seen"
        case lastSeen  = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts        = try c.decode(Int.self, forKey: .ts)
        self.src       = try c.decodeIfPresent(String.self, forKey: .src)
        self.dst       = try c.decode(String.self, forKey: .dst)
        self.bssid     = try c.decode(String.self, forKey: .bssid)
        self.reason    = try c.decodeIfPresent(Int.self,    forKey: .reason)
        self.subtype   = try c.decodeIfPresent(Int.self,    forKey: .subtype)
        self.firstSeen = try c.decodeIfPresent(Int.self,    forKey: .firstSeen) ?? 0
        self.lastSeen  = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)  ?? 0
        self.count     = try c.decodeIfPresent(Int.self,    forKey: .count)     ?? 0
        self.flood     = try c.decodeIfPresent(Int.self,    forKey: .flood)     ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encodeIfPresent(src, forKey: .src)
        try c.encode(dst,   forKey: .dst)
        try c.encode(bssid, forKey: .bssid)
        try c.encodeIfPresent(reason,  forKey: .reason)
        try c.encodeIfPresent(subtype, forKey: .subtype)
        try c.encode(firstSeen, forKey: .firstSeen)
        try c.encode(lastSeen,  forKey: .lastSeen)
        try c.encode(count,     forKey: .count)
        try c.encode(flood,     forKey: .flood)
    }
}

/// `mdns_service` — one entry per Bonjour / Zeroconf service
/// instance sloth has observed (passively, off UDP/5353). Keyed by
/// the full service instance string (e.g. "Living-Room Apple
/// TV._airplay._tcp.local.").
public struct MDNSServiceEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "mdns_service" }
    public let ts: Int
    public let instance: String
    public let service: String?
    public let host: String?
    public let ip: String?
    public let port: Int?
    public let lastSeen: Int

    public var id: String { instance }

    enum CodingKeys: String, CodingKey {
        case type, ts, instance, service, host, ip, port
        case lastSeen = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts       = try c.decode(Int.self,    forKey: .ts)
        self.instance = try c.decode(String.self, forKey: .instance)
        self.service  = try c.decodeIfPresent(String.self, forKey: .service)
        self.host     = try c.decodeIfPresent(String.self, forKey: .host)
        self.ip       = try c.decodeIfPresent(String.self, forKey: .ip)
        self.port     = try c.decodeIfPresent(Int.self,    forKey: .port)
        self.lastSeen = try c.decodeIfPresent(Int.self,    forKey: .lastSeen) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,     forKey: .type)
        try c.encode(ts,       forKey: .ts)
        try c.encode(instance, forKey: .instance)
        try c.encodeIfPresent(service, forKey: .service)
        try c.encodeIfPresent(host,    forKey: .host)
        try c.encodeIfPresent(ip,      forKey: .ip)
        try c.encodeIfPresent(port,    forKey: .port)
        try c.encode(lastSeen, forKey: .lastSeen)
    }
}

/// `dhcp_lease` — one entry per DHCP lease sloth has observed on the
/// LAN. `expire = 0` means sloth doesn't know (typical when the lease
/// was observed via a renewal rather than a fresh DISCOVER/OFFER).
public struct DHCPLeaseEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "dhcp_lease" }
    public let ts: Int
    public let ip: String
    public let hostname: String?
    public let expire: Int

    public var id: String { ip }

    enum CodingKeys: String, CodingKey {
        case type, ts, ip, hostname, expire
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts       = try c.decode(Int.self,    forKey: .ts)
        self.ip       = try c.decode(String.self, forKey: .ip)
        self.hostname = try c.decodeIfPresent(String.self, forKey: .hostname)
        self.expire   = try c.decodeIfPresent(Int.self,    forKey: .expire) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(ip,   forKey: .ip)
        try c.encodeIfPresent(hostname, forKey: .hostname)
        try c.encode(expire, forKey: .expire)
    }
}
