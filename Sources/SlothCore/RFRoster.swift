// RFRoster — ordering for the RF view (sloth-rf tables). Pure, so the
// rules are tested in SlothCoreTests rather than read off a screen.

import Foundation

public enum RFRoster {

    /// Emergencies first (an emergency squawk is the one RF fact worth
    /// paging on), then airborne by altitude high→low, then on-ground
    /// and unknown-altitude, then by hex for a stable order.
    public static func aircraft(_ rows: some Collection<ADSBAircraftEntry>) -> [ADSBAircraftEntry] {
        rows.sorted { a, b in
            if a.hasEmergency != b.hasEmergency { return a.hasEmergency }
            let aa = a.altBaro ?? -.infinity, ba = b.altBaro ?? -.infinity
            if aa != ba { return aa > ba }
            return a.hex < b.hex
        }
    }

    /// Satellites in the solution first, then strongest C/N0 (an
    /// untracked one last), then by label for a stable order.
    public static func satellites(_ rows: some Collection<GNSSSatEntry>) -> [GNSSSatEntry] {
        rows.sorted { a, b in
            if a.isUsed != b.isUsed { return a.isUsed }
            let ca = a.cn0 ?? -1, cb = b.cn0 ?? -1
            if ca != cb { return ca > cb }
            return a.id < b.id
        }
    }

    /// Newest heard first; the key breaks ties.
    public static func newest<T: Identifiable>(
        _ rows: some Collection<T>, stamp: (T) -> Int
    ) -> [T] where T.ID == String {
        rows.sorted { a, b in
            let sa = stamp(a), sb = stamp(b)
            return sa != sb ? sa > sb : a.id < b.id
        }
    }
}
