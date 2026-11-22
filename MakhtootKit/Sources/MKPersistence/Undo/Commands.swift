import Foundation
import MKFoundation
import MKModel

// WS-02 packet §5 task 10. Concrete command catalog. Every command follows
// the same shape for correctness under coalescing (§14.3): `apply` SETS an
// absolute new value (never a relative delta), and `inverse(against:)`
// captures the absolute PRIOR value from the pre-apply scene. That makes
// coalescing trivially correct ، see `UndoStack.swift`'s doc comment for
// why "keep first inverse, discard the rest" restores full pre-gesture
// state regardless of how many coalesced steps ran in between.
//
// All types are `Codable` (in addition to `MKCommand`) so `MKCommandCoder`
// (`CommandJournal.swift`) can serialize the forward form of every command
// to `journal.mkj` (§14.4: "every command's forward form is journaled, not
// inverses").

// MARK: - Insert / Remove

public struct MKInsertNodeCommand: MKCommand, Codable {
    public let id: UUID
    public var node: MKNode
    public var index: Int?
    public var parent: MKNodeID?
    public var name: String { "إدراج عنصر" } // insert element
    public var coalescingKey: String? { nil }

    public init(node: MKNode, index: Int? = nil, parent: MKNodeID? = nil, id: UUID = UUID()) {
        self.id = id
        self.node = node
        self.index = index
        self.parent = parent
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.inserting(node, at: index, parent: parent)
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        MKRemoveNodeCommand(nodeID: node.id)
    }
}

/// Plural sibling of `MKInsertNodeCommand` ، P6 Paste's primitive: inserts
/// several already-fresh-id'd top-level nodes in ONE undo entry (§2.3
/// "go through the command funnel so it is undoable as a single step"),
/// rather than one `MKInsertNodeCommand.perform` call per pasted node
/// (which would fragment a multi-node paste into N separate undo steps).
/// Inverse follows `MKGroupCommand`/`MKUngroupCommand`'s own "snapshot the
/// whole top-level array" shape (`MKRestoreTopLevelNodesCommand`) rather
/// than N individual `MKRemoveNodeCommand`s, for the same reason those two
/// commands chose it: correctness (the pasted nodes are, by construction,
/// simple top-level siblings with no cross-node structural entanglement
/// requiring finer-grained inverses) beats a marginally smaller inverse
/// payload.
public struct MKInsertNodesCommand: MKCommand, Codable {
    public let id: UUID
    public var nodes: [MKNode]
    public var parent: MKNodeID?
    public var name: String { "لصق" } // paste
    public var coalescingKey: String? { nil }

    public init(nodes: [MKNode], parent: MKNodeID? = nil, id: UUID = UUID()) {
        self.id = id
        self.nodes = nodes
        self.parent = parent
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        var result = scene
        for node in nodes {
            result = result.inserting(node, at: nil, parent: parent)
        }
        return result
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        MKRestoreTopLevelNodesCommand(previousNodes: scene.nodes)
    }
}

public struct MKRemoveNodeCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var name: String { "حذف عنصر" } // delete element
    public var coalescingKey: String? { nil }

    public init(nodeID: MKNodeID, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.removing(id: nodeID)
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        guard let node = scene.node(id: nodeID) else { return MKNoOpCommand(name: name) }
        let location = scene.locate(id: nodeID)
        return MKInsertNodeCommand(node: node, index: location?.index, parent: location?.parent)
    }
}

// MARK: - Reorder (z)

public struct MKReorderCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var toIndex: Int
    public var name: String { "إعادة ترتيب الطبقات" } // reorder layers
    public var coalescingKey: String? { "reorder:\(nodeID)" }

    public init(nodeID: MKNodeID, toIndex: Int, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.toIndex = toIndex
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.reordering(id: nodeID, toIndex: toIndex)
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        let fromIndex = scene.nodes.firstIndex(where: { $0.id == nodeID }) ?? toIndex
        return MKReorderCommand(nodeID: nodeID, toIndex: fromIndex)
    }
}

// MARK: - Transform

public struct MKTransformCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var newTransform: MKTransform2D
    public var name: String { "تحريك" } // move
    public var coalescingKey: String? { "transform:\(nodeID)" }

    public init(nodeID: MKNodeID, newTransform: MKTransform2D, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.newTransform = newTransform
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.transform = newTransform
            node = node.withCore(core)
        }
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        let oldTransform = scene.node(id: nodeID)?.core.transform ?? .identity
        return MKTransformCommand(nodeID: nodeID, newTransform: oldTransform)
    }
}

// MARK: - Style

public struct MKStyleCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var newStyle: MKStyle
    public var name: String { "تنسيق" } // style/format
    public var coalescingKey: String? { "style:\(nodeID)" }

    public init(nodeID: MKNodeID, newStyle: MKStyle, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.newStyle = newStyle
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.style = newStyle
            node = node.withCore(core)
        }
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        let oldStyle = scene.node(id: nodeID)?.core.style ?? .default
        return MKStyleCommand(nodeID: nodeID, newStyle: oldStyle)
    }
}

// MARK: - Lock / Hide

public struct MKLockHideCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var isLocked: Bool
    public var isHidden: Bool
    public var name: String { "قفل/إخفاء" } // lock/hide
    public var coalescingKey: String? { nil }

    public init(nodeID: MKNodeID, isLocked: Bool, isHidden: Bool, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.isLocked = isLocked
        self.isHidden = isHidden
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.isLocked = isLocked
            core.isHidden = isHidden
            node = node.withCore(core)
        }
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        let core = scene.node(id: nodeID)?.core
        return MKLockHideCommand(nodeID: nodeID, isLocked: core?.isLocked ?? false, isHidden: core?.isHidden ?? false)
    }
}

// MARK: - Rename

public struct MKRenameCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var newName: String
    public var name: String { "إعادة تسمية" } // rename
    public var coalescingKey: String? { "rename:\(nodeID)" }

    public init(nodeID: MKNodeID, newName: String, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.newName = newName
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.name = newName
            node = node.withCore(core)
        }
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        let oldName = scene.node(id: nodeID)?.core.name ?? ""
        return MKRenameCommand(nodeID: nodeID, newName: oldName)
    }
}

// MARK: - Canvas size change

public struct MKCanvasSpecCommand: MKCommand, Codable {
    public let id: UUID
    public var newCanvas: MKCanvasSpec
    public var name: String { "تغيير حجم اللوحة" } // change canvas size
    public var coalescingKey: String? { "canvasSpec" }

    public init(newCanvas: MKCanvasSpec, id: UUID = UUID()) {
        self.id = id
        self.newCanvas = newCanvas
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        var copy = scene
        copy.canvas = newCanvas
        return copy
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        MKCanvasSpecCommand(newCanvas: scene.canvas)
    }
}

// MARK: - Group / Ungroup

/// Restores the entire top-level `nodes` array to a prior snapshot ، the
/// exact, guaranteed-correct inverse for structural operations
/// (group/ungroup) whose forward effect touches more than one node's
/// position at once, where a field-level diff would be substantially more
/// code for no behavioral benefit at v1 scene sizes (D-112 undo budget is
/// memory-bounded, not diff-size-bounded).
public struct MKRestoreTopLevelNodesCommand: MKCommand, Codable {
    public let id: UUID
    public var previousNodes: [MKNode]
    public var name: String { "استعادة الحالة السابقة" } // restore previous state
    public var coalescingKey: String? { nil }

    public init(previousNodes: [MKNode], id: UUID = UUID()) {
        self.id = id
        self.previousNodes = previousNodes
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        var copy = scene
        copy.nodes = previousNodes
        return copy
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        MKRestoreTopLevelNodesCommand(previousNodes: scene.nodes)
    }
}

public struct MKGroupCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeIDs: [MKNodeID]
    public var groupName: String
    public var groupID: MKNodeID
    public var name: String { "تجميع" } // group
    public var coalescingKey: String? { nil }

    public init(nodeIDs: [MKNodeID], groupName: String, groupID: MKNodeID = MKNodeID(), id: UUID = UUID()) {
        self.id = id
        self.nodeIDs = nodeIDs
        self.groupName = groupName
        self.groupID = groupID
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        scene.reparenting(nodeIDs, intoGroupNamed: groupName, groupID: groupID)
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        MKRestoreTopLevelNodesCommand(previousNodes: scene.nodes)
    }
}

public struct MKUngroupCommand: MKCommand, Codable {
    public let id: UUID
    public var groupID: MKNodeID
    public var name: String { "إلغاء التجميع" } // ungroup
    public var coalescingKey: String? { nil }

    public init(groupID: MKNodeID, id: UUID = UUID()) {
        self.id = id
        self.groupID = groupID
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        var copy = scene
        guard let index = copy.nodes.firstIndex(where: { $0.id == groupID }),
              case .group(let g) = copy.nodes[index] else { return copy }
        // Compose the group's OWN transform into each child before
        // splicing the children back to top level. A child's stored
        // transform is LOCAL to the group's frame; once the group itself
        // has been moved/rotated/scaled after grouping, local ≠ world, and
        // splicing children back with their transforms untouched (this
        // command's original, buggy behavior ، found by WS-06's canvas
        // lane, see docs/impl-log/WS-06.md "real bugs" item 3 and
        // docs/impl-log/WS-02.md session 2) silently snaps them back to
        // their pre-group-transform positions. Composition order follows
        // `MKTransform2D.concatenating`'s contract ("self followed by
        // other"): child-local first (into the group's frame), then the
        // group's transform (into the parent frame) ، the same math as
        // `MKCanvas`'s `MKGroupTransform.worldTransform(childLocal:groupTransform:)`,
        // inlined here because `MKPersistence` cannot depend on `MKCanvas`
        // (the dependency edge runs the other way). Exact whenever the
        // group's scale is uniform or its rotation is zero, per the
        // documented shear-free limitation on `MKTransform2D.concatenating`.
        let groupTransform = g.core.transform
        let composedChildren = g.children.map { child -> MKNode in
            var core = child.core
            core.transform = core.transform.concatenating(groupTransform)
            return child.withCore(core)
        }
        copy.nodes.replaceSubrange(index...index, with: composedChildren)
        return copy
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        MKRestoreTopLevelNodesCommand(previousNodes: scene.nodes)
    }
}

// MARK: - Batch / text-edit primitives (canonicalized from WS-06's canvas lane)

// Added in WS-02 session 2 (docs/impl-log/WS-02.md) at the coordinator's
// direction: the canvas lane (WS-06) shipped local `MKCommand` conformers
// (`MKCanvasMultiTransformCommand`, `MKCanvasMultiCoreCommand`,
// `MKCanvasTextEditCommand` in `MKCanvas/Commands/
// MKCanvasCompositeCommands.swift`) that `MKCommandCoder`'s closed switch
// could not encode ، so `CommandJournal.append` threw `unknownCommandType`
// for every multi-select drag, inspector edit, and typing burst, silently
// exempting those gestures from crash-recovery replay (a D-223/no-loss
// violation). These three types are the CANONICAL, journal-codable
// equivalents, matching the canvas conformers' semantics exactly
// (including coalescing-key formats) so the canvas side can adopt them as
// drop-in replacements and retire its local copies ، see CONTRACTS.md.

/// Multi-node transform-set in ONE undo entry, coalesced per-GESTURE (not
/// per-node). `MKTransformCommand`'s `"transform:\(nodeID)"` key breaks
/// down for multi-select drags: N differing per-node keys inside one
/// gesture bracket produce N undo entries under `MKUndoStack`'s
/// single-`gestureCoalescingKey` rule. Carrying every moved node's new
/// transform in one command instance keeps exactly one key (the gesture
/// id) in play regardless of selection size.
public struct MKBatchTransformCommand: MKCommand, Codable {
    public let id: UUID
    public var newTransforms: [MKNodeID: MKTransform2D]
    public var gestureID: UUID
    public var name: String { "تحريك" } // move

    public init(gestureID: UUID, newTransforms: [MKNodeID: MKTransform2D], id: UUID = UUID()) {
        self.id = id
        self.gestureID = gestureID
        self.newTransforms = newTransforms
    }

    public var coalescingKey: String? { "move-\(gestureID)" }

    public func apply(to scene: MKScene) throws -> MKScene {
        var result = scene
        for (nodeID, transform) in newTransforms {
            result = result.updatingNode(id: nodeID) { node in
                var core = node.core
                core.transform = transform
                node = node.withCore(core)
            }
        }
        return result
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        var priorTransforms: [MKNodeID: MKTransform2D] = [:]
        for nodeID in newTransforms.keys {
            priorTransforms[nodeID] = scene.node(id: nodeID)?.core.transform ?? .identity
        }
        return MKBatchTransformCommand(gestureID: gestureID, newTransforms: priorTransforms)
    }
}

/// Multi-node whole-`MKNodeCore` replacement, one undo entry per gesture ،
/// the shared coalescing mechanism for any multi-node property edit
/// (inspector sliders, handle resize) that touches core fields beyond
/// `transform`.
public struct MKBatchCoreCommand: MKCommand, Codable {
    public let id: UUID
    public var newCores: [MKNodeID: MKNodeCore]
    public var gestureID: UUID
    public var label: String
    public var name: String { label }

    public init(gestureID: UUID, newCores: [MKNodeID: MKNodeCore], label: String = "تحرير", id: UUID = UUID()) {
        // "تحرير" (edit)
        self.id = id
        self.gestureID = gestureID
        self.newCores = newCores
        self.label = label
    }

    public var coalescingKey: String? { "core-\(gestureID)" }

    public func apply(to scene: MKScene) throws -> MKScene {
        var result = scene
        for (nodeID, core) in newCores {
            result = result.updatingNode(id: nodeID) { node in node = node.withCore(core) }
        }
        return result
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        var priorCores: [MKNodeID: MKNodeCore] = [:]
        for nodeID in newCores.keys {
            if let core = scene.node(id: nodeID)?.core { priorCores[nodeID] = core }
        }
        return MKBatchCoreCommand(gestureID: gestureID, newCores: priorCores, label: label)
    }
}

/// Whole-node replace for the D-104 text-editing-overlay commit path,
/// coalesced per keystroke burst (§14.3's `.textEdit(nodeID)` scheme,
/// 700 ms window). Same opaque-replace shape as `MKReplaceNodeCommand`,
/// plus a real coalescing key: callers pass a `burstKey` that stays stable
/// within one burst window (e.g. `"textEdit:\(nodeID):\(burstGeneration)"`)
/// so keystrokes inside the window share one undo entry and a new burst
/// starts a fresh one. This is ARCHITECTURE §14.1's `MKTextEditCommand`,
/// previously missing from this catalog (flagged by WS-06).
public struct MKTextEditCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var newNode: MKNode
    public var burstKey: String
    public var name: String { "كتابة" } // typing

    public init(nodeID: MKNodeID, newNode: MKNode, burstKey: String, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.newNode = newNode
        self.burstKey = burstKey
    }

    public var coalescingKey: String? { burstKey }

    public func apply(to scene: MKScene) throws -> MKScene {
        guard scene.node(id: nodeID) != nil else { throw MKPersistenceError.nodeNotFound(nodeID) }
        return scene.updatingNode(id: nodeID) { $0 = newNode }
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        guard let old = scene.node(id: nodeID) else { return MKNoOpCommand(name: name) }
        return MKTextEditCommand(nodeID: nodeID, newNode: old, burstKey: burstKey)
    }
}

// MARK: - Generic structural replace (canonicalized for WS-04 arrange ops)

/// Canonical, journal-codable structural replacement: swaps one or more
/// nodes (matched by id, anywhere in the tree) for full replacement
/// `MKNode` payloads. Added in WS-02 session 3 (coordinator-directed) so
/// `MKArrange`'s composition-mutation command
/// (`MKArrangedCompositionCommand`, which `MKCommandCoder` can never
/// reference ، `MKArrange` depends on `MKPersistence`, not the reverse)
/// has a canonical equivalent whose journal replay works: derive, revert,
/// join break/restore, ligature decompose/recompose, mark attach/detach,
/// and per-child style/transform edits are all expressible as "replace
/// node X with new full node value X′" (the caller computes X′ purely,
/// exactly as `MKArrange`'s controllers already do).
///
/// Differences vs. `MKReplaceNodeCommand` (kept, unchanged, for existing
/// single-node call sites): plural targets in one undo entry, an Arabic
/// label passthrough (arrange ops need per-operation menu labels ،
/// "فك الارتباط", "اختيار الشكل", …), and an OPTIONAL coalescing key for
/// continuous gestures. Default `coalescingKeySuffix: nil` = never
/// coalesces ، the right semantics for one-shot structural ops
/// (derive/revert/decompose/recompose); pass a per-gesture suffix (e.g.
/// `"style:\(gestureID)"`) only for slider-style continuous edits, same
/// contract as `MKArrangedCompositionCommand.coalescingKeySuffix`.
public struct MKReplaceNodesCommand: MKCommand, Codable {
    public let id: UUID
    /// Keyed by the id of the node BEING REPLACED. Replacement payloads
    /// normally carry the same id (in-place mutation of one node's
    /// content); a differing id is allowed (node-kind swap that mints a
    /// new identity) ، the inverse still restores exactly, since it
    /// captures the full prior node under the original key.
    public var newNodes: [MKNodeID: MKNode]
    /// Arabic undo-menu label (e.g. "تفكيك الرباط" decompose ligature).
    public var label: String
    /// `nil` (default) = never coalesces (one-shot structural op).
    public var coalescingKeySuffix: String?

    public var name: String { label }
    public var coalescingKey: String? { coalescingKeySuffix.map { "replaceNodes-\($0)" } }

    public init(newNodes: [MKNodeID: MKNode], label: String, coalescingKeySuffix: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.newNodes = newNodes
        self.label = label
        self.coalescingKeySuffix = coalescingKeySuffix
    }

    /// Single-node convenience ، the shape every current `MKArrange` call
    /// site needs.
    public init(nodeID: MKNodeID, newNode: MKNode, label: String, coalescingKeySuffix: String? = nil, id: UUID = UUID()) {
        self.init(newNodes: [nodeID: newNode], label: label, coalescingKeySuffix: coalescingKeySuffix, id: id)
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        var result = scene
        for (nodeID, newNode) in newNodes {
            guard result.node(id: nodeID) != nil else { throw MKPersistenceError.nodeNotFound(nodeID) }
            result = result.updatingNode(id: nodeID) { $0 = newNode }
        }
        return result
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        var priorNodes: [MKNodeID: MKNode] = [:]
        for nodeID in newNodes.keys {
            if let old = scene.node(id: nodeID) { priorNodes[nodeID] = old }
        }
        guard !priorNodes.isEmpty else { return MKNoOpCommand(name: label) }
        return MKReplaceNodesCommand(newNodes: priorNodes, label: label, coalescingKeySuffix: coalescingKeySuffix)
    }
}

// MARK: - Opaque replace (WS-04/WS-05 arrange/revert)

/// Opaque whole-node replacement ، the primitive WS-04 (Arrange Mode) and
/// WS-05 (Path Text arrange) build on: converting a `liveText`/`pathText`
/// node into an `arranged` node, or reverting one back, is "replace the
/// node at this id with this other node value," which this packet doesn't
/// need to understand the semantics of (task 10: "plus opaque replaceNode
/// used by WS-04/WS-05 for arrange/revert").
public struct MKReplaceNodeCommand: MKCommand, Codable {
    public let id: UUID
    public var nodeID: MKNodeID
    public var newNode: MKNode
    public var name: String { "استبدال عنصر" } // replace element
    public var coalescingKey: String? { nil }

    public init(nodeID: MKNodeID, newNode: MKNode, id: UUID = UUID()) {
        self.id = id
        self.nodeID = nodeID
        self.newNode = newNode
    }

    public func apply(to scene: MKScene) throws -> MKScene {
        guard scene.node(id: nodeID) != nil else { throw MKPersistenceError.nodeNotFound(nodeID) }
        return scene.updatingNode(id: nodeID) { $0 = newNode }
    }

    public func inverse(against scene: MKScene) -> any MKCommand {
        guard let old = scene.node(id: nodeID) else { return MKNoOpCommand(name: name) }
        return MKReplaceNodeCommand(nodeID: nodeID, newNode: old)
    }
}
