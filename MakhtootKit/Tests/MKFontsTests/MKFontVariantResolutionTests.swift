import CoreText
import Foundation
import MKFoundation
import Testing
@testable import MKFonts

/// Phase A ، real bold/italic font-variant resolution (no synthetic
/// emboldening: a genuine cut/axis, or the base font unchanged).
@Suite("MKFontRecord.defaultFace + MKRegistryFontProvider variant resolution")
struct MKFontVariantResolutionTests {
    // MARK: - Step 0: default-face selection

    /// `faces` is raw JSON order (alphabetical by filename), NOT sorted by
    /// weight ، `Amiri-Bold.ttf` sorts before `Amiri-Regular.ttf`, so
    /// `faces.first` used to silently select the Bold cut. `defaultFace`
    /// must prefer the true regular/400/normal cut instead.
    @Test func defaultFacePrefersRegular400OverAlphabeticallyFirstFace() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let expectations: [(fontID: String, expectedPostScriptName: String)] = [
            ("almarai", "Almarai-Regular"),
            ("amiri", "Amiri-Regular"),
            ("aref-ruqaa", "ArefRuqaa-Regular"),
            ("harmattan", "Harmattan-Regular"),
            ("lateef", "Lateef-Regular"),
            ("mirza", "Mirza-Regular"),
            ("scheherazade-new", "ScheherazadeNew-Regular"),
            ("tajawal", "Tajawal-Regular"),
            ("zain", "Zain-Regular"),
            ("ibm-plex-sans-arabic", "IBMPlexSansArabic-Regular"),
        ]
        for expectation in expectations {
            guard let record = await registry.record(for: expectation.fontID) else {
                Issue.record("\(expectation.fontID) did not load ، cannot verify defaultFace")
                continue
            }
            let defaultFace = record.defaultFace
            #expect(
                defaultFace?.postScriptName == expectation.expectedPostScriptName,
                "\(expectation.fontID).defaultFace was \(defaultFace?.postScriptName ?? "nil"), expected \(expectation.expectedPostScriptName)")
        }
    }

    /// Single-face families: `defaultFace` must still return the only
    /// face even when it isn't a 400/normal cut (weight-nearest-400
    /// fallback, and ultimately `faces.first`).
    @Test func defaultFaceReturnsTheOnlyFaceForSingleFaceFamilies() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        for fontID in ["lalezar", "rakkas", "jomhuria"] {
            guard let record = await registry.record(for: fontID) else {
                Issue.record("\(fontID) did not load")
                continue
            }
            #expect(record.faces.count == 1, "\(fontID) expected to be single-face for this test's premise")
            #expect(record.defaultFace?.postScriptName == record.faces.first?.postScriptName)
        }
    }

    @Test func defaultFaceHandlesEmptyFacesWithoutCrashing() {
        let record = MKFontRecord(
            fontID: "empty-test", familyName: "Empty", origin: .bundled,
            faces: [], categories: [], tags: [])
        #expect(record.defaultFace == nil)
    }

    // MARK: - Step 2: variant resolution

    @Test func variantResolutionReturnsGenuinelyDifferentFontForFamilyWithBoldCut() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()

        // Resolve amiri's regular default face by name, then request bold.
        guard let record = await registry.record(for: "amiri"),
              let regularFace = record.defaultFace else {
            Issue.record("amiri did not load")
            return
        }
        #expect(regularFace.postScriptName == "Amiri-Regular")

        let handle = MKFontHandle(postScriptName: regularFace.postScriptName, pointSize: 24)
        let regular = provider.resolve(handle)
        let bold = provider.resolve(handle, variant: MKFontVariantRequest(bold: true, italic: false))

        let regularPS = CTFontCopyPostScriptName(regular) as String
        let boldPS = CTFontCopyPostScriptName(bold) as String
        #expect(regularPS == "Amiri-Regular")
        #expect(boldPS != regularPS, "requesting bold on amiri should resolve to a genuinely different (Bold) cut")
        #expect(boldPS == "Amiri-Bold", "expected the real Amiri-Bold static cut")
    }

    @Test func variantResolutionReturnsSameFontForSingleFaceFamilyWithNoBoldCut() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()

        for fontID in ["lalezar", "rakkas", "jomhuria"] {
            guard let record = await registry.record(for: fontID), let face = record.defaultFace else {
                Issue.record("\(fontID) did not load")
                continue
            }
            let handle = MKFontHandle(postScriptName: face.postScriptName, pointSize: 24)
            let regular = provider.resolve(handle)
            let bold = provider.resolve(handle, variant: MKFontVariantRequest(bold: true, italic: false))
            let italic = provider.resolve(handle, variant: MKFontVariantRequest(bold: false, italic: true))

            let regularPS = CTFontCopyPostScriptName(regular) as String
            #expect(
                (CTFontCopyPostScriptName(bold) as String) == regularPS,
                "\(fontID) has no bold cut ، requesting bold must return the SAME font, never a synthesized one")
            #expect(
                (CTFontCopyPostScriptName(italic) as String) == regularPS,
                "\(fontID) has no italic cut ، requesting italic must return the SAME font, never a synthesized one")
        }
    }

    @Test func variantResolutionAppliesRealBoldItalicCombinedCutWhenBothRequested() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()

        guard let record = await registry.record(for: "amiri"), let face = record.defaultFace else {
            Issue.record("amiri did not load")
            return
        }
        let handle = MKFontHandle(postScriptName: face.postScriptName, pointSize: 24)
        let bothFont = provider.resolve(handle, variant: MKFontVariantRequest(bold: true, italic: true))
        let bothPS = CTFontCopyPostScriptName(bothFont) as String
        // Amiri ships a real BoldItalic static member (records.json:
        // Amiri-BoldItalic.ttf) ، requesting both traits should land on it,
        // not silently drop one trait.
        #expect(bothPS == "Amiri-BoldItalic")
    }

    /// A variable-font family (single-file, real `wght` axis):
    /// `NotoNaskhArabic[wght].ttf`. Requesting bold must produce a font
    /// whose variation axes report a changed `wght` value ، a genuine
    /// designer-drawn interpolation, not a no-op and not synthesis.
    @Test func variableFontWeightRequestChangesTheWghtAxisValue() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()

        guard let record = await registry.record(for: "noto-naskh-arabic"), let face = record.defaultFace else {
            Issue.record("noto-naskh-arabic did not load")
            return
        }
        #expect(face.isVariable, "noto-naskh-arabic's single face is expected to be a variable font for this test's premise")

        let handle = MKFontHandle(postScriptName: face.postScriptName, pointSize: 24)
        let regular = provider.resolve(handle)
        let bold = provider.resolve(handle, variant: MKFontVariantRequest(bold: true, italic: false))

        // NSNumber keys/values (not `CFNumber`) ، the dictionary
        // `CTFontCopyVariation` returns is an NSDictionary under the hood,
        // which bridges reliably to `[NSNumber: NSNumber]` in Swift.
        let regularVariation = CTFontCopyVariation(regular) as? [NSNumber: NSNumber]
        let boldVariation = CTFontCopyVariation(bold) as? [NSNumber: NSNumber]

        // wght axis tag: 0x77676874 ('w','g','h','t' packed big-endian).
        let wghtTag = NSNumber(value: 0x77676874)
        let regularWeight = regularVariation?[wghtTag]?.doubleValue
        let boldWeight = boldVariation?[wghtTag]?.doubleValue

        #expect(boldWeight != nil, "expected the bold-requested font to report a wght variation value")
        if let regularWeight, let boldWeight {
            #expect(boldWeight > regularWeight, "requesting bold should raise wght above the regular instance's value")
        }
    }
}
