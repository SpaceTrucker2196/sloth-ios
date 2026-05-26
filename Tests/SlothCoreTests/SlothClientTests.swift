import XCTest
@testable import SlothCore

/// In-memory transport that replays a scripted byte sequence. Used to
/// exercise the full client pipeline (bytes → frame → JSON → record)
/// without touching `Network.framework`.
struct ScriptedTransport: SlothTransport {
    let chunks: [Data]
    let terminalError: (any Error)?

    init(chunks: [Data], terminalError: (any Error)? = nil) {
        self.chunks = chunks
        self.terminalError = terminalError
    }

    func bytes(for profile: ConnectionProfile) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream<Data, any Error> { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            if let error = terminalError {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

private struct FakeError: Error, Equatable {}

final class SlothClientTests: XCTestCase {

    private let profile = ConnectionProfile(host: "fake", port: 7777)

    func testRecordsFlowThroughTransport() async throws {
        // Two known records, one unknown — across a split chunk.
        let line1 = #"{"type":"dns","ts":1,"qname":"a"}"#
        let line2 = #"{"type":"alert","ts":2,"title":"T","first_seen":2,"last_seen":2,"sev":2}"#
        let line3 = #"{"type":"future","ts":3}"#

        let split = "\(line1)\n\(line2)\n\(line3)\n"
        let mid   = split.index(split.startIndex, offsetBy: 10)
        let head  = Data(split[split.startIndex..<mid].utf8)
        let tail  = Data(split[mid..<split.endIndex].utf8)

        let transport = ScriptedTransport(chunks: [head, tail])
        let client    = SlothClient(transport: transport)

        var records: [SlothRecord] = []
        for try await r in client.records(for: profile) {
            records.append(r)
        }

        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].typeTag, "dns")
        XCTAssertEqual(records[1].typeTag, "alert")
        guard case .alert(let alert) = records[1] else {
            return XCTFail("expected alert")
        }
        XCTAssertEqual(alert.severity, .crit)
        if case .unknown(let tag, let ts) = records[2] {
            XCTAssertEqual(tag, "future")
            XCTAssertEqual(ts, 3)
        } else {
            XCTFail("expected unknown")
        }
    }

    func testGarbledLineIsSkippedNotFatal() async throws {
        let transport = ScriptedTransport(chunks: [
            Data("not-json\n".utf8),
            Data(#"{"type":"dns","ts":1,"qname":"a"}\#n"#.utf8)
        ])
        let client = SlothClient(transport: transport)
        var got: [SlothRecord] = []
        for try await r in client.records(for: profile) { got.append(r) }
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got.first?.typeTag, "dns")
    }

    func testTransportErrorPropagates() async {
        let transport = ScriptedTransport(
            chunks: [Data(#"{"type":"dns","ts":1,"qname":"a"}\#n"#.utf8)],
            terminalError: FakeError()
        )
        let client = SlothClient(transport: transport)
        do {
            for try await _ in client.records(for: profile) {}
            XCTFail("expected error")
        } catch is FakeError {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}
