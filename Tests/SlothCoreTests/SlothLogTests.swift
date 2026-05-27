import XCTest
@testable import SlothCore

@MainActor
final class SlothLogTests: XCTestCase {

    func testAppendsAcrossLevels() {
        let log = SlothLog(cap: 100)
        log.debug("a", "d")
        log.info ("a", "i")
        log.warn ("a", "w")
        log.error("a", "e")
        XCTAssertEqual(log.lines.map(\.level), [.debug, .info, .warn, .error])
        XCTAssertEqual(log.lines.map(\.message), ["d", "i", "w", "e"])
    }

    func testRingCap() {
        let log = SlothLog(cap: 3)
        log.info("net", "1")
        log.info("net", "2")
        log.info("net", "3")
        log.info("net", "4")
        XCTAssertEqual(log.lines.count, 3)
        XCTAssertEqual(log.lines.map(\.message), ["2", "3", "4"])
    }

    func testClearEmptiesRing() {
        let log = SlothLog()
        log.info("net", "hi")
        XCTAssertEqual(log.lines.count, 1)
        log.clear()
        XCTAssertTrue(log.lines.isEmpty)
    }

    func testExportShapeIsStable() {
        let log = SlothLog()
        log.info("net", "hello")
        log.warn("app", "slow")
        let text = log.exportAsText()
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("INFO"))
        XCTAssertTrue(lines[0].contains("[net]"))
        XCTAssertTrue(lines[0].contains("hello"))
        XCTAssertTrue(lines[1].contains("WARN"))
    }
}
