// ConnectionCoordinator — view-local glue between the editable URI
// field, the saved `ConnectionProfile`, and the `SlothStore`'s stream
// consumer. The store owns connection state and the records; this
// type just owns the active client `Task` and the URI buffer the
// user is currently editing.

import Foundation
import Observation
import SlothCore

@MainActor
@Observable
final class ConnectionCoordinator {

    var profileURI: String
    var parseError: String?

    private var task: Task<Void, Never>?
    private let client: SlothClient
    private let store: SlothStore

    init(store: SlothStore, client: SlothClient = SlothClient()) {
        self.store = store
        self.client = client
        self.profileURI = ConnectionProfile.load()?.uri ?? "tcp:host.tailnet:7777"
    }

    func connect() {
        guard let profile = ConnectionProfile(uri: profileURI) else {
            parseError = "Invalid URI — expected tcp:HOST:PORT"
            return
        }
        profile.save()
        parseError = nil
        disconnect()
        let stream = client.records(for: profile)
        task = Task { [store] in
            await store.ingest(stream: stream)
        }
    }

    func disconnect() {
        task?.cancel()
        task = nil
    }
}
