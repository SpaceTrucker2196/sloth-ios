import XCTest
@testable import SlothCore

// Fixtures are copied from sloth `docs/wiki/jsonl-schema.md` at
// jsonl_version 2.3.0 (#14, #16).
final class HealthRecordTests: XCTestCase {

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }

    // MARK: - #16: the live `alert` shape

    func testLiveAlertWithoutFirstLastSeenDecodes() throws {
        let r = try decode(#"""
        {"type":"alert","ts":1700000006,"title":"THREAT_DOMAIN","detail":"192.168.1.5 queried malware.testing.com (IOC ...)","key":"threat-d:malware.testing.com","sev":2,"ty":3,"count":1,"incident_id":"9f2c41ab77e30d58"}
        """#)
        guard case .alert(let a) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(a.firstSeen, 1700000006)
        XCTAssertEqual(a.lastSeen,  1700000006)
        XCTAssertEqual(a.hits, 1)
        XCTAssertEqual(a.severity, .crit)
    }

    func testKnownTypeWithBadBodyIsMalformedNotDropped() throws {
        let r = try decode(#"{"type":"alert","ts":9,"sev":2}"#)   // no title
        XCTAssertEqual(r, .malformed(type: "alert", ts: 9))
        XCTAssertEqual(r.typeTag, "alert")
    }

    // MARK: - Lifecycle

    func testDecodeEscalate() throws {
        let r = try decode(#"""
        {"type":"alert.escalate","ts":1700000041,"event_id":"9f2c41ab77e30d58-0002","incident_id":"9f2c41ab77e30d58","key":"mgmtfuzz:ba:ad:f0:0d:00:01","title":"MGMT_FUZZ","detail":"...5 overrun...","sev":2,"ty":31,"prev_sev":1,"observations":2,"evaluations":36,"count":36,"first_detected":1700000006,"last_evaluated":1700000041,"first_observed":1700000006,"last_observed":1700000041,"technique":"T1499"}
        """#)
        guard case .alertEvent(let e) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(e.kind, .escalate)
        XCTAssertEqual(e.prevSev, 1)
        XCTAssertEqual(e.severity, .crit)
        XCTAssertEqual(e.incidentID, "9f2c41ab77e30d58")
        XCTAssertEqual(r.typeTag, "alert.escalate")
        XCTAssertEqual(e.asAlert.hits, 36)
        XCTAssertEqual(e.asAlert.firstSeen, 1700000006)
    }

    func testDecodeResolveReason() throws {
        let r = try decode(#"""
        {"type":"alert.resolve","ts":1700000341,"event_id":"x-0003","incident_id":"x","key":"k","title":"T","sev":2,"ty":31,"reason":"expired"}
        """#)
        guard case .alertEvent(let e) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(e.kind, .resolve)
        XCTAssertEqual(e.reason, "expired")
    }

    func testLifecycleRoundTrips() throws {
        let e = AlertEventEntry(kind: .update, ts: 5, eventID: "i-0002",
                                incidentID: "i", key: "k", title: "T", sev: 0)
        let back = try JSONDecoder().decode(
            SlothRecord.self, from: JSONEncoder().encode(SlothRecord.alertEvent(e)))
        XCTAssertEqual(back, .alertEvent(e))
    }

    // MARK: - sensor_health

    func testDecodeWifiHealthWithDeadMonitor() throws {
        let r = try decode(#"""
        {"type":"sensor_health","ts":1700000000,"capture_iface":"any","monitor_iface":"alfa0","monitor_err":"","chan_requested":11,"chan_confirmed":6,"chan_confirmed_ok":0,"capture_open":1,"capture_running":1,"capture_exit":"none","capture_drop":12,"capture_ifdrop":0,"monitor_open":1,"monitor_running":0,"monitor_exit":"iface_gone","monitor_drop":0,"monitor_ifdrop":3,"evictions":5,"storage_failures":0,"scope":"degraded","scope_not_enforced":1,"daemon":"wifi","db_max_mb":512,"jsonl_version":"2.3.0"}
        """#)
        guard case .sensorHealth(let h) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(h.daemonName, "wifi")
        XCTAssertEqual(h.jsonlMajor, 2)
        XCTAssertEqual(h.droppedPackets, 15)
        XCTAssertEqual(h.problems, [
            "monitor radio stopped (iface_gone)",
            "channel retune not confirmed",
            "capture scope degraded",
        ])
    }

    func testRFHealthHasNoCaptureMembersAndNoProblems() throws {
        let r = try decode(#"""
        {"type":"sensor_health","ts":1,"evictions":0,"storage_failures":0,"daemon":"rf","db_max_mb":-1,"jsonl_version":"2.1.0"}
        """#)
        guard case .sensorHealth(let h) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(h.daemonName, "rf")
        XCTAssertNil(h.captureOpen)
        XCTAssertEqual(h.problems, [])
    }

    func testHealthBefore190ReadsAsWifi() throws {
        let r = try decode(#"{"type":"sensor_health","ts":1,"jsonl_version":"1.7.0"}"#)
        guard case .sensorHealth(let h) = r else { return XCTFail("got \(r)") }
        XCTAssertNil(h.daemon)
        XCTAssertEqual(h.daemonName, "wifi")
        XCTAssertEqual(h.jsonlMajor, 1)
    }

    // MARK: - socket_gap

    func testDecodeSocketGap() throws {
        let r = try decode(#"{"type":"socket_gap","ts":1700000000,"seq":600,"dropped":77,"dropped_total":77}"#)
        XCTAssertEqual(r, .socketGap(SocketGapEntry(ts: 1700000000, seq: 600,
                                                    dropped: 77, droppedTotal: 77)))
    }

    // MARK: - A future MINOR stays harmless

    func testFutureTypeStaysUnknown() throws {
        let r = try decode(#"{"type":"wifi_df","ts":3,"bssid":"aa:bb:cc:dd:ee:ff"}"#)
        XCTAssertEqual(r, .unknown(type: "wifi_df", ts: 3))
    }
}

@MainActor
final class HealthStoreTests: XCTestCase {

    private func event(_ kind: AlertEventEntry.Kind, ts: Int, sev: Int,
                       seq: Int) -> SlothRecord {
        .alertEvent(AlertEventEntry(kind: kind, ts: ts,
                                    eventID: "inc-000\(seq)", incidentID: "inc",
                                    key: "mgmtfuzz:x", title: "MGMT_FUZZ",
                                    sev: sev, matchIP: "10.0.0.9"))
    }

    func testEscalateRaisesTheVisibleSeverity() {
        let store = SlothStore()
        store.ingest(event(.create,   ts: 1, sev: 1, seq: 1))
        store.ingest(event(.escalate, ts: 2, sev: 2, seq: 2))
        XCTAssertEqual(store.alerts.count, 1)
        XCTAssertEqual(store.alerts.first?.severity, .crit)
        XCTAssertEqual(store.alertEvents.count, 2)
    }

    func testResolveKeepsTheRowAndMarksIt() {
        let store = SlothStore()
        store.ingest(event(.create,  ts: 1, sev: 1, seq: 1))
        store.ingest(event(.resolve, ts: 9, sev: 1, seq: 2))
        XCTAssertEqual(store.alerts.count, 1)
        XCTAssertTrue(store.resolvedAlertKeys.contains("mgmtfuzz:x"))
        store.ingest(event(.create,  ts: 20, sev: 1, seq: 1))
        XCTAssertFalse(store.resolvedAlertKeys.contains("mgmtfuzz:x"))
    }

    func testHealthIsKeptPerDaemon() {
        let store = SlothStore()
        store.ingest(.sensorHealth(SensorHealthEntry(ts: 1, daemon: "wifi")))
        store.ingest(.sensorHealth(SensorHealthEntry(ts: 2, daemon: "rf")))
        store.ingest(.sensorHealth(SensorHealthEntry(ts: 3, daemon: "wifi")))
        XCTAssertEqual(store.sensorHealth.count, 2)
        XCTAssertEqual(store.sensorHealth["wifi"]?.ts, 3)
    }

    func testSocketGapAndMalformedAreCounted() {
        let store = SlothStore()
        store.ingest(.socketGap(SocketGapEntry(ts: 1, seq: 10, dropped: 4, droppedTotal: 4)))
        store.ingest(.socketGap(SocketGapEntry(ts: 2, seq: 30, dropped: 3, droppedTotal: 7)))
        store.ingest(.malformed(type: "alert", ts: 3))
        XCTAssertEqual(store.socketDroppedTotal, 7)
        XCTAssertEqual(store.malformedCount, 1)
        store.reset()
        XCTAssertEqual(store.socketDroppedTotal, 0)
        XCTAssertEqual(store.malformedCount, 0)
    }
}
