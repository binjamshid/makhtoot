import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import Observation

// WS-06 packet §5 task 16 ("Path-edit mode UX", this run ، see
// `MKPathTextEngineProviding.swift`'s header for the full seam-design
// rationale). PRD §9 (R-9.1–R-9.10, FL-8), ARCHITECTURE §5-§7/§10.3.
//
// Headless (`@Observable`, zero UIKit) interaction spine for Path-Edit
// Mode ، the exact architectural role `MKArrangeInteractionModel` already
// plays for Arrange Mode: `CanvasSession` holds a plain reference,
// SwiftUI/UIKit chrome both bind to this, `GestureCoordinator` calls into
// it. Anchor/handle and glyph-offset mutations funnel through
// `engine`-returned `MKCommand`s via `session.perform(_:)`; the four
// path-level OPTIONS mutations (start offset/side/spacing/reverse) build
// their own `MKReplaceNodesCommand`s directly (see
// `MKPathTextEngineProviding.swift`'s header for why those don't need the
// seam) ، both paths still go through the SAME `session.perform(_:)`
// funnel, so undo/journal behavior (R-4.19) is identical either way.
//
// Live-reflow while editing (R-9.3: "the path itself is editable... with
// text re-flowing live during path edits") needs no explicit method here:
// `MKRender/Drawers/PathTextDrawer.swift` already renders off the REAL
// `PathLayoutEngine` (post-convergence-pass), so committing a path/option
// edit through `session.perform(_:)` on every drag frame (coalesced, same
// as every other live-drag primitive below) is sufficient ، the renderer
// re-lays-out automatically the moment `MKPathTextNode.path`/`.text`/
// `.style`/`.layout` change in the scene.
//
// Per-glyph offset drag (R-9.4's implicit per-glyph hand-adjustment BEFORE
// arranging ، not to be confused with R-6.5/R-7.4's separate arrange-mode
// glyph-move primitive, which only applies once `MKPathTextNode` has been
// frozen into an `.arranged` composition, R-9.7) operates on `glyphOffsets`
// while the node is still LIVE `.pathText`, which is where that field
// actually lives (`MKNode.swift`'s `MKPathTextNode.glyphOffsets`).
@MainActor
@Observable
public final class MKPathTextInteractionModel {
    public let session: CanvasSession

    /// Injected by the app layer once `MKPathText` is reachable (mirrors
    /// `MKArrangeInteractionModel.engine`'s own injection pattern) ،
    /// `weak` since the adapter, not this model, owns its lifetime.
    public weak var engine: (any MKPathTextEngineProviding)?

    /// The handle/anchor most recently tapped (for chrome highlighting) ،
    /// this model's own selection concept, deliberately NOT routed through
    /// `session.selection` (that type's `ids: Set<MKNodeID>` holds scene
    /// node ids; a path anchor/handle id is a plain `UUID` with no scene
    /// identity of its own, the same reason `MKArrangeInteractionModel`
    /// needed its own `setArrangeChildSelection` entry point rather than
    /// reusing `setSelection` ، except here the mismatch is total enough
    /// that a small dedicated property is simpler than a parallel
    /// `CanvasSession` API).
    public private(set) var selectedHandle: MKPathHandleID?

    public private(set) var lastErrorMessage: String?

    private var draggedHandle: MKPathHandleID?
    private var draggedHandleMode: MKPathHandleMode = .mirrored
    private var handleDragCoalescingKey: String?

    private var draggedGlyphKey: MKPathGlyphOffsetKey?
    private var glyphDragGestureID: UUID?

    public init(session: CanvasSession) {
        self.session = session
    }

    // MARK: - Active node (mirrors `MKArrangeInteractionModel.activeOwnerNode`)

    public var isActive: Bool {
        if case .pathEdit = session.mode { return true }
        return false
    }

    public var activeNodeID: MKNodeID? {
        guard case .pathEdit(let id) = session.mode else { return nil }
        return id
    }

    public var activeNode: MKPathTextNode? {
        guard let id = activeNodeID, case .pathText(let n)? = session.scene.node(id: id) else { return nil }
        return n
    }

    // MARK: - Entry / exit (task 16: "'تحرير المسار' toggles pathEdit mode")

    /// Enters Path-Edit Mode on `nodeID`. Only valid for a live `.pathText`
    /// node (R-9.3: "the path itself is editable... in live mode only" ،
    /// an `.arranged` node born from a path has no editable path anymore,
    /// R-9.8) ، a no-op on any other node kind, same "silently refuse an
    /// inapplicable entry" contract `MKArrangeInteractionModel
    /// .enterArrangeMode`'s `default: return` case uses for non-text
    /// nodes. Pure mode transition, no command (mirrors
    /// `enterArrangeMode`'s already-arranged branch ، entry is never
    /// itself an edit).
    public func enterPathEditMode(nodeID: MKNodeID) {
        lastErrorMessage = nil
        guard case .pathText? = session.scene.node(id: nodeID) else {
            lastErrorMessage = Self.notPathTextMessage
            return
        }
        session.mode = .pathEdit(nodeID: nodeID)
        selectedHandle = nil
    }

    /// Pure mode transition back to browse ، the composition's edits
    /// persist exactly (mirrors `exitArrangeMode`'s "close" contract).
    public func exitPathEditMode() {
        session.mode = .browse
        selectedHandle = nil
        draggedHandle = nil
        draggedGlyphKey = nil
    }

    // MARK: - Curvature warning (task 16 accept: "curvature warning banner when WS-05 reports it")

    public var curvatureWarningActive: Bool {
        guard let node = activeNode, let engine else { return false }
        return engine.curvatureWarning(for: node)
    }

    // MARK: - Hit-testing / tap-select (R-9.1's pen editor)

    /// Nearest handle/anchor to `point` within `tolerance`, without
    /// mutating `selectedHandle` ، the read-only query
    /// `GestureCoordinator`'s pan-begin and long-press handlers use (they
    /// resolve a target without necessarily wanting to also change the
    /// visible selection, e.g. long-press-to-delete).
    public func nearestHitTarget(at point: CGPoint, tolerance: CGFloat) -> MKPathHitTarget? {
        guard let node = activeNode, let engine else { return nil }
        return engine.nearestHitTarget(to: point, for: node, tolerance: tolerance)
    }

    /// The full current anchor/handle target set for the active node ،
    /// the chrome layer's per-refresh input (`PathEditChromeLayer.update`
    /// draws one dot per target). Empty outside path-edit mode or before
    /// the engine is injected, so chrome code needs no separate guards.
    public func currentHitTargets() -> [MKPathHitTarget] {
        guard let node = activeNode, let engine else { return [] }
        return engine.hitTargets(for: node)
    }

    /// Tap-select: hits a handle/anchor within `tolerance` and selects it
    /// for chrome highlighting / a subsequent drag; clears the selection
    /// on an empty-space tap. See `GestureCoordinator.handlePathEditTap`'s
    /// doc comment for how this composes with insert-on-curve within one
    /// tap gesture (this method only ever selects ، it never inserts).
    @discardableResult
    public func tap(at point: CGPoint, tolerance: CGFloat) -> MKPathHandleID? {
        guard let hit = nearestHitTarget(at: point, tolerance: tolerance) else {
            selectedHandle = nil
            return nil
        }
        selectedHandle = hit.id
        return hit.id
    }

    // MARK: - Anchor/handle drag (R-9.1, R-9.3) ، one coalesced undo entry per drag (D-112)

    /// Begins a drag of `handle` (an anchor or one of its two Bézier
    /// handles, resolved by the caller via `nearestHitTarget`/`tap`
    /// first). `mode` only matters when `handle.kind` is `.handleIn`/
    /// `.handleOut` (ignored for `.kind == .anchor`).
    public func beginHandleDrag(_ handle: MKPathHandleID, mode: MKPathHandleMode = .mirrored) {
        guard isActive else { return }
        draggedHandle = handle
        draggedHandleMode = mode
        handleDragCoalescingKey = "pathHandle:\(handle.anchorID):\(handle.kind):\(UUID())"
        selectedHandle = handle
        session.beginGesture()
    }

    /// Moves the in-progress drag's handle to `point` (an ABSOLUTE
    /// position, not a delta ، matching `PathEditModel.moveAnchor`/
    /// `.moveHandle`'s own "to newPoint" signatures; unlike
    /// `MKArrangeInteractionModel.updateMove`'s delta-based nudge, a
    /// control-point drag naturally tracks the finger's own position 1:1
    /// rather than accumulating). Coalesces to ONE undo entry across the
    /// whole drag via the stable key `beginHandleDrag` minted.
    public func updateHandleDrag(to point: CGPoint) {
        guard let handle = draggedHandle, let nodeID = activeNodeID, let engine, let key = handleDragCoalescingKey else { return }
        let command: (any MKCommand)?
        switch handle.kind {
        case .anchor:
            command = engine.moveAnchorCommand(handle.anchorID, to: point, moveHandles: true, nodeID: nodeID, in: session.scene, coalescingKey: key)
        case .handleIn, .handleOut:
            command = engine.moveHandleCommand(handle, to: point, mode: draggedHandleMode, nodeID: nodeID, in: session.scene, coalescingKey: key)
        }
        guard let command else { return }
        try? session.perform(command)
    }

    public func endHandleDrag() {
        guard draggedHandle != nil else { return }
        session.endGesture()
        draggedHandle = nil
        handleDragCoalescingKey = nil
    }

    // MARK: - Insert / delete / toggle-closed (R-9.1)

    /// R-9.1's "tap to add anchors" ، a no-op (not an error) when `point`
    /// isn't close enough to the live curve (see
    /// `MKPathTextEngineProviding.insertAnchorCommand`'s doc comment). On
    /// success, selects the freshly inserted anchor.
    public func insertAnchor(near point: CGPoint) throws {
        guard let nodeID = activeNodeID, let engine, let result = engine.insertAnchorCommand(near: point, nodeID: nodeID, in: session.scene) else { return }
        try session.perform(result.command)
        selectedHandle = MKPathHandleID(anchorID: result.anchorID, kind: .anchor)
    }

    /// Deletes `anchorID`; no-op if `PathEditModel.deleteAnchor`'s
    /// structural-validity floor would be violated (the engine returns
    /// `nil` in that case, same "return nil rather than corrupt state"
    /// contract as every other mutation here).
    public func deleteAnchor(_ anchorID: UUID) throws {
        guard let nodeID = activeNodeID, let engine, let command = engine.deleteAnchorCommand(anchorID, nodeID: nodeID, in: session.scene) else { return }
        try session.perform(command)
        if selectedHandle?.anchorID == anchorID { selectedHandle = nil }
    }

    /// Flips open⇄closed (task 10's `PathEditModel.toggleClosed`, exposed
    /// here per task 16's own anchor-CRUD scope). No-op if the result
    /// would violate the minimum-anchor floor.
    public func toggleClosed() throws {
        guard let nodeID = activeNodeID, let engine, let command = engine.toggleClosedCommand(nodeID: nodeID, in: session.scene) else { return }
        try session.perform(command)
    }

    // MARK: - Per-glyph offset drag (R-9.4, live path text ، see file header)

    /// Begins a glyph-offset drag if `point` hits a laid-out glyph;
    /// returns the hit key on success (so the caller, e.g.
    /// `GestureCoordinator`, can track which kind of drag is in progress
    /// without re-querying).
    @discardableResult
    public func beginGlyphOffsetDrag(at point: CGPoint) -> MKPathGlyphOffsetKey? {
        guard let node = activeNode, let engine, let hit = engine.glyphHitTest(at: point, node: node) else { return nil }
        draggedGlyphKey = hit.key
        glyphDragGestureID = UUID()
        session.beginGesture()
        return hit.key
    }

    /// Nudges the dragged glyph's offset by `delta` (composition/canvas-
    /// space, added on top of whatever offset is CURRENTLY stored for the
    /// key ، re-read from `activeNode` fresh every call so repeated
    /// per-frame deltas accumulate exactly like
    /// `MKArrangeInteractionModel.updateMove`'s own delta-nudge, one
    /// coalesced command per frame via the stable `glyphDragGestureID`).
    public func updateGlyphOffsetDrag(byDelta delta: CGSize) {
        guard let key = draggedGlyphKey, let nodeID = activeNodeID, let node = activeNode, let engine, let gestureID = glyphDragGestureID else { return }
        var offset = node.glyphOffsets[key] ?? .zero
        offset.offset.x += delta.width
        offset.offset.y += delta.height
        guard let command = engine.setGlyphOffsetCommand(offset, forKey: key, nodeID: nodeID, in: session.scene, gestureID: gestureID) else { return }
        try? session.perform(command)
    }

    public func endGlyphOffsetDrag() {
        guard draggedGlyphKey != nil else { return }
        session.endGesture()
        draggedGlyphKey = nil
        glyphDragGestureID = nil
    }

    // MARK: - Path-level options (R-9.4) ، plain `MKModel` types, no engine seam (see `MKPathTextEngineProviding.swift`'s header)

    /// Opens the undo-stack gesture transaction a continuous options
    /// scrub (the `setStartOffset` slider) MUST be wrapped in for its
    /// `coalescingKeySuffix` to actually coalesce: `MKPersistence
    /// .UndoStack.perform(_:currentScene:)` only consults the coalescing
    /// key while `gestureActive == true` ، i.e. between `session
    /// .beginGesture()` and `session.endGesture()` ، so a bare sequence of
    /// same-key commands outside a transaction still pushes one undo entry
    /// PER FRAME, silently breaking the D-112 "one drag = one undo entry"
    /// contract. Thin wrapper over `session.beginGesture()`, mirroring
    /// `MKArrangeInteractionModel.beginMove()`'s exact idiom (and this
    /// model's own `beginHandleDrag`/`beginGlyphOffsetDrag`, which already
    /// open their transactions internally ، the options path exposes the
    /// pair separately because the slider chrome, not this model, owns the
    /// scrub's begin/end lifecycle).
    public func beginOptionsGesture() {
        session.beginGesture()
    }

    /// Closes the transaction `beginOptionsGesture()` opened ، see that
    /// method's doc comment. Mirrors `MKArrangeInteractionModel.endMove()`.
    public func endOptionsGesture() {
        session.endGesture()
    }

    /// R-9.4's arc-position "start offset" slider. `gestureID` stable
    /// across one continuous drag/slider-track, fresh for the next, AND
    /// the whole scrub wrapped in `beginOptionsGesture()`/
    /// `endOptionsGesture()` ، BOTH are required for D-112 coalescing (see
    /// `beginOptionsGesture`'s doc comment for why the key alone is not
    /// enough).
    public func setStartOffset(_ offset: Double, gestureID: UUID) throws {
        try replaceLayout(coalescingSuffix: "startOffset:\(gestureID)") { $0.startOffset = offset }
    }

    /// R-9.4's "side (above/below path = baseline flip)" ، a discrete,
    /// one-shot pick (never coalesced; each tap is its own undo entry,
    /// same as `MKArrangeInteractionModel.selectForm`'s discrete commits).
    public func setSide(_ side: MKPathSide) throws {
        try replaceLayout(coalescingSuffix: nil) { $0.side = side }
    }

    /// Convenience toggle between the two visible sides (R-9.4's literal
    /// "flip" framing) ، own design choice, documented per this packet's
    /// instructions: `.center` has no natural "other side," so a toggle
    /// starting from `.center` flips to `.above` (an arbitrary but
    /// reasonable default matching `MKPathLayoutOptions.init`'s own
    /// `side: MKPathSide = .above` default).
    public func toggleAboveBelow() throws {
        guard let node = activeNode else { return }
        try setSide(node.layout.side == .above ? .below : .above)
    }

    /// R-9.4's "spacing along path (tracking-on-path)" mode pick.
    public func setSpacingMode(_ mode: MKPathSpacingMode) throws {
        try replaceLayout(coalescingSuffix: nil) { $0.spacingMode = mode }
    }

    /// R-9.4's "قلب الاتجاه" (reverse direction) ، pure geometry, see
    /// `reversedPath(_:)` and `MKPathTextEngineProviding.swift`'s header
    /// for why this needs no `MKPathText` involvement at all.
    public func reverseDirection() throws {
        guard let nodeID = activeNodeID, case .pathText(var node)? = session.scene.node(id: nodeID) else { return }
        node.path = Self.reversedPath(node.path)
        try session.perform(MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: Self.reverseDirectionLabel))
    }

    private func replaceLayout(coalescingSuffix: String?, _ mutate: (inout MKPathLayoutOptions) -> Void) throws {
        guard let nodeID = activeNodeID, case .pathText(var node)? = session.scene.node(id: nodeID) else { return }
        mutate(&node.layout)
        try session.perform(MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: Self.pathOptionsLabel, coalescingKeySuffix: coalescingSuffix.map { "options:\($0)" }))
    }

    /// Pure geometry ، R-9.4's "قلب الاتجاه." Reverses the segment
    /// traversal order AND, within each segment, swaps `start`↔`end` and
    /// `c1`↔`c2`. `MKPathText.BezierPathModel.swift`'s own "Anchor/segment
    /// correspondence" doc comment (read-only reference, not imported
    /// here) establishes: open path, `n` anchors ⇒ `n-1` segments,
    /// `segments[i]` connects `anchors[i]`→`anchors[i+1]` using
    /// `anchors[i].handleOut` as `c1` and `anchors[i+1].handleIn` as `c2`
    /// (closed path: same rule plus one closing segment). Reversing the
    /// anchor array to `[anchors[n-1], ..., anchors[0]]` and swapping each
    /// anchor's `handleIn`/`handleOut` is BY CONSTRUCTION identical to
    /// reversing the segment list and, within each segment, swapping
    /// `start`↔`end`/`c1`↔`c2` ، the anchor view is just this same segment
    /// data re-sliced at anchor boundaries, so operating on the segment
    /// form directly (which `MKModel.MKBezierPathData` already stores, no
    /// `MKPathText.BezierPathModel` conversion needed) produces the exact
    /// same result.
    static func reversedPath(_ path: MKBezierPathData) -> MKBezierPathData {
        let reversed = path.segments.reversed().map {
            MKBezierSegment(start: $0.end, c1: $0.c2, c2: $0.c1, end: $0.start)
        }
        return MKBezierPathData(segments: reversed, isClosed: path.isClosed)
    }

    private static let pathOptionsLabel = "خيارات المسار"       // path options
    private static let reverseDirectionLabel = "قلب الاتجاه"    // reverse direction
    private static let notPathTextMessage = "لا يمكن تحرير المسار لهذا العنصر"   // this object's path cannot be edited
}
