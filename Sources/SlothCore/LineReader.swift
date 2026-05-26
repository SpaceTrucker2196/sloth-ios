// LineReader — newline framing over a chunked byte stream.
//
// Newlines can split across receive buffers; the JSONL contract is
// one record per `\n`-terminated line. `LineReader` buffers bytes
// across appends until at least one full line is available, and
// returns the framed lines in order. A trailing `\r` (CRLF) is
// trimmed defensively, though sloth's writer only emits `\n`.

import Foundation

public actor LineReader {

    private var buffer = Data()

    public init() {}

    /// Append a chunk and return any complete lines now ready. Each
    /// returned `Data` is one line *without* its trailing newline.
    @discardableResult
    public func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        return drain()
    }

    /// Bytes received but not yet terminated by a newline. The caller
    /// rarely needs this — it's exposed for tests and for the final
    /// "did the server cut the stream mid-line" diagnostic.
    public func pending() -> Data { buffer }

    private func drain() -> [Data] {
        var out: [Data] = []
        while let nl = buffer.firstIndex(of: 0x0a) {
            let raw = buffer[buffer.startIndex..<nl]
            let line: Data
            if raw.last == 0x0d {
                line = Data(raw.dropLast())
            } else {
                line = Data(raw)
            }
            out.append(line)
            let next = buffer.index(after: nl)
            buffer = Data(buffer[next..<buffer.endIndex])
        }
        return out
    }

    /// Wraps an async byte-chunk sequence into an async line sequence.
    /// Each yielded `Data` is one framed line.
    public static func lines(
        from chunks: AsyncThrowingStream<Data, any Error>
    ) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream<Data, any Error> { continuation in
            let task = Task {
                let reader = LineReader()
                do {
                    for try await chunk in chunks {
                        for line in await reader.append(chunk) {
                            continuation.yield(line)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
