import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKExport

// WS-08 packet §5 task 5 accept: "truth-table tests across entitlement
// states (`FakeEntitlement`) × formats × content flags; grace/billingRetry
// behave as premium (D-113)." Also D-229's gating-enforcement closures:
// (1) presence-based `premiumContentPresent` (hidden/locked nodes still
// count ، T-EXP-16 analog), (2) G20 free-tier preset-membership check.
@Suite struct ExportGateTests {
    let gate = MKExportGate()

    // MARK: - Format gating

    @Test func freeUserCanExportJPEGAtASmallSize() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(decision.isAllowed)
    }

    @Test func freeUserCannotExportPNGOpaque() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .pngOpaque, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(decision == .blocked(.formatRequiresPremium(.pngOpaque)))
    }

    @Test func freeUserCannotExportSVGOrVectorPDFOrCMYKPDF() {
        let scene = TestScenes.rectScene()
        for format: MKExportFormat in [.svg, .pdfVectorRGB, .pdfVectorCMYK] {
            let request = MKExportRequest(format: format, target: .preset(id: "social.square"))
            let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
            #expect(decision == .blocked(.formatRequiresPremium(format)))
        }
    }

    @Test func premiumUserCanExportEveryFormat() {
        let scene = TestScenes.rectScene()
        for format: MKExportFormat in [.jpegDefault, .pdfRaster, .pngOpaque, .pngAlpha, .svg, .pdfVectorRGB, .pdfVectorCMYK] {
            let request = MKExportRequest(format: format, target: .preset(id: "social.square"))
            let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
            #expect(decision.isAllowed, "premium user should be allowed \(format)")
        }
    }

    @Test func freeTierPDFRasterIsAllowedFormatWise() {
        // pdfRaster is a FREE-tier format (D-118) even though this
        // session's ExportCoordinator has no writer for it yet ، the
        // GATE's job is format-matrix correctness, independent of writer
        // maturity (ExportCoordinator throws formatNotYetImplemented
        // separately, see ExportCoordinatorTests).
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .pdfRaster, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(decision.isAllowed)
    }

    // MARK: - Transparent background legality

    @Test func transparentBackgroundOnlyLegalForPNGAlpha() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"), background: .transparent)
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision == .blocked(.transparentBackgroundNotSupported(.jpegDefault)))
    }

    @Test func transparentBackgroundLegalForPNGAlphaPremium() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .pngAlpha, target: .preset(id: "social.square"), background: .transparent)
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision.isAllowed)
    }

    // MARK: - G20: engine-level free-tier preset membership (D-229(2))

    @Test func freeUserCannotSelectAPremiumOnlyPreset() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "print.a4"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(decision == .blocked(.presetRequiresPremium(presetID: "print.a4")))
    }

    @Test func premiumUserCanSelectAPremiumOnlyPreset() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .pdfVectorRGB, target: .preset(id: "print.a4"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision.isAllowed)
    }

    @Test func unknownPresetIsBlocked() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "no.such.preset"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision == .blocked(.unknownPreset(presetID: "no.such.preset")))
    }

    @Test func freeUserCannotUseCustomDimensions() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .jpegDefault, target: .custom(pixelSize: CGSize(width: 500, height: 500)))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(decision == .blocked(.customDimensionsRequirePremium))
    }

    @Test func premiumUserCanUseCustomDimensions() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 5000, height: 3000)))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision == .allowed(resolvedPixelSize: CGSize(width: 5000, height: 3000)))
    }

    // MARK: - Content gating (D-119/D-229) ، fonts, photo backgrounds, assets

    @Test func freeUserBlockedByPremiumFontLiveText() {
        let scene = TestScenes.liveTextScene(font: MKFontRef(fontID: "premium.diwani-royal", postScriptName: "DiwaniRoyal"))
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        guard case .blocked(.premiumContentPresent(let items)) = decision else {
            Issue.record("expected premiumContentPresent block, got \(decision)")
            return
        }
        #expect(items.contains(.premiumOrImportedFont(fontID: "premium.diwani-royal", postScriptName: "DiwaniRoyal")))
    }

    @Test func freeUserBlockedByUserImportedFontLiveText() {
        let scene = TestScenes.liveTextScene(font: MKFontRef(fontID: "user.abc123", postScriptName: "MyCustomFont", userImported: true))
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(!decision.isAllowed)
    }

    @Test func freeUserNotBlockedByBundledFont() {
        let scene = TestScenes.liveTextScene(font: MKFontRef(fontID: "bundled.amiri.regular", postScriptName: "Amiri-Regular"))
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(decision.isAllowed)
    }

    @Test func freeUserBlockedByPhotoCanvasBackground() {
        let scene = TestScenes.photoBackgroundScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        guard case .blocked(.premiumContentPresent(let items)) = decision else {
            Issue.record("expected premiumContentPresent block, got \(decision)")
            return
        }
        #expect(items.contains { if case .photoBackground = $0 { return true }; return false })
    }

    @Test func freeUserBlockedByPhotoBackgroundUseImageNode() {
        let scene = TestScenes.photoBackgroundUseImageNodeScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(!decision.isAllowed)
    }

    @Test func freeUserBlockedByExternallySuppliedPremiumAssetNodeID() {
        let groupID = MKNodeID()
        let scene = TestScenes.groupScene(groupID: groupID)
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree, premiumAssetNodeIDs: [groupID])
        guard case .blocked(.premiumContentPresent(let items)) = decision else {
            Issue.record("expected premiumContentPresent block, got \(decision)")
            return
        }
        #expect(items.contains(.premiumAsset(nodeID: groupID)))
    }

    /// D-229(1): the presence-based walk must NOT be render-based ، a
    /// HIDDEN premium-font live-text node still counts (T-EXP-16 analog).
    @Test func hiddenPremiumFontLiveTextStillBlocksFreeExport() {
        let scene = TestScenes.liveTextScene(
            font: MKFontRef(fontID: "premium.thuluth-gold", postScriptName: "ThuluthGold"),
            hidden: true
        )
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        guard case .blocked(.premiumContentPresent(let items)) = decision else {
            Issue.record("expected premiumContentPresent block even though the node is hidden, got \(decision)")
            return
        }
        #expect(!items.isEmpty)
    }

    @Test func hiddenPhotoBackgroundUseImageNodeStillBlocksFreeExport() {
        let scene = TestScenes.photoBackgroundUseImageNodeScene(hidden: true)
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree)
        #expect(!decision.isAllowed)
    }

    @Test func premiumUserIsNeverBlockedByContentFlags() {
        let scene = TestScenes.liveTextScene(font: MKFontRef(fontID: "premium.diwani-royal", postScriptName: "DiwaniRoyal"))
        let request = MKExportRequest(format: .pngOpaque, target: .preset(id: "social.square"))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision.isAllowed)
    }

    // MARK: - D-113 precedence: grace/billingRetry/trial behave as premium

    @Test(arguments: [
        FakeEntitlementResolver.subscribed,
        FakeEntitlementResolver.inGracePeriod,
        FakeEntitlementResolver.inBillingRetry,
        FakeEntitlementResolver.trial,
        FakeEntitlementResolver.alwaysPremium,
    ])
    func everyNonFreeStateBehavesAsFullPremium(_ resolver: FakeEntitlementResolver) {
        let scene = TestScenes.liveTextScene(font: MKFontRef(fontID: "premium.diwani-royal", postScriptName: "DiwaniRoyal"))
        let request = MKExportRequest(format: .svg, target: .custom(pixelSize: CGSize(width: 3000, height: 2000)))
        let decision = gate.evaluate(request, scene: scene, entitlement: resolver)
        #expect(decision.isAllowed, "\(resolver.state) must behave as premium (D-113)")
    }

    // MARK: - Resolved pixel size

    @Test func resolvedSizeIsClampedForFreeTierAndNativeForPremium() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .jpegDefault, target: .preset(id: "social.storyReel"))
        guard case .allowed(let freeSize) = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysFree) else {
            Issue.record("expected allowed")
            return
        }
        #expect(Double(freeSize.width) * Double(freeSize.height) <= Double(MKFreeTierBudget.effectivePixelBudget) + 1)

        let pdfRequest = MKExportRequest(format: .pdfVectorRGB, target: .preset(id: "social.storyReel"))
        guard case .allowed(let premiumSize) = gate.evaluate(pdfRequest, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium) else {
            Issue.record("expected allowed")
            return
        }
        #expect(premiumSize == CGSize(width: 1080, height: 1920))
    }

    @Test func tooSmallCustomSizeIsBlockedEvenForPremium() {
        let scene = TestScenes.rectScene()
        let request = MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 4, height: 4)))
        let decision = gate.evaluate(request, scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium)
        #expect(decision == .blocked(.invalidTargetSize))
    }
}
