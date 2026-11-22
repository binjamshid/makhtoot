import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import Observation

// WS-06 packet §5 task 2: "View-model spine `CanvasSession` (`@MainActor`):
// holds document ref, selection state, mode (`browse/editText/arrange/
// pathEdit`), publishes to SwiftUI; single funnel `perform(_ command:)` →
// document apply + undo stack. Accept: unit tests drive selection/mode
// transitions without UIKit."
//
// `@Observable` (the `Observation` framework, iOS 17+/macOS 14+ ، within
// this project's D-100 floor) is used instead of Combine's
// `ObservableObject`/`@Published` ، the modern, dependency-free way to
// "publish to SwiftUI" a plain `@MainActor` class, with no UIKit import
// anywhere in this file (satisfying the accept criterion literally: this
// type is headless).
@MainActor
@Observable
public final class CanvasSession {
    public let document: MakhtootDocument
    public private(set) var selection: MKSelectionState
    public var mode: MKCanvasMode

    /// Injected by the hosting `MKCanvasViewController` once WS-07's real
    /// geometry/render tree exists (`Geometry/MKCanvasGeometrySource.swift`
    /// header comment) ، `nil`-safe throughout so `CanvasSession` remains
    /// fully constructible and testable without either. `weak` (a class
    /// protocol) since the view controller ، not the session ، owns the
    /// render tree's lifetime.
    public weak var geometrySource: MKCanvasGeometrySource?
    public weak var renderBridge: MKCanvasRenderBridge?

    /// Snap-to-guides toggle (task 9: "snap toggle").
    public var snappingEnabled: Bool = true

    /// P5.5 (§2.2) "Show Grid" toggle ، a pure DISPLAY setting
    /// (`MKCanvasViewController.refreshGrid()` reads it to show/hide the
    /// grid chrome layer). Deliberately independent of `snappingEnabled`:
    /// this never feeds `SnapEngine`/`GuideRenderer`'s candidate-line math,
    /// only a separate always-on-request set of evenly-spaced reference
    /// lines (`MKGridLines`) drawn through the SAME hairline-layer
    /// mechanism `GuideRenderer` already uses for live snap guides, per
    /// this feature's own "display layer over the existing SnapEngine/
    /// GuideRenderer" scoping ، snapping BEHAVIOR is untouched.
    public var showsGrid: Bool = false

    private var tapCycleState = MKHitTestPolicy.TapCycleState()

    public init(document: MakhtootDocument, mode: MKCanvasMode = .browse) {
        self.document = document
        self.selection = .empty
        self.mode = mode
    }

    public var scene: MKScene { document.scene }

    // MARK: - Command funnel

    /// The single funnel every mutation goes through (task 2). Errors are
    /// intentionally not silently dropped ، callers decide whether to
    /// surface them (a `nodeNotFound` from a stale-selection edit racing a
    /// concurrent delete is a real, recoverable condition, not a
    /// programmer error).
    public func perform(_ command: any MKCommand) throws {
        try document.apply(command)
    }

    public func beginGesture() { document.undoStack.beginGesture() }
    public func endGesture() { document.undoStack.endGesture() }

    public func undo() throws { try document.undo() }
    public func redo() throws { try document.redo() }
    public var canUndo: Bool { document.undoStack.canUndo }
    public var canRedo: Bool { document.undoStack.canRedo }

    // MARK: - Mode transitions

    public func enterBrowseMode() {
        mode = .browse
    }

    public func beginEditingText(nodeID: MKNodeID) {
        mode = .editText(nodeID: nodeID)
    }

    // MARK: - Selection

    public func setSelection(_ ids: Set<MKNodeID>) {
        selection.set(sanitized(ids))
    }

    /// Layers-panel selection path (PRD R-4.6, coordinator gate ruling ،
    /// see docs/impl-log/WS-06.md): a LOCKED node is skipped by canvas
    /// tap/marquee selection but IS selectable from the layers panel
    /// (shown with a lock badge) so it can be inspected/unlocked. Hidden
    /// nodes are likewise panel-selectable (the panel is the management
    /// surface for re-showing them). Nonexistent ids are still dropped.
    public func setSelectionFromLayersPanel(_ ids: Set<MKNodeID>) {
        selection.set(ids.filter { scene.node(id: $0) != nil })
    }

    /// Arrange Mode's selection path (packet task 15, R-6.4/R-6.5/R-6.9):
    /// `ids` are arranged-CHILD ids (glyph/mark/ligature, including
    /// decomposed-ligature components) living inside `compositionScope`'s
    /// composition, never top-level scene node ids ، `setSelection`'s
    /// `isSelectable`/`sanitized` filter (`scene.node(id:)` lookup) would
    /// drop every one of them, since none of them are top-level nodes. This
    /// is the dedicated arrange-mode counterpart of
    /// `setSelectionFromLayersPanel` for exactly that reason.
    public func setArrangeChildSelection(_ ids: Set<MKNodeID>, granularity: MKSelectionGranularity, compositionScope: MKNodeID) {
        selection.granularity = granularity
        selection.compositionScope = compositionScope
        selection.set(ids)
    }

    public func clearSelection() {
        selection.clear()
    }

    public func toggleSelection(_ id: MKNodeID) {
        guard isSelectable(id) else { return }
        selection.toggle(id)
    }

    private func isSelectable(_ id: MKNodeID) -> Bool {
        guard let node = scene.node(id: id) else { return false }
        return !node.core.isLocked && !node.core.isHidden
    }

    private func sanitized(_ ids: Set<MKNodeID>) -> Set<MKNodeID> {
        ids.filter(isSelectable)
    }

    /// World-space union bounds of the current selection, or `nil` when
    /// there is no selection or no `geometrySource` yet wired
    /// (ARCHITECTURE §10.4: derived `selectionBounds`).
    public var selectionBounds: CGRect? {
        guard let geometrySource else { return nil }
        let obbs = selection.ids.compactMap { geometrySource.worldOBB(for: $0, in: scene) }
        return MKOrientedRect.unionBounds(of: obbs)
    }

    /// Single-node world OBB convenience, for handle placement when
    /// exactly one node is selected (so resize/rotate can operate in that
    /// node's own rotated local space, task 6: "anchor math in node-local
    /// space").
    public var singleSelectionOBB: MKOrientedRect? {
        guard let id = selection.single, let geometrySource else { return nil }
        return geometrySource.worldOBB(for: id, in: scene)
    }

    // MARK: - Hit testing / tap / marquee (task 3, 7)

    /// Builds hit-test candidates for `scope` from the current scene +
    /// `geometrySource`. Returns an empty array (never crashes) when no
    /// `geometrySource` is wired yet.
    public func hitCandidates(scope: MKCanvasHitScope = .topLevel) -> [MKHitCandidate] {
        guard let geometrySource else { return [] }
        let nodes: [MKNode]
        switch scope {
        case .topLevel:
            nodes = scene.nodes
        case .insideGroup(let groupID):
            if case .group(let g)? = scene.node(id: groupID) { nodes = g.children } else { nodes = [] }
        case .insideComposition:
            // Glyph/mark/ligature-granularity hit-testing is Arrange-Mode
            // canvas UX (packet task 15, P5) ، out of this P4 slice.
            nodes = []
        }
        return nodes.enumerated().compactMap { index, node in
            guard let obb = geometrySource.worldOBB(for: node.id, in: scene) else { return nil }
            return MKHitCandidate(nodeID: node.id, worldOBB: obb, zIndex: index, isLocked: node.core.isLocked, isHidden: node.core.isHidden)
        }
    }

    /// Handles a tap at `point` (canvas space): selects the topmost hit
    /// (walking occluded objects on repeated same-spot taps, ARCHITECTURE
    /// §10.3), or deselects on an empty-canvas tap (ARCHITECTURE §10.2).
    /// `additive` mirrors a shift/⌘ modifier.
    @discardableResult
    public func tap(at point: CGPoint, zoomScale: CGFloat, now: TimeInterval = Date().timeIntervalSinceReferenceDate, additive: Bool = false) -> MKNodeID? {
        let candidates = hitCandidates()
        let tolerance = MKHitTestPolicy.touchTolerance(zoomScale: zoomScale)
        let ordered = MKHitTestPolicy.hits(at: point, in: candidates, tolerance: tolerance)
        let picked = tapCycleState.select(from: ordered, at: point, now: now)
        if let picked {
            if additive { toggleSelection(picked) } else { setSelection([picked]) }
        } else if !additive {
            clearSelection()
        }
        return picked
    }

    /// Marquee-selects nodes intersecting/contained by `rect` (task 7).
    public func marqueeSelect(rect: CGRect, mode: MKMarqueeMode, additive: Bool = false) {
        let candidates = hitCandidates()
        let hit = MKMarqueeController.select(marquee: rect, candidates: candidates, mode: mode)
        setSelection(additive ? selection.ids.union(hit) : hit)
    }

    // MARK: - Group / ungroup (task 8)

    @discardableResult
    public func group(name: String = "مجموعة") throws -> MKNodeID? {
        guard selection.ids.count > 1 else { return nil }
        let topLevelIDs = scene.nodes.map(\.id)
        let ids = topLevelIDs.filter { selection.ids.contains($0) }
        guard ids.count > 1 else { return nil }
        let groupID = MKNodeID()
        try perform(MKGroupCommand(nodeIDs: ids, groupName: name, groupID: groupID))
        setSelection([groupID])
        return groupID
    }

    public func ungroup() throws {
        guard let id = selection.single, case .group(let g) = scene.node(id: id) else { return }
        let childIDs = Set(g.children.map(\.id))
        try perform(MKUngroupCommand(groupID: id))
        setSelection(childIDs)
    }

    // MARK: - Lock / hide / delete / duplicate / reorder (LayersModel primitives)

    public func setLocked(_ locked: Bool, for id: MKNodeID) throws {
        guard let core = scene.node(id: id)?.core else { return }
        try perform(MKLockHideCommand(nodeID: id, isLocked: locked, isHidden: core.isHidden))
    }

    public func setHidden(_ hidden: Bool, for id: MKNodeID) throws {
        guard let core = scene.node(id: id)?.core else { return }
        try perform(MKLockHideCommand(nodeID: id, isLocked: core.isLocked, isHidden: hidden))
    }

    public func rename(_ id: MKNodeID, to newName: String) throws {
        try perform(MKRenameCommand(nodeID: id, newName: newName))
    }

    public func delete(_ id: MKNodeID) throws {
        try perform(MKRemoveNodeCommand(nodeID: id))
        selection.set(selection.ids.subtracting([id]))
    }

    public func deleteSelection() throws {
        for id in selection.ids where !(scene.node(id: id)?.core.isLocked ?? true) {
            try perform(MKRemoveNodeCommand(nodeID: id))
        }
        clearSelection()
    }

    public func reorder(_ id: MKNodeID, toIndex: Int) throws {
        try perform(MKReorderCommand(nodeID: id, toIndex: toIndex))
    }
}
