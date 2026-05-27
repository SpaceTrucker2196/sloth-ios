// Reconnector — exponential-backoff helper for the connect-loop.
//
// MISSION §2(4): retries are time-limited and cancellable. The
// `Reconnector` doubles its delay after each failed attempt, caps
// at 30 s, and stays "ready to wait" until the owning Task is
// cancelled (e.g. on `.background`).
//
// `sleeper` is injectable so tests drive deterministic timing
// without sitting on real wall-clock.

import Foundation

public actor Reconnector {

    public typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

    public let initialDelay: TimeInterval
    public let maxDelay:     TimeInterval
    public let multiplier:   Double

    private let sleeper: Sleeper
    private(set) public var currentDelay: TimeInterval

    public init(
        initialDelay: TimeInterval = 1,
        maxDelay:     TimeInterval = 30,
        multiplier:   Double       = 2,
        sleeper:      @escaping Sleeper = { delay in
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    ) {
        self.initialDelay = initialDelay
        self.maxDelay     = maxDelay
        self.multiplier   = multiplier
        self.sleeper      = sleeper
        self.currentDelay = initialDelay
    }

    /// Reset the backoff state after a successful connect.
    public func reset() {
        currentDelay = initialDelay
    }

    /// Wait the current delay, then double it (capped at `maxDelay`).
    /// Throws `CancellationError` if the owning Task is cancelled
    /// mid-sleep — callers should propagate, not retry.
    public func waitForNextAttempt() async throws {
        let delay = currentDelay
        try await sleeper(delay)
        currentDelay = min(currentDelay * multiplier, maxDelay)
    }

    /// Peek at the next delay (testing aid; never required by the
    /// production caller).
    public var peekDelay: TimeInterval { currentDelay }
}
