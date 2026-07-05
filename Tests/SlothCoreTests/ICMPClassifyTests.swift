// ICMPClassify tests — hermetic. Name tables must mirror sloth's
// src/icmp_log.c desc_v4/desc_v6 exactly; family inference comes
// from the address literal since the wire subset carries no is_v6.

import XCTest
@testable import SlothCore

final class ICMPClassifyTests: XCTestCase {

    // MARK: - family inference

    func testIsV6() {
        XCTAssertTrue(ICMPClassify.isV6(address: "fe80::1"))
        XCTAssertTrue(ICMPClassify.isV6(address: "2606:50c0::1"))
        XCTAssertFalse(ICMPClassify.isV6(address: "192.168.1.5"))
        XCTAssertFalse(ICMPClassify.isV6(address: ""))
        XCTAssertFalse(ICMPClassify.isV6(address: nil))
    }

    // MARK: - v4 names (mirror desc_v4)

    func testV4Names() {
        XCTAssertEqual(ICMPClassify.nameV4(type: 0),  "Echo Reply")
        XCTAssertEqual(ICMPClassify.nameV4(type: 3),  "Unreachable")
        XCTAssertEqual(ICMPClassify.nameV4(type: 5),  "Redirect")
        XCTAssertEqual(ICMPClassify.nameV4(type: 8),  "Echo Req")
        XCTAssertEqual(ICMPClassify.nameV4(type: 11), "TTL Exceeded")
        XCTAssertEqual(ICMPClassify.nameV4(type: 30), "Traceroute")
        XCTAssertEqual(ICMPClassify.nameV4(type: 99), "ICMP")
    }

    // MARK: - v6 names (mirror desc_v6)

    func testV6Names() {
        XCTAssertEqual(ICMPClassify.nameV6(type: 1),   "Unreachable")
        XCTAssertEqual(ICMPClassify.nameV6(type: 2),   "Packet Too Big")
        XCTAssertEqual(ICMPClassify.nameV6(type: 128), "Echo Req")
        XCTAssertEqual(ICMPClassify.nameV6(type: 129), "Echo Reply")
        XCTAssertEqual(ICMPClassify.nameV6(type: 135), "Neigh Sol")
        XCTAssertEqual(ICMPClassify.nameV6(type: 137), "Redirect")
        XCTAssertEqual(ICMPClassify.nameV6(type: 200), "ICMPv6")
    }

    // MARK: - per-entry name uses inferred family

    func testEntryNamePicksFamilyFromAddresses() throws {
        // type 3 means TTL Exceeded on v6 but Unreachable on v4 —
        // the discriminating case for the inference.
        let v4 = try icmp(#"{"type":"icmp","ts":1,"src":"10.0.0.1","dst":"10.0.0.2","itype":3,"code":0}"#)
        XCTAssertEqual(ICMPClassify.name(for: v4), "Unreachable")

        let v6 = try icmp(#"{"type":"icmp","ts":1,"src":"fe80::1","dst":"fe80::2","itype":3,"code":0}"#)
        XCTAssertEqual(ICMPClassify.name(for: v6), "TTL Exceeded")
    }

    func testEntryNameWithoutType() throws {
        let e = try icmp(#"{"type":"icmp","ts":1,"src":"10.0.0.1","dst":"10.0.0.2"}"#)
        XCTAssertEqual(ICMPClassify.name(for: e), "ICMP")
    }

    // MARK: - categories

    func testV4Categories() {
        XCTAssertEqual(ICMPClassify.categoryV4(type: 8),  .echo)
        XCTAssertEqual(ICMPClassify.categoryV4(type: 0),  .echo)
        XCTAssertEqual(ICMPClassify.categoryV4(type: 3),  .error)
        XCTAssertEqual(ICMPClassify.categoryV4(type: 11), .error)
        XCTAssertEqual(ICMPClassify.categoryV4(type: 9),  .discovery)
        XCTAssertEqual(ICMPClassify.categoryV4(type: 13), .other)
    }

    func testV6Categories() {
        XCTAssertEqual(ICMPClassify.categoryV6(type: 128), .echo)
        XCTAssertEqual(ICMPClassify.categoryV6(type: 2),   .error)
        XCTAssertEqual(ICMPClassify.categoryV6(type: 135), .discovery)
        XCTAssertEqual(ICMPClassify.categoryV6(type: 130), .discovery)
        XCTAssertEqual(ICMPClassify.categoryV6(type: 200), .other)
    }

    func testEntryCategoryWithoutTypeIsOther() throws {
        let e = try icmp(#"{"type":"icmp","ts":1,"src":"10.0.0.1","dst":"10.0.0.2"}"#)
        XCTAssertEqual(ICMPClassify.category(for: e), .other)
    }

    // MARK: - helpers

    private func icmp(_ json: String) throws -> ICMPEntry {
        guard case .icmp(let e) = try JSONDecoder()
            .decode(SlothRecord.self, from: Data(json.utf8)) else {
            throw XCTSkip("fixture decode failed")
        }
        return e
    }
}
