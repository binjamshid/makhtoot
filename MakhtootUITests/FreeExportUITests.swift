import XCTest

final class FreeExportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSVGExportOpensShareSheet() {
        let app = XCUIApplication()
        app.launchArguments += ["-MKHasCompletedOnboarding", "YES", "-MKEditorTourCompleted", "YES"]
        app.launch()
        let create = app.navigationBars.buttons["مشروع جديد"]
        let undo = app.buttons["تراجع"]
        if create.waitForExistence(timeout: 5) {
            create.tap()
            let square = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "مربع")).firstMatch
            XCTAssertTrue(square.waitForExistence(timeout: 10))
            square.tap()
        }
        // The editor can also restore an open project from an earlier launch.
        XCTAssertTrue(undo.waitForExistence(timeout: 15), app.debugDescription)
        let export = app.buttons["تصدير"]
        if !export.exists {
            // Compact iPhone toolbars can move Export into iOS's overflow menu.
            let overflow = app.navigationBars.buttons.matching(
                NSPredicate(format: "label IN %@ OR identifier == %@", ["More", "المزيد"], "ellipsis")
            ).firstMatch
            XCTAssertTrue(overflow.waitForExistence(timeout: 5), app.debugDescription)
            overflow.tap()
        }
        XCTAssertTrue(export.waitForExistence(timeout: 5), app.debugDescription)
        export.tap()

        let svg = app.buttons["export-format-svg"]
        XCTAssertTrue(svg.waitForExistence(timeout: 10))
        svg.tap()

        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.buttons["استعادة المشتريات"].exists)
    }
}
