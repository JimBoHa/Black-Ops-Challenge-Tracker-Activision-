import XCTest
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

        XCTAssertEqual(store.challenges, SampleCatalog.challenges)
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
}

private final class FakeTokenStore: TokenStoring {
    var storedToken: String?
    var saveCount = 0

    init(storedToken: String? = nil) { self.storedToken = storedToken }

    func save(_ value: String) -> Bool {
        saveCount += 1
        storedToken = value
        return true
    }

    func read() -> String? { storedToken }
    func delete() { storedToken = nil }
}

private struct RejectedSessionError: LocalizedError {
    var errorDescription: String? { "Rejected test session." }
}

private actor RejectingActivisionService: ActivisionServicing {
    func verifySession(token: String) async throws -> String {
        throw RejectedSessionError()
    }
}
