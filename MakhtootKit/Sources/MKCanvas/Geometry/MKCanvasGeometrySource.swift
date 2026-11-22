import CoreGraphics
import MKFoundation
import MKModel

// WS-06 packet §3/§5 task 3: "Hit-test calls into WS-07's `HitTester` (you
// own priority/policy, WS-07 owns geometry)."
//
// STATUS as of this pass (checked live, not assumed): WS-07 has published
// a concrete contract in `MakhtootKit/CONTRACTS.md` ("WS-07 (`MKRender`) ،
// renderer bring-up contract (P4)") ، `RenderTreeProviding` (layer-tree
// host + `applyTransientTransform(nodeID:transform: CGAffineTransform)` +
// `commitTransients()`) and `HitTester` (`func node(at:in:) ->
// MKHitResult?`, single-best-hit, no candidate list/tolerance parameter).
// The ACTUAL `MKRender` source tree does not build those symbols yet
// (verified: `Sources/MKRender/` has `AssetProviding.swift`,
// `DegradationController.swift`, `MemoryPressureMonitor.swift`,
// `Drawers/`, `Geometry/ArrangedGeometry.swift`, etc. ، no
// `HitTester.swift`/`LayerTreeController.swift`/`RenderTreeProviding`
// declaration on disk, and `Tests/MKRenderTests/` is still a `.gitkeep`
// placeholder) ، WS-07 is mid-flight on the *implementation* of a contract
// it already committed to in writing. Importing `MKRender` and referencing
// those types today would make this target's build race the sibling
// agent's in-progress work and fail non-deterministically. Per this run's
// explicit instruction ("if the contract is missing or insufficient... keep
// that task pending rather than inventing the API"), this file instead
// declares `MKCanvas`'s OWN local seam, with method signatures matching
// the PUBLISHED contract EXACTLY (`applyTransientTransform`'s parameter
// type, `commitTransients()`'s name/shape) so wiring the real
// `RenderTreeProviding` conformer in later is a trivial one-line adapter,
// not a redesign. `HitTester.node(at:in:)` also does not expose a per-node
// bounds/OBB query ، `MKCanvasGeometrySource.worldOBB(for:in:)` below has
// NO equivalent anywhere in the published contract at all (needed for
// marquee selection, snapping, selection-chrome placement, and handle
// math ، none of which are single-point hit queries); this is a genuine,
// confirmed contract gap, not a guess, flagged again in this run's final
// report for WS-07/the orchestrator.
@MainActor
public protocol MKCanvasGeometrySource: AnyObject {
    /// World-space oriented bounding box for `nodeID` as it currently
    /// paints, or `nil` if the node has no visual extent yet (e.g. an
    /// empty group) or is unknown to the geometry source. Includes
    /// `background`/group/arranged-child ids ، callers are responsible for
    /// only asking about ids relevant to their current `MKHitScope`.
    func worldOBB(for nodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect?

    /// The node's INTRINSIC local bounds ، the exact rect `worldOBB(for:
    /// in:)` mapped through the node's transform to produce its answer.
    ///
    /// Needed because `MKOrientedRect.derivingTransform(localBounds:)` is
    /// the inverse of `MKOrientedRect.init(localBounds:transform:)` and is
    /// only self-consistent when handed the SAME rect the forward
    /// direction used ، `localBounds.midX/.midY` is what anchors the
    /// derived `position`. `HandleGestures`/`InspectorModel.setSize`
    /// previously synthesized `CGRect(origin: .zero, size: obb.size /
    /// scale)`, which silently assumes every node's local bounds start at
    /// the origin. That holds for `.liveText` only. `.shape`/`.image` are
    /// authored on a unit square CENTERED on the origin, `.pathText`'s
    /// bounds are its bezier bbox outset by a line height, and
    /// `.arranged`'s are the composition's `originFrame` ، for all of
    /// those the assumed midpoint is wrong, and the node teleported by
    /// that error the instant a resize handle was touched or a width/
    /// height was typed.
    ///
    /// Default returns `nil` so pre-existing conformers and test doubles
    /// keep compiling; callers fall back to the old synthesized rect,
    /// which remains correct for the origin-anchored kinds.
    func localBounds(for nodeID: MKNodeID, in scene: MKScene) -> CGRect?

    /// Exact-shape hit test within `nodeID`'s local space for `worldPoint`
    /// (ARCHITECTURE §10.3 step 3: "precise test by kind... `CGPath.contains`").
    /// A conservative default (`true`, i.e. "the OBB test already decided
    /// it") is provided via the protocol extension below so simple/stub
    /// conformers don't have to implement per-kind precision immediately.
    func containsPrecise(nodeID: MKNodeID, worldPoint: CGPoint, in scene: MKScene) -> Bool

    /// Arrange Mode (packet task 15): world-space OBB for an individual
    /// arranged CHILD (glyph/mark/ligature, including a decomposed
    /// ligature's own components) inside `ownerNodeID`'s composition ، the
    /// geometry input every arrange-mode selection-chrome/handle/marquee
    /// query needs at child granularity, mirroring `worldOBB(for:in:)`'s
    /// role at the top level. `nil` when `ownerNodeID` is not an
    /// `.arranged` node, or `childID` is not present in its composition. A
    /// conservative default (`nil`) is provided so existing top-level-only
    /// conformers (and every pre-existing test double) keep compiling
    /// unchanged ، the real conformer (`MKCanvasRenderAdapter`, app dir)
    /// builds this off `MKRender.HitTester`/`MKArrangedGeometry`, the same
    /// D-220 chain `ArrangedDrawer` paints through.
    func arrangedChildWorldOBB(childID: MKNodeID, ownerNodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect?

    /// Arrange Mode glyph/mark-precise hit test inside `ownerNodeID`'s
    /// composition (mirrors `MKRender.HitTester.arrangedChild` exactly ،
    /// same "topmost paint-order child whose outline/inflated-bounds
    /// contains the point" contract, R-6.9's 6 pt mark-inflation zone
    /// included). `worldPoint` is in the SAME space `worldOBB`/`scene.nodes`
    /// transforms are authored in. `nil` default, same reasoning as
    /// `arrangedChildWorldOBB` above.
    /// `tolerance` is extra tap slop in the composition's own local
    /// (document-point) space ، callers pass `MKHitTestPolicy
    /// .touchTolerance(zoomScale:)` so a finger-sized target stays
    /// finger-sized at every zoom level, exactly like top-level hit
    /// testing already does. Without it, arranged children were reachable
    /// only within a few document points of their own ink, which is
    /// sub-pixel on a zoomed-out canvas and made tashkeel effectively
    /// unselectable.
    func arrangedChildHit(at worldPoint: CGPoint, ownerNodeID: MKNodeID, in scene: MKScene, tolerance: CGFloat) -> (childID: MKNodeID, distance: CGFloat)?
}

public extension MKCanvasGeometrySource {
    func localBounds(for nodeID: MKNodeID, in scene: MKScene) -> CGRect? { nil }
    func containsPrecise(nodeID: MKNodeID, worldPoint: CGPoint, in scene: MKScene) -> Bool { true }
    func arrangedChildWorldOBB(childID: MKNodeID, ownerNodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect? { nil }
    func arrangedChildHit(at worldPoint: CGPoint, ownerNodeID: MKNodeID, in scene: MKScene, tolerance: CGFloat) -> (childID: MKNodeID, distance: CGFloat)? { nil }
}

/// The D-114/task-5 transient-transform fast path: "CALayer position
/// updated by WS-07 fast-path (`applyTransientTransform(nodeID:transform:)`
/// on the render tree ، no content redraw)." Method names/signatures
/// mirror `RenderTreeProviding` (`MakhtootKit/CONTRACTS.md`, "Layer-tree
/// host (WS-06's attach point, D-114)") EXACTLY ، `applyTransientTransform
/// (nodeID:transform: CGAffineTransform)` and `commitTransients()` ، so
/// once that type actually builds (see this file's header note on why it
/// doesn't yet), any real conformer already satisfies this protocol
/// verbatim; no adapter beyond a type-erasure shim is needed.
@MainActor
public protocol MKCanvasRenderBridge: AnyObject {
    /// Updates ONLY the CALayer transform for `nodeID` ، never triggers a
    /// content re-render (D-114/D-115: manipulation frames must not call
    /// `draw(in:)`). Called once per gesture frame during move/resize/
    /// rotate; the final `MKTransformCommand`/multi-node batch at
    /// `endGesture()` is what actually commits the change to `MKScene`.
    func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform)

    /// Called once at gesture end (not per node) so the render tree can
    /// commit accumulated transient layer state to a real content
    /// re-render at the current zoom (§11.3) ، same name/shape as
    /// `RenderTreeProviding.commitTransients()`.
    func commitTransients()
}
