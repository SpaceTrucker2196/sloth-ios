import XCTest
@testable import SlothCore

final class IPClassificationTests: XCTestCase {

    func testRFC1918SkippedV4() {
        XCTAssertFalse(IPClassification.isExternal("10.0.0.1"))
        XCTAssertFalse(IPClassification.isExternal("172.16.0.1"))
        XCTAssertFalse(IPClassification.isExternal("172.31.255.255"))
        XCTAssertFalse(IPClassification.isExternal("192.168.1.1"))
    }

    func testLoopbackLinkLocalMulticastSkippedV4() {
        XCTAssertFalse(IPClassification.isExternal("127.0.0.1"))
        XCTAssertFalse(IPClassification.isExternal("169.254.0.1"))
        XCTAssertFalse(IPClassification.isExternal("224.0.0.1"))
        XCTAssertFalse(IPClassification.isExternal("239.255.255.255"))
    }

    func testExternalV4Accepted() {
        XCTAssertTrue(IPClassification.isExternal("8.8.8.8"))
        XCTAssertTrue(IPClassification.isExternal("1.1.1.1"))
        XCTAssertTrue(IPClassification.isExternal("142.250.80.46"))
    }

    func testRFC1918EdgeBoundariesV4() {
        // 172.16/12 spans 172.16.0.0 through 172.31.255.255.
        XCTAssertTrue(IPClassification.isExternal("172.15.0.1"))
        XCTAssertTrue(IPClassification.isExternal("172.32.0.1"))
    }

    func testIPv6LoopbackLinkLocalMulticastSkipped() {
        XCTAssertFalse(IPClassification.isExternal("::1"))
        XCTAssertFalse(IPClassification.isExternal("fe80::1"))
        XCTAssertFalse(IPClassification.isExternal("ff02::1"))
    }

    func testIPv6ExternalAccepted() {
        XCTAssertTrue(IPClassification.isExternal("2606:4700::1111"))
        XCTAssertTrue(IPClassification.isExternal("2001:db8::1"))
    }

    func testEmptyRejected() {
        XCTAssertFalse(IPClassification.isExternal(""))
    }
}
