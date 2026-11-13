import XCTest
@testable import SlothCore

final class SensorBufferTests: XCTestCase {

    func testLatchingRecordsReplaceInPlace() {
        var buf = SensorBuffer()
        buf.record(.imuSample(IMUSampleEntry(ts: 1, post: "p", headingDeg: 10)))
        buf.record(.imuSample(IMUSampleEntry(ts: 2, post: "p", headingDeg: 20)))
        let imu = buf.snapshot().compactMap { rec -> IMUSampleEntry? in
            if case .imuSample(let e) = rec { return e } else { return nil }
        }
        XCTAssertEqual(imu.count, 1)
        XCTAssertEqual(imu.first?.headingDeg, 20)
    }

    func testContactsAccumulateAndUpdate() {
        var buf = SensorBuffer()
        buf.record(.bleContact(BLEContactEntry(ts: 1, post: "p", addr: "A", rssi: -50, count: 1)))
        buf.record(.bleContact(BLEContactEntry(ts: 2, post: "p", addr: "B", rssi: -60, count: 1)))
        buf.record(.bleContact(BLEContactEntry(ts: 3, post: "p", addr: "A", rssi: -40, count: 9)))
        XCTAssertEqual(buf.contactCount, 2)
        let a = buf.bleContacts.first { $0.addr == "A" }
        XCTAssertEqual(a?.rssi, -40)
        XCTAssertEqual(a?.count, 9)
    }

    func testContactCapEvictsOldest() {
        var buf = SensorBuffer(maxContacts: 2)
        buf.record(.bleContact(BLEContactEntry(ts: 1, post: "p", addr: "A", rssi: -50)))
        buf.record(.bleContact(BLEContactEntry(ts: 2, post: "p", addr: "B", rssi: -50)))
        buf.record(.bleContact(BLEContactEntry(ts: 3, post: "p", addr: "C", rssi: -50)))
        XCTAssertEqual(buf.contactCount, 2)
        XCTAssertNil(buf.bleContacts.first { $0.addr == "A" })
        XCTAssertNotNil(buf.bleContacts.first { $0.addr == "C" })
    }

    func testSnapshotOrderIdentityFirstThenContacts() {
        var buf = SensorBuffer()
        buf.record(.bleContact(BLEContactEntry(ts: 2, post: "p", addr: "A", rssi: -50)))
        buf.record(.iosPost(IOSPostEntry(ts: 1, post: "p", name: "n", appVer: "1")))
        let tags = buf.snapshot().map(\.typeTag)
        XCTAssertEqual(tags.first, "ios_post")
        XCTAssertEqual(tags.last, "ble_contact")
    }

    func testStaleContactEviction() {
        var buf = SensorBuffer()
        buf.record(.bleContact(BLEContactEntry(ts: 100, post: "p", addr: "A", rssi: -50)))
        buf.record(.bleContact(BLEContactEntry(ts: 140, post: "p", addr: "B", rssi: -50)))
        buf.evictStaleContacts(now: 150, ttl: 30)   // cutoff 120 → A gone
        XCTAssertEqual(buf.contactCount, 1)
        XCTAssertNotNil(buf.bleContacts.first { $0.addr == "B" })
    }

    func testSnapshotLinesAreNewlineTerminated() {
        var buf = SensorBuffer()
        buf.record(.iosPost(IOSPostEntry(ts: 1, post: "p", name: "n", appVer: "1")))
        let lines = buf.snapshotLines()
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.last, 0x0A)
    }
}
