import XCTest
import Network
@testable import SlothCore

// #15: an optional second endpoint for sloth-rf, kept apart from the
// Wi-Fi stream's connection state, and a refused connect that names
// the sensor-side flag.

@MainActor
final class RFStreamTests: XCTestCase {

    func testRFStreamFeedsSharedRingsButOwnState() async {
        let store = SlothStore()
        let rfHealth = SensorHealthEntry(ts: 1, daemon: "rf", jsonlVersion: "2.3.0")
        let stream = AsyncThrowingStream<SlothRecord, any Error> { c in
            c.yield(.sensorHealth(rfHealth))
            c.yield(.unknown(type: "gnss_fix", ts: 2))
            c.finish()
        }
        await store.ingest(rfStream: stream)

        XCTAssertEqual(store.sensorHealth["rf"], rfHealth)
        XCTAssertEqual(store.rfRecordsReceived, 2)
        XCTAssertEqual(store.recordsReceived, 0)
        XCTAssertEqual(store.connectionState, .idle)          // Wi-Fi untouched
        XCTAssertEqual(store.rfConnectionState, .disconnected(reason: nil))
    }

    func testRFFailureDoesNotTouchWifiError() async {
        struct Boom: Error {}
        let store = SlothStore()
        store.ingest(.dns(DNSEntry(ts: 1, qname: "a")))
        let stream = AsyncThrowingStream<SlothRecord, any Error> { $0.finish(throwing: Boom()) }
        await store.ingest(rfStream: stream)

        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertNil(store.lastError)
        XCTAssertNotNil(store.rfLastError)
        store.markRFIdle()
        XCTAssertEqual(store.rfConnectionState, .idle)
        XCTAssertNil(store.rfLastError)
    }

    func testResetClearsRFState() {
        let store = SlothStore()
        store.ingestRF(.unknown(type: "adsb_aircraft", ts: 1))
        store.reset()
        XCTAssertEqual(store.rfRecordsReceived, 0)
        XCTAssertEqual(store.rfConnectionState, .idle)
    }

    // MARK: - Profiles

    func testProfileSavedBeforeRFFieldStillLoads() throws {
        let old = #"{"id":"6F1C2D3E-0000-4000-8000-000000000001","name":"home","profile":{"host":"10.0.0.2","port":8765}}"#
        let p = try JSONDecoder().decode(NamedProfile.self, from: Data(old.utf8))
        XCTAssertNil(p.rf)
        XCTAssertEqual(p.profile.port, 8765)
    }

    func testProfileStoreKeepsRFEndpoint() throws {
        let suite = "rf-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ProfileStore(defaults: defaults)
        let rf = ConnectionProfile(host: "sensor.tailnet", port: 8766)
        store.add(name: "s", profile: ConnectionProfile(host: "sensor.tailnet", port: 8765), rf: rf)

        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.activeProfile?.rf, rf)
    }

    // MARK: - Connection hint

    func testRefusedIsShort() {
        let msg = ConnectionHint.describe(NWError.posix(.ECONNREFUSED))
        XCTAssertEqual(msg, "refused — nothing listens on that port")
    }

    func testOtherErrorsPassThrough() {
        let err = NWError.posix(.ETIMEDOUT)
        XCTAssertEqual(ConnectionHint.describe(err), err.localizedDescription)
    }
}
