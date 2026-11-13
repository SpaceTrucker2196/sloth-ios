// CurrentWiFi — reads the SSID/BSSID of the one network the device is
// joined to, the only WiFi fact Apple exposes to a sandboxed app.
//
// `NEHotspotNetwork.fetchCurrent` needs the "Access WiFi Information"
// capability AND (iOS 13+) either an active location permission or
// the app being the current VPN/hotspot-config owner. Without the
// entitlement this returns nil — the post then reports `wifi_self`
// with null fields, which is honest: we don't know. This is NOT a
// nearby-AP scan (that is `PrivateRadioProbe`); it is only the joined
// network.

import Foundation
import NetworkExtension

enum CurrentWiFi {

    /// Fetches the joined network's SSID/BSSID, or nils if iOS won't
    /// disclose them. Completion is delivered on the main actor.
    static func fetch(_ completion: @escaping @Sendable @MainActor (String?, String?) -> Void) {
        NEHotspotNetwork.fetchCurrent { network in
            let ssid = network?.ssid
            let bssid = network?.bssid
            Task { @MainActor in
                completion(ssid, bssid)
            }
        }
    }
}
