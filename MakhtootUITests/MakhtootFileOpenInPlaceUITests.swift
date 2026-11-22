import XCTest

/// FC-6 (AUDIT_2026-07-28.md): `.makhtoot` open-in-place import
/// (`RootShellView.onOpenURL` → `openExternalPackage(at:)` →
/// `container.projectLibrary.importExternalPackage(at:)`), driven through
/// the real system "Open In" surface (Files.app), not a bypass.
///
/// **Known, confirmed environment constraint (read before editing this
/// file).** Makhtoot registers `.makhtoot` as an owned document type
/// (`Info.plist`'s `CFBundleDocumentTypes`/`UTExportedTypeDeclarations`,
/// `LSSupportsOpeningDocumentsInPlace = true`) but has no custom URL
/// scheme (`CFBundleURLTypes`) and no `UIFileSharingEnabled`, so there is
/// no in-process, source-code-free way for a *separate* XCUITest process
/// to hand a file to Files.app — `Foundation.Process`/shell-out is
/// unavailable on iOS, so the test bundle itself cannot invoke `xcrun
/// simctl` the way a host-side CI step could. Seeding a fixture is
/// therefore a HOST-SIDE step, run once before `xcodebuild test`, not
/// something this file can do on its own:
///
/// ```bash
/// FILES_CONTAINER=$(xcrun simctl get_app_container <device-udid> com.apple.DocumentsApp data)
/// cp -R /path/to/UITestFixture.makhtoot "$FILES_CONTAINER/Documents/MakhtootUITestFixture.makhtoot"
/// ```
///
/// A real, valid `.makhtoot` package for that fixture is easiest to
/// produce by letting the app itself create one (any project made via the
/// real `NewProjectSheet` flow is a genuine package under this app's own
/// `Documents/Projects/` container) and copying that.
///
/// Without a pre-seeded fixture at that well-known name, this test
/// self-skips with a message pointing back at this comment, rather than
/// silently reporting a false pass OR hard-failing a suite that has no
/// way to provision its own precondition.
final class MakhtootFileOpenInPlaceUITests: XCTestCase {
    private static let fixtureBaseName = "MakhtootUITestFixture"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOpeningAMakhtootPackageFromFilesImportsItInPlace() throws {
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.launch()

        // "Browse" is Files.app's own tab housing "On My iPhone"/"On My
        // iPad"/"iCloud Drive" ، tapped defensively (some iOS versions land
        // there by default, in which case this is a harmless no-op tap
        // attempt guarded by `exists`). Scoped to `tabBars` specifically:
        // a bare `files.buttons["تصفح"]` is ambiguous against the
        // navigation bar's OWN back button, which (standard iOS back-
        // button convention) also carries the previous screen's title as
        // its own label ، confirmed on-device, not hypothetical.
        let browseTab = files.tabBars.buttons["Browse"].exists ? files.tabBars.buttons["Browse"] : files.tabBars.buttons["تصفح"]
        if browseTab.exists, !browseTab.isSelected {
            browseTab.tap()
        }

        // Browse can land on either a location PICKER (iCloud Drive / On
        // My iPhone / …, observed on some launches) or directly inside the
        // local-storage listing (observed on others, apparently depending
        // on Files.app's own remembered navigation state) ، descend into
        // "On My iPhone"/"On My iPad" defensively when it is offered as a
        // row rather than already the active view.
        let onThisDeviceRow = files.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "على ال", "On My")
        ).firstMatch
        if onThisDeviceRow.waitForExistence(timeout: 3) {
            onThisDeviceRow.tap()
        }

        let fixtureCell = files.cells.containing(
            NSPredicate(format: "label CONTAINS[c] %@", Self.fixtureBaseName)
        ).firstMatch
        let fixtureStaticText = files.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", Self.fixtureBaseName)
        ).firstMatch

        guard fixtureCell.waitForExistence(timeout: 8) || fixtureStaticText.waitForExistence(timeout: 2) else {
            throw XCTSkip(
                "No pre-seeded '\(Self.fixtureBaseName).makhtoot' fixture found in Files.app's local storage. " +
                "This flow needs a host-side seed step before `xcodebuild test` ، see this file's header comment " +
                "for the exact `xcrun simctl get_app_container` + `cp -R` sequence."
            )
        }

        if fixtureCell.exists {
            fixtureCell.tap()
        } else {
            fixtureStaticText.tap()
        }

        // Owning-app UTI handler: tapping a file Makhtoot owns typically
        // either opens Makhtoot directly or offers a "Open in Makhtoot"/
        // preview affordance first ، handle both without assuming which.
        let openInMakhtoot = files.buttons["فتح في مخطوط"].exists
            ? files.buttons["فتح في مخطوط"]
            : files.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Makhtoot")).firstMatch
        if openInMakhtoot.waitForExistence(timeout: 5) {
            openInMakhtoot.tap()
        }

        let makhtoot = XCUIApplication(bundleIdentifier: "net.binjamshid.makhtoot")
        XCTAssertTrue(
            makhtoot.wait(for: .runningForeground, timeout: 15),
            "Makhtoot did not come to the foreground after opening the fixture package from Files"
        )

        // `RootShellView.openExternalPackage(at:)` either lands on the
        // editor (`nav.openEditor`, success) or an alert
        // ("تعذّر فتح الملف", failure) ، both are real, distinguishable
        // production outcomes; only a plain timeout (neither ever
        // appearing) is a genuine failure of the open-in-place path
        // itself.
        let editorOpened = makhtoot.buttons["تراجع"].waitForExistence(timeout: 15)
        let openFailedAlert = makhtoot.alerts["تعذّر فتح الملف"].waitForExistence(timeout: 2)
        XCTAssertTrue(
            editorOpened || openFailedAlert,
            "Neither the editor nor the documented failure alert appeared after opening the .makhtoot fixture in place"
        )
        XCTAssertTrue(editorOpened, "Open-in-place import failed: \(openFailedAlert ? "RootShellView showed its 'تعذّر فتح الملف' alert" : "no recognizable outcome")")
    }
}
