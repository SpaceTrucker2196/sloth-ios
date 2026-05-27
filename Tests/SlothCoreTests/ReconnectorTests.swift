import XCTest
@testable import SlothCore

final class ReconnectorTests: XCTestCase {

    /// Records the delays the reconnector requested so the test can
    /// assert on the backoff progression without sitting on the wall
    /// clock.
    private final class DelayRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [TimeInterval] = []
        func record(_ d: TimeInterval) {
            lock.lock(); values.append(d); lock.unlock()
        }
        func snapshot() -> [TimeInterval] {
            lock.lock(); defer { lock.unlock() }
            return values
        }
    }

    private func makeReconnector(
        recorder: DelayRecorder,
        initial: TimeInterval = 1,
        max: TimeInterval = 30,
        multiplier: Double = 2
    ) -> Reconnector {
        Reconnector(
            initialDelay: initial,
            maxDelay:     max,
            multiplier:   multiplier
        ) { d in
            recorder.record(d)
            // no real sleep
        }
    }

    func testBackoffDoublesUntilCap() async throws {
        let rec = DelayRecorder()
        let r   = makeReconnector(recorder: rec)
        for _ in 0..<6 {
            try await r.waitForNextAttempt()
        }
        let delays = rec.snapshot()
        XCTAssertEqual(delays, [1, 2, 4, 8, 16, 30])
    }

    func testResetReturnsToInitial() async throws {
        let rec = DelayRecorder()
        let r   = makeReconnector(recorder: rec)
        try await r.waitForNextAttempt()
        try await r.waitForNextAttempt()
        await r.reset()
        try await r.waitForNextAttempt()
        XCTAssertEqual(rec.snapshot(), [1, 2, 1])
    }

    func testCustomInitialAndMultiplier() async throws {
        let rec = DelayRecorder()
        let r   = makeReconnector(recorder: rec, initial: 0.5, max: 10, multiplier: 3)
        for _ in 0..<5 {
            try await r.waitForNextAttempt()
        }
        XCTAssertEqual(rec.snapshot(), [0.5, 1.5, 4.5, 10, 10])
    }

    func testSleeperCancellationPropagates() async {
        struct Boom: Error {}
        let r = Reconnector(initialDelay: 1) { _ in
            throw Boom()
        }
        do {
            try await r.waitForNextAttempt()
            XCTFail("expected throw")
        } catch is Boom {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
