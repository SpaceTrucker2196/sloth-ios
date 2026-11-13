// SensorCoordinator — drives the device's sensors and serves their
// output as a sloth sensor post. This is the producer half of the
// app (the consumer half is `ConnectionCoordinator`).
//
// What it collects, all passively:
//   * BLE advertisers in range        → ble_contact   (CoreBluetooth)
//   * compass heading + magnetometer  → imu_sample     (CoreMotion / CoreLocation)
//   * the one joined WiFi network      → wifi_self     (NEHotspotNetwork)
//   * coarse position (opt-in)         → geo_fix        (CoreLocation)
//   * best-effort nearby-AP scan       → radio_scan     (PrivateRadioProbe)
//
// It never transmits on any radio, never pairs, never connects to a
// BLE peer — scan-only. Records land in a `SensorBuffer` (for late
// hubs) and are broadcast live through `PostService`. Nothing is
// written to disk.
//
// Delegate callbacks are requested on the main queue; the nonisolated
// protocol methods hop back onto the main actor with
// `MainActor.assumeIsolated`, matching the pattern in SlothDiscovery.

import Foundation
import Observation
import CoreBluetooth
import CoreMotion
import CoreLocation
import SlothCore

/// Lock-guarded, Sendable mirror of the post's latest snapshot lines.
/// `PostService` calls its getter from the socket queue; the
/// coordinator writes it from the main actor. Keeping it in its own
/// Sendable box means the socket callback never reaches into
/// main-actor state.
final class SnapshotMirror: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [Data] = []
    func set(_ new: [Data]) { lock.lock(); lines = new; lock.unlock() }
    func get() -> [Data] { lock.lock(); defer { lock.unlock() }; return lines }
}

@MainActor
@Observable
public final class SensorCoordinator: NSObject {

    // Observable surface for the Post settings / status UI.
    public private(set) var enabled = false
    public private(set) var serviceStatus = PostService.Status()
    public private(set) var identity: PostIdentity
    public private(set) var bleAuthorized = false
    public private(set) var contactCount = 0
    public private(set) var headingDeg: Double?
    public private(set) var fieldMagUT: Double?
    public private(set) var radioScanReason: String?
    public var shareLocation = false
    public var shareWiFi = true

    private let bootDate = Date()
    private var buffer = SensorBuffer()
    private var service: PostService?
    private let mirror = SnapshotMirror()

    private var central: CBCentralManager?
    private let motion = CMMotionManager()
    private let locationManager = CLLocationManager()
    private var heartbeatTimer: Timer?

    public init(identity: PostIdentity? = nil) {
        self.identity = identity ?? PostIdentity.loadOrCreate(
            defaultName: Self.deviceDefaultName())
        super.init()
    }

    // MARK: - Control

    public func enable() {
        guard !enabled else { return }
        enabled = true
        startService()
        startBLE()
        startMotion()
        startLocation()
        refreshWiFi()
        refreshRadioScan()
        pushHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    public func disable() {
        guard enabled else { return }
        enabled = false
        heartbeatTimer?.invalidate(); heartbeatTimer = nil
        central?.stopScan()
        motion.stopDeviceMotionUpdates()
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        service?.stop(); service = nil
        serviceStatus = PostService.Status()
    }

    public func rename(_ name: String) {
        identity.name = name
        identity.save()
        if enabled { pushHeartbeat() }
    }

    public func setRole(_ role: PostIdentity.Role) {
        identity.role = role
        identity.save()
        if enabled { pushHeartbeat() }
    }

    // MARK: - Periodic (runs on main via the heartbeat timer)

    private func tick() {
        sampleMotion()
        buffer.evictStaleContacts(now: nowTS(), ttl: 60)
        contactCount = buffer.contactCount
        refreshWiFi()
        pushHeartbeat()
        refreshSnapshotMirror()
    }

    private func pushHeartbeat() {
        emit(.iosPost(IOSPostEntry(
            ts: nowTS(), post: identity.id, name: identity.name,
            role: identity.role.rawValue, platform: Self.platformTag(),
            appVer: Self.appVersion(),
            battery: Self.batteryLevel(), charging: Self.isCharging(),
            uptimeS: Int(Date().timeIntervalSince(bootDate)))))
    }

    // MARK: - Emit

    private func emit(_ rec: SensorRecord) {
        buffer.record(rec)
        if let line = rec.jsonlLine() { service?.broadcast(line) }
    }

    private func refreshSnapshotMirror() {
        mirror.set(buffer.snapshotLines())
    }

    // MARK: - PostService

    private func startService() {
        refreshSnapshotMirror()
        let txt: [String: String] = [
            "post": identity.id,
            "role": identity.role.rawValue,
            "ver":  Self.appVersion(),
            "plat": Self.platformTag(),
        ]
        let mirror = self.mirror
        let svc = PostService(
            snapshotProvider: { mirror.get() },
            onStatus: { [weak self] status in self?.serviceStatus = status })
        service = svc
        svc.start(serviceName: identity.name, txt: txt)
    }

    // MARK: - BLE

    private func startBLE() {
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    // MARK: - Motion / heading

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
    }

    /// Pull the latest device-motion sample on the main actor (the
    /// heartbeat tick), avoiding a background push handler.
    private func sampleMotion() {
        guard let dm = motion.deviceMotion else { return }
        let f = dm.magneticField.field
        let mag = (f.x*f.x + f.y*f.y + f.z*f.z).squareRoot()
        let heading = dm.heading >= 0 ? dm.heading : nil
        headingDeg = heading ?? headingDeg
        fieldMagUT = mag
        emit(.imuSample(IMUSampleEntry(
            ts: nowTS(), post: identity.id, headingDeg: heading,
            fieldMagUT: mag, fieldX: f.x, fieldY: f.y, fieldZ: f.z,
            pitchDeg: dm.attitude.pitch * 180 / .pi,
            rollDeg: dm.attitude.roll * 180 / .pi,
            yawDeg: dm.attitude.yaw * 180 / .pi)))
    }

    // MARK: - Location

    private func startLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
        if shareLocation { locationManager.startUpdatingLocation() }
    }

    // MARK: - WiFi (joined network only)

    private func refreshWiFi() {
        guard shareWiFi else { return }
        CurrentWiFi.fetch { [weak self] ssid, bssid in
            guard let self else { return }
            self.emit(.wifiSelf(WiFiSelfEntry(
                ts: self.nowTS(), post: self.identity.id, ssid: ssid, bssid: bssid)))
            self.refreshSnapshotMirror()
        }
    }

    // MARK: - Private radio probe (best-effort)

    private func refreshRadioScan() {
        let result = PrivateRadioProbe.scan()
        radioScanReason = result.available ? nil : result.reason
        emit(.radioScan(RadioScanEntry(
            ts: nowTS(), post: identity.id, available: result.available,
            reason: result.reason, aps: result.aps)))
    }

    // MARK: - Helpers

    fileprivate func nowTS() -> Int { Int(Date().timeIntervalSince1970) }
}

// MARK: - CBCentralManagerDelegate

extension SensorCoordinator: CBCentralManagerDelegate {

    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let poweredOn = central.state == .poweredOn
        MainActor.assumeIsolated {
            bleAuthorized = poweredOn
            if poweredOn {
                self.central?.scanForPeripherals(withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager,
                                           didDiscover peripheral: CBPeripheral,
                                           advertisementData: [String: Any],
                                           rssi RSSI: NSNumber) {
        let addr = peripheral.identifier.uuidString
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map { $0.uuidString } ?? []
        let tx = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            emit(.bleContact(BLEContactEntry(
                ts: nowTS(), post: identity.id, addr: addr, addrType: "opaque",
                name: name, rssi: rssi, txPower: tx,
                services: services, vendor: nil, count: 1)))
            contactCount = buffer.contactCount
            refreshSnapshotMirror()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SensorCoordinator: CLLocationManagerDelegate {

    nonisolated public func locationManager(_ manager: CLLocationManager,
                                            didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading
        guard h >= 0 else { return }
        MainActor.assumeIsolated { headingDeg = h }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager,
                                            didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        let alt = loc.altitude, hacc = loc.horizontalAccuracy
        let course = loc.course >= 0 ? loc.course : nil
        let speed = loc.speed >= 0 ? loc.speed : nil
        MainActor.assumeIsolated {
            guard shareLocation else { return }
            emit(.geoFix(GeoFixEntry(
                ts: nowTS(), post: identity.id, lat: lat, lon: lon,
                altM: alt, hAccM: hacc, courseDeg: course, speedMPS: speed)))
            refreshSnapshotMirror()
        }
    }
}
