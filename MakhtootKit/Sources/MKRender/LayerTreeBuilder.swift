import CoreGraphics
import MKFoundation
import MKModel
import QuartzCore

// WS-07 packet §5 task 5/6. `MKLayerTreeController` ، the real
// `RenderTreeProviding` conformer (D-114): one `CALayer` per top-level
// node, `layer.contents` = a bitmap rendered by `MKSceneRenderer` (via
// `MKSnapshotRenderer`) at `contentsScale = screenScale × zoomBucket`
// (§11.3), re-rasterized only when `MKContentHash` changes (§11.2's dirty
// tracking).
//
// **Transient-transform strategy (task 6, documented simplification):**
// D-114's ideal is "content bitmap at the node's INTRINSIC size, transform
// applied purely as a layer property forever." `MKShapeNode`/`MKImageNode`
// have no separate width/height field (`ShapeDrawer`/`ImageDrawer`'s "size
// lives in `transform.scale`" convention) ، folding `scale` OUT of the
// bitmap render while using it as a live layer property would mean
// rasterizing at a degenerate ~1×1 pt intrinsic size and relying on the
// layer's own transform to blow it up, which is blurry, not "cheap and
// crisp." Instead: `layer.contents` is rasterized at the node's WORLD
// bounds/transform AS OF THE LAST RASTERIZATION (`bakedTransform`), and
// EVERY pure transform change ، live transient gestures AND committed
// transform-only commits alike ، is applied as the anchor-adjusted delta
// from that baked transform (`layerTransform(worldDelta:anchor:)`), a
// layer-property update with zero bitmap work. This satisfies task 6's
// accept criterion (zero `draw(in:)`/bitmap work during a gesture) and
// the WS-13 Session 3 Bug 2 requirement (a committed move/resize/rotate
// is visually applied without any re-raster or cache-busting event), with
// a well-understood, standard tradeoff: minor bitmap resampling while the
// on-layer delta is non-identity, snapping back to a crisp re-render
// whenever the content hash next changes (style/content edit, or a §11.3
// zoom-bucket crossing).

/// P-1: a monotonic per-node revision counter, bumped by
/// `MKArrangeInteractionModel` (`MKCanvas` ، which already depends on this
/// module, see `Package.swift`'s `MKCanvas` target dependency list) right
/// after every composition-mutating command it performs.
/// `MKLayerTreeController` below consults this as a cheap first-pass filter
/// before its own structural-equality confirmation (`ArrangedHashCacheEntry`
/// ، see that type's doc comment for why the equality check is also needed
/// and why it does not reintroduce the O(composition-size) cost this exists
/// to eliminate), so an untouched Arrange Mode composition is never
/// re-encoded/re-hashed on a `sync(to:)` pass that doesn't concern it.
///
/// `@MainActor`-isolated: both the sole writer (`MKArrangeInteractionModel`)
/// and sole reader (`MKLayerTreeController`) already run on the main actor,
/// so this needs no locking to satisfy Swift 6 strict concurrency.
@MainActor
public enum MKCompositionRevision {
    private static var counters: [MKNodeID: Int] = [:]

    /// Called by `MKArrangeInteractionModel` immediately after a
    /// composition-mutating `session.perform(_:)` call succeeds.
    public static func bump(_ nodeID: MKNodeID) {
        counters[nodeID, default: 0] += 1
    }

    /// The current revision for `nodeID` ، `0` for a node never bumped
    /// (a fresh arrangement, or any node kind that never mutates through
    /// `MKArrangeInteractionModel` at all).
    public static func current(for nodeID: MKNodeID) -> Int {
        counters[nodeID] ?? 0
    }

    /// Drops tracked state for a node no longer in the scene ، called from
    /// `MKLayerTreeController.sync(to:)`'s existing removed-node sweep so
    /// this table doesn't grow unbounded over a long editing session
    /// (`duplicateThenRevertForEditing` mints a fresh node id per call).
    public static func forget(_ nodeID: MKNodeID) {
        counters.removeValue(forKey: nodeID)
    }

    /// P8-5 (AUDIT_2026-08-05.md): drops EVERY tracked counter at once ،
    /// called from the editor teardown path (`EditorViewModel.close()`).
    /// `forget(_:)` above is not enough on its own: its only caller is
    /// `MKLayerTreeController.sync(to:)`'s removed-node sweep over that
    /// controller's OWN `layers` dict, so counters for nodes belonging to a
    /// torn-down editor (whose controller is simply deallocated, never
    /// synced against an emptied scene) were never removed and accreted
    /// across sessions in this process-global table. Clearing is safe even
    /// with multiple scenes open: a lost counter only downgrades the
    /// `arrangedHashCache` pre-filter to one extra hash recompute ،
    /// `MKLayerTreeController.contentHash(for:)` confirms a revision match
    /// with structural equality before trusting it (see
    /// `arrangedHashCache`'s doc comment), so no wrong render is possible.
    public static func reset() {
        counters.removeAll()
    }
}

/// One `arrangedHashCache` entry (`MKLayerTreeController`): every field
/// `MKContentHash.hash(of:scaleBucket:)` actually reads for an `.arranged`
/// node, captured alongside the hash it produced, so a later sync can
/// confirm "nothing this hash depends on has changed" with a handful of
/// cheap `==` comparisons instead of recomputing the hash outright.
private struct ArrangedHashCacheEntry {
    var revision: Int
    var scaleBucket: Double
    var style: MKStyle
    var composition: ArrangedComposition
    var hash: String
}

@MainActor
public final class MKLayerTreeController: RenderTreeProviding {
    public let hostLayer = CALayer()

    private var layers: [MKNodeID: CALayer] = [:]
    private var committedContentHash: [MKNodeID: String] = [:]
    /// P-1: caches the last-computed content hash for each `.arranged` node
    /// (the one node kind whose hash is expensive ، `MKContentHash`'s file
    /// header: "encodes the ENTIRE composition"), keyed on
    /// `MKCompositionRevision.current(for:)` PLUS a structural-equality
    /// check against the exact fields that fed that hash. The revision
    /// counter alone is only a fast pre-filter, not a proof of validity ،
    /// it is bumped by `MKArrangeInteractionModel`, but not every path that
    /// can change a composition routes through it (undo/redo restores a
    /// prior composition value directly via `MakhtootDocument`), so a
    /// revision MATCH is treated as "probably still valid, confirm
    /// cheaply" via `==`, not "definitely still valid" on its own. That
    /// equality check does not reintroduce the O(composition-size) cost
    /// this cache exists to avoid: Swift's `Array.==` (and therefore the
    /// synthesized `Equatable` for the structs wrapping it here) fast-paths
    /// identical copy-on-write storage before ever comparing elements, so
    /// the truly-unchanged case ، the case this fix targets ، stays O(1).
    private var arrangedHashCache: [MKNodeID: ArrangedHashCacheEntry] = [:]
    /// The node world transform BAKED INTO the layer's current bitmap ،
    /// set only at rasterization time. Every layer-property transform
    /// (committed transform-only commits AND live transient gestures) is
    /// applied as a delta FROM this, so the bitmap itself never needs
    /// re-rendering for a pure transform change (P4-exit fix; WS-13
    /// Session 3 Bug 2, `docs/impl-log/WS-13.md`).
    private var bakedTransform: [MKNodeID: CGAffineTransform] = [:]
    /// The layer's world anchor (its `position`, = baked world-bounds
    /// center) at bake time ، the pivot CALayer applies transforms about,
    /// needed to convert a world-space delta into a layer transform.
    private var bakedAnchor: [MKNodeID: CGPoint] = [:]
    private var lastScene: MKScene?
    private var rasterizationCount = 0
    private var scaleBucket: Double = 1
    private var screenScale: CGFloat
    /// P14: the last viewport rect reported by `setVisibleRect`, in the same
    /// (unscaled, host-layer) coordinate space every layer's `.frame` lives
    /// in. `.null` until the first real report ، `evictOffscreen()` is a
    /// deliberate no-op before then (never guess at "offscreen" without a
    /// real viewport reading; evicting everything on a `.null` guess would
    /// blank the canvas on first launch before any scroll/zoom event has
    /// ever fired).
    private var lastVisibleRect: CGRect = .null
    /// P-9: mirrors `hasEvictedContent`'s truth value as a stored flag
    /// instead of an O(layers.count) scan, set true by `evictOffscreen()`/
    /// `evictAll()` and cleared at the end of `sync(to:)`. This used to be
    /// an acceptable-cost computed scan because it was only consulted on a
    /// 150 ms poll (see `setVisibleRect`'s doc comment); once P-2 replaced
    /// that poll with a per-scroll-frame `onViewportChanged` callback, the
    /// same scan runs on every scroll frame, so it is stored instead.
    ///
    /// Deliberately module-internal, not `private`: `PerfHarnessTests`
    /// (`@testable import MKRender`) asserts its value directly across the
    /// eviction/resync cycle. Still outside the type's public API surface.
    var hasEvictedContentFlag = false

    private let renderer: MKSnapshotRenderer
    private let backgroundLayerID = MKNodeID()
    /// Weak reference: WS-13's `AppEnvironment` holds the strong ref. Both
    /// types are `@MainActor` so direct property access is safe without await.
    private weak var degradationController: MKDegradationController?

    public init(
        fonts: any MKFontProviding = SystemFontStubProvider(),
        assets: any MKAssetProviding = MKEmptyAssetProvider(),
        screenScale: CGFloat = 2,
        degradationController: MKDegradationController? = nil
    ) {
        self.renderer = MKSnapshotRenderer(fonts: fonts, assets: assets)
        self.screenScale = screenScale
        self.degradationController = degradationController
        hostLayer.name = "MKRender.MKLayerTreeController"
    }

    /// ARCHITECTURE §12.4: stage ≥2 rasterizes half-res bitmaps (scaleBucket −1).
    private var effectiveContentsScale: CGFloat {
        let base = screenScale * CGFloat(scaleBucket)
        return (degradationController?.fidelity ?? .full) == .reduced ? base / 2 : base
    }

    public func sync(to scene: MKScene) {
        lastScene = scene
        var seen = Set<MKNodeID>()

        syncBackground(scene)

        for node in scene.nodes {
            seen.insert(node.id)
            syncNode(node)
        }

        for (id, layer) in layers where !seen.contains(id) && id != backgroundLayerID {
            layer.removeFromSuperlayer()
            layers.removeValue(forKey: id)
            committedContentHash.removeValue(forKey: id)
            bakedTransform.removeValue(forKey: id)
            bakedAnchor.removeValue(forKey: id)
            arrangedHashCache.removeValue(forKey: id)
            MKCompositionRevision.forget(id)
        }

        // P-9: every node above just went through `syncNode`, which
        // re-rasterizes (and thus restores `.contents`) whenever it was
        // nil, so a full `sync(to:)` pass always leaves the tree with no
        // evicted content by construction.
        hasEvictedContentFlag = false
    }

    public func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform) {
        guard let layer = layers[nodeID], let baked = bakedTransform[nodeID], let anchor = bakedAnchor[nodeID] else { return }
        // Delta from the BITMAP's baked transform (not merely the last
        // committed scene transform ، those can differ when a committed
        // transform-only change was applied as a layer property without
        // re-rasterizing, see `syncNode`): baked⁻¹ then live.
        let delta = baked.inverted().concatenating(transform)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setAffineTransform(Self.layerTransform(worldDelta: delta, anchor: anchor))
        CATransaction.commit()
    }

    /// Converts a WORLD-space delta mapping `D` (old world point → new
    /// world point) into the `CALayer.affineTransform` that realizes it.
    ///
    /// CALayer applies its transform about the layer's anchor point:
    /// `rendered(p) = anchor + M(p − anchor)` (with `M` applied to the
    /// offset as a point, translation included). Solving `rendered(p) =
    /// D(p)` for all `p` gives `M = translate(anchor) ∘ D ∘
    /// translate(−anchor)` (apply-order left to right). The original
    /// implementation set `M = D` directly, which is only correct when
    /// `D` is a pure translation (translation is anchor-independent) ،
    /// exactly why the bug stayed latent through WS-06's drag tests
    /// (drags are translations) and would have misplaced live ROTATE/
    /// SCALE gestures the moment a real one ran.
    static func layerTransform(worldDelta: CGAffineTransform, anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: anchor.x, y: anchor.y)
            .concatenating(worldDelta)
            .concatenating(CGAffineTransform(translationX: -anchor.x, y: -anchor.y))
    }

    public func commitTransients() {
        // Structural no-op: WS-06 calls this at gesture end, then commits
        // the real command to the document and calls `sync(to:)` with the
        // now-committed scene; `syncNode` then re-derives every layer's
        // transform as the baked→committed delta (transform-only commits
        // stay layer-property updates; content edits re-rasterize and
        // reset the delta to identity). See `RenderTreeProviding`'s doc
        // comment for why this is a distinct protocol step from
        // `sync(to:)`.
    }

    public func setVisibleRect(_ visibleRect: CGRect, zoomScale: CGFloat) {
        let rectChanged = !lastVisibleRect.equalTo(visibleRect)
        lastVisibleRect = visibleRect

        let newBucket = MKScaleBucket.quantize(Double(zoomScale))
        if newBucket != scaleBucket {
            scaleBucket = newBucket
            // §11.3: content re-rasterizes on a bucket CROSSING only ،
            // `MKScaleBucket.quantize`'s power-of-√2 snapping already
            // provides the "no redraw until zoom settles into a new
            // bucket" behavior (a scroll/zoom that stays within one
            // bucket never reaches this branch); forcing every hash to
            // recompute here re-rasterizes every visible layer exactly
            // once per actual bucket change.
            committedContentHash.removeAll()
            if let scene = lastScene { sync(to: scene) }
            return
        }

        // P14: a layer whose `.contents` a ladder-driven `evictOffscreen()`
        // call nil'd out (see below) needs to re-rasterize once it scrolls
        // back into view, even when that scroll never crosses a zoom
        // bucket. `syncNode`'s re-rasterize condition already fires on
        // `layer.contents == nil` (not hash alone) ، this just makes sure
        // `sync(to:)` actually RUNS after such a scroll, instead of only on
        // the next unrelated scene mutation or bucket crossing.
        if rectChanged, hasEvictedContent, let scene = lastScene {
            sync(to: scene)
        }
    }

    /// P14 (`docs/impl-log/WS-07-p14.md`): true once `evictOffscreen()`/
    /// `evictAll()` has nil'd at least one layer's `.contents` since the
    /// last full `sync(to:)` pass rasterized everything again.
    ///
    /// P-9: this used to recompute via `layers.values.contains { $0.contents
    /// == nil }` on every read, which was acceptable only while it was
    /// consulted on a 150 ms poll. P-2 replaced that poll with a
    /// per-scroll-frame `onViewportChanged` callback into `setVisibleRect`,
    /// making this an O(layers.count) scan on every scroll frame instead ،
    /// now a direct read of `hasEvictedContentFlag`, a stored `Bool`
    /// maintained by `evictOffscreen()`/`evictAll()`/`sync(to:)` instead.
    private var hasEvictedContent: Bool {
        hasEvictedContentFlag
    }

    public func consumeRasterizationCount() -> Int {
        defer { rasterizationCount = 0 }
        return rasterizationCount
    }

    // MARK: - Per-node sync

    private func syncBackground(_ scene: MKScene) {
        let layer = layers[backgroundLayerID] ?? makeLayer(for: backgroundLayerID, insertAtBottom: true)
        let hash = MKContentHash.hash(of: .background(scene.background), scaleBucket: scaleBucket)
        layer.isHidden = scene.background.core.isHidden
        layer.bounds = CGRect(origin: .zero, size: scene.canvas.size)
        layer.position = CGPoint(x: scene.canvas.size.width / 2, y: scene.canvas.size.height / 2)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        guard committedContentHash[backgroundLayerID] != hash else { return }
        let contentsScale = effectiveContentsScale
        let isolatedScene = MKScene(canvas: scene.canvas, background: scene.background, nodes: [])
        let image = MKRenderSignposts.interval(.layerSync) {
            renderer.render(isolatedScene, region: CGRect(origin: .zero, size: scene.canvas.size), scale: contentsScale, quality: .editorPreview(stage: degradationController?.stage ?? .normal))
        }
        layer.contents = image
        layer.contentsScale = contentsScale
        committedContentHash[backgroundLayerID] = hash
        rasterizationCount += 1
    }

    private func syncNode(_ node: MKNode) {
        let hash = contentHash(for: node)
        let layer = layers[node.id] ?? makeLayer(for: node.id, insertAtBottom: false)
        layer.isHidden = node.core.isHidden
        layer.opacity = Float(node.core.opacity)

        // P14: re-rasterize on a nil `.contents` too (not hash change
        // alone) ، the ladder-driven `evictOffscreen()`/`evictAll()` below
        // nils a layer's bitmap WITHOUT touching `committedContentHash`'s
        // sibling bake-state, specifically so a re-rasterize here restores
        // exactly what was there before (no bakedTransform/bakedAnchor
        // reset, no lost in-flight transient-transform delta) ، only the
        // MEMORY (the bitmap itself) was reclaimed.
        if committedContentHash[node.id] != hash || layer.contents == nil {
            rasterize(node, into: layer)
            committedContentHash[node.id] = hash
            bakedTransform[node.id] = node.core.transform.affineTransform
            bakedAnchor[node.id] = layer.position
            rasterizationCount += 1
        }

        // Commit: apply the delta between the bitmap's BAKED transform and
        // the node's CURRENT committed transform as a layer property. Right
        // after a rasterization this is `.identity` (baked == current); for
        // a committed TRANSFORM-ONLY change (content hash unchanged ، move/
        // resize/rotate with no style/content edit) this is the entire
        // visual update, with zero bitmap work. This is the P4-exit fix for
        // WS-13 Session 3 Bug 2 (`docs/impl-log/WS-13.md`): previously this
        // path unconditionally reset the layer transform to `.identity` and
        // NOTHING re-applied the committed transform outside the content-
        // hash-gated `rasterize` call, leaving the layer visually stale at
        // its pre-commit position until an unrelated cache-busting event.
        guard let baked = bakedTransform[node.id], let anchor = bakedAnchor[node.id] else { return }
        let delta = baked.inverted().concatenating(node.core.transform.affineTransform)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setAffineTransform(Self.layerTransform(worldDelta: delta, anchor: anchor))
        CATransaction.commit()
    }

    /// P-1: `MKContentHash.hash(of:scaleBucket:)`, short-circuited for
    /// `.arranged` nodes when `arrangedHashCache` still holds a provably
    /// valid entry (see that property's doc comment). Every other node
    /// kind is already cheap to hash (no large composition to encode, per
    /// the audited finding), so this always falls through to a fresh
    /// `MKContentHash.hash` call for them, exactly as before this fix.
    private func contentHash(for node: MKNode) -> String {
        guard case .arranged(let n) = node else {
            return MKContentHash.hash(of: node, scaleBucket: scaleBucket)
        }
        let revision = MKCompositionRevision.current(for: node.id)
        if let cached = arrangedHashCache[node.id],
           cached.revision == revision,
           cached.scaleBucket == scaleBucket,
           cached.style == n.core.style,
           cached.composition == n.composition {
            return cached.hash
        }
        let hash = MKContentHash.hash(of: node, scaleBucket: scaleBucket)
        arrangedHashCache[node.id] = ArrangedHashCacheEntry(
            revision: revision, scaleBucket: scaleBucket, style: n.core.style, composition: n.composition, hash: hash
        )
        return hash
    }

    private func rasterize(_ node: MKNode, into layer: CALayer) {
        let worldBounds = MKNodeLocalBounds.worldBounds(of: node)
        layer.bounds = CGRect(origin: .zero, size: worldBounds.size)
        layer.position = CGPoint(x: worldBounds.midX, y: worldBounds.midY)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        guard worldBounds.width > 0, worldBounds.height > 0 else {
            layer.contents = nil
            return
        }

        // Isolate the node into its own single-node scene, offsetting its
        // transform so `worldBounds.origin` maps to (0,0) ، the node's own
        // transform (rotation/scale/position-within-bounds) stays baked
        // into the bitmap; only the DELTA since this commit is ever
        // applied as a live layer property (see file header).
        var core = node.core
        core.transform.position = CGPoint(
            x: core.transform.position.x - worldBounds.origin.x,
            y: core.transform.position.y - worldBounds.origin.y
        )
        let isolatedNode = node.withCore(core)
        let transparentBackground = MKBackgroundNode(
            core: MKNodeCore(name: "transparent"), content: .solid(MKSolidColor(r: 0, g: 0, b: 0, a: 0))
        )
        let isolatedScene = MKScene(
            canvas: MKCanvasSpec(size: worldBounds.size), background: transparentBackground, nodes: [isolatedNode]
        )

        let contentsScale = effectiveContentsScale
        let image = MKRenderSignposts.interval(.layerSync) {
            renderer.render(isolatedScene, region: CGRect(origin: .zero, size: worldBounds.size), scale: contentsScale, quality: .editorPreview(stage: degradationController?.stage ?? .normal))
        }
        layer.contents = image
        layer.contentsScale = contentsScale
    }

    private func makeLayer(for id: MKNodeID, insertAtBottom: Bool) -> CALayer {
        let layer = CALayer()
        layer.anchorPoint = .zero
        if insertAtBottom {
            hostLayer.insertSublayer(layer, at: 0)
        } else {
            hostLayer.addSublayer(layer)
        }
        layers[id] = layer
        return layer
    }

    // MARK: - MKMemoryAccountable (P14, D-116 governor wiring)

    /// Sum of every currently-rasterized layer bitmap's accounted bytes
    /// (`bytesPerRow × height`, same accounting `BitmapCache` uses) ، the
    /// LIVE editor's actual dominant memory cost (§12.2's cache list),
    /// unlike the standalone `BitmapCache` actor, which nothing in the app
    /// composition roots currently populates (each `CALayer.contents` IS
    /// this controller's cache, one entry per node ، see the file header's
    /// "Transient-transform strategy" note).
    public func accountedBytes() -> Int {
        var total = 0
        for layer in layers.values {
            guard let image = layer.contents else { continue }
            // `CALayer.contents` is typed `Any?`; this controller only ever
            // assigns a `CGImage` (see `rasterize`/`syncBackground`) so the
            // conditional cast is exhaustive in practice, never force-unwrapped.
            guard CFGetTypeID(image as CFTypeRef) == CGImage.typeID else { continue }
            // swiftlint:disable:next force_cast ، type-checked via CFGetTypeID above
            let cgImage = image as! CGImage
            total += cgImage.bytesPerRow * cgImage.height
        }
        return total
    }

    /// D-116 stage 1: drop bitmaps for every layer whose `.frame` does not
    /// intersect the last-reported visible rect (`setVisibleRect`). A
    /// no-op before any real visible rect has ever been reported
    /// (`lastVisibleRect == .null`) ، see that property's doc comment.
    /// Freed layers re-rasterize lazily, either on the next scene mutation,
    /// the next zoom-bucket crossing, or ، the case those two would MISS ،
    /// the next plain scroll back into view, handled by `setVisibleRect`
    /// forcing a `sync(to:)` pass when `hasEvictedContent` is true.
    public func evictOffscreen() {
        guard !lastVisibleRect.isNull else { return }
        for (id, layer) in layers where id != backgroundLayerID {
            guard !layer.frame.intersects(lastVisibleRect) else { continue }
            layer.contents = nil
            hasEvictedContentFlag = true
        }
    }

    /// D-116/D-223 critical: drop every layer's bitmap unconditionally
    /// (background layer included ، the nuclear option, matching
    /// `BitmapCache.purgeAll()`'s own "critical only" scope).
    public func evictAll() {
        for layer in layers.values {
            layer.contents = nil
        }
        hasEvictedContentFlag = true
    }
}

extension MKLayerTreeController: MKMemoryAccountable {}
