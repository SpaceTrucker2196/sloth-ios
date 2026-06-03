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

    func testRoundTripUnknownPreservesTypeAndTs() throws {
        // The `.unknown` case has bespoke encode logic separate from
        // the per-record sub-structs. Cover it explicitly so a
        // regression in that path can't slip through (the original
        // implementation force-unwrapped an absent CodingKey here).
        let original: SlothRecord = .unknown(type: "future_kind", ts: 1716700005)
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(SlothRecord.self, from: data)
        XCTAssertEqual(back, original)

        // Verify the wire shape, not just round-trip equality.
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "future_kind")
        XCTAssertEqual(json["ts"]   as? Int,    1716700005)
    }

    // MARK: - Snapshot records (M9)

    func testDecodeIFace() throws {
        let json = #"""
        {"type":"iface","ts":1716700100,"name":"en0","rx_bytes":1234,"tx_bytes":5678,"rx_packets":10,"tx_packets":12,"rx_errors":0,"rx_drops":0,"tx_errors":0,"tx_drops":0,"rx_rate":1024.50,"tx_rate":512.25,"mtu":1500,"speed_mbps":1000}
        """#
        guard case .iface(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.name, "en0")
        XCTAssertEqual(e.rxRate, 1024.50)
        XCTAssertEqual(e.txRate, 512.25)
        XCTAssertEqual(e.mtu, 1500)
        XCTAssertEqual(e.speedMbps, 1000)
    }

    func testDecodeDevice() throws {
        let json = #"""
        {"type":"device","ts":1716700101,"mac":"aa:bb:cc:dd:ee:ff","ip":"192.168.1.5","hostname":"laptop.local","vendor":"Apple","is_ap":0,"signal_dbm":-55,"probe_count":3,"sources":7,"last_seen":1716700100}
        """#
        guard case .device(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.mac, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(e.hostname, "laptop.local")
        XCTAssertEqual(e.signalDBM, -55)
        XCTAssertEqual(e.isAP, 0)
    }

    func testDecodeBeacon() throws {
        let json = #"""
        {"type":"beacon","ts":1716700102,"bssid":"11:22:33:44:55:66","ssid":"Home-WiFi","signal_dbm":-42,"channel":36,"enc":"WPA3","vendor":"Ubiquiti","phy":"ax","last_seen":1716700102,"frame_count":99,"rssi_min_60s":-50,"rssi_max_60s":-40}
        """#
        guard case .beacon(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.ssid, "Home-WiFi")
        XCTAssertEqual(e.channel, 36)
        XCTAssertEqual(e.enc, "WPA3")
        XCTAssertEqual(e.rssiSwing60s, 10)
    }

    func testDecodeTwinEpisode() throws {
        let json = #"""
        {"type":"twin_episode","ts":1716700103,"ssid":"Cafe-Net","real_bssid":"aa:bb:cc:01:02:03","twin_bssid":"11:22:33:44:55:66","enc":"WPA2","real_rssi":-70,"twin_rssi":-45,"rssi_swing_dbm":25,"attack_in_progress":1,"attacker_oui":1,"hash_mismatch":1}
        """#
        guard case .twinEpisode(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.ssid, "Cafe-Net")
        XCTAssertEqual(e.twinBSSID, "11:22:33:44:55:66")
        XCTAssertEqual(e.rssiSwingDBM, 25)
        XCTAssertEqual(e.attackInProgress, 1)
        XCTAssertEqual(e.severity, .crit, "attack_in_progress=1 must escalate to CRIT")
    }

    func testDecodeTopHost() throws {
        let json = #"""
        {"type":"top_host","ts":1716700200,"ip":"8.8.8.8","hostname":"dns.google","owner":"Google DNS","first_seen":1716695000,"last_seen":1716700200,"conn_count":5,"rx_rate":1234.5,"tx_rate":678.9,"rx_bytes":1048576,"tx_bytes":262144}
        """#
        guard case .topHost(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.ip, "8.8.8.8")
        XCTAssertEqual(e.hostname, "dns.google")
        XCTAssertEqual(e.owner, "Google DNS")
        XCTAssertEqual(e.connCount, 5)
        XCTAssertEqual(e.rxRate, 1234.5)
        XCTAssertEqual(e.txRate, 678.9)
        XCTAssertEqual(e.rxBytes, 1048576)
        XCTAssertEqual(e.txBytes, 262144)
        XCTAssertEqual(e.totalRate, 1913.4, accuracy: 0.001)
    }

    func testDecodeProcess() throws {
        let json = #"""
        {"type":"process","ts":1716700300,"pid":501,"proc":"firefox","ppid":1,"depth":2,"conn_count":12,"tcp_count":10,"udp_count":2,"tx_bytes":98765,"rx_bytes":1234567,"tx_rate":1024.0,"rx_rate":8192.0,"ports":[443,80,53]}
        """#
        guard case .process(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.pid, 501)
        XCTAssertEqual(e.proc, "firefox")
        XCTAssertEqual(e.connCount, 12)
        XCTAssertEqual(e.tcpCount, 10)
        XCTAssertEqual(e.udpCount, 2)
        XCTAssertEqual(e.ports, [443, 80, 53])
        XCTAssertFalse(e.isUnresolved)
        XCTAssertEqual(e.totalRate, 9216.0)
    }

    func testProcessUnresolvedBucket() throws {
        let json = #"""
        {"type":"process","ts":1,"pid":-1,"proc":"(unresolved)","conn_count":3}
        """#
        guard case .process(let e) = try decode(json) else { return XCTFail() }
        XCTAssertTrue(e.isUnresolved)
        XCTAssertEqual(e.pid, -1)
        XCTAssertEqual(e.ports, [], "missing ports should decode as empty, not nil")
    }

    func testTwinEpisodeSeverityLadder() {
        func make(attack: Int, oui: Int, hash: Int, swing: Int) -> TwinEpisodeEntry {
            let json = """
            {"type":"twin_episode","ts":0,"ssid":"s","real_bssid":"a","twin_bssid":"b",\
            "real_rssi":0,"twin_rssi":0,"rssi_swing_dbm":\(swing),\
            "attack_in_progress":\(attack),"attacker_oui":\(oui),"hash_mismatch":\(hash)}
            """
            // swiftlint:disable:next force_try
            return try! JSONDecoder().decode(TwinEpisodeEntry.self, from: Data(json.utf8))
        }
        XCTAssertEqual(make(attack: 1, oui: 0, hash: 0, swing: 0).severity,  .crit)
        XCTAssertEqual(make(attack: 0, oui: 1, hash: 0, swing: 0).severity,  .warn)
        XCTAssertEqual(make(attack: 0, oui: 0, hash: 1, swing: 0).severity,  .warn)
        XCTAssertEqual(make(attack: 0, oui: 0, hash: 0, swing: 20).severity, .warn)
        XCTAssertEqual(make(attack: 0, oui: 0, hash: 0, swing: 0).severity,  .low)
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }
}
