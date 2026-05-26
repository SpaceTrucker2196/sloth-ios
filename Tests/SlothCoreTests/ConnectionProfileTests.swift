import XCTest
@testable import SlothCore

final class ConnectionProfileTests: XCTestCase {

    func testParseHostPort() {
        let p = ConnectionProfile(uri: "tcp:sloth.example:7777")
        XCTAssertEqual(p?.host, "sloth.example")
        XCTAssertEqual(p?.port, 7777)
    }

    func testParseIPv4() {
        let p = ConnectionProfile(uri: "tcp:10.0.0.1:50051")
        XCTAssertEqual(p?.host, "10.0.0.1")
        XCTAssertEqual(p?.port, 50051)
    }

    func testParseIPv6Bracketed() {
        let p = ConnectionProfile(uri: "tcp:[fd00::1]:9000")
        XCTAssertEqual(p?.host, "fd00::1")
        XCTAssertEqual(p?.port, 9000)
    }

    func testRejectsMissingScheme() {
        XCTAssertNil(ConnectionProfile(uri: "sloth.example:7777"))
    }

    func testRejectsWrongScheme() {
        XCTAssertNil(ConnectionProfile(uri: "udp:sloth.example:7777"))
    }

    func testRejectsBadPort() {
        XCTAssertNil(ConnectionProfile(uri: "tcp:host:99999"))
        XCTAssertNil(ConnectionProfile(uri: "tcp:host:0"))
        XCTAssertNil(ConnectionProfile(uri: "tcp:host:abc"))
    }

    func testRejectsEmptyHost() {
        XCTAssertNil(ConnectionProfile(uri: "tcp::1234"))
    }

    func testUriRoundTrip() {
        let p4 = ConnectionProfile(host: "1.2.3.4", port: 7777)
        XCTAssertEqual(p4.uri, "tcp:1.2.3.4:7777")
        XCTAssertEqual(ConnectionProfile(uri: p4.uri), p4)

        let p6 = ConnectionProfile(host: "fd00::1", port: 9)
        XCTAssertEqual(p6.uri, "tcp:[fd00::1]:9")
        XCTAssertEqual(ConnectionProfile(uri: p6.uri), p6)
    }

    func testUserDefaultsPersistence() throws {
        let suite = UserDefaults(suiteName: "SlothCoreTests.ConnectionProfile")!
        suite.removePersistentDomain(forName: "SlothCoreTests.ConnectionProfile")
        defer { suite.removePersistentDomain(forName: "SlothCoreTests.ConnectionProfile") }

        XCTAssertNil(ConnectionProfile.load(from: suite))

        let p = ConnectionProfile(host: "sloth.tailnet", port: 7777)
        p.save(to: suite)

        XCTAssertEqual(ConnectionProfile.load(from: suite), p)

        ConnectionProfile.clear(in: suite)
        XCTAssertNil(ConnectionProfile.load(from: suite))
    }
}
