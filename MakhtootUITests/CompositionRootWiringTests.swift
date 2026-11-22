import UIKit
import XCTest

/// FC-6 (AUDIT_2026-07-28.md), step 3 of Wave 0 · Agent 0.2's "Do" list:
/// the regression net Wave 1's FC-1 fix must satisfy.
///
/// **Expected RED in Wave 0.** Today, `EditorViewModel.swift`'s seven
/// `SystemFontStubProvider()` literals (not `AppContainer.fontProvider`,
/// the real `MKRegistryFontProvider`) back every font resolution the
/// canvas renders through. This test is written to go GREEN once Wave 1's
/// FC-1 fix lands — see `EXECUTION_PLAN_2026-07-28.md`'s Wave 0 gate,
/// which deliberately excludes this one test from Wave 0's pass/fail gate
/// and runs it only informationally.
///
/// `AppContainer` (the composition root FC-1 fixes) is an in-process
/// `@Observable` type owned by the app target; a `MakhtootUITests` test
/// runs in a *separate* process (`XCUIApplication`) and cannot reach it
/// directly — there is no shared memory to assert `AppContainer
/// .fontProvider` against. Per this file's own plan section ("assert
/// indirectly... compare rendered glyph pixels against the non-bold
/// twin"), this asserts the only thing actually observable from outside
/// the app: toggling Bold on a committed text node must change what the
/// canvas actually renders. If `EditorViewModel` is still wired to the
/// bold-blind stub, the "before" and "after" screenshots come out
/// byte-identical and this test fails, which is the correct, honest
/// signal for this wave.
final class CompositionRootWiringTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBoldToggleActuallyChangesRenderedCanvasPixels() throws {
        let app = XCUIApplication()
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

        XCTAssertTrue(app.buttons["تراجع"].waitForExistence(timeout: 15), "Editor did not open")

        // A short, thick-stroked run so a real weight change has visible
        // pixel coverage to move even at the sample sizes this sheet
        // inserts at.
        app.buttons["إضافة عنصر"].tap()
        let addTextFieldMenuItem = app.buttons["حقل نص"]
        XCTAssertTrue(addTextFieldMenuItem.waitForExistence(timeout: 5))
        addTextFieldMenuItem.tap()
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        // See `ArrangeModeEnterExitUITests.swift`'s matching comment: guard
        // against the intermittent first-tap-doesn't-focus flake by
        // confirming the software keyboard actually appeared, retapping
        // once if it didn't.
        if !app.keyboards.element.waitForExistence(timeout: 3) {
            textEditor.tap()
            XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "Software keyboard never appeared after tapping the text editor")
        }
        textEditor.typeText("ميم")
        app.buttons["إدراج"].tap()

        // Give the newly committed node one full run loop to actually
        // rasterize before the "before" capture.
        Thread.sleep(forTimeInterval: 1)
        let beforeBold = Self.canvasRegion(of: app.screenshot().image)

        app.buttons["الخط والحجم"].tap()
        let boldButton = app.buttons["B"]
        XCTAssertTrue(boldButton.waitForExistence(timeout: 5), "FontSettingsSheet did not show its Bold trait control for the selected node")
        boldButton.tap()
        // Scoped to `FontSettingsSheet`'s own navigation bar ("الخط
        // والتنسيق") ، see `InsertTextCommitUITests.swift`'s matching
        // comment: a bare `app.buttons["تم"]` is ambiguous against
        // `EditorScene`'s own (occluded but still-present) "تم" button.
        app.navigationBars["الخط والتنسيق"].buttons["تم"].tap()

        // The inspector's `setBold` call is synchronous, but the canvas's
        // own re-render/re-rasterize happens on the next run-loop turn(s);
        // give it the same settle time as the "before" capture.
        Thread.sleep(forTimeInterval: 1)
        let afterBold = Self.canvasRegion(of: app.screenshot().image)

        XCTAssertNotEqual(
            beforeBold.pngData(),
            afterBold.pngData(),
            "Toggling Bold produced no visible change on the canvas ، expected until Wave 1's FC-1 fix wires " +
            "AppContainer.fontProvider into EditorViewModel (today every font resolution still goes through " +
            "SystemFontStubProvider(), which does not vary by weight for most bundled Arabic faces)."
        )
    }

    /// Crops out the top status-bar/navigation-bar/memory-banner strip
    /// (≈22% of screen height ، wide enough to also clear
    /// `MemoryBannerView`, which can appear/disappear independently of
    /// this test's own actions and would otherwise be a false-difference
    /// source) and the bottom tool-rail/zoom-controls strip (≈18%),
    /// leaving the central canvas band both captures share. Proportional
    /// to the screenshot's own pixel size rather than fixed points, so it
    /// is not tied to one simulator's point-to-pixel scale.
    private static func canvasRegion(of image: UIImage) -> UIImage {
        let size = image.size
        let topInset = size.height * 0.22
        let bottomInset = size.height * 0.18
        let rect = CGRect(x: 0, y: topInset, width: size.width, height: max(0, size.height - topInset - bottomInset))
        guard let cgImage = image.cgImage, let cropped = cgImage.cropping(to: rect.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
