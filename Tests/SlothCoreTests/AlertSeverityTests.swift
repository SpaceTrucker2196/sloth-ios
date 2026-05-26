import XCTest
@testable import SlothCore

final class AlertSeverityTests: XCTestCase {

    func testWireValuesAreStable() {
        // The integers below are the JSONL `sev` field. They must
        // never change — sloth's writer commits to them.
        XCTAssertEqual(AlertSeverity.low.rawValue,  0)
        XCTAssertEqual(AlertSeverity.warn.rawValue, 1)
        XCTAssertEqual(AlertSeverity.crit.rawValue, 2)
    }

    func testPromotionOnly() {
        XCTAssertEqual(AlertSeverity.low.max(.crit),  .crit)
        XCTAssertEqual(AlertSeverity.crit.max(.low),  .crit)
        XCTAssertEqual(AlertSeverity.warn.max(.low),  .warn)
        XCTAssertEqual(AlertSeverity.low.max(.warn),  .warn)
        XCTAssertEqual(AlertSeverity.low.max(.low),   .low)
    }

    func testSymbolAndBoldRulesMatchTheTUI() {
        // Mirror sloth's tui_alert_hot_attr: bold on WARN + CRIT only.
        XCTAssertFalse(AlertSeverity.low.prefersBold)
        XCTAssertTrue (AlertSeverity.warn.prefersBold)
        XCTAssertTrue (AlertSeverity.crit.prefersBold)

        // Symbol names must be valid SF Symbols (smoke check: not empty).
        for sev in AlertSeverity.allCases {
            XCTAssertFalse(sev.symbolName.isEmpty)
        }
    }

    func testCodableRoundTrip() throws {
        for sev in AlertSeverity.allCases {
            let data = try JSONEncoder().encode(sev)
            let back = try JSONDecoder().decode(AlertSeverity.self, from: data)
            XCTAssertEqual(back, sev)
        }
    }
}
