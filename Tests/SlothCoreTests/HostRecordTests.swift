import XCTest
@testable import SlothCore

// #14: host status and the source inventory. Lines copied from the
// sloth schema page's examples.

@MainActor
final class HostRecordTests: XCTestCase {

    private func decode(_ line: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(line.utf8))
    }

    func testSchemaExamplesDecode() throws {
        let sys = #"{"type":"sys_status","ts":1800000060,"seq":2,"interval_s":60,"cpu_pct":15.0,"cpu_iowait_pct":10.0,"cpu_band":"low","load1":0.20,"load5":0.18,"load15":0.12,"mem_total_kb":3884328,"mem_avail_kb":2913246,"mem_band":"ok","uptime_s":350735,"rss_kb":12276,"disk_for":"db","disk_free_mb":21840,"disk_total_mb":29500,"disk_band":"ok","temps":3,"temp_max_c":51.0,"temp_max_id":"hwmon3/temp1","temp_band":"ok","volts":3,"undervolt":0,"power":0,"sources":7,"sources_configured":4,"sources_ok":3,"sources_down":0,"receivers":5,"beacon_recall_slots":4096}"#
        guard case .sysStatus(let s) = try decode(sys) else { return XCTFail() }
        XCTAssertEqual(s.seq, 2)
        XCTAssertEqual(s.tempMaxC, 51.0)
        XCTAssertEqual(s.problems, [])
        XCTAssertEqual(try XCTUnwrap(s.memUsedPct), 25, accuracy: 0.1)

        let volt = #"{"type":"sys_sensor","ts":1800000000,"seq":1,"class":"volt","id":"hwmon1/in0","label":"rpi_volt","alarm":0}"#
        guard case .sysSensor(let v) = try decode(volt) else { return XCTFail() }
        XCTAssertEqual(v.class, "volt")
        XCTAssertNil(v.v)

        let src = #"{"type":"source_status","ts":1800000060,"seq":2,"name":"monitor","kind":"wifi-monitor","flag":"a monitor-mode interface","state":"ok","detail":"","endpoint":"wlan1mon","hw":"usb:1-1.4","desc":"Realtek RTL8812AU 802.11ac","driver":"rtl88XXau","age_s":0,"age_band":"fresh","unit":"frames","count":184220,"rate":51.30,"errors":0}"#
        guard case .sourceStatus(let m) = try decode(src) else { return XCTFail() }
        XCTAssertEqual(m.stateValue, .ok)
        XCTAssertEqual(m.count, 184220)

        let off = #"{"type":"source_status","ts":1800000060,"seq":2,"name":"aprs","kind":"aprs","flag":"--aprs","state":"not_configured","detail":"","endpoint":""}"#
        guard case .sourceStatus(let a) = try decode(off) else { return XCTFail() }
        XCTAssertEqual(a.stateValue, .notConfigured)
        XCTAssertNil(a.ageS)

        let hw = #"{"type":"receiver_hw","ts":1800000000,"seq":1,"key":"net:wlan0","kind":"wifi","bus":"sdio","id":"02d0:a9a6","known":0,"desc":"","vendor":"","product":"","driver":"brcmfmac","ifaces":"wlan0"}"#
        guard case .receiverHW(let r) = try decode(hw) else { return XCTFail() }
        XCTAssertEqual(r.usbID, "02d0:a9a6")
        XCTAssertEqual(r.displayName, "brcmfmac")
    }

    func testProblemsNameBadBands() {
        let s = SysStatusEntry(ts: 1, seq: 1, cpuBand: "busy", tempBand: "hot",
                               undervolt: 1, sourcesDown: 2)
        XCTAssertEqual(s.problems, ["under-voltage", "temp hot", "2 sources down"])
    }

    func testEachStreamKeepsItsOwnReport() {
        let store = SlothStore()
        store.ingest(.sysStatus(SysStatusEntry(ts: 1, seq: 4, tempMaxC: 50)))
        store.ingestRF(.sysStatus(SysStatusEntry(ts: 1, seq: 9, tempMaxC: 61)))
        XCTAssertEqual(store.hostReports["wifi"]?.status?.tempMaxC, 50)
        XCTAssertEqual(store.hostReports["rf"]?.status?.tempMaxC, 61)
    }

    func testNewBatchReplacesSensorsAndReceivers() {
        let store = SlothStore()
        store.ingest(.sysStatus(SysStatusEntry(ts: 1, seq: 1)))
        store.ingest(.sysSensor(SysSensorEntry(ts: 1, seq: 1, class: "temp", id: "tz0", c: 40)))
        store.ingest(.sysSensor(SysSensorEntry(ts: 1, seq: 1, class: "temp", id: "tz1", c: 41)))
        store.ingest(.receiverHW(ReceiverHWEntry(ts: 1, seq: 1, key: "usb:1-1.2")))
        store.ingest(.sourceStatus(SourceStatusEntry(ts: 1, seq: 1, name: "monitor", state: "ok")))

        store.ingest(.sysStatus(SysStatusEntry(ts: 61, seq: 2)))
        store.ingest(.sysSensor(SysSensorEntry(ts: 61, seq: 2, class: "temp", id: "tz0", c: 42)))

        let r = store.hostReports["wifi"]
        XCTAssertEqual(r?.sensors.map(\.id), ["tz0"])        // tz1 left the host
        XCTAssertEqual(r?.sensors.first?.c, 42)
        XCTAssertEqual(r?.receivers, [])                      // dongle unplugged
        XCTAssertEqual(r?.sources["monitor"]?.state, "ok")    // kept per row
    }

    func testDaemonRestartStartsOver() {
        let store = SlothStore()
        store.ingest(.sysStatus(SysStatusEntry(ts: 1, seq: 30)))
        store.ingest(.sysSensor(SysSensorEntry(ts: 1, seq: 30, class: "temp", id: "tz0")))
        store.ingest(.sysStatus(SysStatusEntry(ts: 2, seq: 1)))
        store.ingest(.sysSensor(SysSensorEntry(ts: 2, seq: 1, class: "temp", id: "tz9")))
        XCTAssertEqual(store.hostReports["wifi"]?.seq, 1)
        XCTAssertEqual(store.hostReports["wifi"]?.sensors.map(\.id), ["tz9"])
    }

    func testSourceListPutsConfiguredFirst() {
        var r = HostReport()
        r.apply(SourceStatusEntry(ts: 1, seq: 1, name: "adsb", state: "not_configured"))
        r.apply(SourceStatusEntry(ts: 1, seq: 1, name: "gnss", state: "ok"))
        r.apply(SourceStatusEntry(ts: 1, seq: 1, name: "aprs", state: "down"))
        XCTAssertEqual(r.sourceList.map(\.name), ["aprs", "gnss", "adsb"])
    }

    func testResetClearsHostReports() {
        let store = SlothStore()
        store.ingest(.sysStatus(SysStatusEntry(ts: 1, seq: 1)))
        store.reset()
        XCTAssertTrue(store.hostReports.isEmpty)
    }

    // JSONL 2.5.0: sloth-rf's state for a decoder it trimmed (no SDR).
    func testNotInstalledSortsWithTheInactiveRows() throws {
        let line = #"{"type":"source_status","ts":1800000060,"seq":2,"name":"rtl433","kind":"sub-ghz","flag":"--rtl433","state":"not_installed","detail":"not started: no SDR on USB at startup (--no-sdr-trim keeps it)","endpoint":"/var/lib/rtl_433/events.jsonl"}"#
        guard case .sourceStatus(let r) = try decode(line) else { return XCTFail() }
        XCTAssertEqual(r.stateValue, .notInstalled)
        XCTAssertTrue(r.isInactive)

        let store = SlothStore()
        store.ingestRF(.sourceStatus(r))
        store.ingestRF(.sourceStatus(SourceStatusEntry(ts: 1, seq: 2, name: "zz", state: "ok")))
        XCTAssertEqual(store.hostReports["rf"]?.sourceList.map(\.name), ["zz", "rtl433"])
    }

    // Lines from W9FJC's live stream, 2026-11-19.
    func testSensorRegistryFromLiveStream() throws {
        let wifi = #"{"type":"sensor","ts":1795121756,"kind":"wifi","state":"active","name":"Wi-Fi monitor","iface":"alfa0","observed":35118365,"first_seen":1795059346,"last_seen":1795121756}"#
        let ble = #"{"type":"sensor","ts":1795121756,"kind":"ble","state":"active","name":"BLE HCI monitor","iface":"bluetooth-monitor","observed":7632707,"first_seen":1795059346,"last_seen":1795121756}"#
        guard case .sensor(let w) = try decode(wifi), case .sensor(let b) = try decode(ble)
        else { return XCTFail() }
        XCTAssertEqual(w.id, "wifi/alfa0")
        XCTAssertEqual(w.stateValue, .active)
        XCTAssertEqual(w.firstSeen, 1795059346)

        let store = SlothStore()
        store.ingest(.sensor(w))
        store.ingest(.sensor(b))
        // A later row for the same radio replaces it, not adds.
        store.ingest(.sensor(SensorEntry(ts: 2, kind: "wifi", state: "error", iface: "alfa0")))
        let radios = try XCTUnwrap(store.hostReports["wifi"]?.radioList)
        XCTAssertEqual(radios.map(\.id), ["ble/bluetooth-monitor", "wifi/alfa0"])
        XCTAssertEqual(radios.last?.stateValue, .error)
        XCTAssertEqual(store.unknownCount, 0)
    }
}
