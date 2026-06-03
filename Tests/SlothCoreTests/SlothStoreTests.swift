import XCTest
@testable import SlothCore

@MainActor
final class SlothStoreTests: XCTestCase {

    // MARK: - Per-type rings

    func testDNSRingAppendsAndCaps() {
        let store = SlothStore(sizes: RingSizes(dns: 3))
        for i in 0..<5 {
            store.ingest(.dns(DNSEntry(ts: i, qname: "q\(i)")))
        }
        XCTAssertEqual(store.dns.count, 3)
        XCTAssertEqual(store.dns.map { $0.qname }, ["q2", "q3", "q4"])
    }

    func testEveryTypeRoutesToItsOwnRing() {
        let store = SlothStore()
        store.ingest(.dns  (DNSEntry  (ts: 1, qname: "a")))
        store.ingest(.tls  (TLSEntry  (ts: 2)))
        store.ingest(.quic (QUICEntry (ts: 3)))
        store.ingest(.http (HTTPEntry (ts: 4)))
        store.ingest(.ntp  (NTPEntry  (ts: 5)))
        store.ingest(.icmp (ICMPEntry (ts: 6)))
        store.ingest(.connections(ConnectionEntry(
            ts: 7, src: "10.0.0.5:1", dst: "1.1.1.1:443", proto: .tcp
        )))
        XCTAssertEqual(store.dns.count,         1)
        XCTAssertEqual(store.tls.count,         1)
        XCTAssertEqual(store.quic.count,        1)
        XCTAssertEqual(store.http.count,        1)
        XCTAssertEqual(store.ntp.count,         1)
        XCTAssertEqual(store.icmp.count,        1)
        XCTAssertEqual(store.connections.count, 1)
    }

    func testConnectionsRingCaps() {
        let store = SlothStore(sizes: RingSizes(connections: 3))
        for i in 0..<5 {
            store.ingest(.connections(ConnectionEntry(
                ts: i, src: "10.0.0.5:\(i)", dst: "1.1.1.1:443", proto: .tcp
            )))
        }
        XCTAssertEqual(store.connections.count, 3)
        XCTAssertEqual(store.connections.map(\.ts), [2, 3, 4])
    }

    func testUnknownTypeIncrementsCounterNotRings() {
        let store = SlothStore()
        store.ingest(.unknown(type: "future", ts: 99))
        XCTAssertEqual(store.unknownCount, 1)
        XCTAssertEqual(store.dns.count + store.tls.count, 0)
    }

    // MARK: - Snapshot tables (M9)

    func testIFaceReplacesOnSameNameAndKeepsSampleTail() throws {
        let store = SlothStore(sizes: RingSizes(ifaceSamples: 4))
        for i in 1...6 {
            let json = """
            {"type":"iface","ts":\(i),"name":"en0","rx_rate":\(Double(i)),"tx_rate":\(Double(i*10))}
            """
            let rec = try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
            store.ingest(rec)
        }
        XCTAssertEqual(store.ifaces.count, 1, "snapshot records replace on natural key, never append")
        XCTAssertEqual(store.ifaces["en0"]?.rxRate, 6)
        XCTAssertEqual(store.ifaceRxSamples["en0"], [3, 4, 5, 6])
        XCTAssertEqual(store.ifaceTxSamples["en0"], [30, 40, 50, 60])
    }

    func testDeviceBeaconTwinReplaceOnNaturalKey() throws {
        let store = SlothStore()
        let device1 = """
        {"type":"device","ts":1,"mac":"aa:bb:cc:dd:ee:ff","hostname":"a"}
        """
        let device2 = """
        {"type":"device","ts":2,"mac":"aa:bb:cc:dd:ee:ff","hostname":"b"}
        """
        let dec = JSONDecoder()
        store.ingest(try dec.decode(SlothRecord.self, from: Data(device1.utf8)))
        store.ingest(try dec.decode(SlothRecord.self, from: Data(device2.utf8)))
        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.devices["aa:bb:cc:dd:ee:ff"]?.hostname, "b")
    }

    func testTopHostReplacesOnIPAndKeepsRateTail() throws {
        let store = SlothStore(sizes: RingSizes(topHostSamples: 3))
        let dec = JSONDecoder()
        for i in 1...5 {
            let json = """
            {"type":"top_host","ts":\(i),"ip":"8.8.8.8","hostname":"dns.google",\
            "owner":"Google DNS","conn_count":\(i),\
            "rx_rate":\(Double(i*100)),"tx_rate":\(Double(i*10)),\
            "rx_bytes":\(i*1000),"tx_bytes":\(i*100),\
            "first_seen":0,"last_seen":\(i)}
            """
            store.ingest(try dec.decode(SlothRecord.self, from: Data(json.utf8)))
        }
        XCTAssertEqual(store.topHosts.count, 1)
        XCTAssertEqual(store.topHosts["8.8.8.8"]?.connCount, 5)
        XCTAssertEqual(store.topHosts["8.8.8.8"]?.rxBytes, 5000)
        // 3-deep tail keeps the last three samples; the appendKeepLast
        // pass on each ingest enforces the cap.
        XCTAssertEqual(store.topHostRxSamples["8.8.8.8"], [300, 400, 500])
        XCTAssertEqual(store.topHostTxSamples["8.8.8.8"], [30, 40, 50])
    }

    func testProcessReplacesOnPIDAndKeepsRateTail() throws {
        let store = SlothStore(sizes: RingSizes(topHostSamples: 3))
        let dec = JSONDecoder()
        for i in 1...5 {
            let json = """
            {"type":"process","ts":\(i),"pid":501,"proc":"firefox",\
            "conn_count":\(i),"rx_rate":\(Double(i*100)),"tx_rate":\(Double(i*10))}
            """
            store.ingest(try dec.decode(SlothRecord.self, from: Data(json.utf8)))
        }
        XCTAssertEqual(store.processes.count, 1)
        XCTAssertEqual(store.processes[501]?.connCount, 5)
        XCTAssertEqual(store.processRxSamples[501], [300, 400, 500])
        XCTAssertEqual(store.processTxSamples[501], [30, 40, 50])
    }

    func testDeauthMDNSDHCPReplaceOnNaturalKey() throws {
        let store = SlothStore()
        let dec = JSONDecoder()
        let a = """
        {"type":"deauth","ts":1,"src":"a","dst":"b","bssid":"x","count":1,"flood":0}
        """
        let b = """
        {"type":"deauth","ts":2,"src":"a","dst":"b","bssid":"x","count":99,"flood":1}
        """
        store.ingest(try dec.decode(SlothRecord.self, from: Data(a.utf8)))
        store.ingest(try dec.decode(SlothRecord.self, from: Data(b.utf8)))
        XCTAssertEqual(store.deauths.count, 1)
        XCTAssertEqual(store.deauths["x|b"]?.count, 99)
        XCTAssertTrue(store.deauths["x|b"]!.isFlood)

        let m1 = """
        {"type":"mdns_service","ts":1,"instance":"i","service":"_x._tcp","host":"a","ip":"1.1.1.1","port":80,"last_seen":1}
        """
        let m2 = """
        {"type":"mdns_service","ts":2,"instance":"i","service":"_x._tcp","host":"a","ip":"1.1.1.1","port":8080,"last_seen":2}
        """
        store.ingest(try dec.decode(SlothRecord.self, from: Data(m1.utf8)))
        store.ingest(try dec.decode(SlothRecord.self, from: Data(m2.utf8)))
        XCTAssertEqual(store.mdnsServices.count, 1)
        XCTAssertEqual(store.mdnsServices["i"]?.port, 8080)

        let d1 = """
        {"type":"dhcp_lease","ts":1,"ip":"192.168.1.5","hostname":"old","expire":100}
        """
        let d2 = """
        {"type":"dhcp_lease","ts":2,"ip":"192.168.1.5","hostname":"new","expire":200}
        """
        store.ingest(try dec.decode(SlothRecord.self, from: Data(d1.utf8)))
        store.ingest(try dec.decode(SlothRecord.self, from: Data(d2.utf8)))
        XCTAssertEqual(store.dhcpLeases.count, 1)
        XCTAssertEqual(store.dhcpLeases["192.168.1.5"]?.hostname, "new")
        XCTAssertEqual(store.dhcpLeases["192.168.1.5"]?.expire, 200)
    }

    func testSnapshotRecordsCountTowardRecordsReceivedButNotRings() throws {
        let store = SlothStore()
        let dec = JSONDecoder()
        let json = """
        {"type":"iface","ts":1,"name":"en0","rx_rate":1.0,"tx_rate":2.0}
        """
        store.ingest(try dec.decode(SlothRecord.self, from: Data(json.utf8)))
        XCTAssertEqual(store.recordsReceived, 1)
        XCTAssertEqual(store.dns.count + store.tls.count + store.connections.count, 0)
    }

    func testRecordsReceivedIncrementsForEveryIngest() {
        let store = SlothStore()
        store.ingest(.dns(DNSEntry(ts: 1, qname: "a")))
        store.ingest(.unknown(type: "future", ts: 2))
        store.ingest(.tls(TLSEntry(ts: 3)))
        XCTAssertEqual(store.recordsReceived, 3)
    }

    // MARK: - Alert dedup + sort

    func testAlertsKeyedByKeyReplacePrior() {
        let store = SlothStore()
        store.ingest(.alert(AlertEntry(
            ts: 1, title: "THREAT", key: "k1", hits: 1,
            firstSeen: 1, lastSeen: 1, sev: 1
        )))
        store.ingest(.alert(AlertEntry(
            ts: 2, title: "THREAT", key: "k1", hits: 3,
            firstSeen: 1, lastSeen: 2, sev: 2
        )))
        XCTAssertEqual(store.alerts.count, 1)
        XCTAssertEqual(store.alerts.first?.hits, 3)
        XCTAssertEqual(store.alerts.first?.severity, .crit)
    }

    func testAlertsSortedNewestFirstByLastSeen() {
        let store = SlothStore()
        store.ingest(.alert(AlertEntry(ts: 1, title: "A", key: "ka", hits: 1, firstSeen: 1, lastSeen: 100, sev: 0)))
        store.ingest(.alert(AlertEntry(ts: 2, title: "B", key: "kb", hits: 1, firstSeen: 2, lastSeen: 300, sev: 1)))
        store.ingest(.alert(AlertEntry(ts: 3, title: "C", key: "kc", hits: 1, firstSeen: 3, lastSeen: 200, sev: 2)))
        XCTAssertEqual(store.alerts.map(\.key), ["kb", "kc", "ka"])
    }

    func testAlertRingRespectsCap() {
        let store = SlothStore(sizes: RingSizes(alerts: 2))
        for i in 0..<5 {
            store.ingest(.alert(AlertEntry(
                ts: i, title: "T\(i)", key: "k\(i)", hits: 1,
                firstSeen: i, lastSeen: i, sev: 0
            )))
        }
        XCTAssertEqual(store.alerts.count, 2)
        // Newest two survive.
        XCTAssertEqual(store.alerts.map(\.key), ["k4", "k3"])
    }

    func testAlertWithoutKeyFallsBackToTitleForDedup() {
        let store = SlothStore()
        store.ingest(.alert(AlertEntry(ts: 1, title: "BURST", firstSeen: 1, lastSeen: 1, sev: 0)))
        store.ingest(.alert(AlertEntry(ts: 2, title: "BURST", firstSeen: 1, lastSeen: 2, sev: 1)))
        XCTAssertEqual(store.alerts.count, 1)
        XCTAssertEqual(store.alerts.first?.severity, .warn)
    }

    // MARK: - AlertHotIndex wiring

    func testAlertIngestPopulatesHotIndex() {
        let store = SlothStore()
        store.ingest(.alert(AlertEntry(
            ts: 1, title: "T", key: "k", hits: 1,
            firstSeen: 1, lastSeen: 1, matchIP: "10.0.0.1:53", sev: 2
        )))
        XCTAssertEqual(store.alertHot.severity(for: "10.0.0.1"), .crit)
    }

    // MARK: - Reset

    func testResetClearsEverything() {
        let store = SlothStore()
        store.ingest(.dns(DNSEntry(ts: 1, qname: "a")))
        store.ingest(.alert(AlertEntry(ts: 1, title: "T", firstSeen: 1, lastSeen: 1, matchIP: "10.0.0.1", sev: 0)))
        store.ingest(.unknown(type: "future", ts: 9))
        store.reset()
        XCTAssertEqual(store.dns.count, 0)
        XCTAssertEqual(store.alerts.count, 0)
        XCTAssertEqual(store.unknownCount, 0)
        XCTAssertEqual(store.recordsReceived, 0)
        XCTAssertEqual(store.connectionState, .idle)
        XCTAssertNil(store.alertHot.severity(for: "10.0.0.1"))
    }

    // MARK: - Stream ingest + connection state

    func testIngestStreamFlipsStateThroughLifecycle() async {
        let store = SlothStore()
        let (stream, cont) = AsyncThrowingStream<SlothRecord, any Error>.makeStream()

        let task = Task { await store.ingest(stream: stream) }

        // Yield once so the consumer enters `.connecting` before we
        // start pushing.
        await Task.yield()
        XCTAssertEqual(store.connectionState, .connecting)

        cont.yield(.dns(DNSEntry(ts: 1, qname: "a")))
        cont.yield(.alert(AlertEntry(ts: 2, title: "T", key: "k", hits: 1,
                                     firstSeen: 2, lastSeen: 2, sev: 2)))
        cont.finish()

        await task.value

        XCTAssertEqual(store.connectionState, .disconnected(reason: nil))
        XCTAssertEqual(store.dns.count, 1)
        XCTAssertEqual(store.alerts.count, 1)
        XCTAssertNil(store.lastError)
    }

    func testIngestStreamSurfacesError() async {
        struct Boom: Error {}
        let store = SlothStore()
        let stream = AsyncThrowingStream<SlothRecord, any Error> { c in
            c.yield(.dns(DNSEntry(ts: 1, qname: "a")))
            c.finish(throwing: Boom())
        }
        await store.ingest(stream: stream)
        if case .disconnected(let reason) = store.connectionState {
            XCTAssertNotNil(reason)
        } else {
            XCTFail("expected .disconnected, got \(store.connectionState)")
        }
        XCTAssertNotNil(store.lastError)
        XCTAssertEqual(store.dns.count, 1)
    }
}
