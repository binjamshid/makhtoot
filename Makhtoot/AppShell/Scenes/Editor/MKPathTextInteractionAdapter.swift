import CoreGraphics
import Foundation
import MKCanvas
import MKFoundation
import MKModel
import MKPathText
import MKPersistence
import MKTextEngine

/// Wires the real `MKPathText` engine into WS-06's `MKPathTextEngineProviding`
/// consumption seam (`MKCanvas/PathText/MKPathTextEngineProviding.swift`) ،
/// the Path-Text twin of `MKArrangeInteractionAdapter`'s role for
/// `MKArrangeEngineProviding`; read that file's header first, this one only
/// restates where Path Text specifics differ. Lives in the app target for
/// the same reason: `MKCanvas` cannot depend on `MKPathText` without a
/// `Package.swift` edit (out of fence), and `Makhtoot.xcodeproj` already
/// links the `MKPathText` product directly, so the app is the natural
/// composition root for this bridge (D-231's "app owns the seam"
/// principle, same as the arrange adapter).
///
/// **`MKPathAnchorID` ⇄ `UUID` bridging, and why a per-node CACHE is
/// required (real bug found and fixed this session, confirmed on-simulator
/// via the E2E drive's own `debug_scene_*.json` checkpoints before this
/// fix: `path-after-anchor-drag.json`'s segments were byte-identical to
/// `path-after-text-commit.json`'s ، the drag silently no-op'd).** The
/// seam's `MKPathHandleID`/`MKPathHitTarget` key anchors by a plain `UUID`,
/// not `MKPathText.MKPathAnchorID` (an `MKID<PathAnchorTag>` wrapper,
/// unreachable type from `MKCanvas`) ، `MKID<Tag>.rawValue`/
/// `MKID<Tag>(rawValue:)` round-trip the raw `UUID` losslessly, so THAT
/// part of the bridge is sound. The actual bug: `BezierPathModel.init(_
/// data: MKBezierPathData)` (`BezierPathModel.swift`, read-only reference)
/// mints a **fresh, random** `MKPathAnchorID` for every anchor on EVERY
/// call ، `MKBezierPathData`/`MKBezierSegment` carry no persisted anchor-id
/// field at all, so there is nothing for that initializer to preserve. A
/// hit-test call (`hitTargets`/`nearestHitTarget`) and a LATER mutation
/// call (`moveAnchorCommand` etc., made from a SEPARATE `BezierPathModel
/// (node.path)` reconstruction of the SAME node) therefore mint two
/// COMPLETELY DIFFERENT random ids for the same physical anchor ،
/// `PathEditModel.moveAnchor`'s own "return `path` unchanged if the id
/// isn't found" contract then makes every mutation attempt across two
/// calls a silent, undetectable no-op. Every method below that needs
/// anchor identity therefore resolves anchors through `stableModel(for:
/// nodeID:)`, which overwrites `BezierPathModel(_:)`'s freshly-minted ids
/// with a per-`MKNodeID` CACHED array (`anchorIDCache`) reused across calls
/// as long as the anchor COUNT is unchanged ، the only thing that
/// legitimately changes anchor count is insert/delete, both of which
/// refresh the cache themselves as part of applying their own edit (see
/// their own doc comments below for how the "which index is new" question
/// is answered once the cache itself is regenerated).
@MainActor
final class MKPathTextInteractionAdapter: MKPathTextEngineProviding {
    private let shapingEngine: MKShapingEngine
    private let fonts: any MKFontProviding

    /// Per-node stable anchor-id cache ، see this type's own header for
    /// why this exists at all. Cleared for a node only implicitly (a stale
    /// entry for a deleted/no-longer-`.pathText` node is harmless: it is
    /// simply never looked up again, and `MKNodeID` values are never
    /// reused, so no cross-node collision risk).
    private var anchorIDCache: [MKNodeID: [UUID]] = [:]

    /// Per-node memoized `layoutResult(for:)` output (Bug 16 fix, WS-16
    /// follow-up). **The actual confirmed main-thread block for this
    /// cluster**: `MKPathTextInteractionModel.curvatureWarningActive` is
    /// read directly from `PathEditToolbarView.body` (a plain `var`, no
    /// caching at the SwiftUI layer), so every re-render of the path-edit
    /// toolbar ، which SwiftUI issues on essentially every touch-driven
    /// state change during a drag, not just once per gesture ، re-ran a
    /// full synchronous `MKShapingEngine.shapeSingleLine` CoreText shaping
    /// pass on the main thread (`layoutResult(for:)` below has neither
    /// `async` nor any actor hop in its call chain: `MKShapingEngine` is a
    /// plain `struct`, not an actor, and `shapeSingleLine` is not itself
    /// `async`). `glyphHitTest(at:node:)` calls the same synchronous path
    /// once per touch-move sample during a glyph-offset drag. Memoizing
    /// against the exact inputs `layoutResult` actually consumes
    /// (text/style/path/layout/glyphOffsets ، NOT `node.core`, whose
    /// transform/z-order are irrelevant to the shaped layout) turns the
    /// "never cached" cost into a true no-op on every call where nothing
    /// changed since the last one, while still respecting this type's own
    /// documented reason for not caching outright: path-edit-mode edits
    /// DO change the input live (R-9.3), and the cache key changing on the
    /// very next edit is exactly what re-triggers a fresh pass.
    private var layoutResultCache: [MKNodeID: (key: LayoutCacheKey, result: PathLayoutResult?)] = [:]

    /// The exact subset of `MKPathTextNode` that `layoutResult(for:)`'s
    /// computation actually depends on (mirrors `userOffsets(from:)`'s own
    /// `PathTextCommands.persistedUserOffsets(from:)` read of
    /// `glyphOffsets`). Deliberately narrower than `MKPathTextNode` itself
    /// (which is `Equatable` end to end, `core` included) ، comparing the
    /// whole node would invalidate the cache on every transform/reorder
    /// even though those never affect the shaped layout.
    struct LayoutCacheKey: Equatable {
        let text: String
        let style: MKTextStyle
        let path: MKBezierPathData
        let layout: MKPathLayoutOptions
        let glyphOffsets: [MKPathGlyphOffsetKey: MKPathGlyphOffset]
    }

    init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.fonts = fonts
        self.shapingEngine = MKShapingEngine(fonts: fonts)
    }

    // MARK: - Anchor/handle query (R-9.1, R-9.3)

    func hitTargets(for node: MKPathTextNode) -> [MKPathHitTarget] {
        let path = stableModel(for: node, nodeID: node.core.id)
        return PathEditModel.hitTargets(in: path).map(Self.mirror)
    }

    func nearestHitTarget(to point: CGPoint, for node: MKPathTextNode, tolerance: CGFloat) -> MKPathHitTarget? {
        let path = stableModel(for: node, nodeID: node.core.id)
        guard let hit = PathEditModel.nearestHitTarget(to: point, in: path, tolerance: tolerance) else { return nil }
        return Self.mirror(hit)
    }

    func curvatureWarning(for node: MKPathTextNode) -> Bool {
        layoutResult(for: node)?.curvatureWarning ?? false
    }

    // MARK: - Anchor/handle mutation (R-9.1, R-9.3)

    func moveAnchorCommand(_ anchorID: UUID, to newPoint: CGPoint, moveHandles: Bool, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)? {
        guard case .pathText(let node)? = scene.node(id: nodeID) else { return nil }
        let path = stableModel(for: node, nodeID: nodeID)
        let moved = PathEditModel.moveAnchor(MKPathAnchorID(rawValue: anchorID), to: newPoint, in: path, moveHandles: moveHandles)
        return PathTextCommands.setPath(moved.bezierPathData(), nodeID: nodeID, in: scene, coalescingKey: coalescingKey)
    }

    func moveHandleCommand(_ handleID: MKPathHandleID, to newPoint: CGPoint, mode: MKPathHandleMode, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)? {
        guard case .pathText(let node)? = scene.node(id: nodeID) else { return nil }
        let path = stableModel(for: node, nodeID: nodeID)
        let realHandle = PathHandleID(anchorID: MKPathAnchorID(rawValue: handleID.anchorID), kind: Self.mirror(handleID.kind))
        let moved = PathEditModel.moveHandle(realHandle, to: newPoint, in: path, mode: Self.mirror(mode))
        return PathTextCommands.setPath(moved.bezierPathData(), nodeID: nodeID, in: scene, coalescingKey: coalescingKey)
    }

    /// After insertion the anchor COUNT changes (N → N+1), so the cache is
    /// deliberately regenerated wholesale here (not "reuse N old + mint 1
    /// new" ، simpler, and correct: nothing outside this one call site can
    /// have observed the OLD cache's ids for THIS node between this call
    /// and the next `hitTargets`/`nearestHitTarget`, since anchor mutation
    /// is always a single synchronous step from the interaction model's
    /// point of view). The new anchor is identified by POSITION: `path`
    /// (pre-insert, stable-id'd) and `inserted` (post-insert, from
    /// `PathEditModel.insertAnchor` ، which preserves the OLD anchors'
    /// `PathAnchor` values, including the stable ids just assigned, and
    /// mints a fresh random id only for the newly spliced-in one) differ
    /// at exactly one index; that index's freshly-cached id is the one
    /// returned to the caller.
    func insertAnchorCommand(near point: CGPoint, nodeID: MKNodeID, in scene: MKScene) -> (command: any MKCommand, anchorID: UUID)? {
        guard case .pathText(let node)? = scene.node(id: nodeID) else { return nil }
        let path = stableModel(for: node, nodeID: nodeID)
        let lut = ArcLengthLUT(path: path)
        let length = lut.nearestLength(to: point)
        // A genuine "point not close enough to the curve" no-op (per this
        // method's own doc comment): reject taps whose nearest ON-CURVE
        // point is still far from the tap itself, rather than always
        // inserting at whatever length is nearest.
        let onCurvePoint = lut.point(atLength: length)
        let distance = hypot(onCurvePoint.x - point.x, onCurvePoint.y - point.y)
        guard distance <= Self.insertAnchorTolerance else { return nil }
        let existingIDs = Set(path.anchors.map(\.id))
        var inserted = PathEditModel.insertAnchor(atLength: length, in: path, lut: lut)
        guard let newIndex = inserted.anchors.firstIndex(where: { !existingIDs.contains($0.id) }) else { return nil }
        let freshCache = (0..<inserted.anchors.count).map { _ in UUID() }
        anchorIDCache[nodeID] = freshCache
        for i in inserted.anchors.indices {
            inserted.anchors[i].id = MKPathAnchorID(rawValue: freshCache[i])
        }
        guard let command = PathTextCommands.setPath(inserted.bezierPathData(), nodeID: nodeID, in: scene, coalescingKey: "pathInsertAnchor:\(UUID())") else { return nil }
        return (command, freshCache[newIndex])
    }

    func deleteAnchorCommand(_ anchorID: UUID, nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)? {
        guard case .pathText(let node)? = scene.node(id: nodeID) else { return nil }
        let path = stableModel(for: node, nodeID: nodeID)
        guard let deleted = PathEditModel.deleteAnchor(MKPathAnchorID(rawValue: anchorID), in: path) else { return nil }
        // Anchor count changes (N → N-1) ، same "let the cache regenerate
        // itself" reasoning as `insertAnchorCommand`, simpler here since no
        // caller needs to know which ids survived (`MKPathTextInteractionModel
        // .deleteAnchor` only needs to know whether the CURRENTLY selected
        // handle was the one just deleted, which it already tracks by the
        // UUID it was given at selection time ، this cache clear only
        // affects the NEXT hit-test, not this call's own return value).
        anchorIDCache[nodeID] = nil
        return PathTextCommands.setPath(deleted.bezierPathData(), nodeID: nodeID, in: scene, coalescingKey: "pathDeleteAnchor:\(UUID())")
    }

    func toggleClosedCommand(nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)? {
        guard case .pathText(let node)? = scene.node(id: nodeID) else { return nil }
        // Open ⇄ closed toggles `BezierPathModel.isClosed` and the SEGMENT
        // count (closed adds one closing segment) but NOT the anchor count
        // (same N points either way) ، the cache stays valid across this
        // call with no special handling, unlike insert/delete.
        let path = stableModel(for: node, nodeID: nodeID)
        guard let toggled = PathEditModel.toggleClosed(in: path) else { return nil }
        return PathTextCommands.setPath(toggled.bezierPathData(), nodeID: nodeID, in: scene, coalescingKey: "pathToggleClosed:\(UUID())")
    }

    // MARK: - Per-glyph offset drag (R-9.4)

    func glyphHitTest(at point: CGPoint, node: MKPathTextNode) -> MKPathGlyphHit? {
        guard let result = layoutResult(for: node) else { return nil }
        let tolerance = CGFloat(node.style.pointSize) * 0.6
        var best: (placement: PathGlyphPlacement, distance: CGFloat)?
        for placement in result.placements {
            let laidOutPosition = CGPoint(x: placement.position.x + placement.userOffset.x, y: placement.position.y + placement.userOffset.y)
            let distance = hypot(laidOutPosition.x - point.x, laidOutPosition.y - point.y)
            if distance <= tolerance, (best == nil || distance < best!.distance) {
                best = (placement, distance)
            }
        }
        guard let best else { return nil }
        let key = MKPathGlyphOffsetKey(codepoints: best.placement.provenanceKey.codepoints, occurrenceOrdinal: best.placement.provenanceKey.occurrenceOrdinal)
        let currentOffset = node.glyphOffsets[key] ?? .zero
        let position = CGPoint(x: best.placement.position.x + best.placement.userOffset.x, y: best.placement.position.y + best.placement.userOffset.y)
        return MKPathGlyphHit(key: key, position: position, currentOffset: currentOffset)
    }

    func setGlyphOffsetCommand(_ offset: MKPathGlyphOffset, forKey key: MKPathGlyphOffsetKey, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID) -> (any MKCommand)? {
        // `PathClusterProvenanceKey`/`MKPathGlyphOffsetKey` are both
        // `codepoints`+`occurrenceOrdinal` ، DETERMINISTIC, derived from the
        // shaped TEXT content, not randomly minted like `MKPathAnchorID`
        // (see this type's header) ، so no cache is needed here; the key
        // round-trips exactly by construction.
        let realKey = PathClusterProvenanceKey(codepoints: key.codepoints, occurrenceOrdinal: key.occurrenceOrdinal)
        let realOffset = PathGlyphUserOffset(offset: offset.offset, rotation: CGFloat(offset.rotation))
        return PathTextCommands.setGlyphOffset(realOffset, forKey: realKey, nodeID: nodeID, in: scene, gestureID: gestureID)
    }

    // MARK: - Stable-anchor-id resolution (see type header)

    /// Rebuilds `BezierPathModel(node.path)` and overwrites each anchor's
    /// freshly-minted id with this adapter's CACHED id for that position,
    /// minting a fresh cache only when the anchor count doesn't match the
    /// cached array (first call for this node, or after a genuine
    /// structural insert/delete already cleared/replaced the cache).
    private func stableModel(for node: MKPathTextNode, nodeID: MKNodeID) -> BezierPathModel {
        var model = BezierPathModel(node.path)
        let ids: [UUID]
        if let cached = anchorIDCache[nodeID], cached.count == model.anchors.count {
            ids = cached
        } else {
            ids = (0..<model.anchors.count).map { _ in UUID() }
            anchorIDCache[nodeID] = ids
        }
        for i in model.anchors.indices {
            model.anchors[i].id = MKPathAnchorID(rawValue: ids[i])
        }
        return model
    }

    // MARK: - Shared layout helper

    /// A fresh `PathLayoutEngine` pass for `node`'s CURRENT `text`/`path`/
    /// `layout`/`glyphOffsets`, memoized per node id against exactly those
    /// four inputs (`LayoutCacheKey`, see this type's header for why a full
    /// re-run was a confirmed main-thread-blocking bug, not a theoretical
    /// one). Still recomputed on every call where any of the four actually
    /// changed since the last one ، path-edit-mode edits change the input
    /// live (R-9.3), and both callers below (`glyphHitTest`,
    /// `curvatureWarning`) need the freshest possible result WHEN it's
    /// stale, just not a brand-new CoreText pass when it isn't. `nil` for
    /// an empty string (nothing to lay out ، `MKShapingEngine
    /// .shapeSingleLine` on an empty string still returns a valid,
    /// zero-glyph `MKShapedLine`, so this is a genuine short-circuit, not a
    /// workaround for a crash); the `nil` result is cached too, so a
    /// still-empty node doesn't re-enter `shapeSingleLine` on every call
    /// either. Uses the RAW (not stable-id'd) `BezierPathModel` ، layout is
    /// purely geometric, it never touches anchor identity, so the
    /// `anchorIDCache` is irrelevant here.
    private func layoutResult(for node: MKPathTextNode) -> PathLayoutResult? {
        let key = LayoutCacheKey(text: node.text.string, style: node.style, path: node.path, layout: node.layout, glyphOffsets: node.glyphOffsets)
        if let cached = layoutResultCache[node.core.id], cached.key == key {
            return cached.result
        }
        let result = Self.computeLayoutResult(shapingEngine: shapingEngine, node: node)
        layoutResultCache[node.core.id] = (key, result)
        return result
    }

    /// `node` (not `LayoutCacheKey`) is threaded straight through here
    /// because `PathTextCommands.persistedUserOffsets(from:)` (the
    /// `MKPathGlyphOffsetKey`/`MKPathGlyphOffset` → `PathClusterProvenanceKey`/
    /// `PathGlyphUserOffset` conversion) only exists as a `private extension`
    /// inside `PathTextCommands.swift` ، `MKPathText`'s converting
    /// initializers for those two types are file-private, not reachable
    /// from this app-target file. `LayoutCacheKey` still governs whether
    /// this function runs at all (see `layoutResult(for:)` above); it just
    /// isn't this function's OWN input.
    private static func computeLayoutResult(shapingEngine: MKShapingEngine, node: MKPathTextNode) -> PathLayoutResult? {
        guard !node.text.string.isEmpty else { return nil }
        let request = MKShapingRequest(string: node.text.string, style: node.style, frame: .singleLine)
        let line = shapingEngine.shapeSingleLine(request)
        let options = PathLayoutOptions(node: node.layout)
        let userOffsets = PathTextCommands.persistedUserOffsets(from: node)
        let path = BezierPathModel(node.path)
        if node.path.isClosed {
            let lut = ArcLengthLUT(path: path)
            return PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options, userOffsets: userOffsets)
        } else {
            return PathLayoutEngine.layout(line: line, path: path, options: options, userOffsets: userOffsets)
        }
    }

    // MARK: - Structural-mirror conversions

    private static func mirror(_ target: PathHitTarget) -> MKPathHitTarget {
        MKPathHitTarget(id: mirror(target.id), position: target.position)
    }

    private static func mirror(_ id: PathHandleID) -> MKPathHandleID {
        MKPathHandleID(anchorID: id.anchorID.rawValue, kind: mirror(id.kind))
    }

    private static func mirror(_ kind: PathHandleID.Kind) -> MKPathHandleID.Kind {
        switch kind {
        case .anchor: return .anchor
        case .handleIn: return .handleIn
        case .handleOut: return .handleOut
        }
    }

    private static func mirror(_ kind: MKPathHandleID.Kind) -> PathHandleID.Kind {
        switch kind {
        case .anchor: return .anchor
        case .handleIn: return .handleIn
        case .handleOut: return .handleOut
        }
    }

    private static func mirror(_ mode: MKPathHandleMode) -> PathHandleMode {
        switch mode {
        case .mirrored: return .mirrored
        case .free: return .free
        }
    }

    /// Own design choice (documented per this packet's instructions, no
    /// existing precedent to mirror): "close enough to the curve to count
    /// as an on-curve tap" for R-9.1's "tap to add anchors" ، matches the
    /// same order of magnitude `MKHitTestPolicy.touchTolerance` uses
    /// elsewhere in this codebase for finger-sized touch targets.
    private static let insertAnchorTolerance: CGFloat = 24
}
