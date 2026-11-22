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
        // The editor may restore the last project after an earlier test.
        let done = app.navigationBars.buttons["تم"]
        if done.exists { done.tap() }


        let create = app.navigationBars.buttons["مشروع جديد"]
        XCTAssertTrue(create.waitForExistence(timeout: 15))
        create.tap()

        let square = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "مربع")).firstMatch
        XCTAssertTrue(square.waitForExistence(timeout: 10))
        square.tap()

        let export = app.buttons["تصدير"]
        XCTAssertTrue(app.buttons["تراجع"].waitForExistence(timeout: 15))
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

        let shareAction = app.buttons["Copy"]
        XCTAssertTrue(shareAction.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.buttons["استعادة المشتريات"].exists)
    }
}
