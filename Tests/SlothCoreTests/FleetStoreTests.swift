import XCTest
@testable import SlothCore

@MainActor
final class FleetStoreTests: XCTestCase {

    func testIngestBuildsPostFromHeartbeat() {
        let store = FleetStore()
        store.ingest(.iosPost(IOSPostEntry(ts: 100, post: "p1", name: "iPad A",
                                           role: "roaming", platform: "ipados",
                                           appVer: "1.1", battery: 0.5)))
        XCTAssertEqual(store.roster.count, 1)
        let p = store.roster[0]
        XCTAssertEqual(p.name, "iPad A")
        XCTAssertEqual(p.role, "roaming")
        XCTAssertEqual(p.battery, 0.5)
        XCTAssertTrue(store.isOnline(p, now: 110))
        XCTAssertFalse(store.isOnline(p, now: 200))
    }

    func testContactsAttachToOwningPost() {
        let store = FleetStore()
        store.ingest(.iosPost(IOSPostEntry(ts: 1, post: "p1", name: "A", appVer: "1")))
        store.ingest(.bleContact(BLEContactEntry(ts: 2, post: "p1", addr: "x", rssi: -55)))
        store.ingest(.bleContact(BLEContactEntry(ts: 2, post: "p2", addr: "y", rssi: -70)))
        XCTAssertEqual(store.roster.count, 2)
        XCTAssertEqual(store.blips(forPost: "p1").count, 1)
        XCTAssertEqual(store.blips(forPost: "p1").first?.id, "x")
    }

    func testFleetBlipsNamespaceByPostAndSkipOffline() {
        let store = FleetStore(offlineTTL: 30)
        store.ingest(.iosPost(IOSPostEntry(ts: 100, post: "p1", name: "A", appVer: "1")))
        store.ingest(.bleContact(BLEContactEntry(ts: 100, post: "p1", addr: "x", rssi: -55)))
        store.ingest(.iosPost(IOSPostEntry(ts: 10, post: "p2", name: "B", appVer: "1")))
        store.ingest(.bleContact(BLEContactEntry(ts: 10, post: "p2", addr: "x", rssi: -55)))

        // now=110: p1 online (100), p2 offline (10).
        let blips = store.fleetBlips(now: 110)
        XCTAssertEqual(blips.count, 1)
        XCTAssertEqual(blips.first?.id, "p1/x")
    }

    func testPruneDropsLongDeadPosts() {
        let store = FleetStore()
        store.ingest(.iosPost(IOSPostEntry(ts: 10, post: "old", name: "O", appVer: "1")))
        store.ingest(.iosPost(IOSPostEntry(ts: 500, post: "new", name: "N", appVer: "1")))
        store.prune(now: 600, hardTTL: 120)
        XCTAssertEqual(store.roster.map(\.id), ["new"])
    }
}
