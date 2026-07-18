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
}
