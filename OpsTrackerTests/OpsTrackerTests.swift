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
