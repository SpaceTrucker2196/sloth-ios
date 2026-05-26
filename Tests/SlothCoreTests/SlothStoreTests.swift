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
        XCTAssertEqual(store.dns.count,  1)
        XCTAssertEqual(store.tls.count,  1)
        XCTAssertEqual(store.quic.count, 1)
        XCTAssertEqual(store.http.count, 1)
        XCTAssertEqual(store.ntp.count,  1)
        XCTAssertEqual(store.icmp.count, 1)
    }

    func testUnknownTypeIncrementsCounterNotRings() {
        let store = SlothStore()
        store.ingest(.unknown(type: "future", ts: 99))
        XCTAssertEqual(store.unknownCount, 1)
        XCTAssertEqual(store.dns.count + store.tls.count, 0)
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
