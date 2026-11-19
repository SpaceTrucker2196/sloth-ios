// ConnectionCoordinator — owns the connect-loop: pulls the active
// profile from `ProfileStore`, runs `SlothStore.ingest(stream:)`, and
// on each disconnect waits `Reconnector` before reconnecting. Cancels
// cleanly when the owning Task is cancelled (e.g. on `.background`).
//
// The URI field in `ConnectionBar` binds to `draftURI` — the user can
// edit it, hit Connect, and the coordinator parses + persists it as
// the active profile.

import Foundation
import Observation
import SlothCore

@MainActor
@Observable
final class ConnectionCoordinator {

    /// What the URI field shows. Mirrors the active profile's URI on
    /// load; the user can edit and hit Connect to commit.
    var draftURI: String
    var parseError: String?

    private var task: Task<Void, Never>?
    private var rfTask: Task<Void, Never>?
    /// The profile the running loops dial. A switch to another one
    /// reconnects (#18); a write that keeps this one active does not.
    private var connectedID: UUID?
    private let client:        SlothClient
    private let store:         SlothStore
    private let profileStore:  ProfileStore
    private let log:           SlothLog

    init(
        store:        SlothStore,
        profileStore: ProfileStore,
        log:          SlothLog,
        client:       SlothClient = SlothClient()
    ) {
        self.store        = store
        self.profileStore = profileStore
        self.log          = log
        self.client       = client
        self.draftURI     = profileStore.activeProfile?.profile.uri
                          ?? ConnectionProfile.load()?.uri
                          ?? "tcp:host.tailnet:8765"
    }

    func loadActiveIntoDraft() {
        if let p = profileStore.activeProfile?.profile {
            draftURI = p.uri
        }
    }

    /// The active profile changed (Settings → Profiles, #18): drop the
    /// old sensor's stream and its records, then dial the new one.
    /// Records of two sensors must never mix under one name.
    func switchToActive() {
        loadActiveIntoDraft()
        guard let id = profileStore.activeID, id != connectedID else { return }
        log.info("net", "profile switched — reconnecting")
        disconnect()
        store.reset()
        connect()
    }

    /// User-initiated connect. Parses the draft URI; if it's new,
    /// adds it as a profile and selects it active. Then starts the
    /// connect-retry loop.
    func connect() {
        guard let profile = ConnectionProfile(uri: draftURI) else {
            parseError = "Invalid URI — expected tcp:HOST:PORT"
            return
        }
        parseError = nil

        // Commit to ProfileStore if the URI is new; otherwise leave
        // the existing labelled profile alone (operator may have a
        // friendly name on it).
        let active = profileStore.activeProfile
        if active?.profile != profile {
            if let existing = profileStore.profiles.first(where: { $0.profile == profile }) {
                profileStore.setActive(existing.id)
            } else {
                let added = profileStore.add(name: profile.host, profile: profile)
                profileStore.setActive(added.id)
            }
        }
        // Also keep the legacy single-profile key in sync for any
        // tool still reading it.
        profile.save()
        connectedID = profileStore.activeID

        disconnect()
        let reconnector = Reconnector()
        task = Task { [weak self] in
            await self?.runConnectLoop(profile: profile, reconnector: reconnector)
        }
        // The sloth-rf stream, when the profile names one (#15). Its
        // own loop and backoff: either daemon can be down alone.
        if let rf = profileStore.activeProfile?.rf {
            let rfReconnector = Reconnector()
            rfTask = Task { [weak self] in
                await self?.runRFLoop(profile: rf, reconnector: rfReconnector)
            }
        }
    }

    /// User-initiated disconnect. Cancels the active task; the
    /// store's connection state lands in `.idle`.
    func disconnect() {
        task?.cancel()
        task = nil
        rfTask?.cancel()
        rfTask = nil
        store.markRFIdle()
    }

    // MARK: - Internals

    private func runRFLoop(profile: ConnectionProfile, reconnector: Reconnector) async {
        log.info("net", "rf stream: connecting to \(profile.uri)")
        while !Task.isCancelled {
            let before = store.rfRecordsReceived
            await store.ingest(rfStream: client.records(for: profile))
            // Back off from 1 s to 30 s while refused; start over only
            // after an attempt that actually delivered records.
            if store.rfRecordsReceived > before { await reconnector.reset() }
            if Task.isCancelled { break }
            if let err = store.rfLastError { log.warn("net", "rf stream: \(err)") }
            do {
                try await reconnector.waitForNextAttempt()
            } catch {
                break
            }
        }
    }

    private func runConnectLoop(profile: ConnectionProfile, reconnector: Reconnector) async {
        log.info("net", "connect requested for \(profile.uri)")
        // Capture `log` for the @Sendable mismatch callback so the
        // SlothLog can record the misconfiguration without crossing
        // a non-Sendable closure boundary.
        let log = self.log
        while !Task.isCancelled {
            let before = store.recordsReceived
            let stream = client.records(
                for: profile,
                onWireFormatMismatch: { fmt in
                    Task { @MainActor in
                        log.error(
                            "net",
                            "Producer is emitting \(fmt.displayName), not JSONL — set sloth's --out-format jsonl. iOS only parses JSONL."
                        )
                    }
                }
            )
            await store.ingest(stream: stream)
            if store.recordsReceived > before { await reconnector.reset() }
            log.info("net", "stream ended in state \(store.connectionState)")
            if Task.isCancelled { break }
            do {
                let delay = await reconnector.peekDelay
                log.warn("net", "reconnecting in \(Int(delay))s")
                try await reconnector.waitForNextAttempt()
            } catch {
                log.info("net", "reconnect cancelled")
                break
            }
        }
    }
}
