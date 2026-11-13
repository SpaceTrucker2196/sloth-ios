# Radar view

**Role**: the fleet's-eye view. A phosphor PPI (plan-position
indicator) scope plotting every BLE contact that every online sloth
post currently hears, over a roster of the posts feeding it.

**Data**: `FleetStore` (via `FleetCoordinator`). The coordinator
browses `_sloth-post._tcp.`, opens a read-only `PostClient` per post,
and ingests `SensorRecord`s. See [[post-protocol]].

**Layout**:
- A circular scope with three range rings and cross-hairs. Centre =
  point-blank RSSI; rim = the audible floor.
- One blip per contact, placed by `FleetRadar` geometry: range from
  RSSI, angle from the contact's stable id hash (or a reported
  bearing when a post supplies one).
- Blip hue heat-grades by RSSI: dim grey (far) → teal → bright
  phosphor → amber (very close).
- Below the scope, the POST roster: a dot (bright = online, dim =
  stale past the offline TTL), the post name, its live contact count,
  and heading when known.

**Interactions**: read-only. The view issues no commands. It refreshes
once a second off a timer; `fleetBlips(now:)` drops offline posts.

**Fleet rule**: a blip id is namespaced `"<post>/<addr>"`, so two
posts hearing the same device show as two blips, each at its own
range — that overlap is the triangulation signal.
