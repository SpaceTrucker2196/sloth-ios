// GeoProjection — flat-earth local ENU projection, good for the short
// baselines a sensor fleet spans (metres to a few km). Converts a
// latitude/longitude to east/north metre offsets from an origin, so
// posts and triangulated contacts can be placed on the radar's metre
// grid. For fleet distances the equirectangular approximation error
// is negligible; this is not a geodesy library.

import Foundation

public enum GeoProjection {

    /// Mean Earth radius, metres.
    public static let earthRadius: Double = 6_371_000

    /// East/north metres of (`lat`, `lon`) relative to (`lat0`,
    /// `lon0`). x grows east, y grows north. The origin maps to
    /// (0, 0).
    public static func enu(
        lat: Double, lon: Double, lat0: Double, lon0: Double
    ) -> (x: Double, y: Double) {
        let dLat = (lat - lat0) * .pi / 180
        let dLon = (lon - lon0) * .pi / 180
        let x = dLon * cos(lat0 * .pi / 180) * earthRadius
        let y = dLat * earthRadius
        return (x, y)
    }
}
