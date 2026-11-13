# Post view

**Role**: operator control for running *this* device as a sloth sensor
post. The producer-side counterpart to the connection bar.

**Data / model**: `SensorCoordinator` (environment object). Toggling
"Serve as sloth post" starts the sensor collectors (CoreBluetooth,
CoreMotion, CoreLocation, NEHotspotNetwork, the private-radio probe)
and the `PostService` listener; toggling off tears them all down.

**Layout**:
- **Serve toggle** + a footer stating the read-only, foreground-only
  contract.
- **STATUS** (when serving): listening state, port, number of hubs
  reading, BLE scan state, contact count, heading, magnetic field,
  and — honestly — why the AP scan is unavailable.
- **IDENTITY**: editable post name, role (mobile / roaming / fixed),
  and the first 8 chars of the post UUID.
- **SHARE**: per-signal opt-ins — joined WiFi (on), coarse location
  (off by default).

**Honesty rule**: every status row reflects what iOS actually
granted. A denied permission shows as off / unavailable with a
reason; the matching record then carries nulls rather than fabricated
values. See [[post-protocol]] "iOS reality".

**Lifecycle**: backgrounding the app disables the post (MISSION
§2(5)). Nothing is persisted but the post identity.
