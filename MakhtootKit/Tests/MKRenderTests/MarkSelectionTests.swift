import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender
import Testing

// Regression coverage for the 2026-07-29 user report: tashkeel cannot be
// selected separately ، tapping a mark selects the whole letter instead.
//
// Two causes, both fixed:
//   * `HitTester.arrangedChild` had NO tolerance parameter at all, so an
//     arranged child was reachable only on its exact ink or within 4
//     document points of its outline's bounding box. That is sub-pixel on
//     a zoomed-out canvas.
//   * Marks and their base glyphs competed in a single pass with the same
//     4 pt outset. A tashkeel is an order of magnitude smaller than the
//     letter it sits on, and the letter's bounding box plus outset
//     blankets the whole area including the mark's, so any near-miss on
//     the mark resolved to the base.
//
// (The third cause was outside this file entirely: `MKCanvasRenderAdapter`
// never implemented `arrangedChildHit`, so in the shipping app NOTHING in
// a composition was tappable. That is covered by the app target.)

@Suite("Arranged mark selection")
struct MarkSelectionTests {
    private let tester = HitTester()

    /// A big base glyph with a SMALL mark floating above it ، the real
    /// proportions of a letter and its tashkeel, which
    /// `TestScenes.arrangedBaseAndMark`'s equal-sized squares cannot
    /// express.
    ///
    /// Outlines are authored in 1000-unit em space and scaled by
    /// `pointSize` (100 here), so the base is a 100 pt square centred on
    /// the composition origin and the mark is a 10 pt square. Positive
    /// `relativeOffset.height` lands at NEGATIVE document y (the
    /// composition boundary's documented `scaleY: -1`).
    private static func bigBaseSmallMark(markOffsetY: CGFloat = 80) -> (node: MKArrangedTextNode, baseID: MKNodeID, markID: MKNodeID) {
        let baseID = MKNodeID()
        let markID = MKNodeID()
        func square(halfEm: Double) -> MKPathData {
            MKPathData(commands: [
                0, -halfEm, -halfEm,
                1, halfEm, -halfEm,
                1, halfEm, halfEm,
                1, -halfEm, halfEm,
                4,
            ], unitsPerEm: 1000)
        }
        let provenance = MKProvenance(
            clusterID: MKClusterID(), codepoints: [0x0628], utf16Start: 0, utf16Length: 1,
            bidiLevel: 0, visualIndex: 0, logicalIndex: 0)

        let base = MKGlyphNode(
            id: baseID,
            glyph: MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "test"),
            outline: square(halfEm: 500),          // 100 pt square at pointSize 100
            layout: MKGlyphLayout(position: .zero, advance: CGSize(width: 100, height: 0)),
            transform: .identity,
            provenance: provenance
        )
        let mark = MKMarkNode(
            id: markID,
            glyph: MKGlyphRef(glyphID: 2, font: .systemFallback, fontChecksum: "test"),
            outline: square(halfEm: 50),           // 10 pt square at pointSize 100
            attachedTo: baseID,
            relativeOffset: CGSize(width: 0, height: markOffsetY),
            followsBase: true,
            transform: .identity,
            provenance: provenance,
            markClass: .tashkeel
        )
        let composition = ArrangedComposition(
            nodes: [.glyph(base), .mark(mark)],
            sourceBackup: MKSourceTextBackup(sourceString: "بَ", style: MKTextStyle(pointSize: 100)),
            originFrame: CGRect(x: -60, y: -120, width: 120, height: 240)
        )
        let node = MKArrangedTextNode(
            core: MKNodeCore(name: "arranged"),
            composition: composition,
            derivedFrom: .liveText
        )
        return (node, baseID, markID)
    }

    /// Tapping squarely on the mark's own ink selects the mark, never the
    /// base beneath it.
    @Test func exactTapOnAMarkSelectsTheMark() throws {
        let (node, _, markID) = Self.bigBaseSmallMark()
        let hit = tester.arrangedChild(
            at: CGPoint(x: 0, y: -80), in: node, compositionWorldTransform: .identity, tolerance: 0)
        #expect(hit?.childID == markID)
    }

    /// The actual reported bug: a finger a few points off the tiny mark.
    /// Without tolerance this resolves to nothing; with tolerance but no
    /// mark preference it resolves to the base, because the base's inflated
    /// box covers the mark's whole neighbourhood.
    @Test func aNearMissOnAMarkStillSelectsTheMarkAndNotTheLetter() throws {
        let (node, baseID, markID) = Self.bigBaseSmallMark()
        // 12 pt above the mark's centre ، outside its own 10 pt box, well
        // inside a finger's reach, and squarely inside the base's inflated
        // bounding box.
        let nearMiss = CGPoint(x: 0, y: -92)
        let hit = tester.arrangedChild(
            at: nearMiss, in: node, compositionWorldTransform: .identity, tolerance: 22)
        #expect(hit?.childID == markID)
        #expect(hit?.childID != baseID)
    }

    /// The safeguard that keeps the mark preference from becoming a
    /// nuisance: exact-ink hits are resolved BEFORE the inflated pass, so
    /// a deliberate tap in the middle of a letter still selects the letter
    /// even when a mark's tolerance zone reaches that far.
    @Test func aTapOnTheLetterBodyStillSelectsTheLetter() throws {
        let (node, baseID, _) = Self.bigBaseSmallMark(markOffsetY: 30)
        // Dead centre of the base glyph.
        let hit = tester.arrangedChild(
            at: CGPoint(x: 0, y: 0), in: node, compositionWorldTransform: .identity, tolerance: 22)
        #expect(hit?.childID == baseID)
    }

    @Test func tolerancePutsPreviouslyUnreachablePointsInRange() throws {
        let (node, _, markID) = Self.bigBaseSmallMark()
        let justOutOfReach = CGPoint(x: 0, y: -98)
        // The pre-fix behaviour: no tolerance, nothing found.
        #expect(tester.arrangedChild(
            at: justOutOfReach, in: node, compositionWorldTransform: .identity, tolerance: 0)?.childID != markID)
        // With a finger-sized tolerance, reachable.
        #expect(tester.arrangedChild(
            at: justOutOfReach, in: node, compositionWorldTransform: .identity, tolerance: 22)?.childID == markID)
    }

    @Test func aTapFarOutsideTheCompositionStillMissesEverything() throws {
        let (node, _, _) = Self.bigBaseSmallMark()
        #expect(tester.arrangedChild(
            at: CGPoint(x: 5000, y: 5000), in: node, compositionWorldTransform: .identity, tolerance: 22) == nil)
    }

    @Test func hiddenChildrenAreNeverHit() throws {
        var (node, _, markID) = Self.bigBaseSmallMark()
        var composition = node.composition
        composition.nodes = composition.nodes.map { child in
            if case .mark(var m) = child, m.id == markID {
                m.isHidden = true
                return .mark(m)
            }
            return child
        }
        node.composition = composition

        let hit = tester.arrangedChild(
            at: CGPoint(x: 0, y: -80), in: node, compositionWorldTransform: .identity, tolerance: 22)
        #expect(hit?.childID != markID)
    }
}
