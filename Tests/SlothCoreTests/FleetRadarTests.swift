import XCTest
@testable import SlothCore

final class FleetRadarTests: XCTestCase {

    func testRangeMappingMonotonicAndClamped() {
        XCTAssertEqual(FleetRadar.range(forRSSI: -20), 0, accuracy: 0.0001)  // closer than ref → clamp 0
        XCTAssertEqual(FleetRadar.range(forRSSI: -30), 0, accuracy: 0.0001)
        XCTAssertEqual(FleetRadar.range(forRSSI: -100), 1, accuracy: 0.0001)
        XCTAssertEqual(FleetRadar.range(forRSSI: -120), 1, accuracy: 0.0001)  // weaker than floor → clamp 1
        let mid = FleetRadar.range(forRSSI: -65)
        XCTAssertGreaterThan(mid, 0)
        XCTAssertLessThan(mid, 1)
        // Stronger signal => smaller range.
        XCTAssertLessThan(FleetRadar.range(forRSSI: -50), FleetRadar.range(forRSSI: -80))
    }

    func testStableAngleDeterministicAndInRange() {
        let a1 = FleetRadar.stableAngle(for: "device-A")
        let a2 = FleetRadar.stableAngle(for: "device-A")
        XCTAssertEqual(a1, a2)
        XCTAssertGreaterThanOrEqual(a1, 0)
        XCTAssertLessThan(a1, 360)
        XCTAssertNotEqual(FleetRadar.stableAngle(for: "device-A"),
                          FleetRadar.stableAngle(for: "device-B"))
    }

    func testBlipCartesianAtKnownAngles() {
        // angle 0 => straight up (x≈0, y≈range)
        let up = RadarBlip(id: "x", range: 1, angleDeg: 0, rssi: -50)
        XCTAssertEqual(up.x, 0, accuracy: 0.0001)
        XCTAssertEqual(up.y, 1, accuracy: 0.0001)
        // angle 90 => right (x≈range, y≈0)
        let right = RadarBlip(id: "x", range: 1, angleDeg: 90, rssi: -50)
        XCTAssertEqual(right.x, 1, accuracy: 0.0001)
        XCTAssertEqual(right.y, 0, accuracy: 0.0001)
    }

    func testBearingOverridesHashedAngle() {
        let c = BLEContactEntry(ts: 1, post: "p", addr: "A", rssi: -50)
        let blip = FleetRadar.blip(for: c, bearingDeg: 123)
        XCTAssertEqual(blip.angleDeg, 123, accuracy: 0.0001)
    }
}
