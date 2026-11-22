import CoreGraphics
import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 7 accept criteria: "zero font-derived paths
// (provenance audit greps origin notes); stroke-quality visual QA at large
// scale."
@Suite("MKCalligraphicGenerator (T7)")
struct MKCalligraphicTests {
    @Test func atLeastTenCalligraphicElements() {
        let elements = MKCalligraphicGenerator.makeAll()
        #expect(elements.count >= 10)
        #expect(elements.allSatisfy { $0.category == .calligraphicElements })
        #expect(Set(elements.map(\.assetID)).count == elements.count)
    }

    @Test func zeroFontDerivedPathsPerProvenanceNotes() {
        // The generated notes explicitly AFFIRM "no font file" was
        // consulted (a desirable, sanctioned statement ، ASSET_SOURCING_
        // RULES.md §4 asks for exactly this record) ، so the check here is
        // for the FORBIDDEN phrasing (a note that says a font WAS used),
        // not for the bare substring "font", which the affirmative
        // disclaimer itself legitimately contains.
        let store = MKAssetProvenanceStore.standard
        for element in MKCalligraphicGenerator.makeAll() {
            let notes = store.provenance(for: element.assetID)?.notes ?? ""
            let lowered = notes.lowercased()
            #expect(!lowered.contains("derived from font"), "\(element.assetID)")
            #expect(!lowered.contains("font glyph"), "\(element.assetID)")
            #expect(lowered.contains("no font file"), "\(element.assetID) should affirmatively record that no font file was consulted")
            #expect(!MKAssetForbiddenSourceMarkers.containsForbiddenMarker(notes))
        }
    }

    @Test func everyCalligraphicElementRendersAtLargeScale() {
        for element in MKCalligraphicGenerator.makeAll() {
            let image = MKAssetThumbnailRenderer.render(descriptor: element, size: CGSize(width: 2048, height: 2048))
            #expect(image != nil, "\(element.assetID)")
        }
    }

    @Test func ornamentalRuleIsPlainAniconicNoTextContent() {
        // Task 7: "bismillah-LENGTH rule (a plain ornamental rule ، NO
        // text, aniconic)." Verified structurally: the geometry is pure
        // path data (no text/font references possible in `MKAssetGeometry`
        // at all ، the type has no string-rendering capability), and the
        // name/tags contain no Qur'anic phrase.
        let rule = MKCalligraphicGenerator.makeAll().first { $0.assetID == "calligraphic.ornamental-rule" }!
        #expect(!rule.nameAr.contains("بسم"))
        #expect(!rule.tags.contains { $0.contains("بسم") })
    }

    @Test func ribbonBuilderProducesAClosedNonDegenerateOutline() {
        let subpath = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: -10, y: 0), CGPoint(x: 0, y: 5), CGPoint(x: 10, y: 0)], widths: [0, 4, 0])
        #expect(subpath.isClosed)
        // 3 centerline points → 3 "left" offset points + 3 "right" offset
        // points = 6 outline vertices → 6 closing edges.
        #expect(subpath.segments.count == 6)
    }
}
