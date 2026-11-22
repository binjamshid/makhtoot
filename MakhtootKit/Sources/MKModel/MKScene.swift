import CoreGraphics
import Foundation
import MKFoundation

// WS-02 packet §5 task 3. `MKScene` ، the root value: canvas spec,
// background node, ordered top-level nodes, schemaVersion. Every mutation
// is a pure function returning a NEW scene (task 3 accept: "mutating a copy
// leaves original intact") ، undo/redo (`MKPersistence`) and the renderer
// snapshot contract (D-102) both depend on this.

public struct MKCanvasSpec: Hashable, Sendable, Codable, Equatable {
    /// Document points. Single canvas per project in v1 (D-111; multi-page
    /// is the `MKFeatureFlags.multiPageSeam` extension seam, always off).
    public var size: CGSize
    /// Export preset provenance (§16.8) ، e.g. `"social.portrait.4x5"`.
    public var presetID: String?

    public init(size: CGSize, presetID: String? = nil) {
        self.size = size
        self.presetID = presetID
    }
}

/// The root scene value (D-111). `Hashable` so `MKSceneDiffer`-style
/// dirty-tracking (autosave, §14.4) can cheaply detect "did anything
/// change" via structural hash before doing real work.
public struct MKScene: Hashable, Sendable, Codable, Equatable {
    public var schemaVersion: Int
    public var canvas: MKCanvasSpec
    public var background: MKBackgroundNode
    /// Ordered children, z-order: index 0 = backmost. Excludes
    /// `background`, which paints beneath everything unconditionally.
    public var nodes: [MKNode]

    public init(
        schemaVersion: Int = MKSceneSchema.currentVersion,
        canvas: MKCanvasSpec,
        background: MKBackgroundNode = .defaultBackground(),
        nodes: [MKNode] = []
    ) {
        self.schemaVersion = schemaVersion
        self.canvas = canvas
        self.background = background
        self.nodes = nodes
    }

    // MARK: - Pure tree operations

    /// Inserts `node` at `index` within `parent`'s children (top-level
    /// `nodes` when `parent` is `nil`), or appended if `index` is
    /// `nil`/out of bounds. If `parent` is non-nil but not found (or isn't
    /// a group), falls back to top-level append ، insertion is best-effort
    /// idempotent-safe rather than throwing, matching every other pure
    /// tree operation on this type.
    public func inserting(_ node: MKNode, at index: Int? = nil, parent: MKNodeID? = nil) -> MKScene {
        var copy = self
        guard let parent else {
            let clampedIndex = index.map { max(0, min($0, copy.nodes.count)) } ?? copy.nodes.count
            copy.nodes.insert(node, at: clampedIndex)
            return copy
        }
        var didInsert = false
        copy.nodes = Self.insertingRecursive(node, at: index, parent: parent, into: copy.nodes, inserted: &didInsert)
        if !didInsert {
            // Parent not found anywhere in the tree ، fall back to
            // top-level append rather than silently dropping the node.
            copy.nodes.append(node)
        }
        return copy
    }

    private static func insertingRecursive(
        _ node: MKNode, at index: Int?, parent: MKNodeID, into nodes: [MKNode], inserted: inout Bool
    ) -> [MKNode] {
        var result = nodes
        for i in result.indices {
            if case .group(var g) = result[i] {
                if g.core.id == parent {
                    let clampedIndex = index.map { max(0, min($0, g.children.count)) } ?? g.children.count
                    g.children.insert(node, at: clampedIndex)
                    result[i] = .group(g)
                    inserted = true
                } else {
                    g.children = insertingRecursive(node, at: index, parent: parent, into: g.children, inserted: &inserted)
                    result[i] = .group(g)
                }
            }
        }
        return result
    }

    /// Locates a node's parent group id (`nil` = top level) and index
    /// within its parent's children array ، the information
    /// `MKRemoveNodeCommand` needs to build an exact `MKInsertNodeCommand`
    /// inverse.
    public func locate(id: MKNodeID) -> (parent: MKNodeID?, index: Int)? {
        if let index = nodes.firstIndex(where: { $0.id == id }) { return (nil, index) }
        return Self.locateRecursive(id: id, in: nodes)
    }

    private static func locateRecursive(id: MKNodeID, in nodes: [MKNode]) -> (parent: MKNodeID?, index: Int)? {
        for node in nodes {
            if case .group(let g) = node {
                if let index = g.children.firstIndex(where: { $0.id == id }) {
                    return (g.core.id, index)
                }
                if let found = locateRecursive(id: id, in: g.children) {
                    return found
                }
            }
        }
        return nil
    }

    /// Removes the node with `id` wherever it is in the tree (top level or
    /// nested inside any group). No-op (returns an identical scene) if not
    /// found.
    public func removing(id: MKNodeID) -> MKScene {
        var copy = self
        copy.nodes = Self.removingRecursive(id: id, from: copy.nodes)
        return copy
    }

    private static func removingRecursive(id: MKNodeID, from nodes: [MKNode]) -> [MKNode] {
        var result: [MKNode] = []
        result.reserveCapacity(nodes.count)
        for node in nodes {
            if node.id == id { continue }
            if case .group(var g) = node {
                g.children = removingRecursive(id: id, from: g.children)
                result.append(.group(g))
            } else {
                result.append(node)
            }
        }
        return result
    }

    /// Moves the node with `id` (searched at the top level only ، z-order
    /// is a sibling concept, and reordering across groups is a
    /// remove+insert composed by the caller/command layer) to `toIndex`
    /// within `nodes`.
    public func reordering(id: MKNodeID, toIndex: Int) -> MKScene {
        var copy = self
        guard let currentIndex = copy.nodes.firstIndex(where: { $0.id == id }) else { return copy }
        let node = copy.nodes.remove(at: currentIndex)
        let clampedIndex = max(0, min(toIndex, copy.nodes.count))
        copy.nodes.insert(node, at: clampedIndex)
        return copy
    }

    /// Groups the top-level nodes with `ids` (in their current relative
    /// order) into a new `MKGroupNode` inserted at the position of the
    /// first grouped node; ids not found at the top level are ignored.
    /// Nested-group reparenting is intentionally out of this packet's
    /// scope (WS-06 gesture-driven regrouping composes this primitive as
    /// needed).
    public func reparenting(_ ids: [MKNodeID], intoGroupNamed name: String, groupID: MKNodeID = MKNodeID()) -> MKScene {
        var copy = self
        let idSet = Set(ids)
        guard let firstIndex = copy.nodes.firstIndex(where: { idSet.contains($0.id) }) else { return copy }
        var grouped: [MKNode] = []
        var remaining: [MKNode] = []
        for node in copy.nodes {
            if idSet.contains(node.id) {
                grouped.append(node)
            } else {
                remaining.append(node)
            }
        }
        guard !grouped.isEmpty else { return copy }
        let groupCore = MKNodeCore(id: groupID, name: name, zOrder: firstIndex)
        let group = MKNode.group(MKGroupNode(core: groupCore, children: grouped))
        let insertAt = min(firstIndex, remaining.count)
        remaining.insert(group, at: insertAt)
        copy.nodes = remaining
        return copy
    }

    /// Applies `transform` to the node with `id`, wherever it is in the
    /// tree. No-op if not found.
    public func updatingNode(id: MKNodeID, _ transform: (inout MKNode) -> Void) -> MKScene {
        var copy = self
        if copy.background.core.id == id {
            var wrapped = MKNode.background(copy.background)
            transform(&wrapped)
            if case .background(let updated) = wrapped { copy.background = updated }
            return copy
        }
        copy.nodes = Self.updatingRecursive(id: id, in: copy.nodes, transform)
        return copy
    }

    private static func updatingRecursive(id: MKNodeID, in nodes: [MKNode], _ transform: (inout MKNode) -> Void) -> [MKNode] {
        var result = nodes
        for i in result.indices {
            if result[i].id == id {
                transform(&result[i])
            } else if case .group(var g) = result[i] {
                g.children = updatingRecursive(id: id, in: g.children, transform)
                result[i] = .group(g)
            }
        }
        return result
    }

    /// Find-by-id over the whole tree (background + nodes, recursing into
    /// groups). Builds a fresh `MKNodeIndex` per call ، for repeated
    /// lookups (e.g. hit-testing many candidates against one scene
    /// revision), build an `MKNodeIndex` once via
    /// `MKNodeIndex(scene:)` and reuse it instead.
    public func node(id: MKNodeID) -> MKNode? {
        MKNodeIndex(scene: self).node(id: id)
    }
}

/// O(1)-lookup index over a scene's nodes (task 3: "find-by-id (indexed)").
/// A plain `struct` wrapping a dictionary built in one tree walk ، not
/// cached inside `MKScene` itself, since `MKScene` is a `Hashable`/`Equatable`
/// value type and caching a derived index on it would either break value
/// semantics (a class-boxed cache two "equal" scenes might not share) or
/// require excluding the cache from `Equatable`/`Hashable` (a common but
/// easy-to-get-wrong pattern). Building the index is a single O(n) pass;
/// building it once per document-mutation cycle (as `MakhtootDocument` does)
/// keeps steady-state lookups O(1).
public struct MKNodeIndex: Sendable {
    private var table: [MKNodeID: MKNode]

    public init(scene: MKScene) {
        var t: [MKNodeID: MKNode] = [:]
        t.reserveCapacity(scene.nodes.count * 2 + 1)
        t[scene.background.core.id] = .background(scene.background)
        for node in scene.nodes { Self.index(node, into: &t) }
        self.table = t
    }

    private static func index(_ node: MKNode, into table: inout [MKNodeID: MKNode]) {
        table[node.id] = node
        if case .group(let g) = node {
            for child in g.children { index(child, into: &table) }
        }
    }

    public func node(id: MKNodeID) -> MKNode? { table[id] }
    public var count: Int { table.count }
}
