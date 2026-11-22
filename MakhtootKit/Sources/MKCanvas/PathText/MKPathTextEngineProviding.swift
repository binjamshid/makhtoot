import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 16 ("Path-edit mode UX", this run ، deferred from
// the P4 CANVAS-LANE session per `CanvasMode.swift`'s own former "out of
// scope" comment, now stale: both `MKArrange` and `MKPathText` are complete
// modules as of this pass). PRD §9 (R-9.1–R-9.10, FL-8). This file is the
// `MKPathText` consumption seam, a near-verbatim structural mirror of
// `Arrange/MKArrangeEngineProviding.swift`'s own precedent ، read that
// file's header first, the reasoning below only restates it where the
// Path Text specifics differ.
//
// `Package.swift`'s `MKCanvas` target dependencies are `["MKFoundation",
// "MKModel", "MKRender", "MKDesignSystem"]` only ، no `MKArrange`, no
// `MKPathText` ، and this run's fence does not permit adding one (additive
// dependency edges are logged, not silently added, same precedent
// `MKArrangeEngineProviding.swift` already established). So `MKCanvas`
// declares its OWN protocol seam here, spelled entirely in terms of types
// it already has: `MKModel`'s `MKPathTextNode`/`MKBezierPathData`/
// `MKPathLayoutOptions`/`MKPathGlyphOffsetKey`/`MKPathGlyphOffset` are all
// `MKModel` declarations (not `MKPathText` ones), directly usable with zero
// mirror needed; `MKPersistence.MKCommand`/`MKReplaceNodesCommand` are
// already used the same undeclared-but-working way by every other file in
// this module (`CanvasSession.swift`, `CanvasContentAPI.swift` both import
// `MKPersistence` successfully despite `Package.swift`'s declared
// dependency list not literally naming it ، an already-relied-upon fact
// about how this package currently builds, not something this file
// re-justifies). Only the handful of small UI-facing hit-target/handle
// types genuinely owned by `MKPathText`
// (`PathEditModel.PathHitTarget`/`PathHandleID`/`PathHandleMode`) get
// small structural mirrors below, keyed by a plain `UUID` rather than
// `MKPathText.MKPathAnchorID` ، that type is an `MKID<PathAnchorTag>` whose
// tag struct lives in `MKPathText`, unreachable from here, exactly the
// same "borrow the id SHAPE, not the id TYPE" move
// `MKArrangeFormSelectorModel` already makes for `MKJoiningForm`-adjacent
// data (there `MKJoiningForm` itself is an `MKModel` type so no mirror was
// needed at all ، the Path Text case is the one degree more removed).
//
// The app target (`Makhtoot/`, a LATER session's fence) already links
// `MKPathText` directly; the real conformer of this protocol
// (`MKPathTextInteractionAdapter` or similar, `Makhtoot/AppShell/Scenes/
// Editor/`) is a near-verbatim pass-through to `PathEditModel`'s pure
// functions (`hitTargets`, `nearestHitTarget`, `moveAnchor`, `moveHandle`,
// `insertAnchor`, `deleteAnchor`, `toggleClosed`) plus `PathTextCommands`'
// `setGlyphOffset`/`setPath` builders and a fresh `PathLayoutEngine.layout`
// run for the glyph-hit-test query (see `glyphHitTest(at:node:)`'s doc
// comment) and for `curvatureWarning(for:)` (reading
// `PathLayoutResult.curvatureWarning` straight through).
//
// **Design decision ، why path-level OPTIONS edits (R-9.4: start offset,
// side, spacing mode, reverse direction) do NOT go through this protocol,
// unlike anchor/handle/glyph-offset edits:** `MKPathLayoutOptions`
// (`startOffset`/`side`/`spacingMode`) is a plain, already-`MKModel`-owned
// Codable struct (`MKNode.swift`) ، `MKCanvas` can read, construct, and
// mutate it with zero `MKPathText` knowledge, and `MKReplaceNodesCommand`
// (see the import-availability note above) is a completely generic
// "replace this node's full value" primitive that needs no algorithm from
// either `MKPathText` or `MKArrange` to build correctly here. Routing
// these through the seam anyway (mirroring the anchor/handle methods'
// shape) would add four protocol methods and a matching four fake-engine
// methods in every future test double for pure boilerplate ، the seam
// exists to cross a MODULE boundary (`MKCanvas` cannot invoke
// `MKPathText`'s hit-testing/layout ALGORITHMS), not to gate every
// `MKCommand` construction generically. `MKPathTextInteractionModel`
// therefore builds these four commands (`setStartOffset`/`setSide`/
// `setSpacingMode`/`reverseDirection`) directly, exactly the way
// `CanvasContentAPI.swift`'s `addLiveText`/`addPathText`/etc. already build
// `MKInsertNodeCommand` directly without any engine seam. Anchor/handle
// edits and the per-glyph-offset drag DO need the seam, because computing
// their new values requires `MKPathText`'s own geometry
// (`PathEditModel`'s de Casteljau split, mirrored-handle math, and
// `PathLayoutEngine`'s arc-length LUT respectively) ، `MKCanvas` has no way
// to compute those values itself.
//
// "قلب الاتجاه" (reverse direction) is the other R-9.4 control and is ALSO
// seam-free, but for a different reason: it needs no `MKPathText` geometry
// AT ALL, not even the generic "plain `MKModel` type" argument above.
// `BezierPathModel.swift`'s own "Anchor/segment correspondence" doc comment
// (`MKPathText`, read-only reference ، this file does not import it)
// establishes that `MKModel.MKBezierPathData`'s flat segment list and
// `MKPathText`'s anchor/handle view of the same path are losslessly
// interconvertible; reversing the path's direction of travel is exactly
// "reverse the segment order, and within each segment swap `start`↔`end`
// and `c1`↔`c2`" ، pure, self-contained cubic-Bézier algebra over
// `MKBezierSegment`, the same four `CGPoint` fields `MKModel` already
// exposes. `MKPathTextInteractionModel.reversedPath(_:)` implements this
// directly; see its doc comment for the one-line proof this is equivalent
// to "reverse the anchor array and swap each anchor's handleIn/handleOut."

// MARK: - Structural mirrors of `MKPathText.PathEditModel`'s UI-facing types

/// Structural mirror of `MKPathText.PathHandleID` (`PathEditModel.swift`) ،
/// identifies one hit-testable control point: an anchor's own point, or one
/// of its two Bézier handles. `anchorID` is a plain `UUID` rather than
/// `MKPathText.MKPathAnchorID` (see file header) ، the REAL conformer's
/// `MKPathAnchorID` is itself just an `MKID<PathAnchorTag>` wrapper over a
/// `UUID`, so this loses no information, only the compile-time tag.
public struct MKPathHandleID: Hashable, Sendable, Equatable {
    public enum Kind: Hashable, Sendable { case anchor, handleIn, handleOut }
    public var anchorID: UUID
    public var kind: Kind

    public init(anchorID: UUID, kind: Kind) {
        self.anchorID = anchorID
        self.kind = kind
    }
}

/// Structural mirror of `MKPathText.PathHitTarget` ، one hit-testable
/// control point WS-06's chrome layer can render/drag, plus its current
/// world/canvas-space position.
public struct MKPathHitTarget: Hashable, Sendable, Equatable {
    public var id: MKPathHandleID
    public var position: CGPoint

    public init(id: MKPathHandleID, position: CGPoint) {
        self.id = id
        self.position = position
    }
}

/// Structural mirror of `MKPathText.PathHandleMode` ، how dragging one
/// handle affects its opposite sibling on the same anchor (task 10/16:
/// "move handle (with mirrored/free handle mode)").
public enum MKPathHandleMode: Sendable, Equatable {
    /// The opposite handle mirrors this one exactly ، smooth (C1-
    /// continuous) curves. The default for ordinary handle drags.
    case mirrored
    /// The opposite handle is left untouched ، corner points / cusps.
    case free
}

/// One glyph hit under a path-edit-mode tap/drag start point, resolved
/// against the node's CURRENTLY LAID-OUT glyphs (R-9.4's per-glyph
/// hand-adjustment) ، the app-layer adapter re-runs `PathLayoutEngine
/// .layout` to answer this (cheap; needs only `MKPathText` + `MKTextEngine`
/// shaping, no `MKRender`/`MKArrange`), the same "adapter does the real
/// work, seam just carries the shape" split every other method here uses.
public struct MKPathGlyphHit: Sendable, Equatable {
    public var key: MKPathGlyphOffsetKey
    /// The glyph's current laid-out position (engine placement + any
    /// existing `MKPathGlyphOffset`), world/canvas space ، for chrome
    /// highlighting and as the drag's start reference point.
    public var position: CGPoint
    /// The offset already stored for `key` (`.zero` if none yet), so a
    /// drag can add its delta on top rather than overwriting from scratch.
    public var currentOffset: MKPathGlyphOffset

    public init(key: MKPathGlyphOffsetKey, position: CGPoint, currentOffset: MKPathGlyphOffset) {
        self.key = key
        self.position = position
        self.currentOffset = currentOffset
    }
}

// MARK: - The `MKPathText` consumption seam

/// See file header for the full "why a seam / why NOT a seam for options"
/// design note. Method-shape convention mirrors `MKArrangeEngineProviding`
/// exactly: mutating methods take `nodeID:/in scene:` and return `(any
/// MKCommand)?` (`nil` when inapplicable ، never a silent no-op that hides
/// a real failure from the caller); pure query methods take the already-
/// resolved `MKPathTextNode` value directly (no `scene`/`nodeID` needed,
/// since the caller ، `MKPathTextInteractionModel.activeNode` ، already
/// has it).
@MainActor
public protocol MKPathTextEngineProviding: AnyObject {
    // MARK: - Anchor/handle query (R-9.1 pen editor, R-9.3 "editable in live mode only")

    /// Every anchor point plus its present handles, as hit targets ، the
    /// full set WS-06's chrome layer draws every frame while path-edit
    /// mode is active.
    func hitTargets(for node: MKPathTextNode) -> [MKPathHitTarget]

    /// The nearest hit target to `point` (node-local/canvas space ، same
    /// convention `MKCanvasGeometrySource.arrangedChildHit`'s `worldPoint`
    /// uses) within `tolerance`, or `nil` if nothing qualifies. Drives both
    /// tap-to-select and a drag's begin-time hit resolution.
    func nearestHitTarget(to point: CGPoint, for node: MKPathTextNode, tolerance: CGFloat) -> MKPathHitTarget?

    /// `true` when `PathLayoutEngine`'s last layout pass for `node` set
    /// `PathLayoutResult.curvatureWarning` (task 16 accept: "curvature
    /// warning banner when WS-05 reports it") ، a locally sharp turn where
    /// adjacent glyph rotations diverge past `PathLayoutOptions
    /// .curvatureWarningThresholdDegrees`. Re-evaluated by the adapter on
    /// every call (path edits change this live, R-9.3), so this is cheap
    /// to poll every frame while dragging, not something WS-06 caches.
    func curvatureWarning(for node: MKPathTextNode) -> Bool

    // MARK: - Anchor/handle mutation (R-9.1, R-9.3) ، each an undoable command, or `nil` if inapplicable

    /// Moves anchor `anchorID` to `newPoint`; `moveHandles` mirrors
    /// `PathEditModel.moveAnchor`'s own parameter (`true` = drag the whole
    /// control point including its handles, `false` = reshape the curve
    /// around a stationary handle pair). `coalescingKey` should stay stable
    /// for one continuous drag and change on the next (D-112 ، one drag,
    /// one undo entry), same contract `PathTextCommands.setPath`'s own
    /// `coalescingKey` parameter documents.
    func moveAnchorCommand(_ anchorID: UUID, to newPoint: CGPoint, moveHandles: Bool, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)?

    /// Moves one handle to an absolute new position, applying `mode` to
    /// its opposite sibling on the same anchor.
    func moveHandleCommand(_ handleID: MKPathHandleID, to newPoint: CGPoint, mode: MKPathHandleMode, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)?

    /// Inserts a new anchor at the point on the live curve nearest `point`
    /// (R-9.1's "tap to add anchors") via `PathEditModel.insertAnchor`'s
    /// lossless de Casteljau split ، the adapter alone can run the
    /// arc-length LUT this needs. Returns `nil` (a no-op, not an error)
    /// when `point` is not close enough to the curve to count as an
    /// on-curve tap; the freshly-minted anchor's id is returned alongside
    /// the command so the caller can select it immediately.
    func insertAnchorCommand(near point: CGPoint, nodeID: MKNodeID, in scene: MKScene) -> (command: any MKCommand, anchorID: UUID)?

    /// Removes anchor `anchorID`, or `nil` if doing so would violate the
    /// minimum-anchor structural-validity floor (`PathEditModel
    /// .deleteAnchor`'s own `nil`-on-invalid contract ، 2 anchors open, 3
    /// closed).
    func deleteAnchorCommand(_ anchorID: UUID, nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)?

    /// Flips `BezierPathModel.isClosed`, or `nil` if the result would
    /// violate the same structural-validity floor (`PathEditModel
    /// .toggleClosed`'s own contract).
    func toggleClosedCommand(nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)?

    // MARK: - Per-glyph offset drag (R-9.4, live path text only ، see MKPathTextInteractionModel's file header)

    /// Hit-tests `point` against `node`'s CURRENTLY LAID-OUT glyphs (a
    /// fresh `PathLayoutEngine.layout` run, not the anchor/handle set
    /// above) and resolves the matching cluster's stable persistence key.
    /// `nil` when no glyph is under `point`.
    func glyphHitTest(at point: CGPoint, node: MKPathTextNode) -> MKPathGlyphHit?

    /// Commits a new per-glyph offset for `key` into `MKPathTextNode
    /// .glyphOffsets` (`PathTextCommands.setGlyphOffset`'s exact
    /// contract). `gestureID` stable across one continuous drag, fresh for
    /// the next (same D-112 coalescing contract as every other gesture
    /// primitive here).
    func setGlyphOffsetCommand(_ offset: MKPathGlyphOffset, forKey key: MKPathGlyphOffsetKey, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID) -> (any MKCommand)?
}
