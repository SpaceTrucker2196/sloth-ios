import XCTest
@testable import SlothCore

final class SlothRecordTests: XCTestCase {

    // MARK: - Per-type decode + ts/typeTag spot checks

    func testDecodeDNS() throws {
        let json = #"""
        {"type":"dns","ts":1716700000,"src":"192.168.1.5:53","qname":"example.com","qtype":"A","answer":"93.184.216.34","rcode":0}
        """#
        let r = try decode(json)
        guard case .dns(let e) = r else { return XCTFail("wrong case: \(r)") }
        XCTAssertEqual(e.ts, 1716700000)
        XCTAssertEqual(e.qname, "example.com")
        XCTAssertEqual(e.answer, "93.184.216.34")
        XCTAssertEqual(r.typeTag, "dns")
    }

    func testDecodeTLS() throws {
        let json = #"""
        {"type":"tls","ts":1,"src":"10.0.0.5","dst":"1.1.1.1:443","sni":"cloudflare.com","version":"1.3","ja3":"abc123"}
        """#
        guard case .tls(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.sni, "cloudflare.com")
        XCTAssertEqual(e.version, "1.3")
    }

    func testDecodeQUIC() throws {
        let json = #"""
        {"type":"quic","ts":2,"src":"10.0.0.5","dst":"8.8.8.8:443","sni":"dns.google","version":"1"}
        """#
        guard case .quic(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.sni, "dns.google")
    }

    func testDecodeHTTP() throws {
        let json = #"""
        {"type":"http","ts":3,"src":"10.0.0.5","dst":"93.184.216.34:80","host":"example.com","method":"GET","path":"/"}
        """#
        guard case .http(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.method, "GET")
        XCTAssertEqual(e.path, "/")
    }

    func testDecodeNTP() throws {
        let json = #"""
        {"type":"ntp","ts":4,"src":"10.0.0.5","dst":"time.apple.com:123","stratum":1}
        """#
        guard case .ntp(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.stratum, 1)
    }

    func testDecodeICMP() throws {
        let json = #"""
        {"type":"icmp","ts":5,"src":"10.0.0.5","dst":"8.8.8.8","itype":8,"code":0}
        """#
        guard case .icmp(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.icmpType, 8)
        XCTAssertEqual(e.code, 0)
    }

    func testDecodeAlert() throws {
        let json = #"""
        {"type":"alert","ts":1000,"title":"THREAT_DOMAIN","detail":"queried bad.test","key":"threat-d:bad.test","hits":4,"first_seen":990,"last_seen":1000,"match_ip":"192.168.1.5:53","sev":2}
        """#
        guard case .alert(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.severity, .crit)
        XCTAssertEqual(e.hits, 4)
        XCTAssertEqual(e.matchIP, "192.168.1.5:53")
        XCTAssertEqual(e.firstSeen, 990)
        XCTAssertEqual(e.lastSeen, 1000)
    }

    // MARK: - Forward compatibility

    func testUnknownTypePreservesTs() throws {
        let json = #"{"type":"future_thing","ts":42,"weird":"ok"}"#
        guard case .unknown(let tag, let ts) = try decode(json) else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(tag, "future_thing")
        XCTAssertEqual(ts, 42)
    }

    func testUnknownFieldsInKnownRecordIgnored() throws {
        let json = #"""
        {"type":"dns","ts":1,"qname":"x","future_field":"ok","another":123}
        """#
        guard case .dns(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.qname, "x")
    }

    func testAlertHitsDefaultsToOne() throws {
        // sloth has emitted alerts without `hits` in older versions;
        // the reader treats absence as 1.
        let json = #"""
        {"type":"alert","ts":1,"title":"T","first_seen":1,"last_seen":1,"sev":0}
        """#
        guard case .alert(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.hits, 1)
        XCTAssertEqual(e.severity, .low)
    }

    // MARK: - Encode round-trip

    func testRoundTripAllKnownTypes() throws {
        let samples: [SlothRecord] = [
            .dns  (.init(ts: 1, src: "a", qname: "q", qtype: "A", answer: "1.2.3.4", rcode: 0)),
            .tls  (.init(ts: 2, src: "a", dst: "b", sni: "s", version: "1.3", ja3: "j")),
            .quic (.init(ts: 3, src: "a", dst: "b", sni: "s", version: "1")),
            .http (.init(ts: 4, src: "a", dst: "b", host: "h", method: "GET", path: "/")),
            .ntp  (.init(ts: 5, src: "a", dst: "b", stratum: 1)),
            .icmp (.init(ts: 6, src: "a", dst: "b", icmpType: 8, code: 0)),
            .alert(.init(ts: 7, title: "T", detail: "d", key: "k", hits: 3,
                         firstSeen: 7, lastSeen: 7, matchIP: "x", sev: 1)),
        ]
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        for original in samples {
            let data = try enc.encode(original)
            let back = try dec.decode(SlothRecord.self, from: data)
            XCTAssertEqual(back, original, "round-trip failed for \(original.typeTag)")
        }
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }
}
