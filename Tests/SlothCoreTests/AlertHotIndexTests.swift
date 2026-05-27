import XCTest
@testable import SlothCore

@MainActor
final class AlertHotIndexTests: XCTestCase {

    // MARK: - bareIP normalisation

    func testBareIPStripsTrailingPort() {
        XCTAssertEqual(AlertHotIndex.bareIP("192.168.1.5:53"), "192.168.1.5")
        XCTAssertEqual(AlertHotIndex.bareIP("203.0.113.7:443"), "203.0.113.7")
    }

    func testBareIPLeavesPortlessAddressesAlone() {
        XCTAssertEqual(AlertHotIndex.bareIP("192.168.1.5"), "192.168.1.5")
    }

    func testBareIPHandlesBracketedIPv6() {
        XCTAssertEqual(AlertHotIndex.bareIP("[fd00::1]:443"), "fd00::1")
    }

    func testBareIPLeavesUnbracketedIPv6Alone() {
        // Multiple colons → can't safely strip; treat as bare v6.
        XCTAssertEqual(AlertHotIndex.bareIP("fd00::1"), "fd00::1")
        XCTAssertEqual(AlertHotIndex.bareIP("::1"), "::1")
    }

    // MARK: - Promotion-only semantics

    func testNoteSetsSeverityForFreshIP() {
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .warn)
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .warn)
    }

    func testLowAlertDoesNotDowngradeLiveCrit() {
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .crit)
        clock.advance(by: 10)
        idx.note(matchIP: "10.0.0.1", severity: .low)
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .crit)
    }

    func testHigherSeverityPromotes() {
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .low)
        clock.advance(by: 10)
        idx.note(matchIP: "10.0.0.1", severity: .warn)
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .warn)
        idx.note(matchIP: "10.0.0.1", severity: .crit)
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .crit)
    }

    func testSameSeverityRefreshesTTL() {
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .warn)
        clock.advance(by: 55)
        idx.note(matchIP: "10.0.0.1", severity: .warn)
        clock.advance(by: 30) // 85s since original; would have expired without refresh
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .warn)
    }

    func testEntryExpiresAfterTTL() {
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .crit)
        clock.advance(by: 61)
        XCTAssertNil(idx.severity(for: "10.0.0.1"))
    }

    func testExpiredEntryReplacedByFreshAlert() {
        // After TTL passes, a fresh LOW *can* set the IP back to LOW —
        // promotion-only applies within the live window, not across
        // re-expiry. Mirrors sloth's `tui_alert_hot_*` lifecycle.
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .crit)
        clock.advance(by: 120)
        idx.note(matchIP: "10.0.0.1", severity: .low)
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .low)
    }

    // MARK: - Cross-key normalisation

    func testLookupByPortlessMatchesEntryRegisteredWithPort() {
        let idx = AlertHotIndex()
        idx.note(matchIP: "192.168.1.5:53", severity: .warn)
        XCTAssertEqual(idx.severity(for: "192.168.1.5"), .warn)
        XCTAssertEqual(idx.severity(for: "192.168.1.5:53"), .warn)
        XCTAssertEqual(idx.severity(for: "192.168.1.5:443"), .warn)
    }

    // MARK: - From AlertEntry

    func testNoteIgnoresAlertWithoutMatchIP() {
        let idx = AlertHotIndex()
        let alert = AlertEntry(ts: 1, title: "T", firstSeen: 1, lastSeen: 1,
                               matchIP: nil, sev: 2)
        idx.note(alert)
        XCTAssertEqual(idx.liveCount, 0)
    }

    func testNoteAcceptsAlertWithMatchIP() {
        let idx = AlertHotIndex()
        let alert = AlertEntry(ts: 1, title: "T", firstSeen: 1, lastSeen: 1,
                               matchIP: "10.0.0.1:53", sev: 2)
        idx.note(alert)
        XCTAssertEqual(idx.severity(for: "10.0.0.1"), .crit)
    }

    // MARK: - Eviction

    func testPurgeRemovesExpiredEntries() {
        let clock = TestClock()
        let idx = AlertHotIndex(ttl: 60, now: clock.now)
        idx.note(matchIP: "10.0.0.1", severity: .crit)
        idx.note(matchIP: "10.0.0.2", severity: .low)
        clock.advance(by: 61)
        idx.note(matchIP: "10.0.0.3", severity: .warn)
        idx.purgeExpired()
        XCTAssertEqual(idx.liveCount, 1)
        XCTAssertEqual(idx.severity(for: "10.0.0.3"), .warn)
        XCTAssertNil(idx.severity(for: "10.0.0.1"))
    }
}

/// Deterministic clock for TTL tests. The index treats the now-closure
/// as read-only state, so mutating the underlying Date is safe under
/// MainActor isolation.
@MainActor
private final class TestClock {
    private var current = Date(timeIntervalSince1970: 0)
    var now: @Sendable () -> Date {
        let box = Box(self)
        return { @Sendable in
            MainActor.assumeIsolated { box.value.current }
        }
    }
    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }

    private struct Box: @unchecked Sendable {
        let value: TestClock
        init(_ value: TestClock) { self.value = value }
    }
}
