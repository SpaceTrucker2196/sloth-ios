import XCTest
@testable import SlothCore

final class LogFilterTests: XCTestCase {

    func testEmptyQueryMatchesAnything() {
        XCTAssertTrue(LogFilter.matches(query: "",  fields: ["anything"]))
        XCTAssertTrue(LogFilter.matches(query: "   ", fields: ["anything"]))
    }

    func testEmptyFieldsRejectsNonEmptyQuery() {
        XCTAssertFalse(LogFilter.matches(query: "x", fields: []))
        XCTAssertFalse(LogFilter.matches(query: "x", fields: [nil, nil]))
    }

    func testCaseInsensitiveSubstring() {
        XCTAssertTrue(LogFilter.matches(query: "GOOGLE", fields: ["dns.google"]))
        XCTAssertTrue(LogFilter.matches(query: "Google", fields: ["DNS.GOOGLE"]))
    }

    func testMultiWordIsAndAcrossFields() {
        // "google 443" must find both substrings across the haystack.
        XCTAssertTrue(LogFilter.matches(
            query: "google 443",
            fields: ["dns.google", "10.0.0.1:443"]
        ))
        // Same query against fields missing "443" should fail.
        XCTAssertFalse(LogFilter.matches(
            query: "google 443",
            fields: ["dns.google", "10.0.0.1:80"]
        ))
    }

    func testIgnoresNilFields() {
        XCTAssertTrue(LogFilter.matches(query: "a", fields: [nil, "abc"]))
    }
}

final class QTypeDistributionTests: XCTestCase {

    private func dns(_ qtype: String) -> DNSEntry {
        DNSEntry(ts: 0, src: "1.1.1.1", qname: "x", qtype: qtype, answer: nil)
    }

    func testEmptyInputReturnsEmptyShares() {
        XCTAssertTrue(QTypeDistribution.shares([]).isEmpty)
    }

    func testKnownQTypesKeepTheirSlice() {
        let shares = QTypeDistribution.shares([dns("A"), dns("AAAA"), dns("MX")])
        XCTAssertEqual(shares.count, 3)
        XCTAssertEqual(Set(shares.map(\.label)), ["A", "AAAA", "MX"])
    }

    func testUnknownQTypeCollapsesToOther() {
        let shares = QTypeDistribution.shares([dns("HTTPS"), dns("SVCB")])
        XCTAssertEqual(shares.count, 1)
        XCTAssertEqual(shares.first?.label, "other")
        XCTAssertEqual(shares.first?.count, 2)
    }

    func testNilOrEmptyQTypeIsOther() {
        let entry = DNSEntry(ts: 0, src: nil, qname: "x", qtype: nil, answer: nil)
        let shares = QTypeDistribution.shares([entry])
        XCTAssertEqual(shares.first?.label, "other")
    }

    func testSortLargestFirstOtherLast() {
        let entries = [dns("A"), dns("A"), dns("A"),
                       dns("AAAA"), dns("HTTPS")]   // HTTPS → other
        let shares = QTypeDistribution.shares(entries)
        XCTAssertEqual(shares.map(\.label), ["A", "AAAA", "other"])
    }
}

final class TLSVersionMixTests: XCTestCase {

    private func tls(_ version: String?) -> TLSEntry {
        TLSEntry(ts: 0, src: "10.0.0.1", dst: "1.1.1.1",
                 sni: "x", version: version, ja3: nil)
    }

    func testEmptyInputReturnsEmptyShares() {
        XCTAssertTrue(TLSVersionMix.shares([]).isEmpty)
    }

    func testCanonicalisesShapes() {
        let shares = TLSVersionMix.shares([
            tls("TLS 1.3"), tls("1.3"), tls("tls1.3"),
        ])
        XCTAssertEqual(shares.count, 1)
        XCTAssertEqual(shares.first?.label, "TLS 1.3")
        XCTAssertEqual(shares.first?.count, 3)
    }

    func testUnknownVersionFallsBackToOther() {
        let shares = TLSVersionMix.shares([tls("SSL 3.0"), tls(nil)])
        XCTAssertEqual(shares.count, 1)
        XCTAssertEqual(shares.first?.label, "other")
        XCTAssertEqual(shares.first?.count, 2)
    }

    func testStableOrderAcrossFrames() {
        // 1.3 should always come first; 1.0/1.1 in the WARN tier.
        let shares = TLSVersionMix.shares([
            tls("TLS 1.0"), tls("TLS 1.3"), tls("TLS 1.2"), tls("TLS 1.1"),
        ])
        XCTAssertEqual(shares.map(\.label), ["TLS 1.3","TLS 1.2","TLS 1.1","TLS 1.0"])
    }

    func testDeprecatedFlag() {
        XCTAssertTrue (TLSVersionMix.isDeprecated("TLS 1.0"))
        XCTAssertTrue (TLSVersionMix.isDeprecated("TLS 1.1"))
        XCTAssertFalse(TLSVersionMix.isDeprecated("TLS 1.2"))
        XCTAssertFalse(TLSVersionMix.isDeprecated("TLS 1.3"))
        XCTAssertFalse(TLSVersionMix.isDeprecated(nil))
    }
}
