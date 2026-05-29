import XCTest
@testable import SlothCore

final class ConnectionEntryTests: XCTestCase {

    func testDecodeTCPRecord() throws {
        let json = #"""
        {"type":"connections","ts":1716700000,"src":"10.0.0.5:54321","dst":"1.1.1.1:443","proto":"tcp","state":"ESTABLISHED","rtt_ms":12.4,"retx":0,"rx_bytes":12345,"tx_bytes":6789,"age_s":47}
        """#
        let r = try decode(json)
        guard case .connections(let e) = r else { return XCTFail("wrong case: \(r)") }
        XCTAssertEqual(e.proto,   .tcp)
        XCTAssertEqual(e.state,   "ESTABLISHED")
        XCTAssertEqual(e.rttMS,   12.4)
        XCTAssertEqual(e.retx,    0)
        XCTAssertEqual(e.rxBytes, 12345)
        XCTAssertEqual(e.txBytes, 6789)
        XCTAssertEqual(e.ageS,    47)
        XCTAssertEqual(e.flowKey, "10.0.0.5:54321→1.1.1.1:443/tcp")
        XCTAssertEqual(r.typeTag, "connections")
    }

    func testDecodeUDPRecordWithoutTCPFields() throws {
        // Per the sloth spec UDP records omit state / rtt_ms / retx.
        // Missing rx_bytes/tx_bytes default to 0.
        let json = #"""
        {"type":"connections","ts":1716700001,"src":"10.0.0.5:5353","dst":"224.0.0.251:5353","proto":"udp"}
        """#
        guard case .connections(let e) = try decode(json) else { return XCTFail() }
        XCTAssertEqual(e.proto, .udp)
        XCTAssertNil(e.state)
        XCTAssertNil(e.rttMS)
        XCTAssertNil(e.retx)
        XCTAssertEqual(e.rxBytes, 0)
        XCTAssertEqual(e.txBytes, 0)
        XCTAssertNil(e.ageS)
    }

    func testRoundTripOmitsOptionalNils() throws {
        let original: SlothRecord = .connections(.init(
            ts: 1, src: "a:1", dst: "b:2", proto: .udp,
            rxBytes: 0, txBytes: 0
        ))
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(SlothRecord.self, from: data)
        XCTAssertEqual(back, original)

        // Confirm the on-wire shape: no `state`/`rtt_ms`/`retx`/`age_s`.
        let dict = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(dict["state"])
        XCTAssertNil(dict["rtt_ms"])
        XCTAssertNil(dict["retx"])
        XCTAssertNil(dict["age_s"])
        XCTAssertEqual(dict["proto"] as? String, "udp")
        XCTAssertEqual(dict["rx_bytes"] as? Int, 0)
        XCTAssertEqual(dict["tx_bytes"] as? Int, 0)
    }

    func testRoundTripTCPPreservesAllFields() throws {
        let original: SlothRecord = .connections(.init(
            ts: 9, src: "10.0.0.5:54321", dst: "1.1.1.1:443",
            proto: .tcp, state: "ESTABLISHED", rttMS: 12.4, retx: 2,
            rxBytes: 1000, txBytes: 500, ageS: 30
        ))
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(SlothRecord.self, from: data)
        XCTAssertEqual(back, original)
    }

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }
}
