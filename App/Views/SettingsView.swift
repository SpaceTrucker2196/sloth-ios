// SettingsView — M8. Manage saved connection profiles.
//
// Presented as a sheet from the connection bar. Lists every
// `NamedProfile` in `ProfileStore` with a tap-to-activate / swipe-
// to-delete affordance. The active profile is marked. An "Add
// profile" row opens a `ProfileEditor` sheet for a fresh entry; tap
// on an existing row's pencil opens the same sheet pre-filled.

import SwiftUI
import SlothCore

struct SettingsView: View {

    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss)         private var dismiss

    @State private var editingProfile: NamedProfile?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Profiles") {
                    if profiles.profiles.isEmpty {
                        Text("No saved profiles yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(profiles.profiles) { p in
                            row(for: p)
                        }
                    }
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add profile", systemImage: "plus.circle")
                    }
                }

                Section {
                    Text("Profiles are the only thing this app persists to disk. " +
                         "Records (DNS, TLS, HTTP, alerts) never leave memory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isAdding) {
                ProfileEditor(mode: .add)
            }
            .sheet(item: $editingProfile) { p in
                ProfileEditor(mode: .edit(p))
            }
        }
    }

    private func row(for p: NamedProfile) -> some View {
        Button {
            profiles.setActive(p.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.callout)
                    Text(p.profile.uri)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if p.id == profiles.activeID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                profiles.remove(p.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingProfile = p
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

// MARK: - ProfileEditor

struct ProfileEditor: View {

    enum Mode: Equatable {
        case add
        case edit(NamedProfile)

        var existing: NamedProfile? {
            if case .edit(let p) = self { return p }
            return nil
        }
    }

    let mode: Mode

    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss)         private var dismiss

    @State private var name: String = ""
    @State private var uri:  String = "tcp:host.tailnet:7777"
    @State private var parseError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. home sloth", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("Endpoint") {
                    TextField("tcp:HOST:PORT", text: $uri)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .font(.body.monospaced())
                    if let err = parseError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .add ? "New profile" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.isEmpty)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        if case .edit(let p) = mode {
            name = p.name
            uri  = p.profile.uri
        }
    }

    private func save() {
        guard let profile = ConnectionProfile(uri: uri) else {
            parseError = "Invalid URI — expected tcp:HOST:PORT"
            return
        }
        switch mode {
        case .add:
            profiles.add(name: name, profile: profile)
        case .edit(let original):
            profiles.update(NamedProfile(id: original.id, name: name, profile: profile))
        }
        dismiss()
    }
}
