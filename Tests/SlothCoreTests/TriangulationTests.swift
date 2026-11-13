import XCTest
@testable import SlothCore

final class GeoProjectionTests: XCTestCase {

    func testOriginMapsToZero() {
        let p = GeoProjection.enu(lat: 33.3, lon: -111.8, lat0: 33.3, lon0: -111.8)
        XCTAssertEqual(p.x, 0, accuracy: 1e-6)
        XCTAssertEqual(p.y, 0, accuracy: 1e-6)
    }

    func testOneDegreeNorthIsAbout111km() {
        let p = GeoProjection.enu(lat: 1, lon: 0, lat0: 0, lon0: 0)
        XCTAssertEqual(p.y, 111_195, accuracy: 50)   // 2πR/360
        XCTAssertEqual(p.x, 0, accuracy: 1e-6)
    }

    func testEastingShrinksWithLatitude() {
        let equator = GeoProjection.enu(lat: 0, lon: 1, lat0: 0, lon0: 0).x
        let high    = GeoProjection.enu(lat: 60, lon: 1, lat0: 60, lon0: 0).x
        XCTAssertLessThan(high, equator)           // cos(60°) ≈ 0.5
        XCTAssertEqual(high, equator * 0.5, accuracy: equator * 0.01)
    }
}

final class MultilaterationTests: XCTestCase {

    func testFewerThanTwoAnchorsIsNil() {
        XCTAssertNil(Multilateration.solve([]))
        XCTAssertNil(Multilateration.solve([.init(x: 0, y: 0, r: 5)]))
    }

    func testThreeAnchorsRecoverKnownPoint() {
        // Target (3, 4); exact ranges from three anchors.
        let anchors: [Multilateration.Anchor] = [
            .init(x: 0, y: 0, r: 5),
            .init(x: 10, y: 0, r: ((10.0-3)*(10-3) + 16).squareRoot()),
            .init(x: 0, y: 10, r: (9.0 + (10.0-4)*(10-4)).squareRoot()),
        ]
        let fix = try! XCTUnwrap(Multilateration.solve(anchors))
        XCTAssertEqual(fix.x, 3, accuracy: 0.01)
        XCTAssertEqual(fix.y, 4, accuracy: 0.01)
        XCTAssertFalse(fix.coarse)
        XCTAssertEqual(fix.anchors, 3)
    }

    func testTwoCrossingCirclesAreCoarse() {
        // (0,0) r5 and (6,0) r5 cross at x=3, y=±4.
        let fix = try! XCTUnwrap(Multilateration.solve([
            .init(x: 0, y: 0, r: 5), .init(x: 6, y: 0, r: 5)]))
        XCTAssertEqual(fix.x, 3, accuracy: 0.01)
        XCTAssertEqual(abs(fix.y), 4, accuracy: 0.01)
        XCTAssertTrue(fix.coarse)
    }

    func testCollinearAnchorsReturnNil() {
        // Three anchors on a line give a singular LS system.
        XCTAssertNil(Multilateration.solve([
            .init(x: 0, y: 0, r: 5),
            .init(x: 1, y: 0, r: 5),
            .init(x: 2, y: 0, r: 5)]))
    }
}

@MainActor
final class FleetGeometryTests: XCTestCase {

    func testLoneGeolocatedPostYieldsNoTriangulation() {
        let store = FleetStore()
        store.ingest(.iosPost(IOSPostEntry(ts: 100, post: "p1", name: "A", appVer: "1")))
        store.ingest(.geoFix(GeoFixEntry(ts: 100, post: "p1", lat: 33.3, lon: -111.8)))
        store.ingest(.bleContact(BLEContactEntry(ts: 100, post: "p1", addr: "x", rssi: -55)))
        let g = store.fleetGeometry(now: 110)
        XCTAssertEqual(g.posts.count, 1)
        XCTAssertTrue(g.located.isEmpty)
    }

    func testTwoPostsLocateASharedContact() {
        let store = FleetStore()
        // Two posts ~30 m apart (east), both hear addr "x".
        store.ingest(.iosPost(IOSPostEntry(ts: 100, post: "a", name: "A", appVer: "1")))
        store.ingest(.geoFix(GeoFixEntry(ts: 100, post: "a", lat: 33.30000, lon: -111.80000)))
        store.ingest(.bleContact(BLEContactEntry(ts: 100, post: "a", addr: "x", rssi: -60)))
        store.ingest(.iosPost(IOSPostEntry(ts: 100, post: "b", name: "B", appVer: "1")))
        store.ingest(.geoFix(GeoFixEntry(ts: 100, post: "b", lat: 33.30000, lon: -111.79968)))
        store.ingest(.bleContact(BLEContactEntry(ts: 100, post: "b", addr: "x", rssi: -60)))

        let g = store.fleetGeometry(now: 110)
        XCTAssertEqual(g.posts.count, 2)
        XCTAssertEqual(g.located.count, 1)
        XCTAssertEqual(g.located.first?.addr, "x")
        XCTAssertTrue(g.locatedAddrs.contains("x"))
        // Origin post sits at (0,0); the other is east of it.
        let origin = g.posts.first { $0.id == "a" }
        XCTAssertEqual(origin?.x ?? 9, 0, accuracy: 1e-6)
        XCTAssertEqual(origin?.y ?? 9, 0, accuracy: 1e-6)
        XCTAssertGreaterThan(g.posts.first { $0.id == "b" }?.x ?? 0, 0)
    }
}
