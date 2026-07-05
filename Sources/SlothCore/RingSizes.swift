// RingSizes — per-record-type cap on the `SlothStore` ring buffers.
//
// Sloth's TUI keeps fixed-size logs per category (`MAX_DNS_LOG`,
// `MAX_TLS_LOG`, …) so the on-screen log windows don't grow without
// bound. The iOS consumer mirrors those caps; once a ring is full,
// the oldest record is evicted on insert.
//
// Canonical source: `include/sloth.h` in the sloth repo —
// MAX_DNS_LOG / MAX_TLS_LOG / MAX_QUIC_LOG / MAX_HTTP_LOG /
// MAX_NTP_LOG / MAX_ICMP_LOG = 256, MAX_ALERTS = 128,
// MAX_PACKETS = 256, MAX_CONNS = 1024. Cross-checked 2026-07-05;
// re-check when sloth grows its windows. Drift here is a coupling
// smell, not a correctness break; rings just hold more or fewer
// records than the TUI shows.

import Foundation

public struct RingSizes: Sendable, Equatable {

    public let dns:    Int
    public let tls:    Int
    public let quic:   Int
    public let http:   Int
    public let ntp:    Int
    public let icmp:   Int
    public let alerts: Int
    /// Cap on the connections ring (M6). Unlike the log rings this
    /// has no TUI twin — sloth's `MAX_CONNS` (1024) caps *active*
    /// flows, while this ring holds flow *history*: cap × 1 record
    /// per active flow per emit-tick ≈ the window the
    /// `ConnectionsAggregator` can build an RTT sparkline from.
    public let connections: Int
    /// Per-interface rate-sample tail used by InterfacesView's
    /// rx/tx sparkline. Sloth emits one `iface` record per interface
    /// per ≈ 1 s tick, so 60 samples ≈ 60 s of history.
    public let ifaceSamples: Int
    /// Per-IP rate-sample tail used by TopHostsView / HomeView. Same
    /// cadence as iface (1 sample/sec); 120 samples ≈ 2 minutes —
    /// matches what the operator can fit at a glance on a phone.
    public let topHostSamples: Int
    /// Cap on the `packet` event ring. Mirrors sloth's
    /// `MAX_PACKETS`; the dashboard band and PacketsView only ever
    /// paint a short tail of it anyway.
    public let packets: Int

    public init(
        dns:    Int = 256,
        tls:    Int = 256,
        quic:   Int = 256,
        http:   Int = 256,
        ntp:    Int = 256,
        icmp:   Int = 256,
        alerts: Int = 128,
        connections:    Int = 2048,
        ifaceSamples:   Int = 60,
        topHostSamples: Int = 120,
        packets:        Int = 256
    ) {
        self.dns    = dns
        self.tls    = tls
        self.quic   = quic
        self.http   = http
        self.ntp    = ntp
        self.icmp   = icmp
        self.alerts = alerts
        self.connections    = connections
        self.ifaceSamples   = ifaceSamples
        self.topHostSamples = topHostSamples
        self.packets        = packets
    }

    /// The defaults sloth-ios ships with. Matches sloth's
    /// `include/sloth.h` caps as of 2026-07-05.
    public static let `default` = RingSizes()
}
