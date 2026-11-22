import CoreGraphics
import CoreText
import MKFoundation
import MKModel
import MKTextEngine

// WS-07 packet §5 task 12. `HitTester`: point→node (z-ordered, topmost
// first, transform-aware), point→arranged-child (glyph outline containment
// + mark bounds), path proximity. Consumed by WS-06's gesture/selection
// policy (CONTRACTS.md).
public struct MKHitResult: Sendable, Equatable {
    public var nodeID: MKNodeID
    public var childID: MKNodeID?
    public var distance: CGFloat

    public init(nodeID: MKNodeID, childID: MKNodeID? = nil, distance: CGFloat = 0) {
        self.nodeID = nodeID
        self.childID = childID
        self.distance = distance
    }
}

public struct HitTester: Sendable {
    private let fonts: any MKFontProviding
    private let engine: MKShapingEngine

    public init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.fonts = fonts
        self.engine = MKShapingEngine(fonts: fonts)
    }

    /// Topmost-first (last-drawn-first), transform-aware point hit test
    /// over `scene`'s top-level nodes (recursing into groups). `point` is
    /// in the SAME space `scene.nodes` transforms are authored in
    /// (document/canvas space, top-left origin, y-down ، see
    /// `SceneRenderer.swift`'s coordinate-conventions note). Returns the
    /// single topmost hit ، see `allHits(at:in:)` for the ordered
    /// candidate list ARCHITECTURE §10.3's tap-cycling needs.
    public func node(at point: CGPoint, in scene: MKScene) -> MKHitResult? {
        allHits(at: point, in: scene).first
    }

    /// Every node under `point`, TOPMOST FIRST ، the ordered candidate
    /// list §10.3's tap-cycling ("repeated taps... walk the hits array")
    /// needs (CONTRACTS.md's WS-07 section, gap #2 flagged by WS-06's
    /// `docs/impl-log/WS-06.md`). Hidden nodes are excluded, matching
    /// `node(at:in:)`; locked nodes are INCLUDED (locked is policy-only
    /// per §11.2 ، callers decide what a locked hit means).
    public func allHits(at point: CGPoint, in scene: MKScene) -> [MKHitResult] {
        var results: [MKHitResult] = []
        for node in scene.nodes.reversed() {
            collect(node, at: point, into: &results)
        }
        return results
    }

    /// Full composed world transform + node-local (pre-transform) bounds
    /// for ANY node id in `scene`, including nodes NESTED inside groups
    /// (ancestor transforms are composed in ، `MKNodeLocalBounds
    /// .worldBounds` only applies a node's OWN transform, which is correct
    /// for top-level nodes but not for a node inside a group). Closes
    /// CONTRACTS.md's WS-07 section gap #1 (flagged by WS-06,
    /// `docs/impl-log/WS-06.md`): callers build an oriented bounding box
    /// by applying `worldTransform` to `localBounds`'s four corners
    /// themselves ، MKRender does not own an OBB type (`MKCanvas` already
    /// has `MKOrientedRect`), so this exposes the two inputs an OBB needs
    /// rather than introducing a second, competing OBB type.
    public func worldGeometry(of nodeID: MKNodeID, in scene: MKScene) -> (localBounds: CGRect, worldTransform: CGAffineTransform)? {
        if scene.background.core.id == nodeID {
            return (MKNodeLocalBounds.localBounds(of: .background(scene.background)), scene.background.core.transform.affineTransform)
        }
        return findWorldGeometry(nodeID, in: scene.nodes, ancestorWorldTransform: .identity)
    }

    /// Precise (non-bounding-box) point-in-node test for one already-
    /// identified node ، the second half of CONTRACTS.md's WS-07 gap #1
    /// (`MKCanvasGeometrySource.containsPrecise(nodeID:worldPoint:in:)`):
    /// callers (WS-06) first narrow candidates via `worldOBB`/`worldGeometry`
    /// (a cheap AABB/OBB check), then call this to confirm the point is
    /// really inside the node's actual painted geometry (shape path,
    /// glyph-level arranged hit, etc.) ، the same per-kind precision
    /// `node(at:in:)`/`allHits(at:in:)` already use, exposed for a SPECIFIC
    /// node id rather than a topmost-wins scene-wide search. `worldPoint`
    /// is composed through the FULL ancestor chain (correct for nodes
    /// nested inside groups, unlike a naive single-transform inversion).
    public func containsPrecise(nodeID: MKNodeID, worldPoint: CGPoint, in scene: MKScene) -> Bool {
        guard let node = scene.node(id: nodeID) else { return false }
        guard let geometry = worldGeometry(of: nodeID, in: scene) else { return false }
        let localPoint = worldPoint.applying(geometry.worldTransform.inverted())
        return preciseContains(node, localPoint: localPoint) != nil
    }

    private func findWorldGeometry(
        _ nodeID: MKNodeID, in nodes: [MKNode], ancestorWorldTransform: CGAffineTransform
    ) -> (CGRect, CGAffineTransform)? {
        for node in nodes {
            let worldTransform = node.core.transform.affineTransform.concatenating(ancestorWorldTransform)
            if node.id == nodeID {
                return (MKNodeLocalBounds.localBounds(of: node), worldTransform)
            }
            if case .group(let g) = node,
               let found = findWorldGeometry(nodeID, in: g.children, ancestorWorldTransform: worldTransform) {
                return found
            }
        }
        return nil
    }

    private func collect(_ node: MKNode, at point: CGPoint, into results: inout [MKHitResult]) {
        guard !node.core.isHidden else { return }
        let localPoint = point.applying(node.core.transform.inverted().affineTransform)
        if case .group(let g) = node {
            for child in g.children.reversed() {
                collect(child, at: localPoint, into: &results)
            }
            return
        }
        if let hit = test(node, at: point) {
            results.append(hit)
        }
    }

    private func test(_ node: MKNode, at point: CGPoint) -> MKHitResult? {
        guard !node.core.isHidden else { return nil }
        let localPoint = point.applying(node.core.transform.inverted().affineTransform)

        if case .group(let g) = node {
            for child in g.children.reversed() {
                if let hit = test(child, at: localPoint) { return hit }
            }
            return nil
        }
        return preciseContains(node, localPoint: localPoint)
    }

    /// The actual per-kind precision test, given a point ALREADY in the
    /// node's own local space (post its own transform, and ، for a nested
    /// node reached via `containsPrecise`'s full ancestor-composed
    /// transform ، post every ancestor's too). Shared by `test(_:at:)`
    /// (scene-wide topmost search) and `containsPrecise(nodeID:worldPoint:in:)`
    /// (single already-identified node). `.group` has no geometry of its
    /// own here ، `test` handles group recursion before reaching this
    /// point; `containsPrecise` on a group id recurses into children below.
    private func preciseContains(_ node: MKNode, localPoint: CGPoint) -> MKHitResult? {
        switch node {
        case .group(let g):
            for child in g.children.reversed() {
                let childLocal = localPoint.applying(child.core.transform.inverted().affineTransform)
                if let hit = preciseContains(child, localPoint: childLocal) { return hit }
            }
            return nil

        case .arranged(let n):
            // 4 pt outset on the composition's own derivation bounding
            // frame (task 12: glyph outline containment falls back to a
            // 4 pt outset on bounds) before doing the finer per-child pass.
            guard n.composition.originFrame.insetBy(dx: -4, dy: -4).contains(localPoint) else { return nil }
            if let childHit = arrangedChild(at: localPoint, in: n, compositionWorldTransform: .identity) {
                return MKHitResult(nodeID: n.core.id, childID: childHit.childID, distance: childHit.distance)
            }
            return MKHitResult(nodeID: n.core.id, childID: nil, distance: 0)

        case .shape(let n):
            guard let path = ShapeDrawer.localPath(for: n.geometry) else { return nil }
            if path.contains(localPoint) {
                return MKHitResult(nodeID: n.core.id)
            }
            // Unfilled/thin geometry (`.line`, open `.path`) never
            // satisfies `CGPath.contains` ، fall back to a small
            // proximity check so hairlines stay tappable.
            if case .line = n.geometry, distance(from: localPoint, toSegment: (CGPoint(x: -0.5, y: 0), CGPoint(x: 0.5, y: 0))) <= 0.05 {
                return MKHitResult(nodeID: n.core.id, distance: distance(from: localPoint, toSegment: (CGPoint(x: -0.5, y: 0), CGPoint(x: 0.5, y: 0))))
            }
            return nil

        case .image:
            let bounds = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
            guard bounds.contains(localPoint) else { return nil }
            return MKHitResult(nodeID: node.core.id)   // alpha-aware hit testing is off in v1 (task 12) ، bounds hit only

        case .liveText(let n):
            guard let bounds = liveTextLocalBounds(n), bounds.contains(localPoint) else { return nil }
            return MKHitResult(nodeID: n.core.id)

        case .pathText(let n):
            let samples = MKPolylineArcLength.sample(n.path.cgPath())
            let (_, dist) = samples.nearest(to: localPoint)
            guard dist <= 8 else { return nil }   // 8 pt tolerance, matching `pathProximity`'s contract
            return MKHitResult(nodeID: n.core.id, distance: dist)

        case .background:
            return nil   // background is not independently hit-testable (always beneath, §10.3)
        }
    }

    /// Glyph-level arranged-child hit (task 12): glyph outline `CGPath
    /// .contains` with a 4 pt outset fallback to bounds; marks get a
    /// minimum 12 pt box. `point` is in the composition's OWN local space
    /// (i.e. already inverse-transformed through the arranged node's
    /// `core.transform` ، see `test(_:at:)` above); `compositionWorldTransform`
    /// is reserved for callers (WS-06) that want the result in a different
    /// reference frame than the composition's own local space ، passing
    /// `.identity` (the common case, matching how `test(_:at:)` calls this)
    /// means "point and results share the composition-local frame."
    /// Base tap slop, in composition-local document points, added around a
    /// glyph/ligature's outline bounding box on the inflated pass.
    public static let glyphTapSlopPoints: CGFloat = 4
    /// Tap slop for MARKS ، R-6.9's "6 pt mark-inflation zone". Larger
    /// than a glyph's because tashkeel are an order of magnitude smaller
    /// than the letters they sit on, so identical slop is not equal
    /// reachability.
    public static let markTapSlopPoints: CGFloat = 6

    public func arrangedChild(
        at point: CGPoint, in node: MKArrangedTextNode, compositionWorldTransform: CGAffineTransform,
        tolerance: CGFloat = 0
    ) -> MKHitResult? {
        let index = MKArrangedGeometry.Index(composition: node.composition)
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        let pointSize = node.composition.sourceBackup.style.pointSize

        struct Candidate {
            let childID: MKNodeID
            let isMark: Bool
            let localPoint: CGPoint
            let outlinePath: CGPath?
        }

        // Topmost-first: reverse paint order so a glyph drawn OVER another
        // (or a mark drawn over its base) wins the hit.
        var candidates: [Candidate] = []
        for childID in index.paintOrder.reversed() {
            guard let element = index.element(id: childID) else { continue }
            let isMark: Bool
            let outline: MKPathData?
            let isHidden: Bool
            switch element {
            case .glyph(let g): isMark = false; outline = g.outline; isHidden = g.isHidden
            case .composedLigature(let id, _, let ligature):
                guard case .ligature(let group) = node.composition.child(id: id) else { continue }
                isMark = false; outline = ligature.outline; isHidden = group.isHidden
            case .mark(let m): isMark = true; outline = m.outline; isHidden = m.isHidden
            }
            guard !isHidden else { continue }
            guard let world = MKArrangedGeometry.worldTransform(of: childID, index: index, compositionAffine: flip) else { continue }
            let path: CGPath? = (outline?.commands.isEmpty == false) ? outline?.cgPath(at: pointSize) : nil
            candidates.append(Candidate(
                childID: childID, isMark: isMark, localPoint: point.applying(world.inverted()), outlinePath: path))
        }

        // Pass 1 ، exact ink, topmost wins, marks and bases on equal
        // footing. A tap that actually lands ON a letter's stroke selects
        // that letter even if a mark's inflated zone also covers the
        // point, which is what keeps pass 2's mark preference from
        // stealing deliberate letter taps.
        for candidate in candidates {
            guard let path = candidate.outlinePath, path.contains(candidate.localPoint) else { continue }
            return MKHitResult(nodeID: node.core.id, childID: candidate.childID, distance: 0)
        }

        // Pass 2 ، inflated bounds, MARKS FIRST.
        //
        // Bug fix (2026-07-29, user report: tashkeel cannot be selected
        // separately ، tapping one selects the whole letter). Marks used
        // to be checked in the same single pass as their bases with the
        // same 4 pt outset, so any near-miss on a two-millimetre fatha
        // fell through to the base glyph, whose bounding box plus outset
        // blankets the entire letter INCLUDING the area the mark sits in.
        // Since a mark is always drawn over its base, a tap that hit no
        // ink at all but is within reach of both should resolve to the
        // smaller, higher target ، the mark.
        for wantsMark in [true, false] {
            for candidate in candidates where candidate.isMark == wantsMark {
                let slop = (wantsMark ? Self.markTapSlopPoints : Self.glyphTapSlopPoints) + max(0, tolerance)
                let box: CGRect
                if let path = candidate.outlinePath {
                    box = path.boundingBoxOfPath.insetBy(dx: -slop, dy: -slop)
                } else {
                    // No outline (INV-13: never re-extract at hit-test
                    // time either) ، a plain slop-sized box about the
                    // child's own origin, the documented v1 simplification.
                    box = CGRect(x: -slop, y: -slop, width: slop * 2, height: slop * 2)
                }
                if box.contains(candidate.localPoint) {
                    return MKHitResult(nodeID: node.core.id, childID: candidate.childID, distance: slop)
                }
            }
        }
        return nil
    }

    /// P4-scoped stand-in for WS-05's arc-length LUT `nearestLength`.
    /// `PathTextDrawer` has since adopted the real `ArcLengthLUT`/
    /// `PathLayoutEngine` for drawing (see that file's comment) ،
    /// `ArcLengthLUT.nearestLength(to:)` exists and could replace this
    /// hit-tester's own polyline `nearest(to:)` too, but that migration is
    /// outside this task's drawer-only fence (path DRAWING, not hit
    /// testing). Flagged here, not fixed, same "cross-fence gap" pattern
    /// WS-05's own README uses. Returns the nearest arc length +
    /// perpendicular distance if within `tolerance`, else `nil`.
    public func pathProximity(to point: CGPoint, on path: MKBezierPathData, tolerance: CGFloat = 8) -> (length: CGFloat, distance: CGFloat)? {
        let samples = MKPolylineArcLength.sample(path.cgPath())
        let (length, distance) = samples.nearest(to: point)
        guard distance <= tolerance else { return nil }
        return (length, distance)
    }

    private func liveTextLocalBounds(_ node: MKLiveTextNode) -> CGRect? {
        guard !node.text.string.isEmpty else { return nil }
        let request = MKShapingRequest(text: node.text, style: node.style, frame: node.frame)
        let paragraph = engine.shapeParagraph(request)
        guard !paragraph.lines.isEmpty else { return nil }
        // Must stay identical to `MKNodeLocalBounds.localBounds(of:)`'s
        // `.liveText` case, or a node's tappable area and its drawn/
        // selected area disagree ، both now go through the shared
        // `MKShapedParagraph.boxWidth`/`boxHeight(lineHeight:)`.
        let width = paragraph.boxWidth
        let lineHeight = CGFloat(node.style.lineHeightMultiple * node.style.pointSize)
        let height = paragraph.boxHeight(lineHeight: lineHeight)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    private func distance(from point: CGPoint, toSegment segment: (CGPoint, CGPoint)) -> CGFloat {
        let (p0, p1) = segment
        let segVector = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
        let segLengthSquared = segVector.x * segVector.x + segVector.y * segVector.y
        let t: CGFloat
        if segLengthSquared > 0 {
            let toPoint = CGPoint(x: point.x - p0.x, y: point.y - p0.y)
            t = min(max((toPoint.x * segVector.x + toPoint.y * segVector.y) / segLengthSquared, 0), 1)
        } else {
            t = 0
        }
        let closest = CGPoint(x: p0.x + segVector.x * t, y: p0.y + segVector.y * t)
        return hypot(point.x - closest.x, point.y - closest.y)
    }
}
