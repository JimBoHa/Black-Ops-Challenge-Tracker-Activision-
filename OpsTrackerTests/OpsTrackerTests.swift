import XCTest
import Security
@testable import OpsTracker

final class OpsTrackerTests: XCTestCase {
    func testChallengeProgressUsesCurrentAndTarget() {
        let challenge = Challenge(
            id: UUID(), title: "Test", detail: "Test", kind: .camo,
            mode: .multiplayer, group: "Test", current: 25, target: 100,
            reward: "Test", expiresAt: nil, tracked: false
        )

        XCTAssertEqual(challenge.progress, 0.25, accuracy: 0.001)
        XCTAssertFalse(challenge.isComplete)
    }

    func testChallengeProgressDoesNotExceedOne() {
        let challenge = Challenge(
            id: UUID(), title: "Test", detail: "Test", kind: .weekly,
            mode: .zombies, group: "Test", current: 12, target: 10,
            reward: "Test", expiresAt: nil, tracked: true
        )

        XCTAssertEqual(challenge.progress, 1)
        XCTAssertTrue(challenge.isComplete)
    }

    func testSampleCatalogHasUniqueStableIdentifiers() {
        let ids = SampleCatalog.challenges.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testUnreadableProgressIsBackedUpBeforeSamplesAreRestored() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = folder.appending(path: "challenges.json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let corruptData = Data("not valid challenge json".utf8)
        try corruptData.write(to: fileURL)

        let store = ChallengeStore(fileURL: fileURL)
        let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("challenges.corrupt-") }

        XCTAssertEqual(store.challenges, SampleCatalog.makeChallenges(at: store.currentDate))
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0]), corruptData)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertNoThrow(try JSONDecoder().decode([Challenge].self, from: Data(contentsOf: fileURL)))
    }

    func testSaveFailureIsReportedAndDoesNotClaimSuccessfulUpdate() {
        let invalidURL = URL(fileURLWithPath: "/dev/null/challenges.json")
        let store = ChallengeStore(fileURL: invalidURL)
        var challenge = store.challenges[0]
        challenge.current += 1

        store.update(challenge)

        XCTAssertEqual(store.persistenceError, "Changes could not be saved. Check available device storage.")
        XCTAssertNil(store.lastUpdated)
    }

    func testExpiredChallengesAreExcludedFromListsAndCompletion() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        var clock = now
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = folder.appending(path: "challenges.json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let expired = Challenge(
            id: UUID(), title: "Expired daily", detail: "Expired", kind: .daily,
            mode: .multiplayer, group: "Yesterday", current: 1, target: 1,
            reward: "XP", expiresAt: now, tracked: true
        )
        let active = Challenge(
            id: UUID(), title: "Active weekly", detail: "Active", kind: .weekly,
            mode: .zombies, group: "This week", current: 0, target: 1,
            reward: "XP", expiresAt: now.addingTimeInterval(1), tracked: true
        )
        try JSONEncoder().encode([expired, active]).write(to: fileURL)

        let store = ChallengeStore(fileURL: fileURL, now: { clock })

        XCTAssertEqual(store.active.map(\.id), [active.id])
        XCTAssertEqual(store.filtered.map(\.id), [active.id])
        XCTAssertEqual(store.tracked.map(\.id), [active.id])
        XCTAssertEqual(store.completion, 0)

        clock = now.addingTimeInterval(2)
        store.refreshExpirations()
        XCTAssertTrue(store.active.isEmpty)
    }

    func testRestoredSamplesReceiveFreshExpirationDates() throws {
        var clock = Date(timeIntervalSince1970: 10_000)
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = folder.appending(path: "challenges.json")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ChallengeStore(fileURL: fileURL, now: { clock })
        let originalDailyExpiration = store.challenges.first { $0.kind == .daily }?.expiresAt

        clock = clock.addingTimeInterval(10 * 24 * 60 * 60)
        XCTAssertTrue(store.resetSampleData())

        let timedChallenges = store.challenges.filter { $0.expiresAt != nil }
        XCTAssertTrue(timedChallenges.allSatisfy { $0.expiresAt! > clock })
        XCTAssertNotEqual(timedChallenges.first { $0.kind == .daily }?.expiresAt, originalDailyExpiration)
        XCTAssertEqual(store.active.count, store.challenges.count)
    }

    @MainActor
    func testStoredTokenIsNotTreatedAsVerifiedConnection() {
        let tokenStore = FakeTokenStore(storedToken: "unverified-token")
        let store = AccountStore(keychain: tokenStore, service: RejectingActivisionService())

        XCTAssertEqual(store.state, .unavailable("Stored Activision session requires verification."))
    }

    @MainActor
    func testRejectedTokenIsNotPersisted() async {
        let tokenStore = FakeTokenStore()
        let store = AccountStore(keychain: tokenStore, service: RejectingActivisionService())

        await store.connect(ssoToken: "invalid-token")

        XCTAssertNil(tokenStore.storedToken)
        XCTAssertEqual(tokenStore.saveCount, 0)
        XCTAssertEqual(store.state, .unavailable("Rejected test session."))
    }

    @MainActor
    func testDisconnectInvalidatesPendingConnection() async {
        let tokenStore = FakeTokenStore()
        let service = ControlledActivisionService()
        let store = AccountStore(keychain: tokenStore, service: service)

        let connection = Task { await store.connect(ssoToken: "pending-token") }
        await service.waitUntilPending(token: "pending-token")
        store.disconnect()
        await service.succeed(token: "pending-token", identity: "Too Late")
        await connection.value

        XCTAssertEqual(store.state, .disconnected)
        XCTAssertNil(store.lastSync)
        XCTAssertNil(tokenStore.storedToken)
        XCTAssertEqual(tokenStore.saveCount, 0)
    }

    @MainActor
    func testOlderConnectionCannotOverwriteNewerConnection() async {
        let tokenStore = FakeTokenStore()
        let service = ControlledActivisionService()
        let store = AccountStore(keychain: tokenStore, service: service)

        let older = Task { await store.connect(ssoToken: "older-token") }
        await service.waitUntilPending(token: "older-token")
        let newer = Task { await store.connect(ssoToken: "newer-token") }
        await service.waitUntilPending(token: "newer-token")

        await service.succeed(token: "newer-token", identity: "New Account")
        await newer.value
        await service.succeed(token: "older-token", identity: "Old Account")
        await older.value

        XCTAssertEqual(store.state, .connected(displayName: "New Account"))
        XCTAssertEqual(tokenStore.storedToken, "newer-token")
        XCTAssertEqual(tokenStore.saveCount, 1)
    }

    @MainActor
    func testFailedKeychainDeletionDoesNotReportDisconnected() {
        let tokenStore = FakeTokenStore(storedToken: "retained-token", deleteSucceeds: false)
        let store = AccountStore(keychain: tokenStore, service: RejectingActivisionService())

        store.disconnect()

        XCTAssertEqual(store.state, .unavailable("Could not remove token from Keychain."))
        XCTAssertEqual(tokenStore.storedToken, "retained-token")
        XCTAssertEqual(tokenStore.deleteCount, 1)
    }

    func testKeychainReplacementFailurePreservesExistingCredential() {
        var storedValue = "existing-token"
        var addCount = 0
        let keychain = KeychainStore(
            updateItem: { _, _ in errSecAuthFailed },
            addItem: { item in
                addCount += 1
                let dictionary = item as NSDictionary
                if let data = dictionary[kSecValueData] as? Data {
                    storedValue = String(decoding: data, as: UTF8.self)
                }
                return errSecSuccess
            }
        )

        XCTAssertFalse(keychain.save("replacement-token"))
        XCTAssertEqual(storedValue, "existing-token")
        XCTAssertEqual(addCount, 0)
    }

    func testKeychainSaveAddsOnlyWhenCredentialIsMissing() {
        var addedValue: String?
        var accessibility: String?
        let keychain = KeychainStore(
            updateItem: { _, _ in errSecItemNotFound },
            addItem: { item in
                let dictionary = item as NSDictionary
                if let data = dictionary[kSecValueData] as? Data {
                    addedValue = String(decoding: data, as: UTF8.self)
                }
                accessibility = dictionary[kSecAttrAccessible] as? String
                return errSecSuccess
            }
        )

        XCTAssertTrue(keychain.save("new-token"))
        XCTAssertEqual(addedValue, "new-token")
        XCTAssertEqual(accessibility, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    @MainActor
    func testKeychainReadFailureDoesNotReportDisconnected() {
        let tokenStore = FakeTokenStore(readSucceeds: false)
        let store = AccountStore(keychain: tokenStore, service: RejectingActivisionService())

        XCTAssertEqual(store.state, .unavailable("Could not read token from Keychain."))
    }

    @MainActor
    func testInvalidSessionIsRemovedAfterSync() async {
        let tokenStore = FakeTokenStore(storedToken: "expired-token")
        let store = AccountStore(keychain: tokenStore, service: InvalidSessionActivisionService())

        await store.sync()

        XCTAssertEqual(store.state, .unavailable("Activision session is invalid or expired."))
        XCTAssertNil(store.lastSync)
        XCTAssertNil(tokenStore.storedToken)
        XCTAssertEqual(tokenStore.deleteCount, 1)
    }
}

private final class FakeTokenStore: TokenStoring {
    var storedToken: String?
    var saveCount = 0
    var deleteCount = 0
    private let deleteSucceeds: Bool
    private let readSucceeds: Bool

    init(storedToken: String? = nil, deleteSucceeds: Bool = true, readSucceeds: Bool = true) {
        self.storedToken = storedToken
        self.deleteSucceeds = deleteSucceeds
        self.readSucceeds = readSucceeds
    }

    func save(_ value: String) -> Bool {
        saveCount += 1
        storedToken = value
        return true
    }

    func read() throws -> String? {
        guard readSucceeds else { throw TokenStoreError.readFailed }
        return storedToken
    }
    func delete() -> Bool {
        deleteCount += 1
        if deleteSucceeds { storedToken = nil }
        return deleteSucceeds
    }
}

private struct RejectedSessionError: LocalizedError {
    var errorDescription: String? { "Rejected test session." }
}

private actor RejectingActivisionService: ActivisionServicing {
    func verifySession(token: String) async throws -> String {
        throw RejectedSessionError()
    }
}

private actor InvalidSessionActivisionService: ActivisionServicing {
    func verifySession(token: String) async throws -> String {
        throw ActivisionServiceError.invalidSession
    }
}

private actor ControlledActivisionService: ActivisionServicing {
    private var pending: [String: CheckedContinuation<String, any Error>] = [:]

    func verifySession(token: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            pending[token] = continuation
        }
    }

    func waitUntilPending(token: String) async {
        while pending[token] == nil {
            await Task.yield()
        }
    }

    func succeed(token: String, identity: String) {
        pending.removeValue(forKey: token)?.resume(returning: identity)
    }
}
