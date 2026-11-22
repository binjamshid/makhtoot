import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 10: "flattened ordered list (top-first) with
// sections for arranged-node children (glyphs 'حرف', marks 'تشكيل',
// ligatures 'لام-ألف/رباط') when expanded; operations: select, toggle
// visible/lock, rename, reorder (drag) → z-order commands, delete,
// duplicate. Virtualized windowing API for 5 000 nodes (`rows(in range:)`)."
// Headless: reads `CanvasSession.scene`, emits commands through
// `CanvasSession.perform`/its typed helpers ، no SwiftUI/UIKit dependency.
@MainActor
@Observable
public final class LayersModel {
    public let session: CanvasSession
    /// Which group/arranged nodes are currently disclosed ، collapsed rows
    /// are never recursed into, which is what keeps `rows(in:)` cheap even
    /// on the 5 000-node fixture (task 10 accept: "scrolls without
    /// materializing all rows").
    public private(set) var expanded: Set<MKNodeID> = []

    public init(session: CanvasSession) {
        self.session = session
    }

    public struct LayerRow: Sendable, Identifiable, Equatable {
        public var id: MKNodeID
        public var name: String
        public var kindLabel: String
        public var isVisible: Bool
        public var isLocked: Bool
        public var depth: Int
        public var hasChildren: Bool
        public var isExpanded: Bool
        public var isBackground: Bool
        public var isSelected: Bool

        public init(id: MKNodeID, name: String, kindLabel: String, isVisible: Bool, isLocked: Bool, depth: Int, hasChildren: Bool, isExpanded: Bool, isBackground: Bool, isSelected: Bool) {
            self.id = id
            self.name = name
            self.kindLabel = kindLabel
            self.isVisible = isVisible
            self.isLocked = isLocked
            self.depth = depth
            self.hasChildren = hasChildren
            self.isExpanded = isExpanded
            self.isBackground = isBackground
            self.isSelected = isSelected
        }
    }

    /// Arabic default kind labels (§6: "Selection labels in the layers
    /// panel use Arabic node names by default").
    public static func kindLabel(for node: MKNode) -> String {
        switch node {
        case .group: return "مجموعة" // group
        case .liveText: return "نص" // text
        case .pathText: return "نص على مسار" // text on a path
        case .arranged: return "تشكيل حر" // free arrangement
        case .shape: return "شكل" // shape
        case .image: return "صورة" // image
        case .background: return "خلفية" // background
        }
    }

    private static func arrangedChildLabel(_ child: MKArrangedChild) -> String {
        switch child {
        case .glyph: return "حرف" // letter/glyph
        case .mark: return "تشكيل" // tashkeel/mark
        case .ligature: return "رباط" // ligature (لام-ألف/رباط family)
        }
    }

    /// Row label for a decomposed-ligature CONSTITUENT (packet task 15,
    /// §8.2) ، nested one level deeper than its owning `رباط` row.
    private var componentLabel: String {
        // Latin gloss: component (of the ligature)
        "جزء من الرباط"
    }

    public func toggleExpanded(_ id: MKNodeID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    /// The full flattened row list, top-first (task 10: display order is
    /// the reverse of `MKScene.nodes`' back-to-front paint order, index 0
    /// = backmost). Background is appended last (bottom of panel) and is
    /// never reorderable.
    public var flattenedRows: [LayerRow] {
        var rows: [LayerRow] = []
        for node in session.scene.nodes.reversed() {
            appendRows(for: node, depth: 0, into: &rows)
        }
        let bg = session.scene.background
        rows.append(LayerRow(
            id: bg.core.id, name: bg.core.name, kindLabel: Self.kindLabel(for: .background(bg)),
            isVisible: !bg.core.isHidden, isLocked: bg.core.isLocked, depth: 0, hasChildren: false,
            isExpanded: false, isBackground: true, isSelected: session.selection.contains(bg.core.id)
        ))
        return rows
    }

    private func appendRows(for node: MKNode, depth: Int, into rows: inout [LayerRow]) {
        let hasChildren: Bool
        switch node {
        case .group(let g): hasChildren = !g.children.isEmpty
        case .arranged(let a): hasChildren = !a.composition.nodes.isEmpty
        default: hasChildren = false
        }
        let isExpanded = expanded.contains(node.id)
        rows.append(LayerRow(
            id: node.id, name: node.core.name, kindLabel: Self.kindLabel(for: node),
            isVisible: !node.core.isHidden, isLocked: node.core.isLocked, depth: depth,
            hasChildren: hasChildren, isExpanded: isExpanded, isBackground: false,
            isSelected: session.selection.contains(node.id)
        ))
        guard isExpanded else { return }
        switch node {
        case .group(let g):
            for child in g.children.reversed() { appendRows(for: child, depth: depth + 1, into: &rows) }
        case .arranged(let a):
            for child in a.composition.nodes.reversed() {
                // A DECOMPOSED ligature (§8.2, packet task 15) shows its own
                // constituent glyph rows nested one level further ، the
                // layers-panel visibility the "decompose ligature" action's
                // result needs (mirrors the group-node disclosure pattern
                // just above, one level deeper).
                let decomposedComponents: [MKGlyphNode]
                if case .ligature(let group) = child, case .decomposed(let d) = group.state {
                    decomposedComponents = d.components
                } else {
                    decomposedComponents = []
                }
                let childExpanded = expanded.contains(child.id)
                rows.append(LayerRow(
                    id: child.id, name: Self.arrangedChildLabel(child), kindLabel: Self.arrangedChildLabel(child),
                    isVisible: true, isLocked: false, depth: depth + 1,
                    hasChildren: !decomposedComponents.isEmpty, isExpanded: childExpanded, isBackground: false,
                    isSelected: session.selection.contains(child.id)
                ))
                guard childExpanded else { continue }
                for component in decomposedComponents.reversed() {
                    rows.append(LayerRow(
                        id: component.id, name: componentLabel, kindLabel: componentLabel,
                        isVisible: true, isLocked: false, depth: depth + 2, hasChildren: false,
                        isExpanded: false, isBackground: false, isSelected: session.selection.contains(component.id)
                    ))
                }
            }
        default:
            break
        }
    }

    /// Virtualized windowing (task 10: "`rows(in range:)`"). Materializes
    /// `flattenedRows` once per call ، cheap for the collapsed common case
    /// (only top-level nodes, O(top-level count) regardless of how many
    /// nodes a 5 000-node fixture has nested inside collapsed groups) and
    /// lets the caller (a `LazyVStack`/`UICollectionView` diffable source)
    /// slice out only the visible window rather than rendering every row.
    public func rows(in range: Range<Int>) -> [LayerRow] {
        let all = flattenedRows
        let clamped = range.clamped(to: 0..<all.count)
        guard clamped.lowerBound < clamped.upperBound else { return [] }
        return Array(all[clamped])
    }

    public var rowCount: Int { flattenedRows.count }

    // MARK: - Operations (task 10)

    /// Panel selection uses the layers-panel path (PRD R-4.6): locked and
    /// hidden nodes ARE selectable from here ، the panel is the sanctioned
    /// affordance for selecting a locked node to unlock it (lock badge in
    /// `LayerRow.isLocked`), unlike canvas tap/marquee which skip them.
    ///
    /// Arrange Mode (packet task 15): `id` may instead be an arranged-CHILD
    /// row (glyph/mark/ligature nested under an `.arranged` row per
    /// `appendRows`' composition branch above) ، those ids are never
    /// top-level scene nodes, so `setSelectionFromLayersPanel`'s
    /// `scene.node(id:)` filter would silently drop them. `ownerOfChild`
    /// resolves that case first and routes through
    /// `CanvasSession.setArrangeChildSelection` instead, entering the
    /// composition scope as a side effect (selecting a nested row from the
    /// panel while browsing implicitly focuses that composition, matching
    /// R-6.10's "layer-listed... entering Arrange Mode again resumes
    /// per-node editing" framing ، the panel IS one more way in).
    public func select(_ id: MKNodeID, additive: Bool = false) {
        if let ownerID = ownerOfChild(id) {
            let newIDs: Set<MKNodeID>
            if additive, session.selection.compositionScope == ownerID {
                var ids = session.selection.ids
                if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
                newIDs = ids
            } else {
                newIDs = [id]
            }
            session.setArrangeChildSelection(newIDs, granularity: session.selection.granularity == .letter ? .letter : .glyph, compositionScope: ownerID)
            return
        }
        if additive {
            var ids = session.selection.ids
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
            session.setSelectionFromLayersPanel(ids)
        } else {
            session.setSelectionFromLayersPanel([id])
        }
    }

    /// The owning `.arranged` top-level node id if `id` is one of its
    /// composition children (including a decomposed ligature's own
    /// components), else `nil`.
    private func ownerOfChild(_ id: MKNodeID) -> MKNodeID? {
        for node in session.scene.nodes {
            guard case .arranged(let arranged) = node else { continue }
            if arranged.composition.child(id: id) != nil { return node.id }
            for child in arranged.composition.nodes {
                if case .ligature(let group) = child, case .decomposed(let d) = group.state, d.components.contains(where: { $0.id == id }) {
                    return node.id
                }
            }
        }
        return nil
    }

    public func toggleVisibility(_ id: MKNodeID) throws {
        guard let core = session.scene.node(id: id)?.core else { return }
        try session.setHidden(!core.isHidden, for: id)
    }

    public func toggleLock(_ id: MKNodeID) throws {
        guard let core = session.scene.node(id: id)?.core else { return }
        try session.setLocked(!core.isLocked, for: id)
    }

    public func rename(_ id: MKNodeID, to newName: String) throws {
        try session.rename(id, to: newName)
    }

    /// Reorders a TOP-LEVEL node to `toIndex` (task 10: "reorder (drag) →
    /// z-order commands"). Matches `MKScene.reordering`'s own documented
    /// scope (top-level only) ، reordering across group boundaries is a
    /// remove+insert the caller composes, not this method's job.
    public func reorder(_ id: MKNodeID, toIndex: Int) throws {
        try session.reorder(id, toIndex: toIndex)
    }

    public func delete(_ id: MKNodeID) throws {
        try session.delete(id)
    }

    /// Duplicates a top-level node: deep-clones it with a FRESH id (and
    /// fresh ids for every arranged descendant, so provenance/undo never
    /// aliases the original), inserted directly above the source in paint
    /// order, then selects the duplicate.
    public func duplicate(_ id: MKNodeID) throws {
        guard let node = session.scene.node(id: id) else { return }
        guard let index = session.scene.nodes.firstIndex(where: { $0.id == id }) else { return }
        let clone = Self.reassigningIDs(node)
        try session.perform(MKInsertNodeCommand(node: clone, index: index + 1, parent: nil))
        session.setSelection([clone.id])
    }

    /// Not `private`: P6's Paste (`EditingOperations.swift`, same module)
    /// reuses this exact fresh-id-minting logic (including the arranged-
    /// composition cross-reference remap below) rather than duplicating it
    /// ، a pasted node needs the identical "new id for the node itself, new
    /// ids for every arranged descendant with cross-references remapped
    /// consistently" guarantee `duplicate(_:)` already established, for the
    /// identical reason (undo/provenance must never alias the source).
    static func reassigningIDs(_ node: MKNode) -> MKNode {
        var core = node.core
        core.id = MKNodeID()
        switch node {
        case .group(var g):
            g.core = core
            g.children = g.children.map(reassigningIDs)
            return .group(g)
        case .liveText(var n): n.core = core; return .liveText(n)
        case .pathText(var n): n.core = core; return .pathText(n)
        case .shape(var n): n.core = core; return .shape(n)
        case .image(var n): n.core = core; return .image(n)
        case .background(var n): n.core = core; return .background(n)
        case .arranged(var n):
            n.core = core
            // Arranged children reference EACH OTHER by id (`MKMarkNode
            // .attachedTo`, `MKLigatureGroup.attachedMarks`) ، a fresh-id
            // pass must remap those cross-references consistently, not
            // just each child's own id, or a duplicated composition's
            // marks would silently point at the ORIGINAL's glyph ids.
            var remap: [MKNodeID: MKNodeID] = [:]
            for child in n.composition.nodes { remap[child.id] = MKNodeID() }
            n.composition.nodes = n.composition.nodes.map { reassigningArrangedChildID($0, remap: remap) }
            return .arranged(n)
        }
    }

    private static func reassigningArrangedChildID(_ child: MKArrangedChild, remap: [MKNodeID: MKNodeID]) -> MKArrangedChild {
        switch child {
        case .glyph(var g):
            g.id = remap[g.id] ?? MKNodeID()
            return .glyph(g)
        case .mark(var m):
            m.id = remap[m.id] ?? MKNodeID()
            if let attached = m.attachedTo { m.attachedTo = remap[attached] ?? attached }
            return .mark(m)
        case .ligature(var l):
            l.id = remap[l.id] ?? MKNodeID()
            l.attachedMarks = l.attachedMarks.map { remap[$0] ?? $0 }
            return .ligature(l)
        }
    }
}
