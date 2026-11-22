import CoreGraphics
import MKModel

// WS-07 packet §5 task 9. Huge-node/huge-canvas tiling support: v1 uses
// DIRECT-DRAW region rendering (ADR WS07-A2 ، chosen over `CATiledLayer`-
// style manual mosaic sublayers for v1 simplicity, tradeoff documented in
// `README.md`) ، `MKSnapshotRenderer.render(_:region:scale:quality:)`
// already renders an arbitrary sub-rect correctly (§11.1's "region:
// canvas-space region to draw" parameter is exactly this), so the "tiling"
// this file adds is purely the BOUNDS MATH (splitting a huge area into
// ≤64 MB strips) ، `MKExport`'s own tiled strips (WS-08) are expected to
// call `MKSnapshotRenderer` directly with their own tile rects computed
// the same way (or reuse `tileRects(covering:scale:maxBytes:)` below).
public enum MKTileRenderer {
    /// Each tile's `CGBitmapContext` allocation must stay ≤64 MB (task 9 /
    /// §16.4's shared budget: "each CGBitmapContext ≤ 64 MB").
    public static let maxTileBytes = 64 * 1024 * 1024
    /// RGBA8 premultiplied ، matches `MKSnapshotRenderer
    /// .makeFlippedBitmapContext`'s `bitmapInfo`.
    private static let bytesPerPixel = 4

    /// Splits `bounds` (canvas/document space) into a row-major grid of
    /// tiles whose device-pixel byte footprint at `scale` never exceeds
    /// `maxBytes`. Task 9 accept: "a 12 000×12 000 pt background scene pans
    /// without >64 MB single allocations."
    public static func tileRects(covering bounds: CGRect, scale: CGFloat, maxBytes: Int = maxTileBytes) -> [CGRect] {
        guard bounds.width > 0, bounds.height > 0, scale > 0 else { return [] }
        let maxPixels = Double(maxBytes) / Double(bytesPerPixel)
        let maxTileSidePoints = maxPixels.squareRoot() / Double(scale)
        let tileSide = max(64.0, maxTileSidePoints.rounded(.down))

        var rects: [CGRect] = []
        var y = bounds.minY
        while y < bounds.maxY {
            let height = min(CGFloat(tileSide), bounds.maxY - y)
            var x = bounds.minX
            while x < bounds.maxX {
                let width = min(CGFloat(tileSide), bounds.maxX - x)
                rects.append(CGRect(x: x, y: y, width: width, height: height))
                x += CGFloat(tileSide)
            }
            y += CGFloat(tileSide)
        }
        return rects
    }

    /// Renders one tile through `MKSnapshotRenderer`, wrapped in the
    /// `renderTile` signpost (task 13) so tile-by-tile cost is visible in
    /// `xctrace` traces independent of the overall `export`/`documentOpen`
    /// interval it nests inside.
    public static func renderTile(
        _ scene: MKScene, rect: CGRect, scale: CGFloat, quality: MKRenderQuality, renderer: MKSnapshotRenderer
    ) -> CGImage? {
        MKRenderSignposts.interval(.renderTile) {
            renderer.render(scene, region: rect, scale: scale, quality: quality)
        }
    }
}
