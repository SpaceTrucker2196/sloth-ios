import XCTest
@testable import SlothCore

// #14: gnss_sky, gnss_sat, aprs_packet.

@MainActor
final class RFSkyRecordTests: XCTestCase {

    private func decode(_ line: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(line.utf8))
    }

    func testSkyAndSatDecode() throws {
        let sky = #"{"type":"gnss_sky","ts":100,"src":"gpsd:127.0.0.1:2947","sky_ts":99,"nsat":22,"usat":11,"rows":22,"overflow":0,"hdop":0.8,"vdop":1.1,"pdop":1.4,"gdop":1.7,"tdop":0.9,"cn0_mean":33.4,"cn0_max":44.0,"cn0_sd":5.1,"cn0_n":18,"passes":40}"#
        guard case .gnssSky(let s) = try decode(sky) else { return XCTFail() }
        XCTAssertEqual(s.usat, 11)
        XCTAssertEqual(s.cn0Mean, 33.4)

        // Listed but not tracked: no cn0. No el/az from gpsd: absent.
        let sat = #"{"type":"gnss_sat","ts":100,"gnss":"Galileo","gnssid":2,"svid":11,"prn":311,"sigid":0,"used":0,"health":1,"sky_ts":99}"#
        guard case .gnssSat(let g) = try decode(sat) else { return XCTFail() }
        XCTAssertNil(g.cn0)
        XCTAssertNil(g.el)
        XCTAssertEqual(g.label, "Galileo 11")
        XCTAssertEqual(g.id, "2/311")
        XCTAssertFalse(g.isUsed)

        let bare = GNSSSatEntry(ts: 1, gnss: "", prn: 7)
        XCTAssertEqual(bare.label, "PRN 7")
    }

    func testAPRSPacketDecodesLevelEitherWay() throws {
        let p1 = #"{"type":"aprs_packet","ts":200,"src":"file:/run/dw.log","seq":17,"chan":0,"utime":199,"source":"KD0ABC-9","heard":"W0DIGI","direct":0,"level":"48(12/9)","dti":"!","name":"KD0ABC-9","symbol":"/>","lat":44.97,"lon":-93.26,"speed_kt":31,"course":270,"comment":"mobile"}"#
        guard case .aprsPacket(let a) = try decode(p1) else { return XCTFail() }
        XCTAssertEqual(a.level, "48(12/9)")
        XCTAssertEqual(a.title, "KD0ABC-9")
        XCTAssertEqual(a.direct, 0)

        let p2 = #"{"type":"aprs_packet","ts":201,"src":"file:/x","seq":18,"chan":0,"utime":200,"source":"W0XYZ","level":52,"name":"FLDAY"}"#
        guard case .aprsPacket(let b) = try decode(p2) else { return XCTFail() }
        XCTAssertEqual(b.level, "52")
        XCTAssertEqual(b.title, "W0XYZ › FLDAY")
    }

    func testSetSatelliteDropsAfterQuietWindow() {
        let store = SlothStore()
        store.ingestRF(.gnssSat(GNSSSatEntry(ts: 1000, gnssid: 0, prn: 5, used: 1)))
        store.ingestRF(.gnssSat(GNSSSatEntry(ts: 1300, gnssid: 0, prn: 9)))
        XCTAssertEqual(store.gnssSats.count, 2)              // 300 s: still in view
        store.ingestRF(.gnssSky(GNSSSkyEntry(ts: 1000 + SlothStore.satQuietDrop + 1)))
        XCTAssertEqual(Array(store.gnssSats.keys), ["0/9"])   // prn 5 set
    }

    func testSatellitesUsedThenStrongest() {
        let rows = [
            GNSSSatEntry(ts: 1, gnssid: 0, prn: 1, cn0: 45, used: 0),
            GNSSSatEntry(ts: 1, gnssid: 0, prn: 2, cn0: 30, used: 1),
            GNSSSatEntry(ts: 1, gnssid: 0, prn: 3, used: 0),
            GNSSSatEntry(ts: 1, gnssid: 0, prn: 4, cn0: 40, used: 1),
        ]
        XCTAssertEqual(RFRoster.satellites(rows).map(\.prn), [4, 2, 1, 3])
    }

    func testAPRSPacketTailIsCapped() {
        let store = SlothStore()
        for i in 1...(SlothStore.aprsPacketCap + 5) {
            store.ingestRF(.aprsPacket(APRSPacketEntry(ts: i, seq: i, source: "N0CALL")))
        }
        XCTAssertEqual(store.aprsPackets.count, SlothStore.aprsPacketCap)
        XCTAssertEqual(store.aprsPackets.first?.seq, 6)
        store.reset()
        XCTAssertTrue(store.aprsPackets.isEmpty)
        XCTAssertTrue(store.gnssSats.isEmpty)
    }
}
