// ConnectionHint — turns a transport error into a sentence that says
// what to change on the sensor (#15).
//
// The common failure is "connection refused": the shipped sloth
// units serve only a unix socket, so nothing listens on TCP until
// the operator adds a TCP data socket or a bridge in front of it.
// Kept short: it is shown in a toast with the stream and address in
// front (#20), and the old "add tcp:0.0.0.0" advice was wrong for a
// sensor that is served through a bridge.

import Foundation
import Network

public enum ConnectionHint {

    public static func describe(_ error: any Error) -> String {
        let base = error.localizedDescription
        guard isRefused(error) else { return base }
        return "refused — nothing listens on that port"
    }

    static func isRefused(_ error: any Error) -> Bool {
        if case .posix(.ECONNREFUSED)? = error as? NWError { return true }
        if let p = error as? POSIXError, p.code == .ECONNREFUSED { return true }
        return error.localizedDescription.localizedCaseInsensitiveContains("refused")
    }
}
