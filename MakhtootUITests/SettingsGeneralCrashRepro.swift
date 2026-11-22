import XCTest

/// 2026-07-29 bug report: "clicking on General settings crashes the app."
/// `-MKHasCompletedOnboarding YES` skips straight to the browser (the same
/// UserDefaults argument-domain override `OnboardingFirstProjectUITests`
/// documents) so this test isolates exactly the reported path: browser →
/// settings gear → "عام" (General) row, with no onboarding interaction
/// in between to introduce noise.
final class SettingsGeneralCrashRepro: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOpeningGeneralSettingsDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-MKHasCompletedOnboarding", "YES", "-MKEditorTourCompleted", "YES"]
        app.launch()

        let settingsButton = app.navigationBars.buttons["الإعدادات"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 15), "Project browser (with its settings gear) did not appear")
        settingsButton.tap()

        let generalRow = app.buttons["عام"]
        XCTAssertTrue(generalRow.waitForExistence(timeout: 10), "Settings list (with its General row) did not appear")
        generalRow.tap()

        // If the app crashed, XCUITest's own health-check on the next query
        // fails immediately/loudly (app.state != .runningForeground) rather
        // than silently hanging — but assert something concrete from
        // GeneralSettingsView's actual content too, not just liveness.
        XCTAssertEqual(app.state, .runningForeground, "App did not survive opening General settings")
        let appearanceHeader = app.staticTexts["المظهر"]
        XCTAssertTrue(appearanceHeader.waitForExistence(timeout: 10), "GeneralSettingsView did not render its Appearance section")
    }
}
