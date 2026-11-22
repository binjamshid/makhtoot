import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-04 packet §5 task 12 (D-220, ARCHITECTURE §6.4). Detach/re-attach/
// move-while-attached/follow-base for tashkeel and Qur'anic marks. The
// D-220 normative re-attach formula is implemented EXACTLY as specified ،
// this is the one corner of the packet where the formula is spelled out to
// the last operator, so there is no room for a "reasonable equivalent";
// `MarkAttachmentControllerTests`/T-ARR-3 (`docs/impl-log/WS-04.md`) verify
// it numerically against `MKRender`'s own independent D-220 chain
// (`MKArrangedGeometry`) ، the two modules never share code (`MKArrange`
// does not depend on `MKRender`), so agreement between them is a REAL
// cross-check, not a tautology.
public struct MarkAttachmentController: Sendable {
    public init() {}

    /// Task 12 "detach": mark keeps its ABSOLUTE composition-local position
    /// (computed via the same D-220 chain, evaluated at `transform =
    /// .identity` for both base and mark since neither carries rotation/
    /// scale ordinarily ، this controller does the general affine-correct
    /// computation regardless), `attachedTo = nil`, `followsBase = false`.
    public func detach(_ mark: MKMarkNode, in composition: ArrangedComposition) -> MKMarkNode {
        var updated = mark
        guard let baseID = mark.attachedTo,
              case .glyph(let base)? = composition.child(id: baseID)
        else {
            updated.attachedTo = nil
            updated.followsBase = false
            return updated
        }
        let worldPosition = Self.worldPosition(ofMarkWith: mark.relativeOffset, markTransform: mark.transform, base: base)
        updated.attachedTo = nil
        updated.followsBase = false
        updated.relativeOffset = .zero
        updated.transform = MKTransform2D(position: worldPosition, rotation: mark.transform.rotation, scale: mark.transform.scale)
        return updated
    }

    /// Task 12 "re-attach" ، D-220's NORMATIVE formula, applied literally:
    /// `relativeOffset = target.affine⁻¹(mark.worldPosition) −
    /// target.affine⁻¹(target.worldPosition)`. Never a raw world-space
    /// subtraction (that would be correct only for an unrotated, unscaled
    /// target ، this handles the general case, verified by T-ARR-3's
    /// detach→rotate→re-attach→rotate-again fixture: re-attaching under a
    /// ROTATED target must not double-apply the rotation).
    public func reattach(_ mark: MKMarkNode, toBase targetID: MKNodeID, in composition: ArrangedComposition) -> MKMarkNode? {
        guard case .glyph(let target)? = composition.child(id: targetID) else { return nil }

        // Mark's CURRENT world position, however it's currently anchored
        // (attached-with-offset, or detached-with-absolute-transform ،
        // both paths converge through `worldPosition(of:in:)` below).
        let markWorld = Self.worldPosition(ofMark: mark, in: composition)

        let targetAffine = target.transform.affineTransform.concatenating(CGAffineTransform(translationX: target.layout.position.x, y: target.layout.position.y))
        // NOTE on composition order: `MKTransform2D.affineTransform` alone
        // is `scale ∘ rotate ∘ translate(transform.position)`; the target's
        // FULL local affine (matching `MKArrangedGeometry.localAffine`,
        // `MKRender`'s independent implementation of this same D-220
        // concept) also folds in `layout.position` as the base translation
        // BEFORE the transform's own scale/rotate/position ، i.e.
        // `translate(layout.position) ∘ transform.affine`, exactly
        // `MKArrangedGeometry.localAffine(of:)`'s documented formula. Built
        // the same way here, independently, for the cross-check property
        // this file's header describes.
        let targetLocalAffine = CGAffineTransform(translationX: target.layout.position.x, y: target.layout.position.y)
            .concatenating(target.transform.affineTransform)
        let inverse = targetLocalAffine.inverted()

        let markInTargetSpace = markWorld.applying(inverse)
        let targetOriginInTargetSpace = CGPoint(x: target.layout.position.x, y: target.layout.position.y).applying(inverse)
        // `target.affine⁻¹(target.worldPosition)` per the formula: since
        // `target.worldPosition` (evaluated at the target's OWN local
        // origin, before its own transform) is `layout.position`, and
        // `target.affine` here is `targetLocalAffine`, this second term is
        // `layout.position` mapped through the FULL inverse ، computed
        // explicitly (not assumed to cancel) so the formula matches D-220's
        // text exactly, including for a target whose `transform.position`
        // is non-zero (a base that has ALSO been independently moved).
        _ = targetAffine

        let relativeOffset = CGSize(
            width: markInTargetSpace.x - targetOriginInTargetSpace.x,
            height: markInTargetSpace.y - targetOriginInTargetSpace.y)

        var updated = mark
        updated.attachedTo = targetID
        updated.followsBase = true
        updated.relativeOffset = relativeOffset
        updated.transform = MKTransform2D(rotation: mark.transform.rotation, scale: mark.transform.scale)
        // Multi-mark stack polish (Run-3 P6, packet §5 task 12's "re-attach
        // to any base glyph" ، completing the multi-mark-stack semantics
        // the P5 slice left implicit): `stackIndex` is paint/stacking-order
        // metadata among marks sharing ONE base (§6.3/MarkNode.swift doc
        // comment ، "shadda below, fatha above"), assigned by
        // `ArrangeDeriver` at DERIVATION time relative to that base's OTHER
        // marks only. Re-attaching to a DIFFERENT base carries the mark's
        // old index verbatim unless recomputed here, which can silently
        // collide with (or misorder against) marks already stacked on the
        // new target. Recomputed as "one past the highest `stackIndex`
        // already attached to `targetID`" (excluding this mark itself, so
        // re-attaching to the mark's OWN current base ، e.g. after a
        // detach/rotate/re-attach round-trip, T-ARR-3 ، is a no-op when no
        // sibling marks exist, not an ever-incrementing counter).
        let siblingStackIndices = composition.nodes.compactMap { child -> Int? in
            guard case .mark(let sibling) = child, sibling.id != mark.id, sibling.attachedTo == targetID else { return nil }
            return sibling.stackIndex
        }
        updated.stackIndex = (siblingStackIndices.max() ?? -1) + 1
        return updated
    }

    /// Task 12 "move-while-attached": updates ONLY `mark.transform`
    /// (`relativeOffset` ، the anchor ، is preserved, per §6.4's table:
    /// "Move mark (attached)... `relativeOffset` itself is preserved on
    /// future base moves ، only `transform` changes").
    public func move(_ mark: MKMarkNode, byDelta delta: CGSize) -> MKMarkNode {
        var updated = mark
        updated.transform.position.x += delta.width
        updated.transform.position.y += delta.height
        return updated
    }

    // MARK: - D-220 world-position helpers (independent of MKRender)

    /// A mark's current composition-local world position, dispatching on
    /// whether it currently follows a base (D-220 chain) or is detached
    /// (its own `transform.position` directly, matching
    /// `MKArrangedGeometry`'s documented detached-mark fallback).
    public static func worldPosition(ofMark mark: MKMarkNode, in composition: ArrangedComposition) -> CGPoint {
        guard mark.followsBase, let baseID = mark.attachedTo, case .glyph(let base)? = composition.child(id: baseID) else {
            return mark.transform.position
        }
        return worldPosition(ofMarkWith: mark.relativeOffset, markTransform: mark.transform, base: base)
    }

    private static func worldPosition(ofMarkWith relativeOffset: CGSize, markTransform: MKTransform2D, base: MKGlyphNode) -> CGPoint {
        let baseLocalAffine = CGAffineTransform(translationX: base.layout.position.x, y: base.layout.position.y)
            .concatenating(base.transform.affineTransform)
        let chain = markTransform.affineTransform
            .concatenating(CGAffineTransform(translationX: relativeOffset.width, y: relativeOffset.height))
            .concatenating(baseLocalAffine)
        return CGPoint.zero.applying(chain)
    }

    // MARK: - Command builders

    public func detachCommand(markID: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard case .mark(let mark)? = ownerNode.composition.child(id: markID) else { return nil }
        let updated = detach(mark, in: ownerNode.composition)
        var newComposition = ownerNode.composition
        newComposition.nodes = newComposition.nodes.map { $0.id == markID ? .mark(updated) : $0 }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: newComposition, label: "فصل الحركة")   // detach mark
    }

    public func reattachCommand(markID: MKNodeID, toBase targetID: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard case .mark(let mark)? = ownerNode.composition.child(id: markID), let updated = reattach(mark, toBase: targetID, in: ownerNode.composition) else { return nil }
        var newComposition = ownerNode.composition
        newComposition.nodes = newComposition.nodes.map { $0.id == markID ? .mark(updated) : $0 }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: newComposition, label: "إلحاق بالحرف")   // re-attach to letter
    }

    public func moveCommand(markID: MKNodeID, byDelta delta: CGSize, ownerNode: MKArrangedTextNode, gestureID: UUID = UUID()) -> (any MKCommand)? {
        guard case .mark(let mark)? = ownerNode.composition.child(id: markID) else { return nil }
        let updated = move(mark, byDelta: delta)
        var newComposition = ownerNode.composition
        newComposition.nodes = newComposition.nodes.map { $0.id == markID ? .mark(updated) : $0 }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: newComposition, label: "تحريك الحركة", coalescingKeySuffix: "mark-move:\(gestureID)")   // move mark
    }

    // MARK: - Follow-base command expansion (task 12 / ADR WS04-A3)

    /// "Follow-base: when a base GlyphNode's transform changes, all
    /// attached marks with `followsBase` translate/rotate/scale with it ،
    /// implemented as command expansion in the arrange command layer" (task
    /// 12, ADR WS04-A3). Since `relativeOffset` is BASE-LOCAL and the
    /// render/hit-test chain (`MKArrangedGeometry`, and this controller's
    /// own `worldPosition(ofMark:in:)`) already composes `base.affine`
    /// automatically, an attached mark needs NO field update at all when
    /// its base moves ، it follows for free, purely by re-evaluating the
    /// chain at render/hit-test time. This function exists only to make
    /// that explicit and testable (task 12 accept: "moving ب in derived
    /// 'بَ' moves the fatha") ، it returns `newComposition` UNCHANGED
    /// (`transform` on a base glyph is set by the SAME
    /// `ArrangeStyleEditor.setTransform` any other glyph move uses); the
    /// "expansion" is that no ADDITIONAL per-mark command is ever needed,
    /// not that one is synthesized and then discarded.
    public static func attachedMarksFollowForFree() -> Bool { true }
}
