// SlothDiscovery — Bonjour browser for `_sloth._tcp.` services on
// the local network.
//
// The contract: a sloth instance running `--data-socket
// tcp:HOST:PORT` should publish a Bonjour service of type
// `_sloth._tcp.` on the same port. iOS picks it up via
// `NetServiceBrowser`, resolves it to a hostname (`*.local.`) and
// port, and surfaces a `DiscoveredService` the operator can tap to
// build a `ConnectionProfile` without typing.
//
// MISSION §2 alignment: no third-party deps (Foundation only), no
// out-bound writes — the browser is read-only and does not advertise
// anything from the iOS side. The Info.plist on the App side must
// declare `NSBonjourServices` and `NSLocalNetworkUsageDescription`
// for iOS 14+ to allow the browse.

import Foundation
import Observation

/// One resolved Bonjour service. The `id` is stable across re-
/// resolves so SwiftUI list identity holds when the service's TXT
/// record is republished.
public struct DiscoveredService: Sendable, Identifiable, Hashable {

    public let id: String      // "<name>.<type>.<domain>"
    public let name: String    // service instance name, e.g. "Living-Room sloth"
    public let hostname: String  // e.g. "slothmac.local"
    public let port: UInt16
    public let txt: [String: String]

    public init(
        id: String,
        name: String,
        hostname: String,
        port: UInt16,
        txt: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.txt = txt
    }

    /// `ConnectionProfile` ready to drop into `SlothClient`. The
    /// `.local.` trailing dot is stripped so the URI looks natural;
    /// `NWConnection` resolves `*.local` via mDNS automatically.
    public var profile: ConnectionProfile {
        ConnectionProfile(host: Self.trimDot(hostname), port: port)
    }

    private static func trimDot(_ s: String) -> String {
        s.hasSuffix(".") ? String(s.dropLast()) : s
    }
}

@MainActor
@Observable
public final class SlothDiscovery {

    public enum State: Sendable, Equatable {
        case idle
        case browsing
        case stopped
        case failed(reason: String)
    }

    public static let serviceType = "_sloth._tcp."

    public private(set) var state: State = .idle
    public private(set) var services: [DiscoveredService] = []

    private var delegate: BrowserDelegate?

    public init() {}

    public func start() {
        guard delegate == nil else { return }
        services = []
        let d = BrowserDelegate(serviceType: Self.serviceType) { [weak self] event in
            guard let self else { return }
            switch event {
            case .browsing:               self.state = .browsing
            case .stopped:                self.state = .stopped
            case .failed(let reason):     self.state = .failed(reason: reason)
            case .upsert(let svc):        self.upsert(svc)
            case .remove(let id):         self.services.removeAll { $0.id == id }
            }
        }
        self.delegate = d
        d.start()
    }

    public func stop() {
        delegate?.stop()
        delegate = nil
        if state == .browsing { state = .stopped }
    }

    private func upsert(_ svc: DiscoveredService) {
        if let i = services.firstIndex(where: { $0.id == svc.id }) {
            services[i] = svc
        } else {
            services.append(svc)
            services.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

// MARK: - Bonjour glue

/// NSObject delegate that owns the `NetServiceBrowser` + per-service
/// resolvers. Marked `@MainActor` so the delegate callbacks (which
/// arrive on the main run loop) can mutate the parent without hops.
@MainActor
private final class BrowserDelegate: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {

    enum Event {
        case browsing
        case stopped
        case failed(reason: String)
        case upsert(DiscoveredService)
        case remove(id: String)
    }

    private let serviceType: String
    private let emit: (Event) -> Void
    private let browser = NetServiceBrowser()
    private var resolving: [NetService] = []

    init(serviceType: String, emit: @escaping (Event) -> Void) {
        self.serviceType = serviceType
        self.emit = emit
        super.init()
        browser.delegate = self
    }

    func start() {
        emit(.browsing)
        // Empty domain "" lets the system default ("local.") apply.
        browser.searchForServices(ofType: serviceType, inDomain: "")
    }

    func stop() {
        browser.stop()
        for svc in resolving { svc.stop() }
        resolving.removeAll()
        emit(.stopped)
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        MainActor.assumeIsolated {
            service.delegate = self
            service.resolve(withTimeout: 5)
            resolving.append(service)
        }
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        let id = Self.identity(of: service)
        MainActor.assumeIsolated {
            resolving.removeAll { $0 == service }
            emit(.remove(id: id))
        }
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        let reason = "Bonjour browse failed: \(errorDict)"
        MainActor.assumeIsolated { emit(.failed(reason: reason)) }
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        let id   = Self.identity(of: sender)
        let name = sender.name
        let host = sender.hostName ?? ""
        let port = sender.port
        let txt  = Self.parseTXT(sender.txtRecordData())
        MainActor.assumeIsolated {
            guard !host.isEmpty, port > 0, port <= Int(UInt16.max) else { return }
            let svc = DiscoveredService(
                id: id,
                name: name,
                hostname: host,
                port: UInt16(port),
                txt: txt
            )
            emit(.upsert(svc))
            resolving.removeAll { $0 == sender }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        MainActor.assumeIsolated {
            resolving.removeAll { $0 == sender }
        }
    }

    // MARK: - Helpers

    nonisolated private static func identity(of service: NetService) -> String {
        "\(service.name).\(service.type)\(service.domain)"
    }

    nonisolated private static func parseTXT(_ data: Data?) -> [String: String] {
        guard let data else { return [:] }
        let dict = NetService.dictionary(fromTXTRecord: data)
        var out: [String: String] = [:]
        for (k, v) in dict {
            out[k] = String(data: v, encoding: .utf8) ?? ""
        }
        return out
    }
}
