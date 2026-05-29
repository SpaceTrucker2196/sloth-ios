import XCTest
@testable import SlothCore

@MainActor
final class SlothDiscoveryTests: XCTestCase {

    // MARK: - DiscoveredService → ConnectionProfile

    func testProfileTrimsTrailingDotFromHostname() {
        let svc = DiscoveredService(
            id: "x",
            name: "Living Room sloth",
            hostname: "slothmac.local.",
            port: 7777
        )
        XCTAssertEqual(svc.profile.host, "slothmac.local")
        XCTAssertEqual(svc.profile.port, 7777)
        XCTAssertEqual(svc.profile.uri, "tcp:slothmac.local:7777")
    }

    func testProfilePassesThroughDotlessHostname() {
        let svc = DiscoveredService(
            id: "x",
            name: "n",
            hostname: "10.0.0.4",
            port: 8765
        )
        XCTAssertEqual(svc.profile.uri, "tcp:10.0.0.4:8765")
    }

    func testDiscoveredServiceEquality() {
        let a = DiscoveredService(id: "k", name: "n", hostname: "h", port: 1)
        let b = DiscoveredService(id: "k", name: "n", hostname: "h", port: 1)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testTXTPreserved() {
        let svc = DiscoveredService(
            id: "x", name: "n", hostname: "h", port: 1,
            txt: ["version": "1.3.0", "schema": "1"]
        )
        XCTAssertEqual(svc.txt["version"], "1.3.0")
        XCTAssertEqual(svc.txt["schema"], "1")
    }

    // MARK: - SlothDiscovery lifecycle

    func testInitialStateIsIdleWithNoServices() {
        let d = SlothDiscovery()
        XCTAssertEqual(d.state, .idle)
        XCTAssertTrue(d.services.isEmpty)
    }

    func testStopFromIdleStaysIdle() {
        let d = SlothDiscovery()
        d.stop()
        XCTAssertEqual(d.state, .idle)
    }

    // Note: `start()` against a real NetServiceBrowser isn't covered
    // by unit tests — the simulator's run-loop driven Bonjour browse
    // is integration territory. The pure model (DiscoveredService +
    // profile derivation) is what the view layer leans on, and that
    // *is* covered above.
}
