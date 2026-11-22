import CoreGraphics
import ImageIO
import MKFoundation
import MKModel

// WS-07 packet §5 task 4. `MKSnapshotRenderer`: synchronous rendering of a
// scene (or a sub-region of one) to a `CGImage`, plus the thumbnail
// pipeline (WS-02 stores the bytes). Every MKRender consumer that needs
// PIXELS out (canvas layer bitmaps via `MKLayerTreeController`, WS-02
// thumbnails, WS-04 fidelity tests, WS-08 export strips) goes through
// `makeFlippedBitmapContext` + `MKSceneRenderer.render` ، this is the
// "single render path" (D-118/INV-2/INV-6) made concrete: there is
// exactly one context-creation helper and one drawing entry point in the
// whole module.
public struct MKSnapshotRenderer: Sendable {
    private let renderer: MKSceneRenderer

    public init(fonts: any MKFontProviding = SystemFontStubProvider(), assets: any MKAssetProviding = MKEmptyAssetProvider()) {
        self.renderer = MKSceneRenderer(fonts: fonts, assets: assets)
    }

    /// Renders `region` of `scene` at `scale` (document points → pixels) and
    /// returns the resulting `CGImage`, or `nil` if the pixel dimensions are
    /// degenerate (zero/negative width or height, or scale ≤ 0).
    public func render(_ scene: MKScene, region: CGRect, scale: CGFloat, quality: MKRenderQuality) -> CGImage? {
        guard let ctx = Self.makeFlippedBitmapContext(width: Int(region.width.rounded(.up)), height: Int(region.height.rounded(.up)), scale: scale) else {
            return nil
        }
        renderer.render(scene, region: region, into: ctx, scale: scale, quality: quality)
        return ctx.makeImage()
    }

    /// Renders `region` of `scene` and additionally returns the
    /// `MKRenderReport` (substitution events) ، used by tests/export
    /// callers that need to assert "no substitutions" (D-118 fidelity
    /// gate) rather than just the pixels.
    public func renderWithReport(
        _ scene: MKScene, region: CGRect, scale: CGFloat, quality: MKRenderQuality
    ) -> (image: CGImage?, report: MKRenderReport) {
        guard let ctx = Self.makeFlippedBitmapContext(width: Int(region.width.rounded(.up)), height: Int(region.height.rounded(.up)), scale: scale) else {
            return (nil, MKRenderReport(substitutions: [], nodeCount: 0, duration: 0))
        }
        let report = renderer.render(scene, region: region, into: ctx, scale: scale, quality: quality)
        return (ctx.makeImage(), report)
    }

    /// Whole-canvas render at `scale` ، convenience over `render(_:region:
    /// scale:quality:)` with `region = CGRect(origin: .zero, size: scene
    /// .canvas.size)`.
    public func renderFullCanvas(_ scene: MKScene, scale: CGFloat, quality: MKRenderQuality) -> CGImage? {
        render(scene, region: CGRect(origin: .zero, size: scene.canvas.size), scale: scale, quality: quality)
    }

    /// Thumbnail pipeline (task 4): long-edge `longEdge` px, full canvas,
    /// export-quality rendering (thumbnails never show degraded/ladder
    /// fidelity ، they represent the DOCUMENT, not the live editor state).
    /// WS-02 encodes the returned `CGImage` to JPEG bytes for
    /// `thumbnail.png`/manifest storage.
    public func renderThumbnail(_ scene: MKScene, longEdge: CGFloat = 512) -> CGImage? {
        let canvasSize = scene.canvas.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let longestEdge = max(canvasSize.width, canvasSize.height)
        guard longestEdge > 0 else { return nil }
        let scale = longEdge / longestEdge
        return renderFullCanvas(scene, scale: scale, quality: .exportQuality)
    }

    /// The canonical bitmap-context constructor every MKRender pixel
    /// consumer uses. Returns a RAW (CoreGraphics-native bottom-left-
    /// origin, y-up) 8-bit-per-component premultiplied-alpha sRGB context
    /// ، the "flipped" in this name describes the guarantee of the WHOLE
    /// pipeline (this helper feeding `MKSceneRenderer.render`, which
    /// applies the canvas→device flip itself via `canvasToDevice`, see
    /// `SceneRenderer.swift`), not a pre-applied transform on the context
    /// object itself: `render` assumes an UNTOUCHED context exactly like
    /// the one this returns, and does the entire orientation/scale/offset
    /// setup in one auditable closed-form transform. `contentsScale` is
    /// folded into `width`/`height` by the caller (pass already-scaled
    /// pixel dimensions); the `scale` parameter here exists only so
    /// callers that think in "points × scale" can pass both without doing
    /// the multiplication themselves.
    public static func makeFlippedBitmapContext(width: Int, height: Int, scale: CGFloat) -> CGContext? {
        let pixelWidth = Int((CGFloat(width) * scale).rounded(.up))
        let pixelHeight = Int((CGFloat(height) * scale).rounded(.up))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
