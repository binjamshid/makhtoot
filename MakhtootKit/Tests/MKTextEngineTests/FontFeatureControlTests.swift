import Testing
import CoreText
import MKModel
@testable import MKTextEngine

/// WS-03 packet §5 task 2 (D-108 feature control). The packet's
/// glyph-count-difference criterion ("with dlig ON vs OFF in Amiri (or SF
/// Arabic fallback)...") is font-dependent: the system SF font exposes no
/// discretionary ligature that changes glyph counts (verified empirically,
/// docs/impl-log/WS-03.md), so the count-difference assertion joins the
/// WS-09 Amiri fixture re-run. What IS testable now, and is tested here:
/// the exact feature dictionaries emitted per setting (the "attribute
/// dump" criterion), the rlig-cannot-be-disabled API guarantee, and the
/// required-ligature (lam-alif) survival under `.off`.
@Suite struct FontFeatureControlTests {

    @Test func standardSettingEmitsNoOverrides() {
        #expect(MKFontFeatureControl.featureSettings(for: .standard).isEmpty)
        #expect(MKFontFeatureControl.ligatureAttributeValue(for: .standard) == 1)
    }

    @Test func discretionarySettingEnablesDligAndCalt() {
        let settings = MKFontFeatureControl.featureSettings(for: .discretionaryOn)
        let tags = settings.compactMap { $0[kCTFontOpenTypeFeatureTag] as? String }
        let values = settings.compactMap { $0[kCTFontOpenTypeFeatureValue] as? Int }
        #expect(Set(tags) == ["dlig", "calt"])
        #expect(values.allSatisfy { $0 == 1 })
        #expect(MKFontFeatureControl.ligatureAttributeValue(for: .discretionaryOn) == 1)
    }

    @Test func offSettingDisablesLigaAndDligOnly() {
        let settings = MKFontFeatureControl.featureSettings(for: .off)
        let tags = settings.compactMap { $0[kCTFontOpenTypeFeatureTag] as? String }
        let values = settings.compactMap { $0[kCTFontOpenTypeFeatureValue] as? Int }
        #expect(Set(tags) == ["liga", "dlig"])
        #expect(values.allSatisfy { $0 == 0 })
        #expect(MKFontFeatureControl.ligatureAttributeValue(for: .off) == 0)
    }

    @Test func rligIsNeverEmittedByAnySetting() {
        // Packet task 2 accept criterion: "rlig disable attempts are
        // rejected by API design (no such option exposed)" ، the closed
        // MKLigatureSetting enum is the rejection mechanism; no case may
        // ever emit an rlig (or calt=0) setting.
        for setting in [MKLigatureSetting.standard, .discretionaryOn, .off] {
            let tags = MKFontFeatureControl.featureSettings(for: setting)
                .compactMap { $0[kCTFontOpenTypeFeatureTag] as? String }
            #expect(!tags.contains("rlig"), "\(setting) must never touch rlig")
        }
    }

    @Test func featureConfiguredFontCarriesTheSettingsInItsAttributes() {
        // The "attribute dump" check on the actual font object: Core Text
        // retains a feature setting on the configured font only when the
        // font actually SUPPORTS that feature (verified empirically ،
        // unsupported tags are silently dropped, which is correct/harmless
        // behavior; docs/impl-log/WS-03.md). The system font supports
        // `liga`, so `.off` (liga=0) must round-trip.
        let base = CTFontCreateUIFontForLanguage(.system, 36, "ar" as CFString)!
        let configured = MKFontFeatureControl.font(base, applying: .off)
        let attribute = CTFontCopyAttribute(configured, kCTFontFeatureSettingsAttribute)
        #expect(attribute != nil, "a supported feature setting (liga=0) must land in the configured font's attributes")

        // `.standard` applies no settings and must return the base font
        // unchanged (fast path).
        let untouched = MKFontFeatureControl.font(base, applying: .standard)
        #expect(untouched == base)
    }

    @Test func lamAlifSurvivesLigaturesOff() {
        // rlig is non-negotiable: «لا» must stay one glyph even at `.off`
        // (required-ligature survival ، the load-bearing D-108 guarantee).
        let line = Fixtures.engine.shapeSingleLine(
            MKShapingRequest(string: "لا", style: Fixtures.style(ligatures: .off)))
        #expect(line.glyphCount == 1, "lam-alif is a required (rlig) ligature and must survive .off")
        #expect(line.clusterMap.clusters.first?.kind == .ligature)
    }

    @Test func standardAndOffProduceSameGlyphCountForNonLigatedText() {
        // Sanity: feature toggling must not perturb text with no optional
        // ligatures in play (SF Arabic: plain letters).
        let standard = Fixtures.engine.shapeSingleLine(
            MKShapingRequest(string: "محمد", style: Fixtures.style(ligatures: .standard)))
        let off = Fixtures.engine.shapeSingleLine(
            MKShapingRequest(string: "محمد", style: Fixtures.style(ligatures: .off)))
        #expect(standard.glyphCount == off.glyphCount)
    }
}
