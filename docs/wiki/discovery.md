# Local-network discovery (Bonjour)

sloth-ios browses the local network for sloth instances over
Bonjour (mDNS) so an operator on the same LAN can pick a host
instead of typing a URI. This page captures both sides of the
contract.

## Service

| field        | value                          |
|--------------|--------------------------------|
| Service type | `_sloth._tcp.`                 |
| Port         | sloth's `--data-socket` port   |
| Domain       | `local.` (default)             |
| TXT (optional, future) | `version=<sloth-semver>`, `schema=<jsonl-schema-version>` |

The iOS side cares only about hostname + port. The TXT record is
displayed if present (e.g. "sloth 1.3.0" under the service name)
but isn't required.

## Producer side (sloth)

sloth must publish the service whenever it is bound to a TCP
data-socket (`sloth -o tcp:0.0.0.0:7777`). On Linux this is
typically done via Avahi (`avahi_entry_group_add_service`) or
directly via `mdnsd`; on macOS it's `dns-sd` /
`NSNetService.publish`.

Recommended service instance name: the system hostname (`gethostname()`),
optionally suffixed with a room or location tag. Example:
`"slothmac"` or `"living-room sloth"`.

The implementation request is tracked at
[`sloth#5`'s successor](https://github.com/SpaceTrucker2196/sloth/issues)
(file a new issue if it doesn't exist yet — title suggestion:
`[mdns] publish _sloth._tcp via Avahi when --data-socket is bound`).

## Consumer side (sloth-ios)

* `Sources/SlothCore/SlothDiscovery.swift` wraps `NetServiceBrowser`
  in an `@MainActor @Observable` class. Browse starts when the
  discovery sheet appears and stops on dismiss.
* `Sources/SlothCore/DiscoveredService` is the resolved record:
  `(id, name, hostname, port, txt)` + a derived `ConnectionProfile`.
* `App/Views/DiscoveryView.swift` is the sheet. Tap a row →
  `ProfileStore.add(name:profile:)` + `setActive(_:)` →
  `ConnectionCoordinator.connect()`.

### iOS Info.plist

Two keys are required for iOS 14+ to allow the browse:

```xml
<key>NSBonjourServices</key>
<array>
  <string>_sloth._tcp</string>
</array>
<key>NSLocalNetworkUsageDescription</key>
<string>Find sloth instances on your local network.</string>
```

Both are set via `project.yml` so xcodegen writes them into the
generated Info.plist.

## Why not Tailscale enumeration?

sloth typically runs on a tailnet, but Tailscale doesn't expose a
peer-list API to non-admin iOS apps. Bonjour works for the common
"both devices on the same WiFi" case; for remote tailnet access
the operator still falls back to typing a URI (or selecting a
saved profile). Future: a tap-to-share-URI mechanic from the
sloth CLI would close the remaining gap without adding a
dependency.

## Operator UX

* `ConnectionBar` has a `wifi.router` button next to the connect
  button — tap to open the discovery sheet directly.
* The ellipsis menu also lists "Discover…" alongside Profiles and
  Diagnostics.
* First-time browse triggers the iOS "Local Network" permission
  prompt. If the operator declines, the discovery sheet shows an
  empty browsing placeholder; they can still enter URIs by hand.
