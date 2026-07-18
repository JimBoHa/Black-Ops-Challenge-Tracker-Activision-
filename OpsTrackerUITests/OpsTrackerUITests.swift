import XCTest

final class OpsTrackerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testMainTabsAndDashboardRender() {
        XCTAssertTrue(app.navigationBars["OPS TRACKER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Overview"].exists)
        XCTAssertTrue(app.tabBars.buttons["Tracker"].exists)
        XCTAssertTrue(app.tabBars.buttons["Account"].exists)
        XCTAssertTrue(app.staticTexts["MISSION READINESS"].exists)
    }

    func testTrackerChallengeOpensDetails() {
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(app.navigationBars["CHALLENGES"].waitForExistence(timeout: 3))
        let challenge = app.staticTexts["Military Camo I"]
        XCTAssertTrue(challenge.waitForExistence(timeout: 3))
        challenge.tap()
        XCTAssertTrue(app.navigationBars["Military Camo I"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Objective"].exists)
        XCTAssertTrue(app.staticTexts["Progress"].exists)
    }

    func testDashboardTrackedChallengeOpensDetails() {
        let challenge = app.staticTexts["Military Camo I"]
        XCTAssertTrue(challenge.waitForExistence(timeout: 3))
        challenge.tap()
        XCTAssertTrue(app.navigationBars["Military Camo I"].waitForExistence(timeout: 3))
    }

    func testAccountScreenShowsSecureSessionControls() {
        app.tabBars.buttons["Account"].tap()
        XCTAssertTrue(app.navigationBars["ACCOUNT"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["SSO token"].exists)
        XCTAssertTrue(app.buttons["Save and connect"].exists)
        XCTAssertFalse(app.buttons["Save and connect"].isEnabled)
    }

    func testRejectedTokenDoesNotShowConnectedState() {
        app.tabBars.buttons["Account"].tap()
        app.buttons["Disconnect"].tap()

        let tokenField = app.secureTextFields["SSO token"]
        tokenField.tap()
        tokenField.typeText("invalid-test-token")
        app.buttons["Save and connect"].tap()

        XCTAssertTrue(app.staticTexts["Activision does not expose challenge progress through a supported public API. Manual tracking remains available."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Activision Account"].exists)
    }

    func testRestoringSampleDataRequiresConfirmation() {
        app.tabBars.buttons["Account"].tap()

        app.buttons["Restore sample tracker data"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.buttons["Restore data"].exists)
        XCTAssertEqual(alert.buttons.count, 2)
    }

    func testOpenChallengeDetailRefreshesAfterSampleRestore() {
        app.tabBars.buttons["Account"].tap()
        app.buttons["Restore sample tracker data"].tap()
        app.alerts.firstMatch.buttons["Restore data"].tap()

        app.tabBars.buttons["Tracker"].tap()
        app.staticTexts["Military Camo I"].tap()
        XCTAssertTrue(app.steppers["Current, 42 / 100"].waitForExistence(timeout: 3))

        let increment = app.buttons["Increment"]
        XCTAssertTrue(increment.exists)
        increment.tap()
        XCTAssertTrue(app.steppers["Current, 43 / 100"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Account"].tap()
        app.buttons["Restore sample tracker data"].tap()
        app.alerts.firstMatch.buttons["Restore data"].tap()
        app.tabBars.buttons["Tracker"].tap()

        XCTAssertTrue(app.steppers["Current, 42 / 100"].waitForExistence(timeout: 3))
    }

    func testFilterChipsExposeSelectionAndMinimumHitTargets() {
        app.tabBars.buttons["Tracker"].tap()
        let all = app.buttons["All"]
        let camos = app.buttons["Camos"]
        XCTAssertTrue(all.waitForExistence(timeout: 3))

        for title in ["All", "Camos", "Calling Cards", "Daily", "Weekly"] {
            let chip = app.buttons[title]
            XCTAssertGreaterThanOrEqual(chip.frame.width, 44)
            XCTAssertGreaterThanOrEqual(chip.frame.height, 44)
        }
        XCTAssertTrue(all.isSelected)
        XCTAssertFalse(camos.isSelected)

        camos.tap()

        XCTAssertFalse(all.isSelected)
        XCTAssertTrue(camos.isSelected)
    }
}
