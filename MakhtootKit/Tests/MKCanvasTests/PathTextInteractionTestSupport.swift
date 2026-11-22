import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
@testable import MKCanvas

// Test scaffolding for the packet-task-16 Path-Edit Mode interaction layer
// ، same architectural role `ArrangeInteractionTestSupport.swift` plays for
// task 15: `MKCanvas` cannot depend on `MKPathText` (see `PathText/
// MKPathTextEngineProviding.swift`'s header for why), so these tests verify
// this module's OWN wiring (mode transitions, hit-test routing, command
// dispatch, undo coalescing) against a scripted double, not `MKPathText`'s
// actual `PathEditModel`/`PathLayoutEngine` ALGORITHMS ، those already have
// their own from-first-principles coverage in `MKPathTextTests`. The
// double's anchor/handle bookkeeping is a small, self-contained
// re-implementation of the SAME documented anchor/segment correspondence
// `BezierPathModel.swift` establishes (mirrored again in
// `MKPathTextInteractionModel.reversedPath`'s own doc comment) ، enough to
// exercise the interaction model's call pattern end to end, not a claim of
// algorithmic fidelity to the real engine.

@MainActor
enum PathTextFixture {
    /// A simple 2-anchor open line (one straight segment, no handles) ،
    /// the minimal fixture every anchor-CRUD/drag test starts from.
    /// Inserted via the real command funnel (`CanvasSession.addPathText`,
    /// task 12) so undo/journal machinery is exercised exactly as
    /// production code would, and seeded into `engine`'s own anchor
    /// bookkeeping so hit-testing/mutation calls have something to find.
    @discardableResult
    static func addLineNode(
        to session: CanvasSession, engine: FakePathTextEngine,
        from start: CGPoint = CGPoint(x: 0, y: 0), to end: CGPoint = CGPoint(x: 100, y: 0),
        text: String = "نص على مسار"
    ) throws -> (nodeID: MKNodeID, startAnchorID: UUID, endAnchorID: UUID) {
        let startID = UUID()
        let endID = UUID()
        let segment = MKBezierSegment(start: start, c1: start, c2: end, end: end)
        let path = MKBezierPathData(segments: [segment], isClosed: false)
        let nodeID = try session.addPathText(path: path, text: text)
        engine.seedAnchors([
            FakePathTextEngine.AnchorState(id: startID, point: start, handleIn: nil, handleOut: nil),
            FakePathTextEngine.AnchorState(id: endID, point: end, handleIn: nil, handleOut: nil),
        ], for: nodeID)
        return (nodeID, startID, endID)
    }
}

/// Scripted `MKPathTextEngineProviding` double. Anchor/handle state lives
/// in `anchors` (keyed by node id), kept in sync as each mutation method
/// below is called, and rebuilt into an `MKBezierPathData` via
/// `rebuildPath` ، an exact structural mirror of
/// `MKPathText.BezierPathModel.bezierPathData()`'s own segment-building
/// rule (see that file's "Anchor/segment correspondence" doc comment),
/// self-contained so this double needs no `MKPathText` import.
@MainActor
final class FakePathTextEngine: MKPathTextEngineProviding {
    struct AnchorState: Equatable {
        var id: UUID
        var point: CGPoint
        var handleIn: CGPoint?
        var handleOut: CGPoint?
    }

    private(set) var anchors: [MKNodeID: [AnchorState]] = [:]
    private(set) var glyphPositions: [MKNodeID: [MKPathGlyphOffsetKey: CGPoint]] = [:]
    private var curvatureWarningNodes: Set<MKNodeID> = []

    private(set) var insertCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var toggleClosedCallCount = 0
    private(set) var glyphOffsetCalls: [(key: MKPathGlyphOffsetKey, offset: MKPathGlyphOffset)] = []

    func seedAnchors(_ list: [AnchorState], for nodeID: MKNodeID) {
        anchors[nodeID] = list
    }

    func seedGlyph(_ key: MKPathGlyphOffsetKey, at position: CGPoint, for nodeID: MKNodeID) {
        glyphPositions[nodeID, default: [:]][key] = position
    }

    func setCurvatureWarning(_ value: Bool, for nodeID: MKNodeID) {
        if value { curvatureWarningNodes.insert(nodeID) } else { curvatureWarningNodes.remove(nodeID) }
    }

    // MARK: - Query

    func hitTargets(for node: MKPathTextNode) -> [MKPathHitTarget] {
        (anchors[node.core.id] ?? []).flatMap { a -> [MKPathHitTarget] in
            var targets = [MKPathHitTarget(id: MKPathHandleID(anchorID: a.id, kind: .anchor), position: a.point)]
            if let handleIn = a.handleIn { targets.append(MKPathHitTarget(id: MKPathHandleID(anchorID: a.id, kind: .handleIn), position: handleIn)) }
            if let handleOut = a.handleOut { targets.append(MKPathHitTarget(id: MKPathHandleID(anchorID: a.id, kind: .handleOut), position: handleOut)) }
            return targets
        }
    }

    func nearestHitTarget(to point: CGPoint, for node: MKPathTextNode, tolerance: CGFloat) -> MKPathHitTarget? {
        var best: MKPathHitTarget?
        var bestDistance = tolerance
        for target in hitTargets(for: node) {
            let d = hypot(target.position.x - point.x, target.position.y - point.y)
            if d <= bestDistance {
                bestDistance = d
                best = target
            }
        }
        return best
    }

    func curvatureWarning(for node: MKPathTextNode) -> Bool {
        curvatureWarningNodes.contains(node.core.id)
    }

    // MARK: - Anchor/handle mutation

    func moveAnchorCommand(_ anchorID: UUID, to newPoint: CGPoint, moveHandles: Bool, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)? {
        guard case .pathText(var node)? = scene.node(id: nodeID), var list = anchors[nodeID], let index = list.firstIndex(where: { $0.id == anchorID }) else { return nil }
        let old = list[index]
        let delta = CGSize(width: newPoint.x - old.point.x, height: newPoint.y - old.point.y)
        var updated = old
        updated.point = newPoint
        if moveHandles {
            if let h = old.handleIn { updated.handleIn = CGPoint(x: h.x + delta.width, y: h.y + delta.height) }
            if let h = old.handleOut { updated.handleOut = CGPoint(x: h.x + delta.width, y: h.y + delta.height) }
        }
        list[index] = updated
        anchors[nodeID] = list
        node.path = Self.rebuildPath(list, isClosed: node.path.isClosed)
        return MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: "تحريك نقطة", coalescingKeySuffix: coalescingKey)
    }

    func moveHandleCommand(_ handleID: MKPathHandleID, to newPoint: CGPoint, mode: MKPathHandleMode, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)? {
        if handleID.kind == .anchor {
            return moveAnchorCommand(handleID.anchorID, to: newPoint, moveHandles: true, nodeID: nodeID, in: scene, coalescingKey: coalescingKey)
        }
        guard case .pathText(var node)? = scene.node(id: nodeID), var list = anchors[nodeID], let index = list.firstIndex(where: { $0.id == handleID.anchorID }) else { return nil }
        var anchor = list[index]
        switch handleID.kind {
        case .anchor:
            return nil   // unreachable, handled above
        case .handleOut:
            anchor.handleOut = newPoint
            if mode == .mirrored {
                let delta = CGPoint(x: newPoint.x - anchor.point.x, y: newPoint.y - anchor.point.y)
                anchor.handleIn = CGPoint(x: anchor.point.x - delta.x, y: anchor.point.y - delta.y)
            }
        case .handleIn:
            anchor.handleIn = newPoint
            if mode == .mirrored {
                let delta = CGPoint(x: newPoint.x - anchor.point.x, y: newPoint.y - anchor.point.y)
                anchor.handleOut = CGPoint(x: anchor.point.x - delta.x, y: anchor.point.y - delta.y)
            }
        }
        list[index] = anchor
        anchors[nodeID] = list
        node.path = Self.rebuildPath(list, isClosed: node.path.isClosed)
        return MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: "تحريك مقبض", coalescingKeySuffix: coalescingKey)
    }

    /// Test double simplification (see file header): always inserts at the
    /// END of the anchor list rather than resolving `point`'s true
    /// nearest-segment arc-length position ، only the real `MKPathText`
    /// adapter can run that LUT (`MKPathTextEngineProviding
    /// .insertAnchorCommand`'s own doc comment). Sufficient to exercise
    /// undo coalescing / selection-after-insert wiring, this suite's
    /// actual scope.
    func insertAnchorCommand(near point: CGPoint, nodeID: MKNodeID, in scene: MKScene) -> (command: any MKCommand, anchorID: UUID)? {
        guard case .pathText(var node)? = scene.node(id: nodeID), var list = anchors[nodeID], list.count >= 2 else { return nil }
        let newID = UUID()
        list.append(AnchorState(id: newID, point: point, handleIn: nil, handleOut: nil))
        anchors[nodeID] = list
        node.path = Self.rebuildPath(list, isClosed: node.path.isClosed)
        insertCallCount += 1
        return (MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: "إضافة نقطة"), newID)
    }

    func deleteAnchorCommand(_ anchorID: UUID, nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)? {
        guard case .pathText(var node)? = scene.node(id: nodeID), var list = anchors[nodeID], let index = list.firstIndex(where: { $0.id == anchorID }) else { return nil }
        list.remove(at: index)
        let minCount = node.path.isClosed ? 3 : 2
        guard list.count >= minCount else { return nil }
        anchors[nodeID] = list
        node.path = Self.rebuildPath(list, isClosed: node.path.isClosed)
        deleteCallCount += 1
        return MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: "حذف نقطة")
    }

    func toggleClosedCommand(nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)? {
        guard case .pathText(var node)? = scene.node(id: nodeID), let list = anchors[nodeID] else { return nil }
        let newClosed = !node.path.isClosed
        let minCount = newClosed ? 3 : 2
        guard list.count >= minCount else { return nil }
        node.path = Self.rebuildPath(list, isClosed: newClosed)
        toggleClosedCallCount += 1
        return MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: "فتح/إغلاق المسار")
    }

    // MARK: - Per-glyph offset

    func glyphHitTest(at point: CGPoint, node: MKPathTextNode) -> MKPathGlyphHit? {
        guard let positions = glyphPositions[node.core.id] else { return nil }
        for (key, position) in positions where hypot(position.x - point.x, position.y - point.y) <= 10 {
            return MKPathGlyphHit(key: key, position: position, currentOffset: node.glyphOffsets[key] ?? .zero)
        }
        return nil
    }

    func setGlyphOffsetCommand(_ offset: MKPathGlyphOffset, forKey key: MKPathGlyphOffsetKey, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID) -> (any MKCommand)? {
        guard case .pathText(var node)? = scene.node(id: nodeID) else { return nil }
        glyphOffsetCalls.append((key, offset))
        node.glyphOffsets[key] = offset
        return MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: "تحريك حرف على المسار", coalescingKeySuffix: "glyphOffset:\(gestureID)")
    }

    // MARK: - Shared segment-rebuild rule (mirrors `BezierPathModel.bezierPathData()`)

    static func rebuildPath(_ anchors: [AnchorState], isClosed: Bool) -> MKBezierPathData {
        guard anchors.count >= 2 else { return MKBezierPathData(segments: [], isClosed: isClosed) }
        var segments: [MKBezierSegment] = []
        let count = anchors.count
        let pairCount = isClosed ? count : count - 1
        for i in 0..<pairCount {
            let a = anchors[i]
            let b = anchors[(i + 1) % count]
            segments.append(MKBezierSegment(start: a.point, c1: a.handleOut ?? a.point, c2: b.handleIn ?? b.point, end: b.point))
        }
        return MKBezierPathData(segments: segments, isClosed: isClosed)
    }
}
