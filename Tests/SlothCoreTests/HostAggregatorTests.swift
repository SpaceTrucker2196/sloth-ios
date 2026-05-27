import XCTest
@testable import SlothCore

@MainActor
final class HostAggregatorTests: XCTestCase {

    /// Minute-aligned now so per-bin offsets are stable.
    private let now = Date(timeIntervalSince1970: 1_699_999_980)
    private var nowEpoch: Int { Int(now.timeIntervalSince1970) }

    // MARK: - isExternal

    func testRFC1918SkippedV4() {
        XCTAssertFalse(HostAggregator.isExternal("10.0.0.1"))
        XCTAssertFalse(HostAggregator.isExternal("172.16.0.1"))
        XCTAssertFalse(HostAggregator.isExternal("172.31.255.255"))
        XCTAssertFalse(HostAggregator.isExternal("192.168.1.1"))
    }

    func testLoopbackLinkLocalMulticastSkippedV4() {
        XCTAssertFalse(HostAggregator.isExternal("127.0.0.1"))
        XCTAssertFalse(HostAggregator.isExternal("169.254.0.1"))
        XCTAssertFalse(HostAggregator.isExternal("224.0.0.1"))
        XCTAssertFalse(HostAggregator.isExternal("239.255.255.255"))
    }

    func testExternalV4Accepted() {
        XCTAssertTrue(HostAggregator.isExternal("8.8.8.8"))
        XCTAssertTrue(HostAggregator.isExternal("1.1.1.1"))
        XCTAssertTrue(HostAggregator.isExternal("142.250.80.46"))
    }

    func testRFC1918EdgeBoundariesV4() {
        // 172.16/12 spans 172.16.0.0 through 172.31.255.255.
        // 172.15.x.x and 172.32.x.x are NOT private.
        XCTAssertTrue(HostAggregator.isExternal("172.15.0.1"))
        XCTAssertTrue(HostAggregator.isExternal("172.32.0.1"))
    }

    func testIPv6LoopbackLinkLocalMulticastSkipped() {
        XCTAssertFalse(HostAggregator.isExternal("::1"))
        XCTAssertFalse(HostAggregator.isExternal("fe80::1"))
        XCTAssertFalse(HostAggregator.isExternal("ff02::1"))
    }

    func testIPv6ExternalAccepted() {
        XCTAssertTrue(HostAggregator.isExternal("2606:4700::1111"))
        XCTAssertTrue(HostAggregator.isExternal("2001:db8::1"))
    }

    func testEmptyIPRejected() {
        XCTAssertFalse(HostAggregator.isExternal(""))
    }

    // MARK: - rateSamples

    func testRateSamplesEmpty() {
        let samples = HostAggregator.rateSamples(timestamps: [], now: nowEpoch)
        XCTAssertEqual(samples.count, HostAggregator.sparkBins)
        XCTAssertEqual(samples.reduce(0, +), 0)
    }

    func testRateSamplesBucketsByMinute() {
        // 3 events in the most-recent minute bin, 1 in the bin 2 ago.
        let recent = [nowEpoch - 5, nowEpoch - 20, nowEpoch - 50]
        let twoAgo = [nowEpoch - 130]
        let samples = HostAggregator.rateSamples(
            timestamps: recent + twoAgo,
            now: nowEpoch
        )
        let last = samples.last!
        let secondToLast = samples[samples.count - 2]
        let thirdToLast  = samples[samples.count - 3]
        XCTAssertEqual(last, 3)
        XCTAssertEqual(secondToLast, 0)
        XCTAssertEqual(thirdToLast, 1)
    }

    func testRateSamplesDropsOutOfWindow() {
        let tooOld = nowEpoch - (HostAggregator.sparkBins * HostAggregator.sparkBinSeconds + 60)
        let samples = HostAggregator.rateSamples(timestamps: [tooOld], now: nowEpoch)
        XCTAssertEqual(samples.reduce(0, +), 0)
    }

    // MARK: - snapshot

    func testSnapshotSkipsInternalDestinations() {
        let store = SlothStore()
        store.ingest(.tls(.init(ts: nowEpoch - 5, src: "10.0.0.5", dst: "10.0.0.1",
                                sni: "internal", version: "TLS 1.3", ja3: "ja3a")))
        store.ingest(.tls(.init(ts: nowEpoch - 5, src: "10.0.0.5", dst: "8.8.8.8",
                                sni: "dns.google", version: "TLS 1.3", ja3: "ja3b")))
        let snap = HostAggregator.snapshot(from: store, now: now)
        XCTAssertEqual(snap.hosts.count, 1)
        XCTAssertEqual(snap.hosts[0].ip, "8.8.8.8")
    }

    func testSnapshotMergesProtocolsPerIP() {
        let store = SlothStore()
        store.ingest(.tls (.init(ts: nowEpoch - 5,  src: "10.0.0.5", dst: "8.8.8.8",
                                 sni: "dns.google", version: "TLS 1.3", ja3: "ja3a")))
        store.ingest(.quic(.init(ts: nowEpoch - 10, src: "10.0.0.5", dst: "8.8.8.8",
                                 sni: "dns.google", version: "v1")))
        store.ingest(.http(.init(ts: nowEpoch - 15, src: "10.0.0.5", dst: "8.8.8.8",
                                 host: "dns.google", method: "GET", path: "/")))
        store.ingest(.dns (.init(ts: nowEpoch - 20, src: "10.0.0.5", qname: "dns.google",
                                 qtype: "A", answer: "8.8.8.8")))
        let snap = HostAggregator.snapshot(from: store, now: now)
        XCTAssertEqual(snap.hosts.count, 1)
        let h = snap.hosts[0]
        XCTAssertEqual(h.totalRecords, 4)
        XCTAssertEqual(h.dnsCount, 1)
        XCTAssertEqual(h.tlsCount, 1)
        XCTAssertEqual(h.quicCount, 1)
        XCTAssertEqual(h.httpCount, 1)
        XCTAssertEqual(h.hostname, "dns.google")
        XCTAssertEqual(h.ja3Fingerprints, ["ja3a"])
    }

    func testSnapshotSortsByTotalRecordsDescending() {
        let store = SlothStore()
        // 8.8.8.8 gets 3 records, 1.1.1.1 gets 1.
        for _ in 0..<3 {
            store.ingest(.tls(.init(ts: nowEpoch - 5, src: "10.0.0.5", dst: "8.8.8.8",
                                    sni: "dns.google", version: "TLS 1.3", ja3: "x")))
        }
        store.ingest(.tls(.init(ts: nowEpoch - 5, src: "10.0.0.5", dst: "1.1.1.1",
                                sni: "one.one.one.one", version: "TLS 1.3", ja3: "y")))
        let snap = HostAggregator.snapshot(from: store, now: now)
        XCTAssertEqual(snap.hosts.map(\.ip), ["8.8.8.8", "1.1.1.1"])
    }

    func testSnapshotCapsAtTopN() {
        let store = SlothStore()
        // Inject 50 distinct external IPs; expect only `topN` come back.
        for i in 1...50 {
            // 8.8.x.y stays inside the public-routable space and avoids
            // the multicast / loopback / RFC1918 ranges.
            let ip = "8.8.\(i % 256).\((i * 7) % 256)"
            store.ingest(.tls(.init(ts: nowEpoch - 5, src: "10.0.0.5", dst: ip,
                                    sni: "h\(i)", version: "TLS 1.3", ja3: "j\(i)")))
        }
        let snap = HostAggregator.snapshot(from: store, now: now)
        XCTAssertEqual(snap.hosts.count, HostAggregator.topN)
    }
}
