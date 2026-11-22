import CoreGraphics
import Foundation
import ImageIO
import MKFoundation
import MKModel
import MKPersistence
import MKRender

/// P5.3 (Bug 2, canvas background image). Bridges `MKPersistence
/// .MKAssetStore` (actor-isolated, async file I/O ، `MKPersistence` cannot
/// depend on `MKRender`, so it has no way to conform to `MKAssetProviding`
/// itself) to `MKRender.MKAssetProviding` (a SYNCHRONOUS protocol the
/// render path calls on every layer sync / snapshot render, per that
/// protocol's own doc comment: "any caller... can hand in resolved images
/// without MKRender depending on MKPersistence"). The app target is the one
/// place both modules are visible, so this adapter lives here, not in
/// either package (would need a `Package.swift` dependency edge this
/// session's brief explicitly forbids changing).
///
/// **Real gap this closes, found while implementing P5.3, not assumed:**
/// `EditorViewModel`'s `MKLayerTreeController`/every `MKSnapshotRenderer`
/// call site (export, thumbnail) previously constructed with NO `assets:`
/// argument, defaulting to `MKEmptyAssetProvider()` ، meaning `MKImageNode`/
/// image-background rendering was NEVER actually reachable in the live app
/// or its exports, only in tests that inject a real provider directly. This
/// type is what makes it reachable; `EditorViewModel.init` now wires one
/// instance everywhere a `MKAssetProviding` is consumed.
///
/// `resolveRasterImage`/`resolvePDFPage` never touch disk themselves ،
/// they only ever answer from `cache`, which `prime(_:data:)` (called
/// synchronously at ingest time, BEFORE the mutating command is performed,
/// so the very first render after the command finds the bitmap already
/// there) and `primeReachableAssets(in:)` (an async catch-up pass for
/// assets a REOPENED document already references, run once after
/// `MakhtootDocument.open` and again on every scene update) populate ahead
/// of time. This keeps `MKAssetProviding`'s "`nil` = missing/undecoded,
/// never blocks" contract intact while still resolving real bitmaps once
/// the async decode catches up (a document reopened with a persisted image
/// background may show `.missingAsset`'s substitution — nothing render،
/// per `BackgroundDrawer` — for one sync pass until priming completes and
/// `EditorViewModel` re-syncs).
///
/// `@unchecked Sendable`: mutated/read only ever from `MainActor` call
/// sites in this app target (ingest, priming, and the `MainActor`-confined
/// `MKLayerTreeController`/`MKSnapshotRenderer` callers) ، the same
/// documented-manual-audit pattern this codebase already uses for
/// `DocumentAutosaveTrigger` (`EditorViewModel.swift`).
final class MKDocumentAssetProvider: MKAssetProviding, MKMemoryAccountable, @unchecked Sendable {
    private var cache: [MKAssetRef: CGImage] = [:]
    private let assetStore: MKAssetStore

    init(assetStore: MKAssetStore) {
        self.assetStore = assetStore
    }

    // MARK: - MKAssetProviding

    func resolveRasterImage(_ ref: MKAssetRef) -> CGImage? { cache[ref] }

    /// P5.3 is raster-only (photo backgrounds); vector PDF background
    /// assets are not part of this feature's scope, matching
    /// `MKEmptyAssetProvider`'s own `nil` for anything unhandled.
    func resolvePDFPage(_ ref: MKAssetRef) -> CGPDFPage? { nil }

    // MARK: - Ingest-time priming

    /// Decodes `data` and caches it under `ref` synchronously, called at
    /// ingest time (`EditorViewModel.setBackgroundImage`) BEFORE the
    /// mutating command is performed ، by the time the scene update fires
    /// and the render tree re-syncs, `resolveRasterImage(ref)` already
    /// answers, so the newly-set image renders on the very first frame
    /// with no missing-asset flash.
    @discardableResult
    func prime(_ ref: MKAssetRef, data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[ref] = image
        return image
    }

    /// Decodes+caches every raster asset ref reachable in `scene`
    /// (background image + top-level/nested `MKImageNode` raster assets)
    /// not already cached. Best-effort: a decode failure for one ref
    /// leaves it absent (the renderer records `.missingAsset` and skips
    /// it, never crashes), never throws. Must be called from `MainActor`
    /// (mutates `cache`, matching this type's documented isolation
    /// contract above).
    func primeReachableAssets(in scene: MKScene) async {
        for ref in Self.rasterRefs(in: scene) where cache[ref] == nil {
            guard let data = try? await assetStore.assetData(for: ref) else { continue }
            prime(ref, data: data)
        }
    }

    static func rasterRefs(in scene: MKScene) -> Set<MKAssetRef> {
        var refs: Set<MKAssetRef> = []
        if case .image(let ref, _) = scene.background.content { refs.insert(ref) }
        func visit(_ node: MKNode) {
            switch node {
            case .image(let n):
                if n.kind == .raster { refs.insert(n.asset) }
            case .group(let g):
                g.children.forEach(visit)
            default:
                break
            }
        }
        scene.nodes.forEach(visit)
        return refs
    }

    // MARK: - MKMemoryAccountable (P14 pattern, D-116 governor wiring)

    /// Same `bytesPerRow × height` accounting `MKLayerTreeController
    /// .accountedBytes()` uses ، this provider's cache is a real,
    /// unbounded-until-evicted bitmap cost (full-resolution decoded
    /// background/asset images), exactly the class of cache §12.2 requires
    /// every module to register.
    func accountedBytes() async -> Int {
        cache.values.reduce(0) { $0 + $1.bytesPerRow * $1.height }
    }

    /// This cache holds only a handful of user-ingested images (background
    /// + placed raster assets), not a per-node/per-tile LRU with a
    /// meaningful "offscreen" notion ، `evictOffscreen()` is a documented
    /// no-op (D-116 stage 1 targets bitmap caches that scale with scene
    /// size; this one does not). `evictAll()` (stage-critical) still
    /// clears it, same as every other registrant.
    func evictOffscreen() async {}

    func evictAll() async {
        cache.removeAll()
    }
}

// P5.3: "downscale to canvas × 2 on ingest" (the P14 hardening pass's own
// pattern for bounding ingested-bitmap memory, per this session's brief).
// The actual downscale math moved to `MKFoundation.MKImageDownscale`
// (`MakhtootKit/Sources/MKFoundation/ImageDownscale.swift`) ، caught in
// review: this app target has no test bundle at all, and the original
// UIKit (`UIImage`/`UIGraphicsImageRenderer`) implementation living HERE
// meant it could never be exercised by `swift test` either (this repo's
// verification runs `MakhtootKit`'s test targets on the macOS host, where
// UIKit doesn't exist). `EditorViewModel.setBackgroundImage` calls
// `MKImageDownscale.downscaledPNG(_:maxPixelSize:)` directly.
