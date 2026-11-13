# sloth sensor-post protocol

The contract a sloth-ios **post** meets a **hub** at. A hub is a sloth
instance or another sloth-ios acting as the fleet viewer. This is the
mirror image of sloth's own `--data-socket`: a one-way, newline-
delimited JSON stream, pulled by the consumer, authored by the
producer. Here the producer is the phone.

## Discovery

A post publishes a Bonjour service:

| Field   | Value                                             |
|---------|---------------------------------------------------|
| type    | `_sloth-post._tcp.`                               |
| name    | the operator-chosen post name                     |
| port    | OS-assigned (read from the resolved service)      |
| TXT     | `post=<uuid>` `role=mobile\|roaming\|fixed` `ver=<app>` `plat=ios\|ipados` |

A hub browses `_sloth-post._tcp.`, resolves each service to host +
port, and opens a TCP connection. A sloth instance should treat each
resolved post as a passive sensor family (see sloth issues #26 / #28);
sloth-ios's `FleetCoordinator` opens a `PostClient` per post.

## Transport

- TCP, newline-delimited UTF-8 JSON, one record per line (`\n`).
- One-way: the post **never reads** from the hub. No handshake, no
  auth, no verbs. Access control is the operator's (tailnet bind,
  Tailscale ACLs) — identical to sloth's data socket.
- On connect, the post bursts a **snapshot** (current identity + one
  of each latching record + every live BLE contact), then streams the
  live tail.
- Foreground only. Backgrounding the app closes the listener.

## Envelope

Every record shares sloth's envelope and adds `post`:

```json
{ "type": "<tag>", "ts": <unix-seconds>, "post": "<uuid>", ... }
```

## Record types

| type           | meaning                          | key fields |
|----------------|----------------------------------|------------|
| `ios_post`     | heartbeat + identity (every 5 s) | `name` `role` `platform` `app_ver` `battery` `charging` `uptime_s` |
| `ble_contact`  | one BLE advertiser heard         | `addr` (opaque id, not a MAC) `addr_type` `name` `rssi` `tx_power` `services[]` `count` |
| `imu_sample`   | compass + magnetometer + attitude| `heading_deg` `field_mag_uT` `field_x/y/z` `pitch_deg` `roll_deg` `yaw_deg` |
| `wifi_self`    | the one joined WiFi network      | `ssid` `bssid` `rssi` `band` (null unless entitled) |
| `geo_fix`      | coarse position (opt-in)         | `lat` `lon` `alt_m` `h_acc_m` `course_deg` `speed_mps` |
| `radio_scan`   | best-effort nearby-AP scan       | `available` `reason` `aps[]` |

### iOS reality

The sandbox gates what a post can actually observe:

- **`ble_contact`** — works. `addr` is iOS's opaque
  `CBPeripheral.identifier`, not a hardware MAC. Scan-only; the post
  never connects to a peer.
- **`imu_sample`** — works via CoreMotion / CoreLocation.
- **`wifi_self`** — only the joined network, and only with the "Access
  WiFi Information" entitlement + location permission. Otherwise the
  fields are null (honest "don't know").
- **`geo_fix`** — opt-in; off by default.
- **`radio_scan`** — a full nearby-AP scan needs the private
  `com.apple.wifi.manager-access` entitlement, which a dev / ad-hoc /
  TestFlight signature cannot carry. On a stock device this comes back
  `available: false` with the blocking reason. A jailbroken or
  Apple-internal-signed build could fill it; the field shape is ready.

## Privacy

Both sides are in-memory only (MISSION §2(6)). The only persisted
producer state is the post identity (`PostIdentity`): a random UUID
and a name in `UserDefaults`, rotatable to shed history.

## Reference

Producer: `Sources/SlothCore/SensorRecord.swift`,
`SensorBuffer.swift`, `PostService.swift`, `PostIdentity.swift`,
`App/Sensors/`. Consumer / fleet: `PostClient.swift`,
`FleetStore.swift`, `FleetRadar.swift`, `App/Sensors/FleetCoordinator.swift`.
