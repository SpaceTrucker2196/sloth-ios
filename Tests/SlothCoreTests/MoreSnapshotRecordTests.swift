// Decode happy-path coverage for the second wave of snapshot
// records (M10 — arp, ssdp_device, nbns_name, probe_client,
// pnl_client, seqnum_*, channel_summary, assoc, eapol, scan_entry,
// packet). Earlier records already exercise the envelope + unknown
// fallback in SlothRecordTests; here we just verify each new case
// decodes and routes through the SlothRecord sum type.

import XCTest
@testable import SlothCore

@MainActor
final class MoreSnapshotRecordTests: XCTestCase {

    func testDecodeARP() throws {
        let json = #"{"type":"arp","ts":1,"mac":"aa:bb:cc:dd:ee:ff","ip":"192.168.1.5","iface":"en0"}"#
        guard case .arp(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.mac, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(e.id, "aa:bb:cc:dd:ee:ff|192.168.1.5")
        XCTAssertEqual(e.iface, "en0")
    }

    func testDecodeSSDPDevice() throws {
        let json = #"{"type":"ssdp_device","ts":2,"usn":"uuid:42::urn:foo","ip":"192.168.1.1","kind":"urn:schemas-upnp-org:device:InternetGatewayDevice:1","location":"http://192.168.1.1:1900/desc.xml","nts":"ssdp:alive","last_seen":2}"#
        guard case .ssdpDevice(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.usn, "uuid:42::urn:foo")
        XCTAssertEqual(e.kind, "urn:schemas-upnp-org:device:InternetGatewayDevice:1")
        XCTAssertEqual(e.nts, "ssdp:alive")
    }

    func testDecodeNBNSName() throws {
        let json = #"{"type":"nbns_name","ts":3,"name":"DESKTOP-ABC","ip":"192.168.1.10","suffix":"00","last_seen":3}"#
        guard case .nbnsName(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.name, "DESKTOP-ABC")
        XCTAssertEqual(e.suffix, "00")
        XCTAssertEqual(e.id, "DESKTOP-ABC|192.168.1.10")
    }

    func testDecodeProbeClient() throws {
        let json = #"{"type":"probe_client","ts":4,"mac":"11:22:33:44:55:66","ssid":"Home-WiFi","signal_dbm":-58,"channel":11,"first_seen":1,"last_seen":4,"frame_count":21}"#
        guard case .probeClient(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.ssid, "Home-WiFi")
        XCTAssertEqual(e.signalDBM, -58)
        XCTAssertEqual(e.frameCount, 21)
    }

    func testDecodePNLClient() throws {
        let json = #"{"type":"pnl_client","ts":5,"mac":"11:22:33:44:55:66","mac_random":1,"probe_count":34,"os_fp":"iPhone","phy":"ax","first_seen":1,"last_seen":5,"ssids":["Home-WiFi","Cafe","Airport-Free"]}"#
        guard case .pnlClient(let e) = try decode(json) else { return XCTFail() }
        XCTAssertTrue(e.isRandomMAC)
        XCTAssertEqual(e.ssids, ["Home-WiFi", "Cafe", "Airport-Free"])
        XCTAssertEqual(e.osFP, "iPhone")
    }

    func testDecodeSeqnumClient() throws {
        let json = #"{"type":"seqnum_client","ts":6,"mac":"11:22:33:44:55:66","mac_random":0,"last_seen":6,"frame_count":12,"hist":[100,101,102,200]}"#
        guard case .seqnumClient(let e) = try decode(json) else { return XCTFail() }
        XCTAssertFalse(e.isRandomMAC)
        XCTAssertEqual(e.hist, [100, 101, 102, 200])
    }

    func testDecodeSeqnumCorrelation() throws {
        let json = #"{"type":"seqnum_correlation","ts":7,"mac_a":"aa:..","mac_b":"bb:..","mac_a_random":1,"mac_b_random":0,"gap":3,"dt_ms":120,"a_count":50,"b_count":48}"#
        guard case .seqnumCorrelation(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.gap, 3)
        XCTAssertEqual(e.dtMS, 120)
        XCTAssertEqual(e.id, "aa:..|bb:..")
    }

    func testDecodeChannelSummary() throws {
        let json = #"{"type":"channel_summary","ts":8,"channel":36,"ap_count":4,"assoc_count":12,"best_signal":-42,"top_ssid":"Home","last_seen":8}"#
        guard case .channelSummary(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.channel, 36)
        XCTAssertEqual(e.apCount, 4)
        XCTAssertEqual(e.assocCount, 12)
        XCTAssertEqual(e.topSSID, "Home")
    }

    func testDecodeAssoc() throws {
        let json = #"{"type":"assoc","ts":9,"bssid":"aa:bb:cc:01:02:03","sta_mac":"11:22:33:44:55:66","ssid":"Home","sta_random":0,"source":"ASSOC_SRC_BEACON","channel":36,"signal_dbm":-50,"first_seen":1,"last_seen":9,"frame_count":7}"#
        guard case .assoc(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.bssid, "aa:bb:cc:01:02:03")
        XCTAssertEqual(e.staMAC, "11:22:33:44:55:66")
        XCTAssertEqual(e.source, "ASSOC_SRC_BEACON")
        XCTAssertEqual(e.id, "aa:bb:cc:01:02:03|11:22:33:44:55:66")
    }

    func testDecodeEAPOL() throws {
        let json = #"{"type":"eapol","ts":10,"bssid":"aa:bb:cc:01:02:03","sta_mac":"11:22:33:44:55:66","ssid":"Home","event_ts":10,"msg_num":3,"has_pmkid":1,"handshake_complete":1,"signal_dbm":-50,"channel":36}"#
        guard case .eapol(let e) = try decode(json) else { return XCTFail() }
        XCTAssertTrue(e.isComplete)
        XCTAssertTrue(e.hasPMKIDFlag)
        XCTAssertEqual(e.msgNum, 3)
    }

    func testDecodeScanEntry() throws {
        let json = #"{"type":"scan_entry","ts":11,"ip":"203.0.113.5","port_count":50,"first_seen":1,"last_seen":11,"flagged":1,"ports":[22,23,80,443,3389]}"#
        guard case .scanEntry(let e) = try decode(json) else { return XCTFail() }
        XCTAssertTrue(e.isFlagged)
        XCTAssertEqual(e.portCount, 50)
        XCTAssertEqual(e.ports, [22, 23, 80, 443, 3389])
    }

    func testDecodeWiFiAPConnected() throws {
        let json = #"{"type":"wifi_ap","ts":100,"bssid":"aa:bb:cc:01:02:03","ssid":"Home","signal_dbm":-42,"channel":36,"enc":"WPA3","status":"CONNECTED"}"#
        guard case .wifiAP(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.ssid, "Home")
        XCTAssertTrue(e.isConnected, "CONNECTED status must light up isConnected")
    }

    func testWiFiAPConnectedAliasesForFutureProducerRename() throws {
        // A future sloth that emits "ASSOCIATED" instead of "CONNECTED"
        // shouldn't silently lose the indicator on the consumer side.
        let json = #"{"type":"wifi_ap","ts":1,"bssid":"x","status":"ASSOCIATED"}"#
        guard case .wifiAP(let e) = try decode(json) else { return XCTFail() }
        XCTAssertTrue(e.isConnected)
    }

    func testDecodeWiFiSTA() throws {
        let json = #"{"type":"wifi_sta","ts":101,"mac":"11:22:33:44:55:66","signal_dbm":-58,"tx_rate_kbps":866000,"rx_rate_kbps":650000,"connected_secs":3600,"inactive_ms":120,"tx_bytes":12345678,"rx_bytes":98765432}"#
        guard case .wifiSTA(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.mac, "11:22:33:44:55:66")
        XCTAssertEqual(e.txRateKbps, 866000)
        XCTAssertEqual(e.rxRateKbps, 650000)
        XCTAssertEqual(e.totalKbps, 1516000)
        XCTAssertEqual(e.connectedSecs, 3600)
    }

    func testDecodePacket() throws {
        let json = #"{"type":"packet","ts":12,"ts_sec":12,"ts_usec":345678,"src":"10.0.0.5","dst":"8.8.8.8","src_port":54321,"dst_port":53,"proto":"udp","len":74,"info":"DNS A example.com"}"#
        guard case .packet(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.src, "10.0.0.5")
        XCTAssertEqual(e.dst, "8.8.8.8")
        XCTAssertEqual(e.srcPort, 54321)
        XCTAssertEqual(e.dstPort, 53)
        XCTAssertEqual(e.proto, "udp")
        XCTAssertEqual(e.info, "DNS A example.com")
    }

    // Store-level smoke check: every new record routes into the
    // correct table without inflating the others.

    func testStoreRoutesEachNewRecordToItsOwnTable() throws {
        let store = SlothStore()
        let cases: [(String, (SlothStore) -> Int)] = [
            (#"{"type":"arp","ts":1,"mac":"m","ip":"i"}"#,
             { $0.arpEntries.count }),
            (#"{"type":"ssdp_device","ts":1,"usn":"u"}"#,
             { $0.ssdpDevices.count }),
            (#"{"type":"nbns_name","ts":1,"name":"n","ip":"i"}"#,
             { $0.nbnsNames.count }),
            (#"{"type":"probe_client","ts":1,"mac":"m"}"#,
             { $0.probeClients.count }),
            (#"{"type":"pnl_client","ts":1,"mac":"m"}"#,
             { $0.pnlClients.count }),
            (#"{"type":"seqnum_client","ts":1,"mac":"m"}"#,
             { $0.seqnumClients.count }),
            (#"{"type":"seqnum_correlation","ts":1,"mac_a":"a","mac_b":"b"}"#,
             { $0.seqnumCorrelations.count }),
            (#"{"type":"channel_summary","ts":1,"channel":36}"#,
             { $0.channelSummaries.count }),
            (#"{"type":"assoc","ts":1,"bssid":"b","sta_mac":"s"}"#,
             { $0.assocs.count }),
            (#"{"type":"eapol","ts":1,"bssid":"b","sta_mac":"s"}"#,
             { $0.eapols.count }),
            (#"{"type":"scan_entry","ts":1,"ip":"i"}"#,
             { $0.scans.count }),
            (#"{"type":"wifi_ap","ts":1,"bssid":"b"}"#,
             { $0.wifiAPs.count }),
            (#"{"type":"wifi_sta","ts":1,"mac":"m"}"#,
             { $0.wifiSTAs.count }),
        ]
        for (json, reader) in cases {
            store.ingest(try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8)))
            XCTAssertEqual(reader(store), 1, "first ingest for \(json) should populate its table")
        }
    }

    func testPacketsRingCaps() throws {
        let store = SlothStore(sizes: RingSizes(packets: 3))
        for i in 1...5 {
            let json = #"{"type":"packet","ts":\#(i),"ts_sec":\#(i),"ts_usec":0,"src":"a","dst":"b","len":1}"#
            store.ingest(try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8)))
        }
        XCTAssertEqual(store.packets.count, 3)
        XCTAssertEqual(store.packets.map(\.ts), [3, 4, 5])
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }
}
