import XCTest

/// FC-6 (AUDIT_2026-07-28.md): the export paywall gate is Makhtoot's
/// revenue boundary (`EditorScene.swift`'s export `Menu`: SVG/vector-PDF
/// check `container.entitlementProvider.isEntitled(.premiumExportFormats)`
/// and call `nav.presentPaywall(.premiumFeatureTap(.exportFormat))`
/// *before* exporting) and had zero automated coverage before this target.
///
/// This exercises SVG export specifically because that gate check has
/// been correct since before this session (unlike JPEG/PNG sharing, which
/// FC-2/Wave 1 fixes separately) — it does not depend on any fix landing
/// in a later wave, so it is stable to run starting in Wave 0.
///
/// **Precondition this test cannot control:** the paywall only appears
/// while `MKEntitlementProviding.state == .free` (D-113 precedence,
/// `MKEntitlementState.swift`). A device mid-trial or already premium
/// would see the export proceed directly instead — a UI test process
/// cannot read or reset this device's persisted Keychain/iCloud-KVS trial
/// record (a separate process from the app under test), and no launch
/// argument for it exists in app source today. If this test fails with
/// the paywall never appearing, check entitlement state before assuming a
/// regression.
final class PremiumExportPaywallGateUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSVGExportOnFreeTierPresentsThePaywall() throws {
        let app = XCUIApplication()
        // See `InsertTextCommitUITests.swift`'s matching comment: skips
        // both first-launch onboarding and the in-editor first-use tour
        // overlay, which would otherwise sit on top of the export toolbar
        // button this test taps.
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

        XCTAssertTrue(app.buttons["تراجع"].waitForExistence(timeout: 15), "Editor did not open for the new project")

        // Timeout generous (20s, not the usual 10s): this toolbar button sits
        // in the same `.primaryAction` `ToolbarItemGroup` the file header's
        // reachability note describes, and its layout pass measurably lags
        // behind the "تراجع" button's own appearance under back-to-back UI
        // test load — observed as an intermittent existence-timeout here
        // specifically in full-suite runs, never in an isolated run of this
        // test alone.
        let exportMenuButton = app.buttons["تصدير"]
        XCTAssertTrue(exportMenuButton.waitForExistence(timeout: 20))
        exportMenuButton.tap()

        let exportSVGItem = app.buttons["تصدير SVG"]
        XCTAssertTrue(exportSVGItem.waitForExistence(timeout: 5), "Export menu did not present the SVG item")
        exportSVGItem.tap()

        // PW-07: `restoreButton` ("استعادة المشتريات") is unconditionally
        // present on `PaywallView` regardless of catalog load state — the
        // single most state-independent signal the paywall is what's on
        // screen, rather than depending on `MKProductCatalog.load()`
        // (network/StoreKit-configuration dependent) having already
        // resolved.
        let restorePurchasesButton = app.buttons["استعادة المشتريات"]
        XCTAssertTrue(
            restorePurchasesButton.waitForExistence(timeout: 15),
            "PaywallView did not appear after requesting a premium export format on a free-tier account " +
            "(see this file's header comment: this fails if the device is currently mid-trial/premium instead of free)"
        )

        // PW-01: a close control must always be present, never nested.
        XCTAssertTrue(app.buttons["إغلاق"].exists, "Paywall is missing its close control (PW-01)")
    }
}
