import XCTest

/// FC-6 (AUDIT_2026-07-28.md): Arrange Mode is Makhtoot's differentiating
/// feature (R-6 in PRD/FOUNDATION terms) and, per the audit, has zero
/// automated coverage of its entry/exit chrome swap
/// (`EditorScene.primaryRail(axis:isRegularWidth:)`: `ToolRailView` ↔
/// `ArrangeToolbarView`).
///
/// Drives the real production path end to end: insert a single-line live
/// text node (auto-selected on commit, see `InsertTextCommitUITests`),
/// tap the wand ("وضع الترتيب") to enter Arrange Mode, confirm the
/// contextual `ArrangeToolbarView` chrome replaced the standard
/// `ToolRailView`, then tap its "إغلاق" (close) control to exit and
/// confirm the standard rail is back.
final class ArrangeModeEnterExitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Same fresh-project bootstrap `InsertTextCommitUITests` documents in
    /// full, plus one committed single-line live-text node so
    /// `EditorViewModel.canToggleArrangeMode` is true (a single
    /// `.liveText`/`.pathText`/`.arranged` node must be the sole
    /// selection).
    private func launchIntoEditorWithOneSelectedTextNode() -> XCUIApplication {
        let app = XCUIApplication()
        // See `InsertTextCommitUITests.swift`'s matching comment: skips
        // both first-launch onboarding and the in-editor first-use tour
        // overlay, which would otherwise sit on top of the tool rail this
        // test taps through.
        app.launchArguments += ["-MKHasCompletedOnboarding", "YES", "-MKEditorTourCompleted", "YES"]
        app.launch()

        // Scoped to the navigation bar: `ProjectBrowserView` also renders a
        // plain empty-state "create your first project" CTA button with the
        // identical accessibility label elsewhere in the view hierarchy
        // (outside the nav bar) whenever the project list is empty — which
        // it is at this point on a fresh launch — so a bare
        // `app.buttons["مشروع جديد"]` matches both ambiguously. Only the
        // toolbar "+" button lives under `app.navigationBars`.
        let newProjectToolbarButton = app.navigationBars.buttons["مشروع جديد"]
        XCTAssertTrue(newProjectToolbarButton.waitForExistence(timeout: 10))
        newProjectToolbarButton.tap()

        let squarePreset = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "مربع")).firstMatch
        XCTAssertTrue(squarePreset.waitForExistence(timeout: 10))
        squarePreset.tap()

        XCTAssertTrue(app.buttons["تراجع"].waitForExistence(timeout: 15))

        app.buttons["إضافة عنصر"].tap()
        let addTextFieldMenuItem = app.buttons["حقل نص"]
        XCTAssertTrue(addTextFieldMenuItem.waitForExistence(timeout: 5))
        addTextFieldMenuItem.tap()

        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        // SwiftUI's `TextEditor` occasionally doesn't pick up focus from the
        // very first tap while the sheet's presentation animation is still
        // settling — observed as an intermittent `typeText` "Neither
        // element nor any descendant has keyboard focus" failure when this
        // suite runs back-to-back with other tests. Confirm the software
        // keyboard actually came up before typing; retap once if it didn't.
        if !app.keyboards.element.waitForExistence(timeout: 3) {
            textEditor.tap()
            XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "Software keyboard never appeared after tapping the text editor")
        }
        // Single line, no spaces: `TextInsertSheet.splitBySpaces` defaults
        // to `false`, so this becomes exactly ONE live-text node — the
        // precondition `canToggleArrangeMode` needs (a single selected
        // node), not several.
        textEditor.typeText("سلام")
        app.buttons["إدراج"].tap()

        return app
    }

    func testEnterThenExitArrangeMode() throws {
        let app = launchIntoEditorWithOneSelectedTextNode()

        let arrangeToggle = app.buttons["وضع الترتيب"]
        XCTAssertTrue(arrangeToggle.waitForExistence(timeout: 10), "Arrange Mode toggle not reachable from the standard tool rail")
        XCTAssertTrue(arrangeToggle.isEnabled, "Arrange Mode toggle should be enabled with exactly one live-text node selected")
        arrangeToggle.tap()

        // `ArrangeToolbarView` REPLACES `ToolRailView` while active
        // (`EditorScene.primaryRail`'s own doc comment: "the arrange
        // toolbar REPLACES the standard object toolbar"). Its granularity
        // chips are unique to this contextual bar.
        let lettersChip = app.buttons["حروف"]
        let closeArrangeButton = app.buttons["إغلاق"]
        XCTAssertTrue(lettersChip.waitForExistence(timeout: 15), "ArrangeToolbarView did not appear after entering Arrange Mode")
        XCTAssertTrue(closeArrangeButton.exists, "ArrangeToolbarView's close control is missing")
        // The standard rail's own font-settings entry must be gone while
        // Arrange Mode owns the primary rail slot.
        XCTAssertFalse(app.buttons["الخط والحجم"].exists, "Standard tool rail should not coexist with the Arrange Mode toolbar")

        closeArrangeButton.tap()

        // Exit: the standard rail's entry points return, and the Arrange
        // Mode-only chip is gone.
        XCTAssertTrue(app.buttons["إضافة عنصر"].waitForExistence(timeout: 10), "Standard tool rail did not return after exiting Arrange Mode")
        XCTAssertFalse(app.buttons["حروف"].exists, "Arrange Mode chrome should be gone after exiting")
    }
}
