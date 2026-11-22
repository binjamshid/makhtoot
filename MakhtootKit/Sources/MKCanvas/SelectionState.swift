import MKFoundation
import MKModel

// WS-06 packet §5 task 4: "Selection model: single/multi, additive tap,
// marquee (intersect/contain modes), selection inside `arranged` nodes
// (glyph/mark/ligature granularity + letter-level switch via WS-04
// `LevelMapping`), locked/hidden exclusion." The glyph/letter-level switch
// itself is WS-04/Arrange-Mode UX (P5, out of this P4 slice per the
// orchestrator's scope note) ، the `granularity` field and its cases are
// kept here because task 4's literal shape ("SelectionState {ids,
// granularity: .object/.glyph/.letter}") is P4 spine work even though only
// `.object` is reachable without Arrange Mode wired up.
public enum MKSelectionGranularity: Sendable, Hashable {
    case object
    /// Selecting individual shaped glyphs inside an `arranged` node.
    case glyph
    /// Selecting by Unicode-letter groupings inside an `arranged` node
    /// (WS-04 `LevelMapping` ، P5).
    case letter
}

/// The canvas's current selection (ARCHITECTURE §10.4:
/// `MKSelectionController` publishes `Set<MKNodeID>` + derived
/// `selectionBounds`). Kept as a plain, `Sendable`, headless value type
/// (not a class/ObservableObject) so `CanvasSession` owns the single
/// source of truth and SwiftUI/UIKit both observe through it ، task 2's
/// accept criterion ("unit tests drive selection/mode transitions without
/// UIKit") depends on this having no UIKit dependency at all.
public struct MKSelectionState: Sendable, Equatable {
    public private(set) var ids: Set<MKNodeID>
    public var granularity: MKSelectionGranularity
    /// Non-nil only while `granularity != .object`: the `arranged` node
    /// whose children `ids` refers into (task 3: "inside an `arranged`
    /// node in arrange mode, hit at glyph/mark granularity").
    public var compositionScope: MKNodeID?

    public init(ids: Set<MKNodeID> = [], granularity: MKSelectionGranularity = .object, compositionScope: MKNodeID? = nil) {
        self.ids = ids
        self.granularity = granularity
        self.compositionScope = compositionScope
    }

    public static let empty = MKSelectionState()

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }
    public var isMultiple: Bool { ids.count > 1 }
    public var single: MKNodeID? { ids.count == 1 ? ids.first : nil }

    public func contains(_ id: MKNodeID) -> Bool { ids.contains(id) }

    /// Replaces the selection outright (plain tap on a node, or deselect
    /// with an empty set).
    public mutating func set(_ newIDs: Set<MKNodeID>) {
        ids = newIDs
    }

    /// Additive tap (ARCHITECTURE §10.2's shift/⌘-tap convention) ، toggles
    /// membership of one id.
    public mutating func toggle(_ id: MKNodeID) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    public mutating func clear() {
        ids.removeAll()
        compositionScope = nil
        granularity = .object
    }

    /// Filters a raw candidate id set down to selectable ones ، both locked
    /// and hidden nodes are excluded from CANVAS selection (tap/marquee),
    /// per PRD R-4.6 (P0): "locked nodes are skipped by tap selection but
    /// selectable from the layers panel (with lock badge)". The layers
    /// panel path (`LayersModel.select`) deliberately does NOT route
    /// through this filter for lock state ، panel selection of a locked
    /// node is the sanctioned unlock affordance. (An earlier conflict with
    /// ARCHITECTURE.md §10.3 step 5 was resolved in this behavior's favor
    /// by coordinator gate ruling ، see docs/impl-log/WS-06.md and
    /// `HitTestPolicy.swift`'s header comment.)
    public static func selectable(from candidates: some Sequence<MKNodeID>, isLocked: (MKNodeID) -> Bool, isHidden: (MKNodeID) -> Bool) -> Set<MKNodeID> {
        Set(candidates.filter { !isLocked($0) && !isHidden($0) })
    }
}
