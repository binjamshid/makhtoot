import Foundation
import MKFoundation
import Testing
@testable import MKModel

/// WS-02 packet §5 task 4 accept criteria: Codable round-trip of a
/// hand-built composition for "لا"; provenance fields all non-optional
/// where D-106 requires.
@Suite("Arranged node family (GlyphNode/MarkNode/LigatureGroup)")
struct ArrangedCompositionTests {
    @Test func laLigatureCompositionRoundTripsThroughJSON() throws {
        let scene = FixtureScenes.arrangedLaScene()
        let data = try MKSceneCodec.encode(scene)
        let decoded = try MKSceneCodec.decode(data)
        #expect(decoded == scene)

        guard case .arranged(let arranged) = decoded.nodes[0] else {
            Issue.record("expected an arranged node")
            return
        }
        #expect(arranged.composition.sourceBackup.sourceString == "لا")
        #expect(arranged.composition.nodes.count == 1)
        guard case .ligature(let group) = arranged.composition.nodes[0] else {
            Issue.record("expected a ligature child")
            return
        }
        #expect(group.provenance.codepoints == [0x0644, 0x0627])
        guard case .composed(let composed) = group.state else {
            Issue.record("expected composed ligature state")
            return
        }
        #expect(composed.decomposable == true)
    }

    @Test func glyphNodeCarriesFullProvenanceNonOptionally() {
        let clusterID = MKClusterID()
        let provenance = MKProvenance(
            clusterID: clusterID, codepoints: [0x062D], utf16Start: 0, utf16Length: 1,
            bidiLevel: 1, visualIndex: 0, logicalIndex: 0
        )
        let glyph = MKGlyphNode(
            glyph: MKGlyphRef(glyphID: 10, font: .systemFallback, fontChecksum: "abc"),
            layout: MKGlyphLayout(position: .zero, advance: CGSize(width: 20, height: 0)),
            provenance: provenance
        )
        // All of these are non-optional struct fields ، merely accessing
        // them (no force-unwrap needed) IS the "non-optional" assertion.
        #expect(glyph.provenance.codepoints == [0x062D])
        #expect(glyph.provenance.clusterID == clusterID)
        #expect(glyph.joining.form == .isolated)
    }

    @Test func markNodeDefaultsToFollowingItsBase() {
        let provenance = MKProvenance(
            clusterID: MKClusterID(), codepoints: [0x064E], utf16Start: 1, utf16Length: 1,
            bidiLevel: 1, visualIndex: 0, logicalIndex: 0
        )
        let baseID = MKNodeID()
        let mark = MKMarkNode(
            glyph: MKGlyphRef(glyphID: 99, font: .systemFallback, fontChecksum: "abc"),
            attachedTo: baseID, provenance: provenance, markClass: .tashkeel
        )
        #expect(mark.followsBase == true)
        #expect(mark.attachedTo == baseID)

        var detached = mark
        detached.attachedTo = nil // detaching is a field change, not a tree move (§3.4)
        #expect(detached.attachedTo == nil)
    }

    @Test func decomposedLigatureRetainsOriginalForExactRecomposition() throws {
        let provenance = MKProvenance(
            clusterID: MKClusterID(), codepoints: [0x0644, 0x0627], utf16Start: 0, utf16Length: 2,
            bidiLevel: 1, visualIndex: 0, logicalIndex: 0
        )
        let original = MKComposedLigature(
            glyph: MKGlyphRef(glyphID: 421, font: .systemFallback, fontChecksum: "abc"),
            layout: MKGlyphLayout(position: .zero, advance: .zero), decomposable: true
        )
        let component = MKGlyphNode(
            glyph: MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "abc"),
            layout: MKGlyphLayout(position: .zero, advance: .zero), provenance: provenance
        )
        let decomposed = MKDecomposedLigature(components: [component], original: original)
        let group = MKLigatureGroup(state: .decomposed(decomposed), provenance: provenance)

        let data = try JSONEncoder().encode(group)
        let roundTripped = try JSONDecoder().decode(MKLigatureGroup.self, from: data)
        guard case .decomposed(let decodedState) = roundTripped.state else {
            Issue.record("expected decomposed state")
            return
        }
        #expect(decodedState.original == original) // D-108: exact recomposition source retained
    }
}
