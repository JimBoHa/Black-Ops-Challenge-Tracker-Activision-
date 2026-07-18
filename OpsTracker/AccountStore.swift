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
    private var activeRequestID: UUID?

    init(
        keychain: any TokenStoring = KeychainStore(),
        service: any ActivisionServicing = ActivisionService()
    ) {
        self.keychain = keychain
        self.service = service
        do {
            if try keychain.read() != nil {
                state = .unavailable("Stored Activision session requires verification.")
            }
        } catch {
            state = .unavailable("Could not read token from Keychain.")
        }
    }

    func connect(ssoToken: String) async {
        let requestID = UUID()
        activeRequestID = requestID
        let token = ssoToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            activeRequestID = nil
            state = .unavailable("Enter an Activision SSO token.")
            return
        }
        state = .syncing
        do {
            let identity = try await service.verifySession(token: token)
            guard activeRequestID == requestID else { return }
            guard keychain.save(token) else {
                activeRequestID = nil
                state = .unavailable("Could not save token in Keychain.")
                return
            }
            activeRequestID = nil
            state = .connected(displayName: identity)
            lastSync = .now
        } catch {
            guard activeRequestID == requestID else { return }
            activeRequestID = nil
            state = .unavailable(error.localizedDescription)
        }
    }

    func sync() async {
        let requestID = UUID()
        activeRequestID = requestID
        let storedToken: String?
        do {
            storedToken = try keychain.read()
        } catch {
            activeRequestID = nil
            state = .unavailable("Could not read token from Keychain.")
            return
        }
        guard let token = storedToken else {
            activeRequestID = nil
            state = .disconnected
            return
        }
        state = .syncing
        do {
            let identity = try await service.verifySession(token: token)
            guard activeRequestID == requestID else { return }
            activeRequestID = nil
            state = .connected(displayName: identity)
            lastSync = .now
        } catch ActivisionServiceError.invalidSession {
            guard activeRequestID == requestID else { return }
            activeRequestID = nil
            lastSync = nil
            if keychain.delete() {
                state = .unavailable("Activision session is invalid or expired.")
            } else {
                state = .unavailable("Activision session expired, but its token could not be removed from Keychain.")
            }
        } catch {
            guard activeRequestID == requestID else { return }
            activeRequestID = nil
            state = .unavailable(error.localizedDescription)
        }
    }

    func disconnect() {
        activeRequestID = nil
        if keychain.delete() {
            state = .disconnected
            lastSync = nil
        } else {
            state = .unavailable("Could not remove token from Keychain.")
        }
    }
}

protocol TokenStoring {
    func save(_ value: String) -> Bool
    func read() throws -> String?
    func delete() -> Bool
}

enum TokenStoreError: Error {
    case readFailed
    case invalidData
}

struct KeychainStore: TokenStoring {
    let service: String
    let account: String
    private let updateItem: (CFDictionary, CFDictionary) -> OSStatus
    private let addItem: (CFDictionary) -> OSStatus

    init(
        service: String = "com.jimboha.OpsTracker",
        account: String = "activision-sso",
        updateItem: @escaping (CFDictionary, CFDictionary) -> OSStatus = { SecItemUpdate($0, $1) },
        addItem: @escaping (CFDictionary) -> OSStatus = { SecItemAdd($0, nil) }
    ) {
        self.service = service
        self.account = account
        self.updateItem = updateItem
        self.addItem = addItem
    }

    func save(_ value: String) -> Bool {
        let data = Data(value.utf8)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = updateItem(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        let newItem = identity.merging(attributes) { _, newValue in newValue }
        return addItem(newItem as CFDictionary) == errSecSuccess
    }

    func read() throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw TokenStoreError.readFailed }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw TokenStoreError.invalidData
        }
        return value
    }

    func delete() -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
