// SensorBuffer — the post's in-memory ring of the sensor records it
// has most recently produced, ready to stream to any hub that
// connects. Purely in-memory per MISSION §2(5): closing the app
// discards it.
//
// Two record shapes share the buffer:
//   * Latching records (ios_post, imu_sample, wifi_self, radio_scan,
//     geo_fix) — only the newest matters, so each replaces the prior
//     one of its kind. A hub that connects late gets current state.
//   * Accumulating records (ble_contact) — one entry per contact
//     `addr`, updated in place (rssi/count refreshed) with a bounded
//     cap so a crowded room can't grow the buffer without limit.
//
// `snapshotLines()` renders the whole buffer as newline-delimited
// JSONL in a stable order (identity first, then sensors, then
// contacts) so a freshly connected hub receives a coherent picture in
// one burst before the live tail continues.

import Foundation

public struct SensorBuffer: Sendable {

    /// Cap on distinct BLE contacts retained. Oldest-seen evicted
    /// first when exceeded. Mirrors the bounded-ring discipline the
    /// consumer side uses in `RingSizes`.
    public let maxContacts: Int

    private var identity: SensorRecord?
    private var imu: SensorRecord?
    private var wifiSelf: SensorRecord?
    private var radioScan: SensorRecord?
    private var geoFix: SensorRecord?

    // addr -> (record, lastSeenTS) preserving first-insert order via
    // a parallel key list for deterministic eviction + output.
    private var contacts: [String: BLEContactEntry] = [:]
    private var contactOrder: [String] = []

    public init(maxContacts: Int = 256) {
        self.maxContacts = max(1, maxContacts)
    }

    // MARK: - Ingest

    public mutating func record(_ rec: SensorRecord) {
        switch rec {
        case .iosPost:   identity  = rec
        case .imuSample: imu       = rec
        case .wifiSelf:  wifiSelf  = rec
        case .radioScan: radioScan = rec
        case .geoFix:    geoFix    = rec
        case .bleContact(let e): upsertContact(e)
        }
    }

    private mutating func upsertContact(_ e: BLEContactEntry) {
        if contacts[e.addr] == nil {
            contactOrder.append(e.addr)
            if contactOrder.count > maxContacts {
                let evict = contactOrder.removeFirst()
                contacts.removeValue(forKey: evict)
            }
        }
        contacts[e.addr] = e
    }

    // MARK: - Readout

    public var contactCount: Int { contacts.count }

    public var currentIdentity: IOSPostEntry? {
        if case .iosPost(let e)? = identity { return e }
        return nil
    }

    public var bleContacts: [BLEContactEntry] {
        contactOrder.compactMap { contacts[$0] }
    }

    /// Every retained record in hub-friendly order.
    public func snapshot() -> [SensorRecord] {
        var out: [SensorRecord] = []
        if let identity  { out.append(identity) }
        if let imu       { out.append(imu) }
        if let wifiSelf  { out.append(wifiSelf) }
        if let radioScan { out.append(radioScan) }
        if let geoFix    { out.append(geoFix) }
        out.append(contentsOf: bleContacts.map(SensorRecord.bleContact))
        return out
    }

    /// Snapshot encoded as newline-delimited JSONL bytes.
    public func snapshotLines() -> [Data] {
        snapshot().compactMap { $0.jsonlLine() }
    }

    /// Drop contacts whose newest sighting is older than `ttl`
    /// seconds relative to `now`. Keeps the radar from showing ghosts
    /// of devices that have walked away.
    public mutating func evictStaleContacts(now: Int, ttl: Int) {
        guard ttl > 0 else { return }
        let cutoff = now - ttl
        let survivors = contactOrder.filter { addr in
            (contacts[addr]?.ts ?? 0) >= cutoff
        }
        for addr in contactOrder where !survivors.contains(addr) {
            contacts.removeValue(forKey: addr)
        }
        contactOrder = survivors
    }
}
