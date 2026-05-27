import XCTest
@testable import SlothCore

@MainActor
final class ProfileStoreTests: XCTestCase {

    private func freshDefaults(_ suiteName: String = #function) -> UserDefaults {
        let d = UserDefaults(suiteName: "ProfileStoreTests.\(suiteName)")!
        d.removePersistentDomain(forName: "ProfileStoreTests.\(suiteName)")
        return d
    }

    func testFreshDefaultsYieldsEmptyStore() {
        let store = ProfileStore(defaults: freshDefaults())
        XCTAssertTrue(store.profiles.isEmpty)
        XCTAssertNil(store.activeID)
        XCTAssertNil(store.activeProfile)
    }

    func testAddPopulatesAndActivates() {
        let store = ProfileStore(defaults: freshDefaults())
        let p = store.add(name: "home", profile: ConnectionProfile(host: "h", port: 7777))
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.activeID, p.id)
        XCTAssertEqual(store.activeProfile?.name, "home")
    }

    func testRemoveActiveFallsBackToFirst() {
        let store = ProfileStore(defaults: freshDefaults())
        let a = store.add(name: "a", profile: ConnectionProfile(host: "a", port: 1))
        let b = store.add(name: "b", profile: ConnectionProfile(host: "b", port: 2))
        XCTAssertEqual(store.activeID, a.id)
        store.remove(a.id)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.activeID, b.id)
    }

    func testRemoveNonActiveLeavesActive() {
        let store = ProfileStore(defaults: freshDefaults())
        let a = store.add(name: "a", profile: ConnectionProfile(host: "a", port: 1))
        let b = store.add(name: "b", profile: ConnectionProfile(host: "b", port: 2))
        store.setActive(b.id)
        store.remove(a.id)
        XCTAssertEqual(store.activeID, b.id)
    }

    func testSetActiveIgnoresUnknownID() {
        let store = ProfileStore(defaults: freshDefaults())
        let a = store.add(name: "a", profile: ConnectionProfile(host: "a", port: 1))
        store.setActive(UUID())
        XCTAssertEqual(store.activeID, a.id)
    }

    func testUpdateChangesNameButPreservesID() {
        let store = ProfileStore(defaults: freshDefaults())
        let a = store.add(name: "a", profile: ConnectionProfile(host: "a", port: 1))
        let renamed = NamedProfile(id: a.id, name: "alpha", profile: a.profile)
        store.update(renamed)
        XCTAssertEqual(store.profiles.first?.name, "alpha")
        XCTAssertEqual(store.profiles.first?.id, a.id)
    }

    func testPersistenceRoundTrip() {
        let defaults = freshDefaults()
        let a: NamedProfile
        do {
            let store = ProfileStore(defaults: defaults)
            a = store.add(name: "home", profile: ConnectionProfile(host: "h", port: 7777))
            store.add(name: "work", profile: ConnectionProfile(host: "w", port: 8888))
            store.setActive(a.id)
        }
        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.profiles.count, 2)
        XCTAssertEqual(reloaded.activeID, a.id)
    }

    func testLegacySingleProfileIsUpgraded() {
        let defaults = freshDefaults()
        // Pre-existing M1 single-profile blob.
        let legacy = ConnectionProfile(host: "legacy", port: 7777)
        legacy.save(to: defaults)

        let store = ProfileStore(defaults: defaults)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.profile, legacy)
        XCTAssertEqual(store.activeID, store.profiles.first?.id)
    }
}
