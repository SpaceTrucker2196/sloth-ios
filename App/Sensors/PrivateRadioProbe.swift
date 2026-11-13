// PrivateRadioProbe — best-effort nearby-WiFi-AP scan via Apple's
// private MobileWiFi framework. This is the "try the private APIs"
// path: it exists because the test build ships off-store, so there is
// no App Review to forbid it. It still runs inside the iOS sandbox,
// and that is the wall.
//
// Honest status: on a stock (non-jailbroken) device this returns
// `available: false`. The private `Apple80211` / `MobileWiFi` scan
// entry points require the Apple-signed `com.apple.wifi.manager-access`
// entitlement. A dev/ad-hoc/TestFlight signature cannot carry it, so
// `WiFiManagerClientCreate` / `Apple80211Open` either fail to resolve
// under the sandbox or return a non-zero error before any scan runs.
// A full nearby-AP capture needs a jailbroken device or an
// Apple-internal signing identity; this probe reports exactly which
// wall it hit instead of fabricating access points it never saw.
//
// The probe is deliberately non-invasive: it checks whether the
// private framework can even be loaded and its scan symbol resolved.
// It does NOT invoke the scan — invoking a privileged symbol without
// the entitlement risks a sandbox kill, and a crash is a worse
// failure mode than an honest "unavailable". If a future entitled or
// jailbroken build wants the real scan, wire the resolved symbols
// here behind the same `available` contract.

import Foundation
import SlothCore

enum PrivateRadioProbe {

    struct Result {
        let available: Bool
        let reason: String?
        let aps: [RadioScanEntry.ScannedAP]
    }

    // Private framework path + the symbol a real scan would need.
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi"
    private static let scanSymbol = "WiFiManagerClientCreate"

    static func scan() -> Result {
        guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
            return Result(
                available: false,
                reason: "private WiFi framework not loadable in this sandbox",
                aps: [])
        }
        defer { dlclose(handle) }

        guard dlsym(handle, scanSymbol) != nil else {
            return Result(
                available: false,
                reason: "MobileWiFi loaded but \(scanSymbol) not resolvable",
                aps: [])
        }

        // Symbol resolved, but invoking it without the
        // com.apple.wifi.manager-access entitlement is refused by the
        // sandbox. Report the real blocker rather than calling it.
        return Result(
            available: false,
            reason: "blocked: com.apple.wifi.manager-access entitlement required "
                  + "(needs jailbreak or Apple-internal signing)",
            aps: [])
    }
}
