// Multilateration — solve a contact's probable position from several
// posts that each heard it, given each post's position and an
// estimated range (from RSSI). This is what turns "two posts both
// hear device X" into a point on the radar.
//
// Ranges from RSSI are noisy, so this is a best-fit, not a fix:
//   * 3+ anchors → linear least-squares (over-determined, one point).
//   * exactly 2 anchors → the two range circles; their intersection
//     if they cross, else the coarse point on the baseline weighted
//     by the two ranges. slothweb shows this case as "coarse".
//   * <2 anchors → nil (a single post cannot place a bearing).

import Foundation

public enum Multilateration {

    public struct Anchor: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public let r: Double   // estimated range to the contact, metres
        public init(x: Double, y: Double, r: Double) {
            self.x = x; self.y = y; self.r = max(0, r)
        }
    }

    public struct Fix: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public let anchors: Int
        public let coarse: Bool   // true for the 2-anchor fallback
        public init(x: Double, y: Double, anchors: Int, coarse: Bool) {
            self.x = x; self.y = y; self.anchors = anchors; self.coarse = coarse
        }
    }

    public static func solve(_ anchors: [Anchor]) -> Fix? {
        switch anchors.count {
        case ..<2: return nil
        case 2:    return solveTwo(anchors[0], anchors[1])
        default:   return solveLeastSquares(anchors)
        }
    }

    // MARK: - 3+ anchors: linear least squares

    private static func solveLeastSquares(_ a: [Anchor]) -> Fix? {
        // Subtract the reference equation (index 0) from each other to
        // linearise: for i>0,
        //   2(x0-xi)x + 2(y0-yi)y = ri² - r0² - (xi²+yi²) + (x0²+y0²)
        let a0 = a[0]
        var sxx = 0.0, sxy = 0.0, syy = 0.0, sxb = 0.0, syb = 0.0
        for i in 1..<a.count {
            let ai = a[i]
            let c1 = 2 * (a0.x - ai.x)
            let c2 = 2 * (a0.y - ai.y)
            let rhs = ai.r*ai.r - a0.r*a0.r
                    - (ai.x*ai.x + ai.y*ai.y) + (a0.x*a0.x + a0.y*a0.y)
            sxx += c1*c1; sxy += c1*c2; syy += c2*c2
            sxb += c1*rhs; syb += c2*rhs
        }
        let det = sxx*syy - sxy*sxy
        guard abs(det) > 1e-9 else { return nil }   // collinear anchors
        let x = ( syy*sxb - sxy*syb) / det
        let y = (-sxy*sxb + sxx*syb) / det
        return Fix(x: x, y: y, anchors: a.count, coarse: false)
    }

    // MARK: - 2 anchors: circle intersection or coarse baseline

    private static func solveTwo(_ a: Anchor, _ b: Anchor) -> Fix? {
        let dx = b.x - a.x, dy = b.y - a.y
        let d = (dx*dx + dy*dy).squareRoot()
        guard d > 1e-6 else {
            // Co-located anchors can't triangulate; sit at that point.
            return Fix(x: a.x, y: a.y, anchors: 2, coarse: true)
        }
        // Distance along the baseline to the radical line.
        let aDist = (a.r*a.r - b.r*b.r + d*d) / (2*d)
        let ux = dx/d, uy = dy/d                 // unit baseline vector
        let px = a.x + aDist*ux, py = a.y + aDist*uy   // foot on baseline
        let h2 = a.r*a.r - aDist*aDist
        if h2 >= 0 {
            // Circles cross: pick one intersection deterministically
            // (offset to the left of the baseline). Without a third
            // anchor the mirror point is equally valid; this is coarse.
            let h = h2.squareRoot()
            return Fix(x: px - h*uy, y: py + h*ux, anchors: 2, coarse: true)
        }
        // Circles don't reach: the foot on the baseline is the best
        // single guess.
        return Fix(x: px, y: py, anchors: 2, coarse: true)
    }
}
