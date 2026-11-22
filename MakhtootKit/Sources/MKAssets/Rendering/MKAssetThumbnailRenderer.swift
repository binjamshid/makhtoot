import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 10. Deterministic thumbnail rasterizer: runtime CG
// render + LRU cache (packet's own choice between the two documented
// options ، "runtime-cached CG render... to avoid stale checked-in art").
//
// **No `MKRender` dependency (packet §3: "no direct dependency; thumbnails
// use a small internal CG rasterizer over path data").** This renderer is
// deliberately self-contained rather than reusing `MKRender.MKSnapshot
// Renderer` ، `MKAssets`'s only declared dependency is `MKModel`
// (FOUNDATION §2), and the packet explicitly frames the internal
// rasterizer as the DEFAULT choice ("or WS-07's snapshot API if available
// at build time ، prefer reuse" is the alternative, but adding a new
// cross-module edge is a bigger structural change than a ~40-line CG
// bitmap-context render loop). Fill rule: plain `ctx.fillPath()` (CG's
// default nonzero winding), matching `MKRender.StylePainting.paint`
// exactly ، so a thumbnail and the real canvas render of the same asset
// agree on every hole/subtraction (crescent, rosette rings, …), verified by
// `MKAssetThumbnailRendererTests`.
//
// **Ink-on-paper color note (task 10: "theme-aware... ink-on-paper token
// colors").** `MKAssets` has no `MKDesignSystem` dependency (not a
// FOUNDATION §2 edge) ، motif fill uses `MKModel.MKSolidColor.defaultInk`,
// the MKModel-layer ink default ADR'd for exactly this "need the Ink &
// Paper ink color without a MKDesignSystem edge" situation (see its doc
// comment in `Sources/MKModel/MKNodeStyle.swift`). Background is
// TRANSPARENT (alpha 0), not a hardcoded paper-neutral fill ، no model-layer
// paper-color constant exists to source one from, and a transparent PNG
// composites correctly over WS-13's own paper-toned browser chrome without
// this module inventing an untracked color value.
public actor MKAssetThumbnailRenderer {
    private struct CacheKey: Hashable {
        let assetID: String
        let width: Int
        let height: Int
    }

    private var cache: [CacheKey: CGImage] = [:]
    private var lruOrder: [CacheKey] = [] // least-recent first
    private let capacity: Int

    public init(capacity: Int = 256) {
        self.capacity = capacity
    }

    public var cachedCount: Int { cache.count }

    /// Renders (or returns the cached render of) `descriptor` at `size`
    /// points. `.patternBackgrounds` assets render a 2×2 tile preview
    /// (task 10 accept criterion); every other category renders its single
    /// motif centered with a small margin.
    public func thumbnail(for descriptor: MKAssetDescriptor, size: CGSize = CGSize(width: 200, height: 200), library: MKAssetLibrary = .standard) -> CGImage? {
        let key = CacheKey(assetID: descriptor.assetID, width: Int(size.width.rounded()), height: Int(size.height.rounded()))
        if let cached = cache[key] {
            touch(key)
            return cached
        }
        guard let image = Self.render(descriptor: descriptor, size: size, library: library) else { return nil }
        store(key: key, image: image)
        return image
    }

    private func touch(_ key: CacheKey) {
        lruOrder.removeAll { $0 == key }
        lruOrder.append(key)
    }

    private func store(key: CacheKey, image: CGImage) {
        cache[key] = image
        touch(key)
        while lruOrder.count > capacity {
            let evicted = lruOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }

    // MARK: - Pure rendering (no cache/actor state ، testable standalone)

    nonisolated public static func render(descriptor: MKAssetDescriptor, size: CGSize, library: MKAssetLibrary = .standard) -> CGImage? {
        if descriptor.category == .patternBackgrounds, let fill = library.patternFill(assetID: descriptor.assetID) {
            return renderPatternPreview(fill: fill, size: size)
        }
        return renderSingleMotif(geometry: descriptor.pathData, size: size)
    }

    private static func makeContext(size: CGSize) -> CGContext? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Top-left origin, y-down ، matches MKRender's documented convention
        // (README "Coordinate conventions") even though this renderer is
        // self-contained; keeps a thumbnail's up/down sense consistent with
        // the real canvas render of the same asset.
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }

    private static func renderSingleMotif(geometry: MKAssetGeometry, size: CGSize) -> CGImage? {
        guard let ctx = makeContext(size: size) else { return nil }
        let bounds = geometry.localBounds
        guard bounds.width > 0, bounds.height > 0 else { return ctx.makeImage() }
        let margin = 0.08
        let availableW = size.width * (1 - 2 * margin)
        let availableH = size.height * (1 - 2 * margin)
        let scale = min(availableW / bounds.width, availableH / bounds.height)
        ctx.saveGState()
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
        ctx.setFillColor(MKSolidColor.defaultInk.cgColorRGBA)
        ctx.addPath(geometry.cgPath())
        ctx.fillPath() // nonzero winding, matching MKRender.StylePainting
        ctx.restoreGState()
        return ctx.makeImage()
    }

    private static func renderPatternPreview(fill: MKPatternFill, size: CGSize) -> CGImage? {
        guard let ctx = makeContext(size: size) else { return nil }
        ctx.setFillColor(fill.backgroundColor.cgColorRGBA)
        ctx.fill(CGRect(origin: .zero, size: size))

        let tileSize = fill.tile.tileSize
        guard tileSize.width > 0, tileSize.height > 0 else { return ctx.makeImage() }
        let cellSize = CGSize(width: size.width / 2, height: size.height / 2)
        let scale = min(cellSize.width / tileSize.width, cellSize.height / tileSize.height)
        let motifPath = fill.tile.geometry.cgPath()
        ctx.setFillColor(fill.motifColor.cgColorRGBA)
        for row in 0..<2 {
            for col in 0..<2 {
                ctx.saveGState()
                let cellOrigin = CGPoint(x: Double(col) * cellSize.width, y: Double(row) * cellSize.height)
                ctx.translateBy(x: cellOrigin.x + cellSize.width / 2, y: cellOrigin.y + cellSize.height / 2)
                ctx.scaleBy(x: scale, y: scale)
                ctx.translateBy(x: -fill.tile.geometry.localBounds.midX, y: -fill.tile.geometry.localBounds.midY)
                ctx.addPath(motifPath)
                ctx.fillPath()
                ctx.restoreGState()
            }
        }
        return ctx.makeImage()
    }
}

extension MKSolidColor {
    /// This module's own CGColor bridge (kept local, not a `MKModel`
    /// addition) ، `MKColor` (the real conversion module, WS-08) is out of
    /// this run's fence/scope; a simple sRGB `CGColor` is all a thumbnail
    /// rasterizer needs.
    var cgColorRGBA: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}
