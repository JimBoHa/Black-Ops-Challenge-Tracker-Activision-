import Foundation
import Observation
import Security

enum SyncState: Equatable {
    case disconnected
    case connected(displayName: String)
    case syncing
    case unavailable(String)
}

@Observable
@MainActor
final class AccountStore {
    private(set) var state: SyncState = .disconnected
    private(set) var lastSync: Date?
    private let keychain: any TokenStoring
    private let service: any ActivisionServicing

    init(
        keychain: any TokenStoring = KeychainStore(),
        service: any ActivisionServicing = ActivisionService()
    ) {
        self.keychain = keychain
        self.service = service
        if keychain.read() != nil {
            state = .unavailable("Stored Activision session requires verification.")
        }
    }

    func connect(ssoToken: String) async {
        let token = ssoToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { state = .unavailable("Enter an Activision SSO token."); return }
        state = .syncing
        do {
            let identity = try await service.verifySession(token: token)
            guard keychain.save(token) else {
                state = .unavailable("Could not save token in Keychain.")
                return
            }
            state = .connected(displayName: identity)
            lastSync = .now
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    func sync() async {
        guard let token = keychain.read() else { state = .disconnected; return }
        state = .syncing
        do {
            let identity = try await service.verifySession(token: token)
            state = .connected(displayName: identity)
            lastSync = .now
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    func disconnect() {
        keychain.delete()
        state = .disconnected
        lastSync = nil
    }
}

protocol TokenStoring {
    func save(_ value: String) -> Bool
    func read() -> String?
    func delete()
}

struct KeychainStore: TokenStoring {
    let service = "com.jimboha.OpsTracker"
    let account = "activision-sso"

    func save(_ value: String) -> Bool {
        delete()
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}
