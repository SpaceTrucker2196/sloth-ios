// PostClient — the hub side of the post protocol. Where `SlothClient`
// reads a sloth instance's stream into `SlothRecord`, `PostClient`
// reads a sensor post's stream into `SensorRecord`. Same transport
// seam, same newline framing, same drop-a-garbled-line policy. A
// sloth-ios acting as the fleet viewer opens one of these per
// discovered post and funnels the records into `FleetStore`.

import Foundation

public struct PostClient: Sendable {

    private let transport: any SlothTransport

    public init(transport: any SlothTransport = NetworkTransport()) {
        self.transport = transport
    }

    public func records(
        for profile: ConnectionProfile
    ) -> AsyncThrowingStream<SensorRecord, any Error> {
        let chunks = transport.bytes(for: profile)
        let lines  = LineReader.lines(from: chunks)
        return AsyncThrowingStream<SensorRecord, any Error> { continuation in
            let task = Task {
                let decoder = JSONDecoder()
                do {
                    for try await line in lines {
                        if line.isEmpty { continue }
                        if let rec = try? decoder.decode(SensorRecord.self, from: line) {
                            continuation.yield(rec)
                        }
                        // A line that isn't a known sensor record is
                        // dropped, same as the consumer path. Posts
                        // only ever emit valid SensorRecord JSONL.
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
