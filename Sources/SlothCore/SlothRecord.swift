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
    case arp(ARPEntry)
    case ssdpDevice(SSDPDeviceEntry)
    case nbnsName(NBNSNameEntry)
    case probeClient(ProbeClientEntry)
    case pnlClient(PNLClientEntry)
    case seqnumClient(SeqnumClientEntry)
    case seqnumCorrelation(SeqnumCorrelationEntry)
    case channelSummary(ChannelSummaryEntry)
    case assoc(AssocEntry)
    case eapol(EAPOLEntry)
    case scanEntry(ScanEntry)
    case packet(PacketEntry)
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
        case .arp        (let e): return e.ts
        case .ssdpDevice (let e): return e.ts
        case .nbnsName   (let e): return e.ts
        case .probeClient(let e): return e.ts
        case .pnlClient  (let e): return e.ts
        case .seqnumClient     (let e): return e.ts
        case .seqnumCorrelation(let e): return e.ts
        case .channelSummary   (let e): return e.ts
        case .assoc      (let e): return e.ts
        case .eapol      (let e): return e.ts
        case .scanEntry  (let e): return e.ts
        case .packet     (let e): return e.ts
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
        case .arp:         return "arp"
        case .ssdpDevice:  return "ssdp_device"
        case .nbnsName:    return "nbns_name"
        case .probeClient: return "probe_client"
        case .pnlClient:   return "pnl_client"
        case .seqnumClient:     return "seqnum_client"
        case .seqnumCorrelation:return "seqnum_correlation"
        case .channelSummary:   return "channel_summary"
        case .assoc:       return "assoc"
        case .eapol:       return "eapol"
        case .scanEntry:   return "scan_entry"
        case .packet:      return "packet"
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
        case "arp":         self = .arp        (try ARPEntry        (from: decoder))
        case "ssdp_device": self = .ssdpDevice (try SSDPDeviceEntry (from: decoder))
        case "nbns_name":   self = .nbnsName   (try NBNSNameEntry   (from: decoder))
        case "probe_client":self = .probeClient(try ProbeClientEntry(from: decoder))
        case "pnl_client":  self = .pnlClient  (try PNLClientEntry  (from: decoder))
        case "seqnum_client":      self = .seqnumClient     (try SeqnumClientEntry     (from: decoder))
        case "seqnum_correlation": self = .seqnumCorrelation(try SeqnumCorrelationEntry(from: decoder))
        case "channel_summary":    self = .channelSummary   (try ChannelSummaryEntry   (from: decoder))
        case "assoc":       self = .assoc      (try AssocEntry      (from: decoder))
        case "eapol":       self = .eapol      (try EAPOLEntry      (from: decoder))
        case "scan_entry":  self = .scanEntry  (try ScanEntry       (from: decoder))
        case "packet":      self = .packet     (try PacketEntry     (from: decoder))
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
        case .arp        (let e): try e.encode(to: encoder)
        case .ssdpDevice (let e): try e.encode(to: encoder)
        case .nbnsName   (let e): try e.encode(to: encoder)
        case .probeClient(let e): try e.encode(to: encoder)
        case .pnlClient  (let e): try e.encode(to: encoder)
        case .seqnumClient     (let e): try e.encode(to: encoder)
        case .seqnumCorrelation(let e): try e.encode(to: encoder)
        case .channelSummary   (let e): try e.encode(to: encoder)
        case .assoc      (let e): try e.encode(to: encoder)
        case .eapol      (let e): try e.encode(to: encoder)
        case .scanEntry  (let e): try e.encode(to: encoder)
        case .packet     (let e): try e.encode(to: encoder)
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

// MARK: - LAN snapshot records

/// `arp` — one entry per (mac, ip) seen in ARP frames sloth has
/// observed. `iface` is the local network interface the frame
/// arrived on.
public struct ARPEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "arp" }
    public let ts: Int
    public let mac: String
    public let ip: String
    public let iface: String?

    public var id: String { "\(mac)|\(ip)" }

    enum CodingKeys: String, CodingKey { case type, ts, mac, ip, iface }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts    = try c.decode(Int.self,    forKey: .ts)
        self.mac   = try c.decode(String.self, forKey: .mac)
        self.ip    = try c.decode(String.self, forKey: .ip)
        self.iface = try c.decodeIfPresent(String.self, forKey: .iface)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(mac,  forKey: .mac)
        try c.encode(ip,   forKey: .ip)
        try c.encodeIfPresent(iface, forKey: .iface)
    }
}

/// `ssdp_device` — one entry per SSDP / UPnP device sloth has seen.
/// `kind` is the SSDP `NT` / `ST` value (renamed from `type` on the
/// wire to avoid colliding with the envelope's `type` field).
public struct SSDPDeviceEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "ssdp_device" }
    public let ts: Int
    public let usn: String
    public let ip: String?
    public let kind: String?
    public let location: String?
    public let nts: String?
    public let lastSeen: Int

    public var id: String { usn }

    enum CodingKeys: String, CodingKey {
        case type, ts, usn, ip, kind, location, nts
        case lastSeen = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts       = try c.decode(Int.self,    forKey: .ts)
        self.usn      = try c.decode(String.self, forKey: .usn)
        self.ip       = try c.decodeIfPresent(String.self, forKey: .ip)
        self.kind     = try c.decodeIfPresent(String.self, forKey: .kind)
        self.location = try c.decodeIfPresent(String.self, forKey: .location)
        self.nts      = try c.decodeIfPresent(String.self, forKey: .nts)
        self.lastSeen = try c.decodeIfPresent(Int.self,    forKey: .lastSeen) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(usn,  forKey: .usn)
        try c.encodeIfPresent(ip,       forKey: .ip)
        try c.encodeIfPresent(kind,     forKey: .kind)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(nts,      forKey: .nts)
        try c.encode(lastSeen, forKey: .lastSeen)
    }
}

/// `nbns_name` — NetBIOS name announcement (Windows hosts).
public struct NBNSNameEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "nbns_name" }
    public let ts: Int
    public let name: String
    public let ip: String
    public let suffix: String?
    public let lastSeen: Int

    public var id: String { "\(name)|\(ip)" }

    enum CodingKeys: String, CodingKey {
        case type, ts, name, ip, suffix
        case lastSeen = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts       = try c.decode(Int.self,    forKey: .ts)
        self.name     = try c.decode(String.self, forKey: .name)
        self.ip       = try c.decode(String.self, forKey: .ip)
        self.suffix   = try c.decodeIfPresent(String.self, forKey: .suffix)
        self.lastSeen = try c.decodeIfPresent(Int.self,    forKey: .lastSeen) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(name, forKey: .name)
        try c.encode(ip,   forKey: .ip)
        try c.encodeIfPresent(suffix, forKey: .suffix)
        try c.encode(lastSeen, forKey: .lastSeen)
    }
}

// MARK: - WiFi-client snapshot records

/// `probe_client` — one 802.11 probe-requesting station per MAC sloth
/// has seen. `ssid` is the most-recent SSID the station probed for
/// (empty / `(any)` for wildcard / broadcast probes).
public struct ProbeClientEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "probe_client" }
    public let ts: Int
    public let mac: String
    public let ssid: String?
    public let signalDBM: Int?
    public let channel: Int?
    public let firstSeen: Int
    public let lastSeen: Int
    public let frameCount: Int

    public var id: String { mac }

    enum CodingKeys: String, CodingKey {
        case type, ts, mac, ssid, channel
        case signalDBM  = "signal_dbm"
        case firstSeen  = "first_seen"
        case lastSeen   = "last_seen"
        case frameCount = "frame_count"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.mac        = try c.decode(String.self, forKey: .mac)
        self.ssid       = try c.decodeIfPresent(String.self, forKey: .ssid)
        self.signalDBM  = try c.decodeIfPresent(Int.self,    forKey: .signalDBM)
        self.channel    = try c.decodeIfPresent(Int.self,    forKey: .channel)
        self.firstSeen  = try c.decodeIfPresent(Int.self,    forKey: .firstSeen)  ?? 0
        self.lastSeen   = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)   ?? 0
        self.frameCount = try c.decodeIfPresent(Int.self,    forKey: .frameCount) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(mac,  forKey: .mac)
        try c.encodeIfPresent(ssid,      forKey: .ssid)
        try c.encodeIfPresent(signalDBM, forKey: .signalDBM)
        try c.encodeIfPresent(channel,   forKey: .channel)
        try c.encode(firstSeen,  forKey: .firstSeen)
        try c.encode(lastSeen,   forKey: .lastSeen)
        try c.encode(frameCount, forKey: .frameCount)
    }
}

/// `pnl_client` — Preferred Network List record per probing station.
/// `ssids[]` is the cumulative set of SSIDs sloth has seen this MAC
/// probe for; `mac_random = 1` flags locally-administered (likely
/// randomised) MACs that won't survive a roam.
public struct PNLClientEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "pnl_client" }
    public let ts: Int
    public let mac: String
    public let macRandom: Int
    public let probeCount: Int
    public let osFP: String?
    public let phy: String?
    public let firstSeen: Int
    public let lastSeen: Int
    public let ssids: [String]

    public var id: String { mac }

    /// Whether sloth flagged the MAC as locally-administered.
    public var isRandomMAC: Bool { macRandom != 0 }

    enum CodingKeys: String, CodingKey {
        case type, ts, mac, phy, ssids
        case macRandom  = "mac_random"
        case probeCount = "probe_count"
        case osFP       = "os_fp"
        case firstSeen  = "first_seen"
        case lastSeen   = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.mac        = try c.decode(String.self, forKey: .mac)
        self.macRandom  = try c.decodeIfPresent(Int.self,       forKey: .macRandom)  ?? 0
        self.probeCount = try c.decodeIfPresent(Int.self,       forKey: .probeCount) ?? 0
        self.osFP       = try c.decodeIfPresent(String.self,    forKey: .osFP)
        self.phy        = try c.decodeIfPresent(String.self,    forKey: .phy)
        self.firstSeen  = try c.decodeIfPresent(Int.self,       forKey: .firstSeen)  ?? 0
        self.lastSeen   = try c.decodeIfPresent(Int.self,       forKey: .lastSeen)   ?? 0
        self.ssids      = try c.decodeIfPresent([String].self,  forKey: .ssids)      ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(mac,  forKey: .mac)
        try c.encode(macRandom,  forKey: .macRandom)
        try c.encode(probeCount, forKey: .probeCount)
        try c.encodeIfPresent(osFP, forKey: .osFP)
        try c.encodeIfPresent(phy,  forKey: .phy)
        try c.encode(firstSeen, forKey: .firstSeen)
        try c.encode(lastSeen,  forKey: .lastSeen)
        try c.encode(ssids,     forKey: .ssids)
    }
}

/// `seqnum_client` — 12-bit 802.11 sequence-number history sloth
/// observed per MAC. Used to detect MAC-randomisation defeat (a real
/// device's seqnum advances monotonically across MAC changes).
public struct SeqnumClientEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "seqnum_client" }
    public let ts: Int
    public let mac: String
    public let macRandom: Int
    public let lastSeen: Int
    public let frameCount: Int
    public let hist: [Int]

    public var id: String { mac }

    public var isRandomMAC: Bool { macRandom != 0 }

    enum CodingKeys: String, CodingKey {
        case type, ts, mac, hist
        case macRandom  = "mac_random"
        case lastSeen   = "last_seen"
        case frameCount = "frame_count"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.mac        = try c.decode(String.self, forKey: .mac)
        self.macRandom  = try c.decodeIfPresent(Int.self,    forKey: .macRandom)  ?? 0
        self.lastSeen   = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)   ?? 0
        self.frameCount = try c.decodeIfPresent(Int.self,    forKey: .frameCount) ?? 0
        self.hist       = try c.decodeIfPresent([Int].self,  forKey: .hist)       ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(mac,  forKey: .mac)
        try c.encode(macRandom,  forKey: .macRandom)
        try c.encode(lastSeen,   forKey: .lastSeen)
        try c.encode(frameCount, forKey: .frameCount)
        try c.encode(hist,       forKey: .hist)
    }
}

/// `seqnum_correlation` — sloth's detector for the case where two
/// MACs are likely the same physical NIC (seqnums interleave with a
/// small gap and short dt). `gap` is the seqnum delta; `dt_ms` is
/// the wall-clock delta in milliseconds.
public struct SeqnumCorrelationEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "seqnum_correlation" }
    public let ts: Int
    public let macA: String
    public let macB: String
    public let macARandom: Int
    public let macBRandom: Int
    public let gap: Int
    public let dtMS: Int
    public let aCount: Int
    public let bCount: Int

    public var id: String { "\(macA)|\(macB)" }

    enum CodingKeys: String, CodingKey {
        case type, ts, gap
        case macA       = "mac_a"
        case macB       = "mac_b"
        case macARandom = "mac_a_random"
        case macBRandom = "mac_b_random"
        case dtMS       = "dt_ms"
        case aCount     = "a_count"
        case bCount     = "b_count"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.macA       = try c.decode(String.self, forKey: .macA)
        self.macB       = try c.decode(String.self, forKey: .macB)
        self.macARandom = try c.decodeIfPresent(Int.self, forKey: .macARandom) ?? 0
        self.macBRandom = try c.decodeIfPresent(Int.self, forKey: .macBRandom) ?? 0
        self.gap        = try c.decodeIfPresent(Int.self, forKey: .gap)        ?? 0
        self.dtMS       = try c.decodeIfPresent(Int.self, forKey: .dtMS)       ?? 0
        self.aCount     = try c.decodeIfPresent(Int.self, forKey: .aCount)     ?? 0
        self.bCount     = try c.decodeIfPresent(Int.self, forKey: .bCount)     ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(macA, forKey: .macA)
        try c.encode(macB, forKey: .macB)
        try c.encode(macARandom, forKey: .macARandom)
        try c.encode(macBRandom, forKey: .macBRandom)
        try c.encode(gap,    forKey: .gap)
        try c.encode(dtMS,   forKey: .dtMS)
        try c.encode(aCount, forKey: .aCount)
        try c.encode(bCount, forKey: .bCount)
    }
}

/// `channel_summary` — per-WiFi-channel roll-up.
public struct ChannelSummaryEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "channel_summary" }
    public let ts: Int
    public let channel: Int
    public let apCount: Int
    public let assocCount: Int
    public let bestSignal: Int?
    public let topSSID: String?
    public let lastSeen: Int

    public var id: Int { channel }

    enum CodingKeys: String, CodingKey {
        case type, ts, channel
        case apCount    = "ap_count"
        case assocCount = "assoc_count"
        case bestSignal = "best_signal"
        case topSSID    = "top_ssid"
        case lastSeen   = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self, forKey: .ts)
        self.channel    = try c.decode(Int.self, forKey: .channel)
        self.apCount    = try c.decodeIfPresent(Int.self,    forKey: .apCount)    ?? 0
        self.assocCount = try c.decodeIfPresent(Int.self,    forKey: .assocCount) ?? 0
        self.bestSignal = try c.decodeIfPresent(Int.self,    forKey: .bestSignal)
        self.topSSID    = try c.decodeIfPresent(String.self, forKey: .topSSID)
        self.lastSeen   = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)   ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,    forKey: .type)
        try c.encode(ts,      forKey: .ts)
        try c.encode(channel, forKey: .channel)
        try c.encode(apCount,    forKey: .apCount)
        try c.encode(assocCount, forKey: .assocCount)
        try c.encodeIfPresent(bestSignal, forKey: .bestSignal)
        try c.encodeIfPresent(topSSID,    forKey: .topSSID)
        try c.encode(lastSeen, forKey: .lastSeen)
    }
}

/// `assoc` — WiFi station-to-AP association observation.
public struct AssocEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "assoc" }
    public let ts: Int
    public let bssid: String
    public let staMAC: String
    public let ssid: String?
    public let staRandom: Int
    public let source: String?
    public let channel: Int?
    public let signalDBM: Int?
    public let firstSeen: Int
    public let lastSeen: Int
    public let frameCount: Int

    public var id: String { "\(bssid)|\(staMAC)" }

    enum CodingKeys: String, CodingKey {
        case type, ts, bssid, ssid, source, channel
        case staMAC     = "sta_mac"
        case staRandom  = "sta_random"
        case signalDBM  = "signal_dbm"
        case firstSeen  = "first_seen"
        case lastSeen   = "last_seen"
        case frameCount = "frame_count"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts         = try c.decode(Int.self,    forKey: .ts)
        self.bssid      = try c.decode(String.self, forKey: .bssid)
        self.staMAC     = try c.decode(String.self, forKey: .staMAC)
        self.ssid       = try c.decodeIfPresent(String.self, forKey: .ssid)
        self.staRandom  = try c.decodeIfPresent(Int.self,    forKey: .staRandom)  ?? 0
        self.source     = try c.decodeIfPresent(String.self, forKey: .source)
        self.channel    = try c.decodeIfPresent(Int.self,    forKey: .channel)
        self.signalDBM  = try c.decodeIfPresent(Int.self,    forKey: .signalDBM)
        self.firstSeen  = try c.decodeIfPresent(Int.self,    forKey: .firstSeen)  ?? 0
        self.lastSeen   = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)   ?? 0
        self.frameCount = try c.decodeIfPresent(Int.self,    forKey: .frameCount) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,   forKey: .type)
        try c.encode(ts,     forKey: .ts)
        try c.encode(bssid,  forKey: .bssid)
        try c.encode(staMAC, forKey: .staMAC)
        try c.encodeIfPresent(ssid,      forKey: .ssid)
        try c.encode(staRandom,  forKey: .staRandom)
        try c.encodeIfPresent(source,    forKey: .source)
        try c.encodeIfPresent(channel,   forKey: .channel)
        try c.encodeIfPresent(signalDBM, forKey: .signalDBM)
        try c.encode(firstSeen,  forKey: .firstSeen)
        try c.encode(lastSeen,   forKey: .lastSeen)
        try c.encode(frameCount, forKey: .frameCount)
    }
}

/// `eapol` — WPA 4-way handshake observation. `handshake_complete = 1`
/// means sloth saw all four messages for this (bssid, sta_mac) pair —
/// the strongest signal for an "attack-capable" capture of this
/// session.
public struct EAPOLEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "eapol" }
    public let ts: Int
    public let bssid: String
    public let staMAC: String
    public let ssid: String?
    public let eventTS: Int
    public let msgNum: Int
    public let hasPMKID: Int
    public let handshakeComplete: Int
    public let signalDBM: Int?
    public let channel: Int?

    public var id: String { "\(bssid)|\(staMAC)" }

    public var isComplete: Bool { handshakeComplete != 0 }
    public var hasPMKIDFlag: Bool { hasPMKID != 0 }

    enum CodingKeys: String, CodingKey {
        case type, ts, bssid, ssid, channel
        case staMAC            = "sta_mac"
        case eventTS           = "event_ts"
        case msgNum            = "msg_num"
        case hasPMKID          = "has_pmkid"
        case handshakeComplete = "handshake_complete"
        case signalDBM         = "signal_dbm"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts                = try c.decode(Int.self,    forKey: .ts)
        self.bssid             = try c.decode(String.self, forKey: .bssid)
        self.staMAC            = try c.decode(String.self, forKey: .staMAC)
        self.ssid              = try c.decodeIfPresent(String.self, forKey: .ssid)
        self.eventTS           = try c.decodeIfPresent(Int.self,    forKey: .eventTS) ?? 0
        self.msgNum            = try c.decodeIfPresent(Int.self,    forKey: .msgNum)  ?? 0
        self.hasPMKID          = try c.decodeIfPresent(Int.self,    forKey: .hasPMKID) ?? 0
        self.handshakeComplete = try c.decodeIfPresent(Int.self,    forKey: .handshakeComplete) ?? 0
        self.signalDBM         = try c.decodeIfPresent(Int.self,    forKey: .signalDBM)
        self.channel           = try c.decodeIfPresent(Int.self,    forKey: .channel)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,   forKey: .type)
        try c.encode(ts,     forKey: .ts)
        try c.encode(bssid,  forKey: .bssid)
        try c.encode(staMAC, forKey: .staMAC)
        try c.encodeIfPresent(ssid, forKey: .ssid)
        try c.encode(eventTS, forKey: .eventTS)
        try c.encode(msgNum,  forKey: .msgNum)
        try c.encode(hasPMKID, forKey: .hasPMKID)
        try c.encode(handshakeComplete, forKey: .handshakeComplete)
        try c.encodeIfPresent(signalDBM, forKey: .signalDBM)
        try c.encodeIfPresent(channel,   forKey: .channel)
    }
}

/// `scan_entry` — sloth's port-scan detector. One record per IP that
/// has hit `port_count` distinct ports. `flagged = 1` means the IP
/// crossed sloth's detector threshold; `ports[]` is the observed set
/// (capped on the producer side).
public struct ScanEntry: Sendable, Codable, Equatable, Identifiable {
    public var type: String { "scan_entry" }
    public let ts: Int
    public let ip: String
    public let portCount: Int
    public let firstSeen: Int
    public let lastSeen: Int
    public let flagged: Int
    public let ports: [Int]

    public var id: String { ip }

    public var isFlagged: Bool { flagged != 0 }

    enum CodingKeys: String, CodingKey {
        case type, ts, ip, flagged, ports
        case portCount = "port_count"
        case firstSeen = "first_seen"
        case lastSeen  = "last_seen"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts        = try c.decode(Int.self,    forKey: .ts)
        self.ip        = try c.decode(String.self, forKey: .ip)
        self.portCount = try c.decodeIfPresent(Int.self,    forKey: .portCount) ?? 0
        self.firstSeen = try c.decodeIfPresent(Int.self,    forKey: .firstSeen) ?? 0
        self.lastSeen  = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)  ?? 0
        self.flagged   = try c.decodeIfPresent(Int.self,    forKey: .flagged)   ?? 0
        self.ports     = try c.decodeIfPresent([Int].self,  forKey: .ports)     ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(ts,   forKey: .ts)
        try c.encode(ip,   forKey: .ip)
        try c.encode(portCount, forKey: .portCount)
        try c.encode(firstSeen, forKey: .firstSeen)
        try c.encode(lastSeen,  forKey: .lastSeen)
        try c.encode(flagged,   forKey: .flagged)
        try c.encode(ports,     forKey: .ports)
    }
}

/// `packet` — live packet header (no payload — raw frame bytes are
/// intentionally not emitted). Treated as an event stream on the
/// consumer side, not a snapshot table: sloth's natural-identity
/// tuple `(ts_sec, ts_usec, src, dst)` is essentially unique per
/// packet, so the iOS store keeps the most-recent N in a ring.
public struct PacketEntry: Sendable, Codable, Equatable {
    public var type: String { "packet" }
    public let ts: Int
    public let tsSec: Int
    public let tsUSec: Int
    public let src: String
    public let dst: String
    public let srcPort: Int?
    public let dstPort: Int?
    public let proto: String?
    public let len: Int
    public let info: String?

    enum CodingKeys: String, CodingKey {
        case type, ts, src, dst, proto, len, info
        case tsSec   = "ts_sec"
        case tsUSec  = "ts_usec"
        case srcPort = "src_port"
        case dstPort = "dst_port"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts      = try c.decode(Int.self,    forKey: .ts)
        self.tsSec   = try c.decodeIfPresent(Int.self,    forKey: .tsSec)   ?? 0
        self.tsUSec  = try c.decodeIfPresent(Int.self,    forKey: .tsUSec)  ?? 0
        self.src     = try c.decode(String.self, forKey: .src)
        self.dst     = try c.decode(String.self, forKey: .dst)
        self.srcPort = try c.decodeIfPresent(Int.self,    forKey: .srcPort)
        self.dstPort = try c.decodeIfPresent(Int.self,    forKey: .dstPort)
        self.proto   = try c.decodeIfPresent(String.self, forKey: .proto)
        self.len     = try c.decodeIfPresent(Int.self,    forKey: .len)     ?? 0
        self.info    = try c.decodeIfPresent(String.self, forKey: .info)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type,  forKey: .type)
        try c.encode(ts,    forKey: .ts)
        try c.encode(tsSec, forKey: .tsSec)
        try c.encode(tsUSec, forKey: .tsUSec)
        try c.encode(src,   forKey: .src)
        try c.encode(dst,   forKey: .dst)
        try c.encodeIfPresent(srcPort, forKey: .srcPort)
        try c.encodeIfPresent(dstPort, forKey: .dstPort)
        try c.encodeIfPresent(proto,   forKey: .proto)
        try c.encode(len, forKey: .len)
        try c.encodeIfPresent(info, forKey: .info)
    }
}
