import XCTest
@testable import SlothCore

final class PostIdentityTests: XCTestCase {

    private func suite(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testLoadOrCreateMintsThenPersists() {
        let d = suite("post.identity.mint")
        let first = PostIdentity.loadOrCreate(defaultName: "x", in: d)
        XCTAssertFalse(first.id.isEmpty)
        let second = PostIdentity.loadOrCreate(defaultName: "y", in: d)
        XCTAssertEqual(first.id, second.id, "second load reuses the persisted id")
        XCTAssertEqual(second.name, "x", "persisted name wins over default")
    }

    func testRotateChangesIdKeepsName() {
        let d = suite("post.identity.rotate")
        let a = PostIdentity.loadOrCreate(defaultName: "Jeff iPhone", in: d)
        let b = PostIdentity.rotate(keepingNameFrom: a, in: d)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(b.name, "Jeff iPhone")
        let reload = PostIdentity.loadOrCreate(in: d)
        XCTAssertEqual(reload.id, b.id)
    }

    func testRoundTripViaPostClient() async throws {
        let line = SensorRecord.iosPost(IOSPostEntry(
            ts: 1, post: "p1", name: "n", appVer: "1")).jsonlLine()!
        let transport = ScriptedTransport(chunks: [line])
        let client = PostClient(transport: transport)
        var got: [SensorRecord] = []
        for try await r in client.records(for: ConnectionProfile(host: "f", port: 1)) {
            got.append(r)
        }
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got.first?.typeTag, "ios_post")
    }
}
