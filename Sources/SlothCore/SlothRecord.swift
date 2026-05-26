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
    case unknown(type: String, ts: Int)

    public var ts: Int {
        switch self {
        case .dns  (let e): return e.ts
        case .tls  (let e): return e.ts
        case .quic (let e): return e.ts
        case .http (let e): return e.ts
        case .ntp  (let e): return e.ts
        case .icmp (let e): return e.ts
        case .alert(let e): return e.ts
        case .unknown(_, let ts): return ts
        }
    }

    public var typeTag: String {
        switch self {
        case .dns:   return "dns"
        case .tls:   return "tls"
        case .quic:  return "quic"
        case .http:  return "http"
        case .ntp:   return "ntp"
        case .icmp:  return "icmp"
        case .alert: return "alert"
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
        case "alert": self = .alert(try AlertEntry(from: decoder))
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
        case .alert(let e): try e.encode(to: encoder)
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
