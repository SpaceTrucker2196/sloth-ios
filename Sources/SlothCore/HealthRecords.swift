// Alert lifecycle and stream-health records (sloth jsonl_version 2.x).
//
// Upstream contract: sloth `docs/wiki/jsonl-schema.md`, sections
// `alert.create` / `alert.update` / `alert.escalate` / `alert.resolve`
// (#98), `sensor_health` (#91, `daemon` since 1.9.0, `jsonl_version`
// since 1.0.0) and `socket_gap` (#93).
//
// Each struct stores the wire `type` so synthesized Codable round-trips
// it; every field the schema marks as omittable is optional.

import Foundation

// MARK: - Alert lifecycle

/// One `alert.*` lifecycle event. An incident opens with one `create`,
/// carries one `incident_id` through `update` / `escalate`, and closes
/// with one `resolve`. Before #98 a WARN→CRIT transition emitted
/// nothing; `escalate` is the record that carries it now.
public struct AlertEventEntry: Sendable, Codable, Equatable, Identifiable {

    public enum Kind: String, Sendable, CaseIterable {
        case create   = "alert.create"
        case update   = "alert.update"
        case escalate = "alert.escalate"
        case resolve  = "alert.resolve"
    }

    public let type: String
    public let ts: Int
    public let eventID: String
    public let incidentID: String
    public let key: String
    public let title: String
    public let detail: String?
    public let sev: Int
    public let prevSev: Int?
    public let ty: Int?
    public let technique: String?
    public let confidence: Int?
    public let matchIP: String?
    public let observations: Int?
    public let evaluations: Int?
    public let firstDetected: Int?
    public let lastEvaluated: Int?
    /// `alert.resolve` only: `expired`, `evicted`, `cleared`,
    /// `recovered`, `displaced`. Free text so a new reason never fails
    /// the decode.
    public let reason: String?

    public var id: String { eventID }
    public var kind: Kind? { Kind(rawValue: type) }
    public var severity: AlertSeverity { AlertSeverity(rawValue: sev) ?? .low }

    enum CodingKeys: String, CodingKey {
        case type, ts, key, title, detail, sev, ty, technique, confidence
        case observations, evaluations, reason
        case eventID       = "event_id"
        case incidentID    = "incident_id"
        case prevSev       = "prev_sev"
        case matchIP       = "match_ip"
        case firstDetected = "first_detected"
        case lastEvaluated = "last_evaluated"
    }

    public init(kind: Kind, ts: Int, eventID: String, incidentID: String,
                key: String, title: String, detail: String? = nil,
                sev: Int, prevSev: Int? = nil, ty: Int? = nil,
                technique: String? = nil, confidence: Int? = nil,
                matchIP: String? = nil, observations: Int? = nil,
                evaluations: Int? = nil, firstDetected: Int? = nil,
                lastEvaluated: Int? = nil, reason: String? = nil) {
        self.type = kind.rawValue; self.ts = ts
        self.eventID = eventID; self.incidentID = incidentID
        self.key = key; self.title = title; self.detail = detail
        self.sev = sev; self.prevSev = prevSev; self.ty = ty
        self.technique = technique; self.confidence = confidence
        self.matchIP = matchIP; self.observations = observations
        self.evaluations = evaluations; self.firstDetected = firstDetected
        self.lastEvaluated = lastEvaluated; self.reason = reason
    }

    /// The legacy-shaped row the Alerts views already render, carrying
    /// the incident's *current* severity and detail.
    public var asAlert: AlertEntry {
        AlertEntry(ts: ts, title: title, detail: detail, key: key,
                   hits: evaluations ?? 1,
                   firstSeen: firstDetected ?? ts,
                   lastSeen: lastEvaluated ?? ts,
                   matchIP: matchIP, sev: sev)
    }
}

// MARK: - Sensor health

/// The sensor's self-report: "was sloth able to see". One per daemon;
/// change-only, so a healthy sensor sends one per 300 s heartbeat.
///
/// Members a daemon has nothing to say about are *absent*, not zero
/// (sloth-rf carries no `capture_*` / `monitor_*`), so every field
/// past the envelope is optional.
public struct SensorHealthEntry: Sendable, Codable, Equatable {

    public let type: String
    public let ts: Int
    /// `"wifi"` or `"rf"`. Absent before 1.9.0, when there was one
    /// daemon — read through `daemonName`.
    public let daemon: String?
    public let jsonlVersion: String?

    public let captureIface: String?
    public let monitorIface: String?
    public let monitorErr: String?
    public let captureOpen: Int?
    public let captureRunning: Int?
    public let captureExit: String?
    public let captureDrop: Int?
    public let captureIfdrop: Int?
    public let monitorOpen: Int?
    public let monitorRunning: Int?
    public let monitorExit: String?
    public let monitorDrop: Int?
    public let monitorIfdrop: Int?
    public let chanConfirmedOK: Int?
    public let evictions: Int?
    public let storageFailures: Int?
    public let scope: String?
    public let scopeNotEnforced: Int?

    enum CodingKeys: String, CodingKey {
        case type, ts, daemon, evictions, scope
        case jsonlVersion     = "jsonl_version"
        case captureIface     = "capture_iface"
        case monitorIface     = "monitor_iface"
        case monitorErr       = "monitor_err"
        case captureOpen      = "capture_open"
        case captureRunning   = "capture_running"
        case captureExit      = "capture_exit"
        case captureDrop      = "capture_drop"
        case captureIfdrop    = "capture_ifdrop"
        case monitorOpen      = "monitor_open"
        case monitorRunning   = "monitor_running"
        case monitorExit      = "monitor_exit"
        case monitorDrop      = "monitor_drop"
        case monitorIfdrop    = "monitor_ifdrop"
        case chanConfirmedOK  = "chan_confirmed_ok"
        case storageFailures  = "storage_failures"
        case scopeNotEnforced = "scope_not_enforced"
    }

    public init(ts: Int, daemon: String? = nil, jsonlVersion: String? = nil,
                captureIface: String? = nil, monitorIface: String? = nil,
                monitorErr: String? = nil,
                captureOpen: Int? = nil, captureRunning: Int? = nil,
                captureExit: String? = nil, captureDrop: Int? = nil,
                captureIfdrop: Int? = nil,
                monitorOpen: Int? = nil, monitorRunning: Int? = nil,
                monitorExit: String? = nil, monitorDrop: Int? = nil,
                monitorIfdrop: Int? = nil, chanConfirmedOK: Int? = nil,
                evictions: Int? = nil, storageFailures: Int? = nil,
                scope: String? = nil, scopeNotEnforced: Int? = nil) {
        self.type = "sensor_health"; self.ts = ts
        self.daemon = daemon; self.jsonlVersion = jsonlVersion
        self.captureIface = captureIface; self.monitorIface = monitorIface
        self.monitorErr = monitorErr
        self.captureOpen = captureOpen; self.captureRunning = captureRunning
        self.captureExit = captureExit; self.captureDrop = captureDrop
        self.captureIfdrop = captureIfdrop
        self.monitorOpen = monitorOpen; self.monitorRunning = monitorRunning
        self.monitorExit = monitorExit; self.monitorDrop = monitorDrop
        self.monitorIfdrop = monitorIfdrop
        self.chanConfirmedOK = chanConfirmedOK; self.evictions = evictions
        self.storageFailures = storageFailures
        self.scope = scope; self.scopeNotEnforced = scopeNotEnforced
    }

    public var daemonName: String { daemon ?? "wifi" }

    /// MAJOR part of `jsonl_version`. The app is written against 2.x;
    /// a MINOR bump only adds, so only MAJOR is worth comparing.
    public var jsonlMajor: Int? {
        jsonlVersion.flatMap { $0.split(separator: ".").first }.flatMap { Int($0) }
    }

    /// Plain-language problems, empty when the sensor is observing.
    /// An open handle behind a dead thread is the failure #91 exists
    /// for: it looks exactly like a quiet network.
    public var problems: [String] {
        var out: [String] = []
        if captureOpen == 1, captureRunning == 0 {
            out.append("capture stopped (\(captureExit ?? "?"))")
        }
        if monitorOpen == 1, monitorRunning == 0 {
            out.append("monitor radio stopped (\(monitorExit ?? "?"))")
        }
        if let err = monitorErr, !err.isEmpty { out.append("monitor: \(err)") }
        if chanConfirmedOK == 0 { out.append("channel retune not confirmed") }
        if scopeNotEnforced == 1 { out.append("capture scope \(scope ?? "not enforced")") }
        if let n = storageFailures, n > 0 { out.append("\(n) storage write failures") }
        return out
    }

    /// Lifetime packets lost by libpcap and the NIC, both handles.
    public var droppedPackets: Int {
        [captureDrop, captureIfdrop, monitorDrop, monitorIfdrop]
            .compactMap { $0 }.reduce(0, +)
    }
}

// MARK: - Socket gap

/// Written only to the one data-socket connection that lost records:
/// this client fell behind and sloth dropped lines for it.
public struct SocketGapEntry: Sendable, Codable, Equatable {
    public let type: String
    public let ts: Int
    public let seq: Int
    public let dropped: Int
    public let droppedTotal: Int

    enum CodingKeys: String, CodingKey {
        case type, ts, seq, dropped
        case droppedTotal = "dropped_total"
    }

    public init(ts: Int, seq: Int, dropped: Int, droppedTotal: Int) {
        self.type = "socket_gap"; self.ts = ts; self.seq = seq
        self.dropped = dropped; self.droppedTotal = droppedTotal
    }
}
