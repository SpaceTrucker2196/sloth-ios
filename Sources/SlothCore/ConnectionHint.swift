// ConnectionHint — turns a transport error into a sentence that says
// what to change on the sensor (#15).
//
// The common failure is "connection refused": the shipped sloth
// units serve only a unix socket, so nothing listens on TCP until
// the operator adds a TCP data socket. Naming the flag saves a round
// trip to the docs.

import Foundation
import Network

public enum ConnectionHint {

    /// The sensor-side flags that expose a daemon's stream on TCP.
    /// Same form for `sloth-wifi` and `sloth-rf`.
    public static let exposeFlags =
        "--data-socket tcp:0.0.0.0:PORT --data-socket-allow-remote"

    public static func describe(_ error: any Error) -> String {
        let base = error.localizedDescription
        guard isRefused(error) else { return base }
        return "Connection refused — nothing listens on that port. " +
               "On the sensor, add \(exposeFlags) to the daemon's args."
    }

    static func isRefused(_ error: any Error) -> Bool {
        if case .posix(.ECONNREFUSED)? = error as? NWError { return true }
        if let p = error as? POSIXError, p.code == .ECONNREFUSED { return true }
        return error.localizedDescription.localizedCaseInsensitiveContains("refused")
    }
}
