# JSONL protocol (consumer side)

This page documents what sloth-ios needs to know about the wire
format. The **authoritative** specification lives in the sloth repo:

→ [`sloth/docs/wiki/jsonl-schema.md`](https://github.com/SpaceTrucker2196/sloth/blob/main/docs/wiki/jsonl-schema.md)

Read that first. Below is just the consumer-side cheat sheet.

## Connection

- Transport: TCP (`tcp:HOST:PORT`) or UNIX-domain (`unix:/path`).
- After `connect()`, the socket is **read-only**. sloth never reads
  from it; sloth-ios never writes to it.
- No handshake, no auth, no length prefix. Lines as they arrive.
- Framing: one JSON object per line, terminated by `\n`. Split on
  `\n`; parse each line independently.
- Backpressure: a slow consumer that fills its TCP receive buffer
  *loses lines* — sloth's writer drops them rather than queueing
  (see sloth `data_socket.c`). Reconnect to resume.

## Records

Every record has an envelope:

```json
{ "type": "<type>", "ts": <unix-seconds>, ... }
```

Known `type` values as of 2026-05-26:

- `dns`
- `tls`
- `quic`
- `http`
- `ntp`
- `icmp`
- `alert`

The full field-by-field listing is in the schema page. The Swift
sum type that mirrors it lives in `Sources/SlothCore/SlothRecord.swift`.

## Forward compatibility

- **Unknown `type` values must be ignored**, not rejected. New record
  types may appear when sloth grows new observables.
- **Unknown keys in known records must be ignored.** Schema is
  append-only; existing field names and meanings don't change.
- The `sev` integer in `alert` records is guaranteed stable:
  `0 = LOW, 1 = WARN, 2 = CRIT`.

## Decoding sketch (Swift)

```swift
public enum SlothRecord: Decodable, Sendable {
    case dns(DNSEntry)
    case tls(TLSEntry)
    case quic(QUICEntry)
    case http(HTTPEntry)
    case ntp(NTPEntry)
    case icmp(ICMPEntry)
    case alert(AlertEntry)
    case unknown(type: String, ts: Int)

    private enum DiscriminatorKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DiscriminatorKey.self)
        let t = try c.decode(String.self, forKey: .type)
        switch t {
        case "dns":   self = .dns  (try .init(from: decoder))
        case "tls":   self = .tls  (try .init(from: decoder))
        case "quic":  self = .quic (try .init(from: decoder))
        case "http":  self = .http (try .init(from: decoder))
        case "ntp":   self = .ntp  (try .init(from: decoder))
        case "icmp":  self = .icmp (try .init(from: decoder))
        case "alert": self = .alert(try .init(from: decoder))
        default:
            // Forward-compat: keep the record alive but unparsed.
            let stub = try Stub(from: decoder)
            self = .unknown(type: t, ts: stub.ts)
        }
    }

    private struct Stub: Decodable { let ts: Int }
}
```

`AlertEntry.sev` is `Int` (decoded directly) and immediately
promoted to a typed enum at the consume site to enforce the 3-tier
contract.

## Line reader

Newlines can split across receive buffers. The consumer must buffer
across `NWConnection.receive(_:_:_:)` callbacks until a `\n` is
found. `Sources/SlothCore/LineReader.swift` is the canonical
implementation — copy it, don't reinvent it.

## Failure modes

- **Garbled JSON line**: log + skip. Don't tear down the connection
  over one bad record; sloth's writer never emits invalid JSON, so a
  single bad line is a wire-corruption event, not a contract break.
- **`connect()` fails / refused**: surface as a status pill; retry
  with exponential backoff up to 30s (`Reconnector.swift`).
- **App backgrounds**: cancel the receive loop. iOS will reap the
  socket anyway. Reconnect on foreground.
- **Server disconnects**: same as above — retry with backoff.
