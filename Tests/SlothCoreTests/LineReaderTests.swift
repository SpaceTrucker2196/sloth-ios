import XCTest
@testable import SlothCore

final class LineReaderTests: XCTestCase {

    func testSingleChunkSplits() async {
        let reader = LineReader()
        let lines = await reader.append(Data("a\nb\nc\n".utf8))
        XCTAssertEqual(lines.map { String(data: $0, encoding: .utf8) },
                       ["a", "b", "c"])
        let pending = await reader.pending()
        XCTAssertTrue(pending.isEmpty)
    }

    func testTrailingPartialLineHeldUntilNewline() async {
        let reader = LineReader()
        let first  = await reader.append(Data("hel".utf8))
        let second = await reader.append(Data("lo\nwo".utf8))
        let third  = await reader.append(Data("rld\n".utf8))
        XCTAssertEqual(first, [])
        XCTAssertEqual(second.map { String(data: $0, encoding: .utf8) }, ["hello"])
        XCTAssertEqual(third .map { String(data: $0, encoding: .utf8) }, ["world"])
    }

    func testNewlineSplitAcrossChunks() async {
        // The chunk boundary lands between the bytes that make up a
        // single line; the reader must buffer until `\n` arrives.
        let reader = LineReader()
        let a = await reader.append(Data("one".utf8))
        let b = await reader.append(Data("\ntwo\n".utf8))
        XCTAssertEqual(a, [])
        XCTAssertEqual(b.map { String(data: $0, encoding: .utf8) }, ["one", "two"])
    }

    func testCRLFTrimmedDefensively() async {
        let reader = LineReader()
        let lines = await reader.append(Data("alpha\r\nbeta\r\n".utf8))
        XCTAssertEqual(lines.map { String(data: $0, encoding: .utf8) },
                       ["alpha", "beta"])
    }

    func testEmptyLinesPreserved() async {
        // Empty lines aren't valid JSONL but the framer should still
        // surface them — the JSON layer skips them, not us.
        let reader = LineReader()
        let lines = await reader.append(Data("\n\nx\n".utf8))
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], Data())
        XCTAssertEqual(lines[1], Data())
        XCTAssertEqual(String(data: lines[2], encoding: .utf8), "x")
    }

    func testStreamAdapterYieldsLines() async throws {
        let bytes = AsyncThrowingStream<Data, any Error> { continuation in
            continuation.yield(Data("hello\nwor".utf8))
            continuation.yield(Data("ld\n".utf8))
            continuation.finish()
        }
        var got: [String] = []
        for try await line in LineReader.lines(from: bytes) {
            got.append(String(data: line, encoding: .utf8) ?? "")
        }
        XCTAssertEqual(got, ["hello", "world"])
    }
}
