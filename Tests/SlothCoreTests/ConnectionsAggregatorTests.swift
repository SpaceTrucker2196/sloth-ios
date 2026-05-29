import XCTest
@testable import SlothCore

final class ConnectionsAggregatorTests: XCTestCase {

    // MARK: - Helpers

    private func tcp(
        _ tag: Int,
        src: String, dst: String,
        state: String = "ESTABLISHED",
        rtt: Double? = nil,
        rx: Int = 0, tx: Int = 0,
        age: Int? = nil
    ) -> ConnectionEntry {
        .init(ts: tag, src: src, dst: dst, proto: .tcp,
              state: state, rttMS: rtt, retx: 0,
              rxBytes: rx, txBytes: tx, ageS: age)
    }

    private func udp(
        _ tag: Int,
        src: String, dst: String,
        rx: Int = 0, tx: Int = 0
    ) -> ConnectionEntry {
        .init(ts: tag, src: src, dst: dst, proto: .udp,
              rxBytes: rx, txBytes: tx)
    }

    // MARK: - Dedup + latest-wins

    func testEmptyInputYieldsEmptySnapshot() {
        XCTAssertTrue(ConnectionsAggregator.snapshot(from: []).isEmpty)
    }

    func testFlowDedupKeepsLatestRecord() {
        let entries = [
            tcp(1, src: "10.0.0.5:5", dst: "1.1.1.1:443", rtt: 20, rx: 100, tx: 50),
            tcp(2, src: "10.0.0.5:5", dst: "1.1.1.1:443", rtt: 18, rx: 200, tx: 90),
            tcp(3, src: "10.0.0.5:5", dst: "1.1.1.1:443", rtt: 14, rx: 400, tx: 200),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries)
        XCTAssertEqual(snap.count, 1)
        let flow = try! XCTUnwrap(snap.first)
        XCTAssertEqual(flow.latest.ts, 3)
        XCTAssertEqual(flow.latest.rxBytes, 400)
        XCTAssertEqual(flow.recordCount, 3)
        XCTAssertEqual(flow.rttSeries, [20, 18, 14])
    }

    func testDifferentFlowsKeptSeparate() {
        let entries = [
            tcp(1, src: "10.0.0.5:5", dst: "1.1.1.1:443"),
            tcp(2, src: "10.0.0.5:6", dst: "1.1.1.1:443"),
            udp(3, src: "10.0.0.5:5", dst: "1.1.1.1:443"),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries)
        XCTAssertEqual(snap.count, 3)
        XCTAssertEqual(Set(snap.map(\.key)).count, 3)
    }

    // MARK: - Sparkline

    func testSparklineRespectsCapacity() {
        let cap = 3
        let entries = (1...5).map { i in
            tcp(i, src: "10.0.0.5:5", dst: "1.1.1.1:443",
                rtt: Double(i) * 10)
        }
        let snap = ConnectionsAggregator.snapshot(from: entries, sparklineCapacity: cap)
        let series = snap.first?.rttSeries ?? []
        XCTAssertEqual(series, [30, 40, 50])
    }

    func testSparklineSkipsNilRTT() {
        let entries: [ConnectionEntry] = [
            tcp(1, src: "a:1", dst: "b:1", rtt: 10),
            udp(2, src: "a:1", dst: "b:1"),               // different flow
            tcp(3, src: "a:1", dst: "b:1", rtt: nil),     // same flow, no sample
            tcp(4, src: "a:1", dst: "b:1", rtt: 12),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries)
        let tcpFlow = snap.first { $0.latest.proto == .tcp }!
        XCTAssertEqual(tcpFlow.rttSeries, [10, 12])
    }

    // MARK: - Sort

    func testBandwidthSortDescByTotalBytes() {
        let entries = [
            tcp(1, src: "a:1", dst: "b:1", rx: 10, tx: 10),
            tcp(2, src: "c:1", dst: "d:1", rx: 1_000, tx: 500),
            tcp(3, src: "e:1", dst: "f:1", rx: 200, tx: 100),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries, sort: .bandwidth)
        XCTAssertEqual(snap.map { $0.totalBytes }, [1_500, 300, 20])
    }

    func testRTTSortPutsNilLast() {
        let entries: [ConnectionEntry] = [
            tcp(1, src: "a:1", dst: "b:1", rtt: 50),
            tcp(2, src: "c:1", dst: "d:1", rtt: nil),
            tcp(3, src: "e:1", dst: "f:1", rtt: 5),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries, sort: .rtt)
        XCTAssertEqual(snap.map(\.latest.rttMS), [50, 5, nil])
    }

    func testStateSortGroupsAlphabeticallyThenByBandwidth() {
        let entries = [
            tcp(1, src: "a:1", dst: "b:1", state: "SYN_SENT",    rx: 1, tx: 0),
            tcp(2, src: "c:1", dst: "d:1", state: "ESTABLISHED", rx: 50, tx: 50),
            tcp(3, src: "e:1", dst: "f:1", state: "ESTABLISHED", rx: 1, tx: 0),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries, sort: .state)
        XCTAssertEqual(snap.map(\.latest.state), ["ESTABLISHED", "ESTABLISHED", "SYN_SENT"])
        XCTAssertEqual(snap[0].totalBytes, 100)
        XCTAssertEqual(snap[1].totalBytes, 1)
    }

    func testAgeSortDescByAgeS() {
        let entries: [ConnectionEntry] = [
            tcp(1, src: "a:1", dst: "b:1", age: 5),
            tcp(2, src: "c:1", dst: "d:1", age: 60),
            tcp(3, src: "e:1", dst: "f:1", age: 30),
        ]
        let snap = ConnectionsAggregator.snapshot(from: entries, sort: .age)
        XCTAssertEqual(snap.map(\.latest.ageS), [60, 30, 5])
    }

    // MARK: - Apply(sort:) round-trip

    func testApplySortReSortsExistingSnapshot() {
        let entries = [
            tcp(1, src: "a:1", dst: "b:1", rx: 10),
            tcp(2, src: "c:1", dst: "d:1", rx: 100),
        ]
        let bw  = ConnectionsAggregator.snapshot(from: entries, sort: .bandwidth)
        let key = ConnectionsAggregator.apply(sort: .bandwidth, to: bw)
        XCTAssertEqual(bw.map(\.key), key.map(\.key))
    }
}
