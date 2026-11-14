import XCTest
@testable import SlothCore

@MainActor
final class PostPeerStoreTests: XCTestCase {

    private func suite(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testAddParsesAndPersists() {
        let d = suite("post.peers.add")
        let store = PostPeerStore(defaults: d)
        XCTAssertTrue(store.add(uri: "tcp:100.64.0.5:8770"))
        XCTAssertEqual(store.peers.count, 1)
        XCTAssertEqual(store.peers.first?.host, "100.64.0.5")
        XCTAssertEqual(store.peers.first?.port, 8770)
        // Reload from the same suite → persisted.
        let reload = PostPeerStore(defaults: d)
        XCTAssertEqual(reload.peers.count, 1)
    }

    func testRejectsBadAddressAndDuplicates() {
        let d = suite("post.peers.bad")
        let store = PostPeerStore(defaults: d)
        XCTAssertFalse(store.add(uri: "not-an-address"))
        XCTAssertFalse(store.add(uri: "http://x"))
        XCTAssertTrue(store.add(uri: "tcp:host:1"))
        XCTAssertFalse(store.add(uri: "tcp:host:1"), "exact duplicate rejected")
        XCTAssertEqual(store.peers.count, 1)
    }

    func testRemove() {
        let d = suite("post.peers.remove")
        let store = PostPeerStore(defaults: d)
        store.add(uri: "tcp:a:1")
        store.add(uri: "tcp:b:2")
        store.remove(ConnectionProfile(host: "a", port: 1))
        XCTAssertEqual(store.peers.map(\.host), ["b"])
    }
}
