# RF

The sloth-rf daemon's tables. Since sloth jsonl 2.0.0 (#216) these
records are on sloth-rf's own data socket only, so the view fills
only when the active profile has an **RF stream** endpoint (#15).

## Data source

| Record | Key | Store |
|---|---|---|
| `gnss_fix` | singleton | `SlothStore.gnssFix` |
| `adsb_aircraft` | `hex` | `SlothStore.aircraft` (a `gone` record removes the row) |
| `aprs_station` | `call` | `SlothStore.aprsStations` (`gone` removes) |
| `rtl433_device` | `model` + `id` | `SlothStore.rtl433Devices` (no `gone`; sloth evicts) |
| `victron_device` | `mac` | `SlothStore.victronDevices` (no `gone`) |

Not yet read: `gnss_sky`, `gnss_sat`, `aprs_packet` (stay `.unknown`).

## Layout

iPhone: an **RF** tab. iPad: an `AIRCRAFT | RF` band above Packets;
either title drills into the full view.

```
GNSS            3D  9 sats used  HDOP 0.9
                44.97770, -93.26500
Aircraft · 12   ⛔ N123AB  a1b2c3 · sq 7700 · general     4500 ft
                SWA1234    a8f00e · sq 3412              36000 ft
APRS · 3        KD0ABC-9   mobile          direct   14 pkts
Sub-GHz · 5     Acurite-Tower  id 1234 · ch A      21.4°C 48%
Victron · 1     SmartShunt  c0:ff:ee:…             13.21 V 87%
```

Sections with no rows are hidden. With every table empty the view
says whether the RF stream is live or not configured.

## Ordering

`RFRoster` (SlothCore, tested): aircraft with an emergency first,
then altitude high → low, ground / unknown last. Other tables newest
`last_seen` first.

## Severity / colour

An ADS-B `emergency` other than `none` paints the row and the iPad
band title in `alertHotCrit`, with an octagon icon (shape, not hue
alone). GNSS `jam` ≥ 64 shows a warning label (≥ 128 crit). A
rtl_433 `battery_ok` under 0.5 shows a low-battery glyph.

## Units

Readings show in the unit sloth sent them in. rtl_433 temperatures
are never converted between °C and °F.

## Accessibility

Each row combines into one accessibility element. The low-battery
glyph has a spoken label.
