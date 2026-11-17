import XCTest
@testable import SlothCore

// RF records from sloth-rf (#14). Field names from sloth
// docs/wiki/jsonl-schema.md at jsonl_version 2.3.0.
final class RFRecordTests: XCTestCase {

    private func decode(_ json: String) throws -> SlothRecord {
        try JSONDecoder().decode(SlothRecord.self, from: Data(json.utf8))
    }

    func testDecodeGNSSFix() throws {
        let r = try decode(#"{"type":"gnss_fix","ts":5,"src":"gpsd:127.0.0.1:2947","fix_ts":5,"mode":3,"status":1,"nsat":14,"usat":9,"hdop":0.9,"vdop":1.2,"pdop":1.5,"lat":44.9777,"lon":-93.265,"alt_m":256.1,"time_off_ms":120,"jam":12,"tpv_count":400}"#)
        guard case .gnssFix(let f) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(f.modeName, "3D")
        XCTAssertEqual(f.usat, 9)
        XCTAssertEqual(f.altM, 256.1)
        XCTAssertEqual(r.typeTag, "gnss_fix")
    }

    func testDecodeAircraftWithEmergencyAndMissingFigures() throws {
        let r = try decode(#"{"type":"adsb_aircraft","ts":7,"hex":"a1b2c3","non_icao":0,"state":"live","src":"beast:127.0.0.1:30005","source_type":"adsb_icao","flight":"N123AB","squawk":"7700","category":"A1","emergency":"general","on_ground":0,"alt_band":4,"first_seen":1,"last_seen":7}"#)
        guard case .adsbAircraft(let a) = r else { return XCTFail("got \(r)") }
        XCTAssertTrue(a.hasEmergency)
        XCTAssertNil(a.altBaro)
        XCTAssertEqual(a.squawk, "7700")
    }

    func testAircraftEmergencyNoneOrEmptyIsNotAnEmergency() {
        XCTAssertFalse(ADSBAircraftEntry(ts: 1, hex: "a", emergency: "none").hasEmergency)
        XCTAssertFalse(ADSBAircraftEntry(ts: 1, hex: "a", emergency: "").hasEmergency)
        XCTAssertFalse(ADSBAircraftEntry(ts: 1, hex: "a").hasEmergency)
    }

    func testDecodeAPRSStation() throws {
        let r = try decode(#"{"type":"aprs_station","ts":9,"call":"KD0ABC-9","state":"live","src":"file:/var/log/direwolf.csv","first_seen":1,"last_seen":9,"packets":14,"heard_direct":1,"symbol":"/>","lat":44.9,"lon":-93.2,"comment":"mobile"}"#)
        guard case .aprsStation(let s) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(s.id, "KD0ABC-9")
        XCTAssertEqual(s.packets, 14)
    }

    func testRTL433IdDecodesAsNumberOrText() throws {
        let n = try decode(#"{"type":"rtl433_device","ts":3,"src":"file:/x","model":"Acurite-Tower","id":1234,"first_seen":1,"last_seen":3,"msgs":8,"other_keys":2,"channel":"A","temperature_C":21.4,"humidity":48,"battery_ok":1}"#)
        guard case .rtl433Device(let d) = n else { return XCTFail("got \(n)") }
        XCTAssertEqual(d.id, "Acurite-Tower/1234")
        XCTAssertEqual(d.temperatureC, 21.4)
        XCTAssertNil(d.temperatureF)

        let t = try decode(#"{"type":"rtl433_device","ts":3,"model":"Oregon","id":"0x1f","channel":2,"temperature_F":70.1}"#)
        guard case .rtl433Device(let e) = t else { return XCTFail("got \(t)") }
        XCTAssertEqual(e.deviceID, "0x1f")
        XCTAssertEqual(e.channel, "2")
        XCTAssertEqual(e.temperatureF, 70.1)
    }

    func testDecodeVictronWithAC() throws {
        let r = try decode(#"{"type":"victron_device","ts":4,"src":"file:/run/sloth-va.jsonl","mac":"c0:ff:ee:00:00:01","model":"Phoenix Inverter","record":"inverter","first_seen":1,"last_seen":4,"readings":3,"sessions":0,"rssi":-71,"values_src":"readout","voltage_v":13.21,"ac_voltage_v":120.4,"ac_current_a":1.2,"ac_apparent_va":144,"device_state":9}"#)
        guard case .victronDevice(let v) = r else { return XCTFail("got \(r)") }
        XCTAssertEqual(v.acVoltageV, 120.4)
        XCTAssertEqual(v.deviceState, "9")
    }
}

@MainActor
final class RFStoreTests: XCTestCase {

    func testGoneRemovesAircraftAndStation() {
        let store = SlothStore()
        store.ingestRF(.adsbAircraft(ADSBAircraftEntry(ts: 1, hex: "abc")))
        store.ingestRF(.aprsStation(APRSStationEntry(ts: 1, call: "N0CALL")))
        XCTAssertEqual(store.aircraft.count, 1)
        store.ingestRF(.adsbAircraft(ADSBAircraftEntry(ts: 2, hex: "abc", state: "gone")))
        store.ingestRF(.aprsStation(APRSStationEntry(ts: 2, call: "N0CALL", state: "gone")))
        XCTAssertTrue(store.aircraft.isEmpty)
        XCTAssertTrue(store.aprsStations.isEmpty)
    }

    func testTablesKeyOnNaturalKeyAndReset() {
        let store = SlothStore()
        store.ingestRF(.rtl433Device(RTL433DeviceEntry(ts: 1, model: "M", deviceID: "1", temperatureC: 20)))
        store.ingestRF(.rtl433Device(RTL433DeviceEntry(ts: 2, model: "M", deviceID: "1", temperatureC: 21)))
        store.ingestRF(.victronDevice(VictronDeviceEntry(ts: 1, mac: "aa", voltageV: 13)))
        store.ingestRF(.gnssFix(GNSSFixEntry(ts: 1, mode: 3)))
        XCTAssertEqual(store.rtl433Devices.count, 1)
        XCTAssertEqual(store.rtl433Devices["M/1"]?.temperatureC, 21)
        XCTAssertEqual(store.gnssFix?.mode, 3)
        store.reset()
        XCTAssertNil(store.gnssFix)
        XCTAssertTrue(store.rtl433Devices.isEmpty)
        XCTAssertTrue(store.victronDevices.isEmpty)
    }

    func testAircraftOrderEmergencyThenAltitude() {
        let rows = [
            ADSBAircraftEntry(ts: 1, hex: "low",  altBaro: 3000),
            ADSBAircraftEntry(ts: 1, hex: "none"),
            ADSBAircraftEntry(ts: 1, hex: "high", altBaro: 36000),
            ADSBAircraftEntry(ts: 1, hex: "sos",  emergency: "general", altBaro: 1000),
        ]
        XCTAssertEqual(RFRoster.aircraft(rows).map(\.hex), ["sos", "high", "low", "none"])
    }
}
