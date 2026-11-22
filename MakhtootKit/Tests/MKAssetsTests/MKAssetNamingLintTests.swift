import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 14 accept criteria: "manifest lint: nameAr
// non-empty, Arabic-script regex; tag coverage."
@Suite("Arabic naming & tags lint (T14)")
struct MKAssetNamingLintTests {
    /// Arabic-script Unicode ranges (mirrors `MKFoundation.MKRTLUtilities
    /// .isRTLCharacter`'s detection ranges ، reimplemented locally per this
    /// module's "no MKFoundation-string-utility dependency beyond the
    /// entitlement/id types already needed" posture; `MKAssets` does
    /// already depend on `MKFoundation`, so this COULD call `MKRTLUtilities`
    /// directly ، kept local anyway since a naming-lint test asserting
    /// against the exact same ranges the production code uses would be
    /// tautological; an independently-stated range list is a stronger
    /// check).
    // C8-1: 0x0870...0x089F (Arabic Extended-B) added alongside the two
    // extended blocks already listed, mirroring the same fix in
    // `MKRTLUtilities.arabicRanges`.
    private static let arabicRanges: [ClosedRange<UInt32>] = [0x0600...0x06FF, 0x0750...0x077F, 0x0870...0x089F, 0x08A0...0x08FF]

    private func isArabicScript(_ string: String) -> Bool {
        string.unicodeScalars.contains { scalar in Self.arabicRanges.contains { $0.contains(scalar.value) } }
    }

    @Test func everyAssetHasANonEmptyArabicScriptName() {
        for descriptor in MKAssetLibrary.standard.all {
            #expect(!descriptor.nameAr.isEmpty, "\(descriptor.assetID)")
            #expect(isArabicScript(descriptor.nameAr), "\(descriptor.assetID): '\(descriptor.nameAr)' is not Arabic-script")
        }
    }

    @Test func noAssetNameContainsLatinLetters() {
        for descriptor in MKAssetLibrary.standard.all {
            let hasLatin = descriptor.nameAr.unicodeScalars.contains { CharacterSet(charactersIn: "a"..."z").contains($0) || CharacterSet(charactersIn: "A"..."Z").contains($0) }
            #expect(!hasLatin, "\(descriptor.assetID): '\(descriptor.nameAr)' contains Latin letters")
        }
    }

    @Test func everyAssetHasAtLeastTwoTags() {
        for descriptor in MKAssetLibrary.standard.all {
            #expect(descriptor.tags.count >= 2, "\(descriptor.assetID) has \(descriptor.tags.count) tag(s)")
        }
    }

    @Test func everyTagIsNonEmptyArabicScript() {
        for descriptor in MKAssetLibrary.standard.all {
            for tag in descriptor.tags {
                #expect(!tag.isEmpty, "\(descriptor.assetID)")
                #expect(isArabicScript(tag), "\(descriptor.assetID): tag '\(tag)' is not Arabic-script")
            }
        }
    }

    @Test func star8RosetteMatchesThePacketsOwnWorkedExample() {
        // Task 1's own example: `nameAr: "نجمة ثمانية"`, tags including
        // `["هندسي", "إسلامي", "نجمة"]` ، the basic-shape star-8 (not the
        // ornament rosette, which is separately named "خاتم" per task 5).
        let star8 = MKAssetLibrary.standard.descriptor(assetID: "shape.star-8")!
        #expect(star8.nameAr == "نجمة ثمانية")
        #expect(star8.tags.contains("نجمة"))
        #expect(star8.tags.contains("هندسي"))
    }
}
