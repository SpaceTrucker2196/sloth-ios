import XCTest
@testable import SlothCore

final class WireFormatTests: XCTestCase {

    func testJSONLObject() {
        let line = #"{"type":"dns","ts":1,"qname":"x"}"#
        XCTAssertEqual(WireFormat.sniff(Data(line.utf8)), .jsonl)
    }

    func testJSONLArrayIsAlsoAcceptedAsJSON() {
        // Defensive: sloth never emits top-level arrays today, but
        // they're still JSON so the sniffer shouldn't flag them.
        XCTAssertEqual(WireFormat.sniff(Data("[1,2,3]".utf8)), .jsonl)
    }

    func testCEFPrefix() {
        let line = "CEF:0|sloth-net|sloth|1|dns|dns|3|src=192.168.1.5 qname=example.com"
        XCTAssertEqual(WireFormat.sniff(Data(line.utf8)), .cef)
    }

    func testCEFIsCaseSensitive() {
        // ArcSight spec is upper-case CEF: only. A lowercase variant
        // shouldn't be misclassified.
        XCTAssertEqual(WireFormat.sniff(Data("cef:0|x".utf8)), .unknown)
    }

    func testSyslogRFC5424() {
        let line = "<134>1 2026-06-03T09:00:00Z slothbox sloth 1234 dns [sloth@32473 src=\"x\"] {\"type\":\"dns\"}"
        XCTAssertEqual(WireFormat.sniff(Data(line.utf8)), .syslog)
    }

    func testEmptyIsUnknown() {
        XCTAssertEqual(WireFormat.sniff(Data()), .unknown)
    }

    func testRandomGarbageIsUnknown() {
        XCTAssertEqual(WireFormat.sniff(Data("garbled".utf8)), .unknown)
    }
}
