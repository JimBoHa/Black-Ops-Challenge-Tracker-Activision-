import SwiftUI

struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @Environment(ChallengeStore.self) private var store
    @State private var token = ""
    @State private var showingToken = false

    var body: some View {
        Form {
            Section("Activision") {
                switch account.state {
                case .disconnected:
                    Label("Not connected", systemImage: "person.crop.circle.badge.xmark").foregroundStyle(.secondary)
                case .connected(let name):
                    Label(name, systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                case .syncing:
                    HStack { ProgressView(); Text("Checking Activision session…") }
                case .unavailable(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }

            Section("Secure session") {
                tokenField
                Toggle("Show token", isOn: $showingToken)
                Button("Save and connect") { Task { await account.connect(ssoToken: token); token = "" } }.disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Never enter your Activision password. Session token stays in this device's Keychain and is never committed or logged.").font(.caption).foregroundStyle(.secondary)
            }

            Section("Data") {
                if let persistenceError = store.persistenceError {
                    Label(persistenceError, systemImage: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
                Button("Retry sync") { Task { await account.sync() } }
                Button("Restore sample tracker data") { store.resetSampleData() }
                Button("Disconnect", role: .destructive) { account.disconnect() }
            }

            Section("Live-sync status") {
                Text("Activision currently provides no supported public endpoint for BO7 camo, calling-card, daily, or weekly challenge progress. Offline/manual tracking works; live progress sync requires authorized API access from Activision.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ACCOUNT")
    }

    @ViewBuilder
    private var tokenField: some View {
#if os(iOS)
        if showingToken {
            TextField("SSO token", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } else {
            SecureField("SSO token", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
#else
        if showingToken { TextField("SSO token", text: $token) }
        else { SecureField("SSO token", text: $token) }
#endif
    }
}
