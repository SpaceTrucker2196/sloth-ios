// DashboardRoster tests — hermetic. Fixtures are decoded from wire
// JSON (TopHostEntry / PacketEntry expose no memberwise init) or
// built with the AlertEntry init the alert tests already use.

import XCTest
@testable import SlothCore

final class DashboardRosterTests: XCTestCase {

    // MARK: - newest

    func testNewestSortsByStampDescending() {
        let out = DashboardRoster.newest(
            ["a:1", "b:3", "c:2"],
            stamp: { Int($0.split(separator: ":")[1])! },
            id: { String($0.split(separator: ":")[0]) },
            limit: 10
        )
        XCTAssertEqual(out, ["b:3", "c:2", "a:1"])
    }

    func testNewestBreaksStampTiesByIDAscending() {
        let out = DashboardRoster.newest(
            ["z:5", "a:5", "m:5"],
            stamp: { _ in 5 },
            id: { String($0.split(separator: ":")[0]) },
            limit: 10
        )
        XCTAssertEqual(out, ["a:5", "m:5", "z:5"])
    }

    func testNewestHonoursLimit() {
        let out = DashboardRoster.newest(
            (1...20).map(String.init),
            stamp: { Int($0)! },
            id: { $0 },
            limit: 3
        )
        XCTAssertEqual(out, ["20", "19", "18"])
    }

    func testNewestEmptyInputAndZeroLimit() {
        XCTAssertEqual(
            DashboardRoster.newest([String](), stamp: { _ in 0 }, id: { $0 }, limit: 5),
            []
        )
        XCTAssertEqual(
            DashboardRoster.newest(["x:1"], stamp: { _ in 1 }, id: { $0 }, limit: 0),
            []
        )
    }

    // MARK: - critAlerts

    private func alert(_ key: String, sev: Int, lastSeen: Int) -> AlertEntry {
        AlertEntry(ts: lastSeen, title: key, key: key,
                   firstSeen: lastSeen, lastSeen: lastSeen, sev: sev)
    }

    func testCritAlertsFiltersToCritOnly() {
        let out = DashboardRoster.critAlerts([
            alert("low",  sev: 0, lastSeen: 100),
            alert("warn", sev: 1, lastSeen: 200),
            alert("crit", sev: 2, lastSeen: 50),
        ])
        XCTAssertEqual(out.map { $0.key }, ["crit"])
    }

    func testCritAlertsNewestFirstWithKeyTieBreak() {
        let out = DashboardRoster.critAlerts([
            alert("b", sev: 2, lastSeen: 10),
            alert("a", sev: 2, lastSeen: 10),
            alert("c", sev: 2, lastSeen: 30),
        ])
        XCTAssertEqual(out.map { $0.key }, ["c", "a", "b"])
    }

    func testCritAlertsLimit() {
        let alerts = (1...10).map { alert("k\($0)", sev: 2, lastSeen: $0) }
        XCTAssertEqual(DashboardRoster.critAlerts(alerts, limit: 4).count, 4)
    }

    // MARK: - topHosts

    private func host(_ ip: String, rx: Double, tx: Double) throws -> TopHostEntry {
        let json = """
        {"type":"top_host","ts":1,"ip":"\(ip)","rx_rate":\(rx),"tx_rate":\(tx)}
        """
        guard case .topHost(let e) = try decode(json) else {
            throw XCTSkip("fixture decode failed")
        }
        return e
    }

    func testTopHostsSortsByTotalRateDescending() throws {
        let table = [
            "10.0.0.1": try host("10.0.0.1", rx: 10, tx: 0),
            "10.0.0.2": try host("10.0.0.2", rx: 50, tx: 50),
            "10.0.0.3": try host("10.0.0.3", rx: 0,  tx: 30),
        ]
        let out = DashboardRoster.topHosts(table)
        XCTAssertEqual(out.map { $0.ip }, ["10.0.0.2", "10.0.0.3", "10.0.0.1"])
    }

    func testTopHostsIdleTableIsDeterministicByIP() throws {
        let table = [
            "10.0.0.9": try host("10.0.0.9", rx: 0, tx: 0),
            "10.0.0.1": try host("10.0.0.1", rx: 0, tx: 0),
            "10.0.0.5": try host("10.0.0.5", rx: 0, tx: 0),
        ]
        let out = DashboardRoster.topHosts(table)
        XCTAssertEqual(out.map { $0.ip }, ["10.0.0.1", "10.0.0.5", "10.0.0.9"])
    }

    func testTopHostsLimit() throws {
        var table: [String: TopHostEntry] = [:]
        for i in 1...12 {
            let ip = "10.0.0.\(i)"
            table[ip] = try host(ip, rx: Double(i), tx: 0)
        }
        let out = DashboardRoster.topHosts(table, limit: 5)
        XCTAssertEqual(out.count, 5)
        XCTAssertEqual(out.first?.ip, "10.0.0.12")
    }

    // MARK: - packetTail / logTail

    private func packet(ts: Int, src: String) throws -> PacketEntry {
        let json = """
        {"type":"packet","ts":\(ts),"ts_sec":\(ts),"ts_usec":0,"src":"\(src)","dst":"10.0.0.2","len":60}
        """
        guard case .packet(let e) = try decode(json) else {
            throw XCTSkip("fixture decode failed")
        }
        return e
    }

    func testPacketTailReturnsNewestFirst() throws {
        let ring = [
            try packet(ts: 1, src: "a"),
            try packet(ts: 2, src: "b"),
            try packet(ts: 3, src: "c"),
        ]
        let out = DashboardRoster.packetTail(ring, limit: 2)
        XCTAssertEqual(out.map { $0.src }, ["c", "b"])
    }

    func testLogTailReturnsNewestFirstAndCaps() {
        let ring = Array(1...10)
        XCTAssertEqual(DashboardRoster.logTail(ring, limit: 3), [10, 9, 8])
        XCTAssertEqual(DashboardRoster.logTail([Int](), limit: 3), [])
    }

    // MARK: - helpers

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }
}
