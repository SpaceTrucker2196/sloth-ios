// PeersView — manage the tailnet post addresses the fleet hub pulls
// directly. Bonjour finds posts on the local link; a post reporting
// home over cellular + Tailscale is reached by its address here
// (tcp:100.x.y.z:PORT).

import SwiftUI
import SlothCore

struct PeersView: View {
    let peers: PostPeerStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var badInput = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("tcp:100.x.y.z:PORT", text: $draft)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit(addDraft)
                        Button("Add", action: addDraft)
                            .disabled(draft.isEmpty)
                    }
                    if badInput {
                        Text("Not a valid tcp:HOST:PORT address.")
                            .font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("ADD TAILNET POST")
                } footer: {
                    Text("Bonjour finds posts on this network already. Add an address only for a post reached over Tailscale.")
                }

                Section("PULLED POSTS") {
                    if peers.peers.isEmpty {
                        Text("none").foregroundStyle(Color.phosphorDim)
                    }
                    ForEach(peers.peers, id: \.uri) { p in
                        Text(p.uri).font(.system(.body, design: .monospaced))
                    }
                    .onDelete { peers.remove(atOffsets: $0) }
                }
            }
            .navigationTitle("Fleet Peers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addDraft() {
        let ok = peers.add(uri: draft.trimmingCharacters(in: .whitespaces))
        badInput = !ok
        if ok { draft = "" }
    }
}
