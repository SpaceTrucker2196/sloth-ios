// Device-facing helpers for SensorCoordinator. UIKit lives here (the
// SlothCore package stays UIKit-free), kept out of the main file so
// the sensor logic reads cleanly.

import Foundation
import UIKit

extension SensorCoordinator {

    static func deviceDefaultName() -> String {
        UIDevice.current.name   // e.g. "Jeff's iPhone"; operator can rename
    }

    static func platformTag() -> String {
        UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
    }

    static func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v)+\(b)"
    }

    static func batteryLevel() -> Double? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : Double(level)
    }

    static func isCharging() -> Bool? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        switch UIDevice.current.batteryState {
        case .charging, .full: return true
        case .unplugged:       return false
        default:               return nil
        }
    }
}
