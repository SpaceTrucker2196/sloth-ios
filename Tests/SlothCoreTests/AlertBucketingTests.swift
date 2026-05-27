import XCTest
@testable import SlothCore

final class AlertBucketingTests: XCTestCase {

    /// Anchor "now" at a minute boundary (verify: mod 60 == 0) so the
    /// per-minute buckets line up predictably with the offsets in the
    /// fixtures below. 1_700_000_000 is NOT on a boundary (mod 60 == 20);
    /// 1_699_999_980 is.
    private let now = Date(timeIntervalSince1970: 1_699_999_980)

    private func entry(secondsAgo: Int, sev: AlertSeverity, key: String = "k") -> AlertEntry {
        let ts = Int(now.timeIntervalSince1970) - secondsAgo
        return AlertEntry(
            ts: ts, title: "t", detail: nil, key: key, hits: 1,
            firstSeen: ts, lastSeen: ts, matchIP: nil, sev: sev.rawValue
        )
    }

    // MARK: - empty / window edges

    func testEmptyInputProducesNoBuckets() {
        let result = AlertBucketing.buckets(from: [], now: now)
        XCTAssertTrue(result.isEmpty)
    }

    func testAlertOutsideWindowExcluded() {
        let old = entry(secondsAgo: 60 * 61, sev: .crit)
        let result = AlertBucketing.buckets(from: [old], now: now, windowMinutes: 60)
        XCTAssertTrue(result.isEmpty)
    }

    func testAlertExactlyOnWindowEdgeIncluded() {
        // 60 minutes ago to the second — must be in-window with the
        // current `.rounded(.down)` boundary.
        let edge = entry(secondsAgo: 60 * 60, sev: .crit)
        let result = AlertBucketing.buckets(from: [edge], now: now, windowMinutes: 60)
        XCTAssertEqual(result.count, 1)
    }

    func testZeroWindowReturnsEmpty() {
        let fresh = entry(secondsAgo: 5, sev: .crit)
        XCTAssertTrue(AlertBucketing.buckets(from: [fresh], now: now, windowMinutes: 0).isEmpty)
    }

    // MARK: - bucketing

    func testTwoAlertsSameMinuteSameSeverityCollapseToOneBucket() {
        let a = entry(secondsAgo: 10, sev: .warn, key: "a")
        let b = entry(secondsAgo: 30, sev: .warn, key: "b")
        let result = AlertBucketing.buckets(from: [a, b], now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.count, 2)
        XCTAssertEqual(result.first?.severity, .warn)
    }

    func testTwoAlertsSameMinuteDifferentSeverityProduceTwoBuckets() {
        let crit = entry(secondsAgo: 10, sev: .crit, key: "a")
        let warn = entry(secondsAgo: 30, sev: .warn, key: "b")
        let result = AlertBucketing.buckets(from: [crit, warn], now: now)
        XCTAssertEqual(result.count, 2)
        // Severity ordering inside a minute is ascending raw value:
        // LOW(0) then WARN(1) then CRIT(2).
        XCTAssertEqual(result[0].severity, .warn)
        XCTAssertEqual(result[1].severity, .crit)
    }

    func testAlertsInDifferentMinutesProduceSeparateBuckets() {
        // 10 seconds ago and 70 seconds ago — different minute boundaries
        let recent = entry(secondsAgo: 10, sev: .low)
        let older  = entry(secondsAgo: 70, sev: .low)
        let result = AlertBucketing.buckets(from: [recent, older], now: now)
        XCTAssertEqual(result.count, 2)
        // Sorted minute ascending — older first.
        XCTAssertLessThan(result[0].minuteStart, result[1].minuteStart)
    }

    func testMixedThreeTierSpread() {
        let mix: [AlertEntry] = [
            entry(secondsAgo: 30,  sev: .crit, key: "c1"),
            entry(secondsAgo: 31,  sev: .crit, key: "c2"),
            entry(secondsAgo: 32,  sev: .warn, key: "w1"),
            entry(secondsAgo: 33,  sev: .low,  key: "l1"),
            entry(secondsAgo: 90,  sev: .low,  key: "l2"),
        ]
        let result = AlertBucketing.buckets(from: mix, now: now)
        // 1 (low, older) + 3 (one per sev in the recent minute) = 4
        XCTAssertEqual(result.count, 4)
        let recentCounts = Dictionary(
            uniqueKeysWithValues: result.suffix(3).map { ($0.severity, $0.count) }
        )
        XCTAssertEqual(recentCounts[.crit], 2)
        XCTAssertEqual(recentCounts[.warn], 1)
        XCTAssertEqual(recentCounts[.low],  1)
    }
}
