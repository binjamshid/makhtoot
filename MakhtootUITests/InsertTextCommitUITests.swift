import XCTest

/// FC-6 (AUDIT_2026-07-28.md): insert-text-then-commit is the flow
/// `EditorViewModel.swift:353`'s own doc comment cites by name as a bug
/// that was "caught on-simulator, not by inspection" (a committed text
/// overlay that stayed stuck on screen) — exactly the layer this target
/// exists to cover.
///
/// Drives the real `TextInsertSheet` (P2.1's primary text-entry path, not
/// the DEBUG `debugSetActiveOverlayText`/`debugCommitActiveOverlay` hooks
/// `EditorViewModel` also exposes for the E2E launch-arg drives) and
/// confirms the inserted node actually committed and became the live
/// selection, via `FontSettingsSheet` showing its selection-bound "Traits"
/// section (`hasSelection == true`) rather than its empty-selection state.
final class InsertTextCommitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Skips onboarding (`-MKHasCompletedOnboarding YES`, the same
    /// `UserDefaults` argument-domain override
    /// `OnboardingFirstProjectUITests` documents in full) and creates one
    /// fresh square-canvas project via the real
    /// `NewProjectSheet`/`ProjectBrowserView.createProject(canvas:)` path,
    /// landing inside the editor.
    private func launchIntoFreshProjectEditor() -> XCUIApplication {
        let app = XCUIApplication()
        // `-MKEditorTourCompleted YES`: skips `EditorTourOverlay` (the
        // in-editor first-use tour, `EditorTourModel.isCompleted`,
        // `UserDefaults` key `"MKEditorTourCompleted"`), which otherwise
        // covers the tool rail's "+"/"أء" buttons on the very first editor
        // open and would block every tap this test performs. Same
        // argument-domain override technique as
        // `-MKHasCompletedOnboarding`, no app source touched.
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
        XCTAssertTrue(newProjectToolbarButton.waitForExistence(timeout: 10), "Project browser did not appear at launch")
        newProjectToolbarButton.tap()

        let squarePreset = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "مربع")).firstMatch
        XCTAssertTrue(squarePreset.waitForExistence(timeout: 10), "New Project sheet did not present its size presets")
        squarePreset.tap()

        let undoButton = app.buttons["تراجع"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 15), "Editor chrome never appeared for the newly created project")
        return app
    }

    func testInsertTextThenCommitSelectsTheNewNode() throws {
        let app = launchIntoFreshProjectEditor()

        // "+" (إضافة عنصر) → "حقل نص" (add text field) opens the real
        // `TextInsertSheet` (`ToolRailView.swift`).
        let addObjectButton = app.buttons["إضافة عنصر"]
        XCTAssertTrue(addObjectButton.waitForExistence(timeout: 10))
        addObjectButton.tap()

        let addTextFieldMenuItem = app.buttons["حقل نص"]
        XCTAssertTrue(addTextFieldMenuItem.waitForExistence(timeout: 5))
        addTextFieldMenuItem.tap()

        let insertTitle = app.navigationBars["إدراج نص"]
        XCTAssertTrue(insertTitle.waitForExistence(timeout: 10), "TextInsertSheet did not present")

        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5), "TextInsertSheet's TextEditor is not reachable")
        textEditor.tap()
        // See `ArrangeModeEnterExitUITests.swift`'s matching comment: guard
        // against the intermittent first-tap-doesn't-focus flake by
        // confirming the software keyboard actually appeared, retapping
        // once if it didn't.
        if !app.keyboards.element.waitForExistence(timeout: 3) {
            textEditor.tap()
            XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "Software keyboard never appeared after tapping the text editor")
        }
        textEditor.typeText("مرحبا بالعالم")

        let insertButton = app.buttons["إدراج"]
        XCTAssertTrue(insertButton.exists)
        XCTAssertTrue(insertButton.isEnabled, "Insert should enable once the field is non-empty")
        insertButton.tap()

        // Commit: the sheet dismisses (its own nav title goes away) and
        // `EditorViewModel.insertTextFromSheet` selects every node it just
        // created (`session.setSelection(Set(createdTopLevelIDs))`).
        XCTAssertFalse(insertTitle.waitForExistence(timeout: 2), "Insert sheet should have dismissed after committing")

        let fontSettingsButton = app.buttons["الخط والحجم"]
        XCTAssertTrue(fontSettingsButton.waitForExistence(timeout: 5))
        fontSettingsButton.tap()

        // `FontSettingsSheet.hasSelection` gates the whole "Traits" section
        // (`traitsRow`, the "B/I/U/S" row) ، its presence is direct proof
        // the just-inserted node both committed to the scene AND is the
        // live selection, not merely that a sheet opened.
        let boldTrait = app.buttons["B"]
        XCTAssertTrue(boldTrait.waitForExistence(timeout: 5), "Newly committed text node was not selected after insert")

        // `EditorScene`'s own toolbar has its OWN "تم" (done) button
        // underneath this presented sheet, still present (if occluded) in
        // the accessibility tree ، a bare `app.buttons["تم"]` matches both
        // ambiguously. `FontSettingsSheet.titleLabel` ("الخط والتنسيق")
        // scopes this to the sheet's own navigation bar specifically.
        app.navigationBars["الخط والتنسيق"].buttons["تم"].tap()
    }
}
