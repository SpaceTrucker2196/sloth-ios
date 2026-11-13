// PostService — the sensor post's read-only stream server.
//
// Symmetry with sloth: sloth exposes a one-way `--data-socket` that
// consumers read. A sloth-ios sensor post does the identical thing in
// the other direction — it opens an `NWListener`, advertises itself
// over Bonjour as `_sloth-post._tcp.`, and when a hub (sloth, or
// another sloth-ios acting as fleet viewer) connects, it streams
// newline-delimited `SensorRecord` JSONL. The post never reads from a
// connected hub; the protocol is one-way, no handshake, no verbs.
// Access control is the operator's job — bind on the tailnet, lean on
// Tailscale ACLs. This matches sloth's data-socket trust model.
//
// Lifecycle mirrors MISSION §4: the listener runs only in the
// foreground. The app layer stops it on background and restarts on
// foreground.
//
// Concurrency: all socket state is confined to `queue`. The class is
// `@unchecked Sendable` because every mutable field is touched only
// from that serial queue; the status callback hops to the main actor.

import Foundation
import Network

public final class PostService: @unchecked Sendable {

    public struct Status: Sendable, Equatable {
        public var listening: Bool
        public var port: UInt16?
        public var clientCount: Int
        public var lastError: String?
        public init(listening: Bool = false, port: UInt16? = nil,
                    clientCount: Int = 0, lastError: String? = nil) {
            self.listening = listening; self.port = port
            self.clientCount = clientCount; self.lastError = lastError
        }
    }

    public static let serviceType = "_sloth-post._tcp"

    private let queue = DispatchQueue(label: "io.river.sloth.post")
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: NWConnection] = [:]

    /// Returns the current snapshot the post wants a freshly connected
    /// hub to receive before the live tail. Called on `queue`.
    private let snapshotProvider: @Sendable () -> [Data]

    /// Fired on the main actor whenever listening/ client state
    /// changes, so an @Observable wrapper can republish it.
    private let onStatus: (@MainActor @Sendable (Status) -> Void)?

    private var status = Status() {
        didSet {
            let snap = status
            if let onStatus {
                Task { @MainActor in onStatus(snap) }
            }
        }
    }

    public init(
        snapshotProvider: @escaping @Sendable () -> [Data],
        onStatus: (@MainActor @Sendable (Status) -> Void)? = nil
    ) {
        self.snapshotProvider = snapshotProvider
        self.onStatus = onStatus
    }

    // MARK: - Control

    /// Start listening and advertising. `name` is the Bonjour
    /// instance name the hub sees; `txt` is published in the TXT
    /// record (post id, role, version) so a hub can roster the post
    /// before it connects.
    public func start(serviceName: String, txt: [String: String], port: UInt16? = nil) {
        queue.async { [self] in
            guard listener == nil else { return }
            do {
                let params = NWParameters.tcp
                params.includePeerToPeer = true
                let l: NWListener
                if let port, let p = NWEndpoint.Port(rawValue: port) {
                    l = try NWListener(using: params, on: p)
                } else {
                    l = try NWListener(using: params)   // OS picks a free port
                }
                l.service = NWListener.Service(
                    name: serviceName,
                    type: Self.serviceType,
                    txtRecord: NWTXTRecord(txt))
                l.stateUpdateHandler = { [weak self] state in
                    self?.handleListenerState(state)
                }
                l.newConnectionHandler = { [weak self] conn in
                    self?.accept(conn)
                }
                listener = l
                l.start(queue: queue)
            } catch {
                status = Status(listening: false, port: nil, clientCount: 0,
                                lastError: "listener failed: \(error)")
            }
        }
    }

    public func stop() {
        queue.async { [self] in
            for (_, c) in clients { c.cancel() }
            clients.removeAll()
            listener?.cancel()
            listener = nil
            status = Status(listening: false)
        }
    }

    /// Push one already-encoded JSONL line (newline-terminated) to
    /// every connected hub. Called by the app layer as sensors fire.
    public func broadcast(_ line: Data) {
        queue.async { [self] in
            for (_, c) in clients { Self.send(line, on: c) }
        }
    }

    public func broadcast(_ lines: [Data]) {
        queue.async { [self] in
            for line in lines { for (_, c) in clients { Self.send(line, on: c) } }
        }
    }

    // MARK: - Internals (all on `queue`)

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            let p = listener?.port?.rawValue
            status = Status(listening: true, port: p, clientCount: clients.count)
        case .failed(let err):
            listener = nil
            status = Status(listening: false, lastError: "listener failed: \(err)")
        case .cancelled:
            status = Status(listening: false, clientCount: 0)
        default:
            break
        }
    }

    private func accept(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                // Burst the current snapshot so a late hub sees state.
                for line in self.snapshotProvider() { Self.send(line, on: conn) }
                self.status = Status(listening: true,
                                     port: self.listener?.port?.rawValue,
                                     clientCount: self.clients.count)
            case .failed, .cancelled:
                self.clients.removeValue(forKey: key)
                self.status = Status(listening: self.listener != nil,
                                     port: self.listener?.port?.rawValue,
                                     clientCount: self.clients.count)
            default:
                break
            }
        }
        clients[key] = conn
        conn.start(queue: queue)
        // Read-only contract: we never call conn.receive. We only
        // write. A hub that closes surfaces via stateUpdateHandler.
    }

    private static func send(_ data: Data, on conn: NWConnection) {
        conn.send(content: data, completion: .contentProcessed { _ in })
    }
}
