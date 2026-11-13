import XCTest
@testable import SlothCore

final class SensorRecordTests: XCTestCase {

    private func roundTrip(_ rec: SensorRecord) throws -> SensorRecord {
        let data = try SensorRecord.lineEncoder.encode(rec)
        return try JSONDecoder().decode(SensorRecord.self, from: data)
    }

    func testEveryRecordTypeRoundTrips() throws {
        let samples: [SensorRecord] = [
            .iosPost(IOSPostEntry(ts: 1, post: "p1", name: "Jeff iPhone",
                                  appVer: "1.1", battery: 0.82, charging: true, uptimeS: 90)),
            .bleContact(BLEContactEntry(ts: 2, post: "p1", addr: "ABC",
                                        name: "AirPods", rssi: -61,
                                        txPower: 4, services: ["fd6f"], count: 7)),
            .imuSample(IMUSampleEntry(ts: 3, post: "p1", headingDeg: 182.4,
                                      fieldMagUT: 48.2, fieldX: 1, fieldY: 2, fieldZ: 3)),
            .geoFix(GeoFixEntry(ts: 4, post: "p1", lat: 37.77, lon: -122.41, hAccM: 12)),
            .wifiSelf(WiFiSelfEntry(ts: 5, post: "p1", ssid: "home", bssid: "aa:bb")),
            .radioScan(RadioScanEntry(ts: 6, post: "p1", available: false,
                                      reason: "sandboxed", aps: [])),
        ]
        for s in samples {
            let back = try roundTrip(s)
            XCTAssertEqual(back, s, "round trip failed for \(s.typeTag)")
        }
    }

    func testEnvelopeTagsMatchSlothSchema() {
        XCTAssertEqual(SensorRecord.iosPost(.init(ts: 0, post: "p", name: "n", appVer: "1")).typeTag, "ios_post")
        XCTAssertEqual(SensorRecord.bleContact(.init(ts: 0, post: "p", addr: "a", rssi: -50)).typeTag, "ble_contact")
        XCTAssertEqual(SensorRecord.imuSample(.init(ts: 0, post: "p")).typeTag, "imu_sample")
        XCTAssertEqual(SensorRecord.geoFix(.init(ts: 0, post: "p", lat: 0, lon: 0)).typeTag, "geo_fix")
        XCTAssertEqual(SensorRecord.wifiSelf(.init(ts: 0, post: "p")).typeTag, "wifi_self")
        XCTAssertEqual(SensorRecord.radioScan(.init(ts: 0, post: "p", available: false)).typeTag, "radio_scan")
    }

    func testJSONLLineIsNewlineTerminatedAndSnakeCase() throws {
        let rec = SensorRecord.iosPost(IOSPostEntry(
            ts: 10, post: "p1", name: "n", appVer: "1.1", uptimeS: 5))
        let line = try XCTUnwrap(rec.jsonlLine())
        XCTAssertEqual(line.last, 0x0A)
        let text = String(decoding: line, as: UTF8.self)
        XCTAssertTrue(text.contains(#""type":"ios_post""#))
        XCTAssertTrue(text.contains(#""app_ver":"1.1""#))
        XCTAssertTrue(text.contains(#""uptime_s":5"#))
    }

    func testUnknownTypeDecodeThrows() {
        let bad = Data(#"{"type":"not_a_sensor","ts":1,"post":"p"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SensorRecord.self, from: bad))
    }
}
