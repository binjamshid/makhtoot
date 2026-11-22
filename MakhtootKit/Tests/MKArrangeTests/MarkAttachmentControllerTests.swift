import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

/// WS-04 packet §5 task 12 (D-220) + TEST_MATRIX T-ARR-3 ("Detach → rotate
/// base 90° → re-attach → rotate base again", flagged by
/// `MKRenderTests/ArrangedGeometryTests.swift` as "needs MKArrange's
/// re-attach mutation... out of MKRender's scope" ، this is that test,
/// landing here as its own module now exists).
@Suite struct MarkAttachmentControllerTests {
    private let tolerance: CGFloat = 0.05

    private func makeBaseAndMark(baseTransform: MKTransform2D, markRelativeOffset: CGSize) -> (composition: ArrangedComposition, baseID: MKNodeID, markID: MKNodeID) {
        let baseID = MKNodeID()
        let markID = MKNodeID()
        let squareOutline = MKPathData(commands: [0, -500, -500, 1, 500, -500, 1, 500, 500, 1, -500, 500, 4])
        let provenance = MKProvenance(clusterID: MKClusterID(), codepoints: [0x0628], utf16Start: 0, utf16Length: 1, bidiLevel: 1, visualIndex: 0, logicalIndex: 0)
        let base = MKGlyphNode(
            id: baseID, glyph: MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "t"), outline: squareOutline,
            layout: MKGlyphLayout(position: .zero, advance: CGSize(width: 40, height: 0)), transform: baseTransform, provenance: provenance)
        let markProvenance = MKProvenance(clusterID: MKClusterID(), codepoints: [0x0640], utf16Start: 1, utf16Length: 1, bidiLevel: 1, visualIndex: 1, logicalIndex: 1)
        let mark = MKMarkNode(
            id: markID, glyph: MKGlyphRef(glyphID: 2, font: .systemFallback, fontChecksum: "t"), outline: squareOutline,
            attachedTo: baseID, relativeOffset: markRelativeOffset, followsBase: true, provenance: markProvenance, markClass: .tashkeel)
        let composition = ArrangedComposition(
            nodes: [.glyph(base), .mark(mark)],
            sourceBackup: MKSourceTextBackup(sourceString: "بَ", style: .default), originFrame: .zero)
        return (composition, baseID, markID)
    }

    @Test func movingBaseMovesTheMark() {
        let (composition, baseID, markID) = makeBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 0, height: 20))
        guard case .mark(let mark)? = composition.child(id: markID) else { Issue.record("no mark"); return }
        let beforeMove = MarkAttachmentController.worldPosition(ofMark: mark, in: composition)

        var moved = composition
        moved.nodes = moved.nodes.map { child in
            guard case .glyph(var g) = child, g.id == baseID else { return child }
            g.transform.position = CGPoint(x: 100, y: 0)
            return .glyph(g)
        }
        guard case .mark(let markAfter)? = moved.child(id: markID) else { Issue.record("no mark after move"); return }
        let afterMove = MarkAttachmentController.worldPosition(ofMark: markAfter, in: moved)

        #expect(abs(afterMove.x - (beforeMove.x + 100)) <= tolerance, "the fatha follows ب for free when its base moves")
    }

    @Test func detachThenMovingBaseDoesNotMoveTheMark() {
        let controller = MarkAttachmentController()
        let (composition, baseID, markID) = makeBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 0, height: 20))
        guard case .mark(let mark)? = composition.child(id: markID) else { Issue.record("no mark"); return }
        let detached = controller.detach(mark, in: composition)
        #expect(detached.attachedTo == nil)
        #expect(detached.followsBase == false)

        var afterDetach = composition
        afterDetach.nodes = afterDetach.nodes.map { $0.id == markID ? .mark(detached) : $0 }
        let beforeMove = MarkAttachmentController.worldPosition(ofMark: detached, in: afterDetach)

        var moved = afterDetach
        moved.nodes = moved.nodes.map { child in
            guard case .glyph(var g) = child, g.id == baseID else { return child }
            g.transform.position = CGPoint(x: 100, y: 0)
            return .glyph(g)
        }
        guard case .mark(let markAfter)? = moved.child(id: markID) else { Issue.record("no mark after move"); return }
        let afterMove = MarkAttachmentController.worldPosition(ofMark: markAfter, in: moved)

        #expect(abs(afterMove.x - beforeMove.x) <= tolerance, "a detached mark must not follow its former base")
    }

    @Test func reattachToADifferentBaseWorks() {
        let controller = MarkAttachmentController()
        var (composition, _, markID) = makeBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 0, height: 20))

        let otherBaseID = MKNodeID()
        let squareOutline = MKPathData(commands: [0, -500, -500, 1, 500, -500, 1, 500, 500, 1, -500, 500, 4])
        let otherProvenance = MKProvenance(clusterID: MKClusterID(), codepoints: [0x062F], utf16Start: 2, utf16Length: 1, bidiLevel: 1, visualIndex: 2, logicalIndex: 2)
        let otherBase = MKGlyphNode(
            id: otherBaseID, glyph: MKGlyphRef(glyphID: 3, font: .systemFallback, fontChecksum: "t"), outline: squareOutline,
            layout: MKGlyphLayout(position: CGPoint(x: 200, y: 0), advance: CGSize(width: 40, height: 0)), provenance: otherProvenance)
        composition.nodes.append(.glyph(otherBase))

        guard case .mark(let mark)? = composition.child(id: markID) else { Issue.record("no mark"); return }
        let worldBefore = MarkAttachmentController.worldPosition(ofMark: mark, in: composition)
        guard let reattached = controller.reattach(mark, toBase: otherBaseID, in: composition) else {
            Issue.record("reattach failed")
            return
        }
        #expect(reattached.attachedTo == otherBaseID)

        var afterReattach = composition
        afterReattach.nodes = afterReattach.nodes.map { $0.id == markID ? .mark(reattached) : $0 }
        let worldAfter = MarkAttachmentController.worldPosition(ofMark: reattached, in: afterReattach)
        #expect(abs(worldAfter.x - worldBefore.x) <= tolerance, "re-attach must preserve absolute world position")
        #expect(abs(worldAfter.y - worldBefore.y) <= tolerance)
        _ = markID
    }

    /// T-ARR-3: detach → rotate base 90° → re-attach → rotate base again ،
    /// no double-rotation. Re-attaching under a ROTATED target must not
    /// bake the rotation twice into `relativeOffset`.
    @Test func detachRotateReattachRotateAgainDoesNotDoubleRotate() {
        let controller = MarkAttachmentController()
        let (composition0, baseID, markID) = makeBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 10, height: 0))

        // 1. Rotate the base 90° BEFORE detaching (mark still follows).
        var rotated = composition0
        rotated.nodes = rotated.nodes.map { child in
            guard case .glyph(var g) = child, g.id == baseID else { return child }
            g.transform.rotation = .pi / 2
            return .glyph(g)
        }
        guard case .mark(let markAtRotation)? = rotated.child(id: markID) else { Issue.record("no mark"); return }
        let worldAtFirstRotation = MarkAttachmentController.worldPosition(ofMark: markAtRotation, in: rotated)

        // 2. Detach ، absolute position preserved.
        let detached = controller.detach(markAtRotation, in: rotated)
        var afterDetach = rotated
        afterDetach.nodes = afterDetach.nodes.map { $0.id == markID ? .mark(detached) : $0 }
        let worldAfterDetach = MarkAttachmentController.worldPosition(ofMark: detached, in: afterDetach)
        #expect(abs(worldAfterDetach.x - worldAtFirstRotation.x) <= tolerance)
        #expect(abs(worldAfterDetach.y - worldAtFirstRotation.y) <= tolerance)

        // 3. Re-attach to the SAME (still-rotated) base.
        guard let reattached = controller.reattach(detached, toBase: baseID, in: afterDetach) else {
            Issue.record("reattach failed")
            return
        }
        var afterReattach = afterDetach
        afterReattach.nodes = afterReattach.nodes.map { $0.id == markID ? .mark(reattached) : $0 }
        let worldAfterReattach = MarkAttachmentController.worldPosition(ofMark: reattached, in: afterReattach)
        #expect(abs(worldAfterReattach.x - worldAtFirstRotation.x) <= tolerance, "re-attach must reproduce the exact pre-detach world position")
        #expect(abs(worldAfterReattach.y - worldAtFirstRotation.y) <= tolerance)

        // 4. Rotate the base ANOTHER 90° (now 180° total) ، the mark must
        // move to where a SINGLE additional 90° rotation predicts, not
        // where a double-counted rotation would put it.
        var rotatedAgain = afterReattach
        rotatedAgain.nodes = rotatedAgain.nodes.map { child in
            guard case .glyph(var g) = child, g.id == baseID else { return child }
            g.transform.rotation = .pi   // total 180°, one MORE 90° turn from step 1/3's 90°
            return .glyph(g)
        }
        guard case .mark(let finalMark)? = rotatedAgain.child(id: markID) else { Issue.record("no mark"); return }
        let worldFinal = MarkAttachmentController.worldPosition(ofMark: finalMark, in: rotatedAgain)

        // Independent oracle: relativeOffset (10, 0) rotated by 90° gives
        // (0, 10) ، that's `worldAtFirstRotation`. One MORE 90° (total
        // 180°) from the ORIGINAL (10, 0) offset gives (-10, 0). A
        // double-rotation bug (re-attach baking in the first 90° AND the
        // base's own 90° both applying again) would instead land near
        // (0, -10) or similar ، clearly distinguishable from (-10, 0).
        #expect(abs(worldFinal.x - (-10)) <= tolerance, "double-rotation bug check: x")
        #expect(abs(worldFinal.y - 0) <= tolerance, "double-rotation bug check: y")
    }

    // MARK: - Multi-mark stack (Run-3 P6 completion, packet §6's شدّة+فتحة
    // fixture: "«دَّ» in «شَدَّةٌ» ، two stacked marks follow the dal on
    // move; detaching only the fatha leaves shadda following"). These run
    // against a REAL `ArrangeDeriver` composition (not the hand-built
    // square-outline fixtures above) so the stack is exactly what
    // production derivation produces, not a synthetic stand-in.

    private func markNode(_ scalar: UInt32, in composition: ArrangedComposition) -> MKMarkNode? {
        for child in composition.nodes {
            if case .mark(let m) = child, m.provenance.codepoints == [scalar] { return m }
        }
        return nil
    }

    private func glyphNode(_ scalar: UInt32, in composition: ArrangedComposition) -> MKGlyphNode? {
        for child in composition.nodes {
            if case .glyph(let g) = child, g.provenance.codepoints.contains(scalar) { return g }
        }
        return nil
    }

    @Test func stackedMarksBothFollowTheDalOnMove() async {
        // د + shadda (U+0651) + fatha (U+064E) ، the "دَّ" fixture from
        // packet §6, isolated from its "شَدَّةٌ" host word so the base's id
        // is unambiguous to look up. Runs against Amiri specifically (not
        // this target's usual Geeza Pro default): a real, font-dependent
        // finding surfaced while building this fixture ، Geeza Pro's own
        // `MKMarkAttacher` output FUSES shadda+fatha into a single
        // `MKMarkNode` carrying both codepoints (one combined combining-
        // mark-stack glyph), while Amiri keeps them as two separate,
        // individually stack-indexed `MKMarkNode`s. Both are legitimate
        // WS-03 capture outcomes (font-dependent glyph repertoire, same
        // "do not hardcode glyph counts; assert relations" spirit
        // `ArrangeDeriverTests` already documents for الله) ، this fixture
        // needs the two-marks-separately case, so it uses the font that
        // actually produces it.
        let text = "د\u{0651}\u{064E}"
        let style = ArrangeFixtures.amiriStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.amiriFonts)

        guard let dal = glyphNode(0x062F, in: composition),
              let shadda = markNode(0x0651, in: composition),
              let fatha = markNode(0x064E, in: composition)
        else {
            Issue.record("expected a dal base with shadda+fatha marks")
            return
        }
        #expect(shadda.attachedTo == dal.id, "shadda must attach to the dal")
        #expect(fatha.attachedTo == dal.id, "fatha must attach to the dal")
        #expect(shadda.stackIndex != fatha.stackIndex, "stacked marks on the same base get distinct stack indices")

        let shaddaWorldBefore = MarkAttachmentController.worldPosition(ofMark: shadda, in: composition)
        let fathaWorldBefore = MarkAttachmentController.worldPosition(ofMark: fatha, in: composition)

        var moved = composition
        moved.nodes = moved.nodes.map { child in
            guard case .glyph(var g) = child, g.id == dal.id else { return child }
            g.transform.position = CGPoint(x: 50, y: -15)
            return .glyph(g)
        }
        guard let shaddaAfter = markNode(0x0651, in: moved), let fathaAfter = markNode(0x064E, in: moved) else {
            Issue.record("marks vanished after moving the base")
            return
        }
        let shaddaWorldAfter = MarkAttachmentController.worldPosition(ofMark: shaddaAfter, in: moved)
        let fathaWorldAfter = MarkAttachmentController.worldPosition(ofMark: fathaAfter, in: moved)

        #expect(abs(shaddaWorldAfter.x - (shaddaWorldBefore.x + 50)) <= tolerance, "shadda follows the dal")
        #expect(abs(shaddaWorldAfter.y - (shaddaWorldBefore.y - 15)) <= tolerance, "shadda follows the dal (y)")
        #expect(abs(fathaWorldAfter.x - (fathaWorldBefore.x + 50)) <= tolerance, "fatha ALSO follows the dal")
        #expect(abs(fathaWorldAfter.y - (fathaWorldBefore.y - 15)) <= tolerance, "fatha ALSO follows the dal (y)")
    }

    @Test func detachingOnlyOneStackedMarkLeavesItsSiblingFollowing() async {
        // See `stackedMarksBothFollowTheDalOnMove`'s doc comment: Amiri, not
        // Geeza Pro, is the font that keeps shadda+fatha as two distinct
        // `MKMarkNode`s on this bundled-font set.
        let text = "د\u{0651}\u{064E}"
        let style = ArrangeFixtures.amiriStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.amiriFonts)

        guard let dal = glyphNode(0x062F, in: composition),
              markNode(0x0651, in: composition) != nil,
              let fatha = markNode(0x064E, in: composition)
        else {
            Issue.record("expected a dal base with shadda+fatha marks")
            return
        }

        let controller = MarkAttachmentController()
        let detachedFatha = controller.detach(fatha, in: composition)
        #expect(detachedFatha.attachedTo == nil)
        #expect(detachedFatha.followsBase == false)

        var afterDetach = composition
        afterDetach.nodes = afterDetach.nodes.map { $0.id == fatha.id ? .mark(detachedFatha) : $0 }
        // Shadda's OWN node is untouched by detaching its sibling.
        guard let shaddaStill = markNode(0x0651, in: afterDetach) else {
            Issue.record("shadda vanished")
            return
        }
        #expect(shaddaStill.attachedTo == dal.id, "detaching the fatha must not disturb the shadda's attachment")
        #expect(shaddaStill.followsBase, "the shadda keeps following its base")

        let fathaWorldBeforeMove = MarkAttachmentController.worldPosition(ofMark: detachedFatha, in: afterDetach)
        let shaddaWorldBeforeMove = MarkAttachmentController.worldPosition(ofMark: shaddaStill, in: afterDetach)

        var moved = afterDetach
        moved.nodes = moved.nodes.map { child in
            guard case .glyph(var g) = child, g.id == dal.id else { return child }
            g.transform.position = CGPoint(x: 70, y: 0)
            return .glyph(g)
        }
        guard let fathaAfterMove = markNode(0x064E, in: moved), let shaddaAfterMove = markNode(0x0651, in: moved) else {
            Issue.record("marks vanished after moving the base")
            return
        }
        let fathaWorldAfterMove = MarkAttachmentController.worldPosition(ofMark: fathaAfterMove, in: moved)
        let shaddaWorldAfterMove = MarkAttachmentController.worldPosition(ofMark: shaddaAfterMove, in: moved)

        #expect(abs(fathaWorldAfterMove.x - fathaWorldBeforeMove.x) <= tolerance, "the DETACHED fatha must not follow the dal anymore")
        #expect(abs(shaddaWorldAfterMove.x - (shaddaWorldBeforeMove.x + 70)) <= tolerance, "the still-attached shadda keeps following the dal")
    }

    /// Multi-mark stack polish: re-attaching a mark to a base that ALREADY
    /// has a stacked mark must not collide `stackIndex` with the existing
    /// occupant (paint/z-order metadata, `MarkNode.swift`'s own doc
    /// comment: "shadda below, fatha above").
    @Test func reattachToABaseWithAnExistingMarkAssignsANonCollidingStackIndex() {
        let controller = MarkAttachmentController()
        var (composition, baseID, existingMarkID) = makeBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 0, height: 20))

        let incomingMarkID = MKNodeID()
        let squareOutline = MKPathData(commands: [0, -500, -500, 1, 500, -500, 1, 500, 500, 1, -500, 500, 4])
        let incomingProvenance = MKProvenance(clusterID: MKClusterID(), codepoints: [0x0651], utf16Start: 5, utf16Length: 1, bidiLevel: 1, visualIndex: 5, logicalIndex: 5)
        let incomingMark = MKMarkNode(
            id: incomingMarkID, glyph: MKGlyphRef(glyphID: 4, font: .systemFallback, fontChecksum: "t"), outline: squareOutline,
            attachedTo: nil, relativeOffset: .zero, followsBase: false, transform: MKTransform2D(position: CGPoint(x: 300, y: 300)),
            provenance: incomingProvenance, markClass: .tashkeel, stackIndex: 0)
        composition.nodes.append(.mark(incomingMark))

        guard case .mark(let existingMark)? = composition.child(id: existingMarkID) else { Issue.record("no existing mark"); return }
        #expect(existingMark.stackIndex == 0, "sanity: the pre-existing mark occupies stack slot 0")

        guard let reattached = controller.reattach(incomingMark, toBase: baseID, in: composition) else {
            Issue.record("reattach failed")
            return
        }
        #expect(reattached.stackIndex != existingMark.stackIndex, "the newly-attached mark must not collide with the existing occupant's stack slot")
        #expect(reattached.stackIndex == existingMark.stackIndex + 1, "new occupant takes the next free slot")
        _ = baseID
    }
}
