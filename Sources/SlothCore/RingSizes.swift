// RingSizes — per-record-type cap on the `SlothStore` ring buffers.
//
// Sloth's TUI keeps fixed-size logs per category (`MAX_DNS_LOG`,
// `MAX_TLS_LOG`, …) so the on-screen log windows don't grow without
// bound. The iOS consumer mirrors those caps; once a ring is full,
// the oldest record is evicted on insert. Numbers below are
// best-effort defaults — when sloth's `app.h` (or wherever the
// canonical caps live) is checked, these should match. Drift here
// is a coupling smell, not a correctness break; rings just hold
// more or fewer records than the TUI shows.

import Foundation

public struct RingSizes: Sendable, Equatable {

    public let dns:    Int
    public let tls:    Int
    public let quic:   Int
    public let http:   Int
    public let ntp:    Int
    public let icmp:   Int
    public let alerts: Int
    /// Cap on the connections ring (M6). Cap × 1 record per active
    /// flow per emit-tick ≈ the visible flow-history window the
    /// `ConnectionsAggregator` can build a sparkline from.
    public let connections: Int

    public init(
        dns:    Int = 1024,
        tls:    Int = 1024,
        quic:   Int = 512,
        http:   Int = 1024,
        ntp:    Int = 128,
        icmp:   Int = 256,
        alerts: Int = 128,
        connections: Int = 2048
    ) {
        self.dns    = dns
        self.tls    = tls
        self.quic   = quic
        self.http   = http
        self.ntp    = ntp
        self.icmp   = icmp
        self.alerts = alerts
        self.connections = connections
    }

    /// The defaults sloth-ios ships with. Mirrors sloth's TUI caps
    /// at the time of M2; revisit if sloth grows its windows.
    public static let `default` = RingSizes()
}
