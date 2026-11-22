import XCTest

/// FC-6 (AUDIT_2026-07-28.md): the highest-value flow with zero prior
/// automated coverage — first-launch onboarding through to a freshly
/// created project's editor actually opening. Every prior "caught on-
/// simulator, not by inspection" bug this audit documents lives in exactly
/// this uncovered layer.
///
/// Onboarding's own page count is NOT fixed (`OnboardingView.pages`):
/// a third "trial" page is inserted only when `MKTrialManager.peek()`
/// resolves `.active` at the moment the screen's `.task` runs, which
/// depends on this device's own persisted (Keychain/iCloud KVS) trial
/// record — a UI test process cannot control or observe that record
/// directly. This test never hardcodes a page index or a tap count; it
/// repeatedly taps "التالي" (Next) until the final page's "ابدأ التصميم"
/// (start designing) button is reachable, which is correct regardless of
/// whether the trial page is present.
///
/// `-MKHasCompletedOnboarding NO` is not a bespoke test hook — it is the
/// standard `UserDefaults` "argument domain" override
/// (`AppNavigationModel.swift`'s own `"MKHasCompletedOnboardingKey"`,
/// read via `UserDefaults.standard.bool(forKey:)`), which always outranks
/// the persisted value. No app-source file was touched to make this
/// possible.
final class OnboardingFirstProjectUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingThenFirstProjectCreationOpensEditor() throws {
        let app = XCUIApplication()
        // `-MKEditorTourCompleted YES`: the same `UserDefaults`
        // argument-domain override technique, this time for
        // `EditorTourModel.isCompleted` (`"MKEditorTourCompleted"`) ، the
        // in-editor first-use tour overlay (`EditorTourOverlay`) otherwise
        // covers the tool rail on the very first editor open this test
        // itself produces, which is irrelevant to what THIS test is
        // checking (onboarding → first project creation reaching the
        // editor, not the tour).
        app.launchArguments += ["-MKHasCompletedOnboarding", "NO", "-MKEditorTourCompleted", "YES"]
        app.launch()

        // MARK: Onboarding

        let startDesigningButton = app.buttons["ابدأ التصميم"]
        var taps = 0
        // 4 is `OnboardingView.pages`' own maximum count (2 fixed pages +
        // trial page + closing page) ، one extra beyond that would signal
        // the loop is stuck, not legitimately advancing.
        while !startDesigningButton.exists, taps < 4 {
            let next = app.buttons["التالي"]
            XCTAssertTrue(next.waitForExistence(timeout: 10), "Expected either 'التالي' or 'ابدأ التصميم' to be reachable on the onboarding pager")
            next.tap()
            taps += 1
        }
        XCTAssertTrue(startDesigningButton.waitForExistence(timeout: 10), "Onboarding never reached its closing page")
        startDesigningButton.tap()

        // MARK: Browser — first project creation

        // Scoped to the navigation bar: `ProjectBrowserView` also renders a
        // plain empty-state "create your first project" CTA button with the
        // identical accessibility label elsewhere in the view hierarchy
        // (outside the nav bar) whenever the project list is empty — which
        // it is here, right after onboarding, before any project exists —
        // so a bare `app.buttons["مشروع جديد"]` matches both ambiguously.
        // Only the toolbar "+" button lives under `app.navigationBars`.
        let newProjectToolbarButton = app.navigationBars.buttons["مشروع جديد"]
        XCTAssertTrue(newProjectToolbarButton.waitForExistence(timeout: 10), "Project browser did not appear after finishing onboarding")
        newProjectToolbarButton.tap()

        let squarePreset = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "مربع")).firstMatch
        XCTAssertTrue(squarePreset.waitForExistence(timeout: 10), "New Project sheet did not present its size presets")
        squarePreset.tap()

        // MARK: Editor opens for the freshly created project

        // `EditorScene`'s toolbar "تم" (done) button and the undo control
        // are both real editor chrome, only present once `EditorViewModel`
        // has finished opening the real `.makhtoot` package this exact tap
        // just created (`ProjectBrowserView.createProject(canvas:)` →
        // `EditorScene.open()`) — this is the actual production path, no
        // DEBUG bypass.
        let undoButton = app.buttons["تراجع"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 15), "Editor chrome never appeared for the newly created project")

        // The font-settings tool-rail entry is present only inside the
        // real editor (never on the browser/onboarding screens), a second
        // independent signal the editor genuinely opened.
        XCTAssertTrue(app.buttons["الخط والحجم"].exists, "Tool rail did not render for the newly opened editor")
    }
}
