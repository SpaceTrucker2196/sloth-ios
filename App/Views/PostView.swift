// PostView — operator control for running this device as a sloth
// sensor post. Flipping "Serve as sloth post" starts the sensor
// collectors and the read-only stream server; a sloth (or another
// sloth-ios) on the tailnet then discovers and reads it.
//
// Every row is honest about what iOS actually grants: BLE scan state,
// whether the joined-WiFi read worked, and why the private radio scan
// is unavailable. Nothing is faked.

import SwiftUI
import SlothCore

struct PostView: View {

    @Environment(SensorCoordinator.self) private var post

    var body: some View {
        @Bindable var post = post
        Form {
            Section {
                Toggle("Serve as sloth post", isOn: Binding(
                    get: { post.enabled },
                    set: { $0 ? post.enable() : post.disable() }))
                    .tint(.phosphorBright)
            } footer: {
                Text("Streams this device's sensors to any sloth on the tailnet. Read-only: the post never accepts commands. Foreground only.")
            }

            if post.enabled {
                Section("STATUS") {
                    row("Listening", post.serviceStatus.listening ? "yes" : "no")
                    if let p = post.serviceStatus.port { row("Port", "\(p)") }
                    row("Hubs reading", "\(post.serviceStatus.clientCount)")
                    row("BLE scan", post.bleAuthorized ? "on" : "off / denied")
                    row("Contacts", "\(post.contactCount)")
                    if let h = post.headingDeg { row("Heading", "\(Int(h))°") }
                    if let f = post.fieldMagUT { row("Mag field", String(format: "%.1f µT", f)) }
                    if let reason = post.radioScanReason {
                        row("AP scan", "unavailable")
                        Text(reason).font(.caption2).foregroundStyle(Color.phosphorDim)
                    }
                }
            }

            Section("IDENTITY") {
                LabeledContent("Name") {
                    TextField("post name", text: Binding(
                        get: { post.identity.name },
                        set: { post.rename($0) }))
                        .multilineTextAlignment(.trailing)
                }
                Picker("Role", selection: Binding(
                    get: { post.identity.role },
                    set: { post.setRole($0) })) {
                    Text("Mobile").tag(PostIdentity.Role.mobile)
                    Text("Roaming").tag(PostIdentity.Role.roaming)
                    Text("Fixed").tag(PostIdentity.Role.fixed)
                }
                row("Post ID", String(post.identity.id.prefix(8)))
            }

            Section("SHARE") {
                Toggle("Joined WiFi (SSID/BSSID)", isOn: $post.shareWiFi)
                    .tint(.phosphorBright)
                Toggle("Location (coarse GPS)", isOn: $post.shareLocation)
                    .tint(.phosphorBright)
            }
        }
        .navigationTitle("Post")
    }

    private func row(_ k: String, _ v: String) -> some View {
        LabeledContent(k) {
            Text(v).foregroundStyle(Color.phosphorTeal).monospacedDigit()
        }
    }
}
