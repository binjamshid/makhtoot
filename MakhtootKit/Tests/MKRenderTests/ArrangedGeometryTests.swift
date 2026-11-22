import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKRender

/// T-ARR-1/T-ARR-2 (TEST_MATRIX.md §7.13) ، the renderer-side D-220 numeric
/// assertions this packet owns per its brief ("implement the T-ARR family
/// ... implement the renderer-side assertions"). `T-ARR-3` (detach → rotate
/// → re-attach → rotate, no double-rotation) needs `MKArrange`'s re-attach
/// mutation (WS-04, P5, not yet built) and is out of MKRender's scope ،
/// see `docs/impl-log/WS-07.md`.
@Suite struct ArrangedGeometryTests {
    private let tolerance: CGFloat = 0.05

    /// T-ARR-1: mark world-position formula at base rotations 30/90/180/270°,
    /// composition affine = identity for isolation, uniform scale 1.0.
    @Test(arguments: [CGFloat.pi / 6, .pi / 2, .pi, 3 * .pi / 2])
    func markWorldPositionAtBaseRotations(_ rotation: CGFloat) {
        let relativeOffset = CGSize(width: 10, height: -20)
        let (node, baseID, markID) = TestScenes.arrangedBaseAndMark(
            baseTransform: MKTransform2D(position: CGPoint(x: 100, y: 100), rotation: rotation),
            markRelativeOffset: relativeOffset
        )
        let index = MKArrangedGeometry.Index(composition: node.composition)

        let expected = expectedMarkWorldPosition(
            basePosition: CGPoint(x: 100, y: 100), baseRotation: rotation, baseScale: CGSize(width: 1, height: 1),
            relativeOffset: relativeOffset, markTransform: .identity
        )

        let actualTransform = MKArrangedGeometry.worldTransform(ofMark: markID, index: index, compositionAffine: .identity)
        #expect(actualTransform != nil)
        guard let actualTransform else { return }
        let actual = CGPoint.zero.applying(actualTransform)

        #expect(abs(actual.x - expected.x) <= tolerance, "rotation \(rotation): x mismatch actual=\(actual.x) expected=\(expected.x)")
        #expect(abs(actual.y - expected.y) <= tolerance, "rotation \(rotation): y mismatch actual=\(actual.y) expected=\(expected.y)")
        _ = baseID
    }

    /// T-ARR-1's second half: the mark's own rotation pivots about the
    /// relativeOffset-anchored origin, not the mark's own bounds center or
    /// the base's origin. Verified by giving the mark its own additional
    /// local transform and checking a point OFFSET from the mark's origin
    /// (not just the origin itself) lands where the D-220 chain predicts.
    @Test func markOwnRotationPivotsAboutRelativeOffsetOrigin() {
        let relativeOffset = CGSize(width: 15, height: 0)
        let markLocalRotation = CGFloat.pi / 2
        let (node, _, markID) = TestScenes.arrangedBaseAndMark(
            baseTransform: .identity,
            markRelativeOffset: relativeOffset,
            markTransform: MKTransform2D(rotation: markLocalRotation)
        )
        let index = MKArrangedGeometry.Index(composition: node.composition)
        guard let world = MKArrangedGeometry.worldTransform(ofMark: markID, index: index, compositionAffine: .identity) else {
            Issue.record("expected a world transform")
            return
        }

        // A point 5 units to the "right" of the mark's own local origin
        // (i.e. (5,0) in mark-local space) should, after a 90° local
        // rotation pivoting about the relativeOffset-anchored origin, land
        // at (relativeOffset + (0, 5)) ، NOT at (relativeOffset.x + 5,
        // relativeOffset.y), which is what a "pivot about the mark's own
        // bounds" (wrong) implementation would produce here since base
        // transform is identity.
        let markLocalPoint = CGPoint(x: 5, y: 0)
        let world5 = markLocalPoint.applying(world)
        let expected = CGPoint(x: relativeOffset.width + 0, y: relativeOffset.height + 5)
        #expect(abs(world5.x - expected.x) <= tolerance)
        #expect(abs(world5.y - expected.y) <= tolerance)
    }

    /// T-ARR-2: non-uniform base scale skews `relativeOffset`
    /// component-wise ، falls out of the affine chain, not a special case.
    @Test func markWorldPositionUnderNonUniformBaseScale() {
        let relativeOffset = CGSize(width: 10, height: 10)
        let scale = CGSize(width: 1.4, height: 0.7)
        let (node, _, markID) = TestScenes.arrangedBaseAndMark(
            baseTransform: MKTransform2D(position: CGPoint(x: 50, y: 50), scale: scale),
            markRelativeOffset: relativeOffset
        )
        let index = MKArrangedGeometry.Index(composition: node.composition)
        guard let world = MKArrangedGeometry.worldTransform(ofMark: markID, index: index, compositionAffine: .identity) else {
            Issue.record("expected a world transform")
            return
        }
        let actual = CGPoint.zero.applying(world)
        let expected = expectedMarkWorldPosition(
            basePosition: CGPoint(x: 50, y: 50), baseRotation: 0, baseScale: scale,
            relativeOffset: relativeOffset, markTransform: .identity
        )
        #expect(abs(actual.x - expected.x) <= tolerance)
        #expect(abs(actual.y - expected.y) <= tolerance)
    }

    /// T-ARR-2's second half: combined non-uniform scale + 45° rotation ،
    /// the formula (not a simplified uniform-scale shortcut) must still hold.
    @Test func markWorldPositionUnderCombinedScaleAndRotation() {
        let relativeOffset = CGSize(width: 12, height: -6)
        let scale = CGSize(width: 1.4, height: 0.7)
        let rotation = CGFloat.pi / 4
        let (node, _, markID) = TestScenes.arrangedBaseAndMark(
            baseTransform: MKTransform2D(position: CGPoint(x: 20, y: 30), rotation: rotation, scale: scale),
            markRelativeOffset: relativeOffset
        )
        let index = MKArrangedGeometry.Index(composition: node.composition)
        guard let world = MKArrangedGeometry.worldTransform(ofMark: markID, index: index, compositionAffine: .identity) else {
            Issue.record("expected a world transform")
            return
        }
        let actual = CGPoint.zero.applying(world)
        let expected = expectedMarkWorldPosition(
            basePosition: CGPoint(x: 20, y: 30), baseRotation: rotation, baseScale: scale,
            relativeOffset: relativeOffset, markTransform: .identity
        )
        #expect(abs(actual.x - expected.x) <= tolerance)
        #expect(abs(actual.y - expected.y) <= tolerance)
    }

    /// Glyph/ligature children (no `followsBase`): world = composition.affine
    /// ∘ child.affine ، sanity check against a hand-computed expectation,
    /// including a non-identity `compositionAffine`.
    @Test func glyphChildWorldTransformComposesWithCompositionAffine() {
        let (node, baseID, _) = TestScenes.arrangedBaseAndMark(
            baseTransform: MKTransform2D(position: CGPoint(x: 5, y: 5), rotation: 0)
        )
        let index = MKArrangedGeometry.Index(composition: node.composition)
        let compositionAffine = CGAffineTransform(translationX: 100, y: 200)
        guard let world = MKArrangedGeometry.worldTransform(ofChild: baseID, index: index, compositionAffine: compositionAffine) else {
            Issue.record("expected a world transform")
            return
        }
        let actual = CGPoint.zero.applying(world)
        #expect(abs(actual.x - 105) <= tolerance)
        #expect(abs(actual.y - 205) <= tolerance)
    }

    // MARK: - Hand-evaluated D-220 formula (independent of the implementation under test)

    /// Hand-evaluates `composition.affine ∘ base.affine ∘ translate(relativeOffset)
    /// ∘ mark.affine` applied to the mark-local origin, with
    /// `compositionAffine = identity`, for test-oracle purposes ، deliberately
    /// NOT sharing code with `MKArrangedGeometry` (an independent
    /// implementation of the same formula is what makes this a real check).
    private func expectedMarkWorldPosition(
        basePosition: CGPoint, baseRotation: CGFloat, baseScale: CGSize,
        relativeOffset: CGSize, markTransform: MKTransform2D
    ) -> CGPoint {
        // base.affine applied to (relativeOffset, then markTransform's
        // origin contribution ، for identity markTransform this is just
        // relativeOffset): scale, then rotate, then translate (MKTransform2D's
        // own documented composition order).
        let scaled = CGPoint(x: relativeOffset.width * baseScale.width, y: relativeOffset.height * baseScale.height)
        let rotated = CGPoint(
            x: scaled.x * cos(baseRotation) - scaled.y * sin(baseRotation),
            y: scaled.x * sin(baseRotation) + scaled.y * cos(baseRotation)
        )
        return CGPoint(x: rotated.x + basePosition.x, y: rotated.y + basePosition.y)
    }
}
