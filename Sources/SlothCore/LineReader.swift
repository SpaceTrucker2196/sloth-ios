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
        // Scan the whole buffer once, then trim the consumed prefix
        // once at the end. A naïve rebuild-per-line is O(n²) on chunks
        // that contain many lines — sloth bursts can easily put
        // hundreds of records in a single 64 KiB receive.
        var out: [Data] = []
        var cursor = buffer.startIndex
        while cursor < buffer.endIndex,
              let nl = buffer[cursor...].firstIndex(of: 0x0a) {
            let raw = buffer[cursor..<nl]
            let line = raw.last == 0x0d ? Data(raw.dropLast()) : Data(raw)
            out.append(line)
            cursor = buffer.index(after: nl)
        }
        if cursor > buffer.startIndex {
            buffer = Data(buffer[cursor..<buffer.endIndex])
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
