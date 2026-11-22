import CoreGraphics
import MKCanvas
import MKFoundation
import MKModel
import MKRender
import QuartzCore

/// Wires WS-07's now-real `MKLayerTreeController`/`HitTester` (`MKRender`)
/// into WS-06's `MKCanvasGeometrySource`/`MKCanvasRenderBridge` consumption
/// seam (`MKCanvas`) ، `MakhtootKit/CONTRACTS.md`'s "WS-06 ، consumption
/// seam over WS-07's contract" note promised this would be "a one-line
/// substitution, not a redesign" once the real types landed; this adapter
/// IS that substitution. It lives in the app target (not either package)
/// because this session's fence is app-dir-only (never edit package
/// sources) ، `MKCanvas` cannot be taught to import `MKRender` from here
/// even though FOUNDATION §2's module map says it eventually should;
/// wiring the two together at the composition-root level is exactly what
/// D-231's "app owns the seam" principle expects for a cross-package
/// bridge like this.
///
/// `worldOBB(for:in:)` deliberately does NOT reuse `HitTester
/// .worldGeometry(of:in:)` verbatim (which returns a raw `CGAffineTransform`
/// composed by matrix concatenation and can accumulate shear once a
/// non-uniform-scale child is nested inside a rotated group). Instead it
/// composes the SAME way `InspectorModel.worldTransform(for:in:)` already
/// does ، via `MKGroupTransform.worldTransform` on decomposed
/// `MKTransform2D` values, which is shear-free by construction (matches
/// `MKOrientedRect`'s own single-rotation-angle shape) ، then builds the
/// OBB from that transform + `MKNodeLocalBounds.localBounds(of:)`. This
/// keeps every consumer of `session.geometrySource` (selection chrome,
/// marquee, snapping, handle math, `InspectorModel.sizeValue`/`setSize`)
/// self-consistent with the position/rotation math `InspectorModel`
/// itself already uses for the SAME node.
@MainActor
final class MKCanvasRenderAdapter: MKCanvasGeometrySource, MKCanvasRenderBridge {
    let layerTree: MKLayerTreeController
    private let hitTester: HitTester

    /// `fonts` defaults to `MKFoundation.SystemFontStubProvider` ،
    /// WS-13 Session 3's app-local `MKAppFontProvider` workaround (a raw
    /// `CTFontCreateWithName(".SFArabic", ...)` call, confirmed
    /// runtime-fragile: dot-prefixed system-font names are silently
    /// substituted with TimesNewRoman on the macOS 26 host) is retired as
    /// of WS-13 Session 4 now that the upstream stub is fixed at the
    /// source (by-name resolution with a PostScript-name round-trip check,
    /// falling back through the language-tagged UI font to the SF Arabic
    /// cascade member via `CTFontCreateForStringWithLanguage`) ، see
    /// `MakhtootKit/CONTRACTS.md` "P4-exit fixes" §2. Every text-aware
    /// consumer this adapter owns (hit-testing here, rendering via
    /// `layerTree` ، caller threads the SAME provider into its
    /// `MKLayerTreeController.init(fonts:)`) should agree.
    init(layerTree: MKLayerTreeController, fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.layerTree = layerTree
        self.hitTester = HitTester(fonts: fonts)
    }

    var hostLayer: CALayer { layerTree.hostLayer }

    func sync(to scene: MKScene) {
        layerTree.sync(to: scene)
    }

    func setVisibleRect(_ visibleRect: CGRect, zoomScale: CGFloat) {
        layerTree.setVisibleRect(visibleRect, zoomScale: zoomScale)
    }

    func consumeRasterizationCount() -> Int {
        layerTree.consumeRasterizationCount()
    }

    // MARK: - MKCanvasRenderBridge

    func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform) {
        layerTree.applyTransientTransform(nodeID: nodeID, transform: transform)
    }

    func commitTransients() {
        layerTree.commitTransients()
    }

    // MARK: - MKCanvasGeometrySource

    func worldOBB(for nodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect? {
        guard let node = scene.node(id: nodeID) else { return nil }
        guard let transform = InspectorModel.worldTransform(for: nodeID, in: scene) else { return nil }
        let localBounds = MKNodeLocalBounds.localBounds(of: node)
        return MKOrientedRect(localBounds: localBounds, transform: transform)
    }

    /// The exact rect `worldOBB(for:in:)` above maps through the node's
    /// world transform ، published so `HandleGestures`/`InspectorModel
    /// .setSize` can invert that mapping consistently instead of assuming
    /// origin-anchored local bounds (see `MKCanvasGeometrySource
    /// .localBounds(for:in:)`).
    func localBounds(for nodeID: MKNodeID, in scene: MKScene) -> CGRect? {
        guard let node = scene.node(id: nodeID) else { return nil }
        return MKNodeLocalBounds.localBounds(of: node)
    }

    func containsPrecise(nodeID: MKNodeID, worldPoint: CGPoint, in scene: MKScene) -> Bool {
        hitTester.containsPrecise(nodeID: nodeID, worldPoint: worldPoint, in: scene)
    }

    // MARK: - Arrange Mode child geometry
    //
    // Bug fix (2026-07-29). These two were NEVER implemented here ، this
    // adapter is the only production conformer of `MKCanvasGeometrySource`,
    // so both silently resolved to the protocol extension's `nil` default.
    // The consequences were not subtle:
    //
    // * `MKArrangeInteractionModel.tap(at:zoomScale:)` always saw `nil`
    //   and took its "tapped empty composition space" branch, so NO
    //   glyph, ligature or tashkeel mark could be selected by touch
    //   anywhere in Arrange Mode ، the whole point of the mode.
    // * `MKCanvasViewController`'s arrange-scoped chrome pass
    //   (`arrangedChildWorldOBB` per selected child) always produced an
    //   empty OBB list, so even a selection made some other way drew no
    //   outline or handles.
    //
    // Which is most of why the wand "did nothing you could see": entry
    // and derivation worked, everything downstream of the first tap did
    // not.

    /// Composition-space affine (`MKArrangedGeometry`'s `compositionAffine`
    /// argument): arranged children carry composition-local y-UP
    /// coordinates, while canvas/document space is y-DOWN. Same constant
    /// `ArrangedDrawer` and `HitTester.arrangedChild` already use.
    private static let compositionAffine = CGAffineTransform(scaleX: 1, y: -1)

    func arrangedChildHit(
        at worldPoint: CGPoint, ownerNodeID: MKNodeID, in scene: MKScene, tolerance: CGFloat
    ) -> (childID: MKNodeID, distance: CGFloat)? {
        guard case .arranged(let owner)? = scene.node(id: ownerNodeID),
              let geometry = hitTester.worldGeometry(of: ownerNodeID, in: scene)
        else { return nil }
        // Into the owner's own local space, through the FULL ancestor
        // chain (correct for an arranged node nested in a group).
        let localPoint = worldPoint.applying(geometry.worldTransform.inverted())
        guard let hit = hitTester.arrangedChild(
            at: localPoint, in: owner, compositionWorldTransform: .identity, tolerance: tolerance),
              let childID = hit.childID
        else { return nil }
        return (childID, hit.distance)
    }

    func arrangedChildWorldOBB(childID: MKNodeID, ownerNodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect? {
        guard case .arranged(let owner)? = scene.node(id: ownerNodeID),
              let ownerTransform = InspectorModel.worldTransform(for: ownerNodeID, in: scene)
        else { return nil }

        let index = MKArrangedGeometry.Index(composition: owner.composition)
        guard let element = index.element(id: childID),
              let childAffine = MKArrangedGeometry.worldTransform(
                of: childID, index: index, compositionAffine: Self.compositionAffine)
        else { return nil }

        let pointSize = owner.composition.sourceBackup.style.pointSize
        let outline: MKPathData?
        switch element {
        case .glyph(let g): outline = g.outline
        case .composedLigature(_, _, let ligature): outline = ligature.outline
        case .mark(let m): outline = m.outline
        }

        // The child's extent in ITS OWN outline space, then into the
        // composition's local space. A child with no persisted outline
        // (INV-13 forbids re-extracting one here) falls back to the same
        // slop-sized box `HitTester.arrangedChild` uses for that case, so
        // chrome and hit-testing agree about where it is.
        let localRect: CGRect
        if let outline, !outline.commands.isEmpty {
            localRect = outline.cgPath(at: pointSize).boundingBoxOfPath
        } else {
            let half = HitTester.markTapSlopPoints
            localRect = CGRect(x: -half, y: -half, width: half * 2, height: half * 2)
        }
        guard localRect.width > 0, localRect.height > 0 else { return nil }

        // Composition-local AABB of the transformed outline box. Building
        // the OBB from this axis-aligned rect (rather than threading the
        // child's own rotation through) means a rotated glyph reports a
        // conservative enclosing box ، the same simplification
        // `MKOrientedRect.unionBounds` already makes for multi-select, and
        // correct for what this feeds (selection outlines and handles).
        let compositionRect = localRect.applying(childAffine)
        return MKOrientedRect(localBounds: compositionRect, transform: ownerTransform)
    }
}
