import Testing
import CoreGraphics
@testable import MKExport

// WS-08 packet §5 task 7 accept: "table matches the BRIEF preset list;
// unit tests on pt↔px DPI math."
@Suite struct ExportPresetsTests {
    @Test func catalogContainsEveryBriefLockedPreset() {
        let ids = Set(MKExportPresetCatalog.standard.presets.map(\.id))
        let expected: Set<String> = [
            "social.square", "social.storyReel", "social.messagingStatus",
            "social.portrait", "social.landscape",
            "wallpaper.iphone", "wallpaper.ipad",
            "print.a5", "print.a4", "print.a3", "print.businessCard",
        ]
        #expect(expected.isSubset(of: ids))
    }

    @Test func squarePresetIs1080AndFreeTierEligible() {
        let square = MKExportPresetCatalog.standard.preset(id: "social.square")
        #expect(square?.pixelWidth == 1080)
        #expect(square?.pixelHeight == 1080)
        #expect(square?.freeTierEligible == true)
        // Already within budget ، task 6's "1080x1080 untouched" applies.
        #expect(square?.freeResolvedPixelSize == square?.pixelSize)
    }

    @Test func printAndWallpaperPresetsArePremiumOnly() {
        for id in ["print.a4", "print.a5", "print.a3", "print.businessCard", "wallpaper.iphone", "wallpaper.ipad"] {
            let preset = MKExportPresetCatalog.standard.preset(id: id)
            #expect(preset?.freeTierEligible == false, "\(id) must be premium-only")
        }
    }

    @Test func a4At300DPIMatchesMillimeterMath() throws {
        let a4 = try #require(MKExportPresetCatalog.standard.preset(id: "print.a4"))
        #expect(a4.dpi == 300)
        // 210mm / 25.4 * 300 ≈ 2480.3px, 297mm / 25.4 * 300 ≈ 3507.9px.
        #expect(abs(Double(a4.pixelWidth) - 2480) <= 1)
        #expect(abs(Double(a4.pixelHeight) - 3508) <= 1)
    }

    @Test func businessCardMatchesMillimeterMath() throws {
        let card = try #require(MKExportPresetCatalog.standard.preset(id: "print.businessCard"))
        // 90mm / 25.4 * 300 ≈ 1063.0px, 55mm / 25.4 * 300 ≈ 649.6px.
        #expect(abs(Double(card.pixelWidth) - 1063) <= 1)
        #expect(abs(Double(card.pixelHeight) - 650) <= 1)
    }

    @Test func unknownPresetIDReturnsNil() {
        #expect(MKExportPresetCatalog.standard.preset(id: "no.such.preset") == nil)
    }

    @Test func storyReelPresetIsFreeTierEligibleAtItsBaselineSize() throws {
        let preset = try #require(MKExportPresetCatalog.standard.preset(id: "social.storyReel"))
        #expect(preset.pixelWidth == 1080)
        #expect(preset.pixelHeight == 1920)
        #expect(preset.freeTierEligible)
        // 1080x1920 = 2,073,600 px > 2MP, so the free-resolved size differs
        // from the raw preset size (§16.8's own worked example, 1080×1350
        // → clamp) ، free tier still gets a slightly smaller image.
        #expect(preset.freeResolvedPixelSize != preset.pixelSize)
        #expect(Double(preset.freeResolvedPixelSize.width) * Double(preset.freeResolvedPixelSize.height) <= Double(MKFreeTierBudget.effectivePixelBudget) + 1)
    }

    // MARK: - Custom-dimension validator (task 7)

    @Test func customDimensionValidatorRejectsTooSmall() {
        #expect(MKCustomDimensionValidator.validate(CGSize(width: 4, height: 4)) == .tooSmall)
        #expect(MKCustomDimensionValidator.validate(CGSize(width: 16, height: 16)) == .ok)
    }

    @Test func customDimensionValidatorWarnsAboveDiskFeasibilityThreshold() {
        #expect(MKCustomDimensionValidator.validate(CGSize(width: 20000, height: 20000)) == .warnDiskFeasibility)
        #expect(MKCustomDimensionValidator.validate(CGSize(width: 1000, height: 1000)) == .ok)
    }
}
