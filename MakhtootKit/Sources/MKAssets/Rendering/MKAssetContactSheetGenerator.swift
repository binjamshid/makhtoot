import CoreGraphics
import Foundation
import ImageIO
import MKModel
import UniformTypeIdentifiers

// WS-14 packet §5 task 11. Visual QA contact-sheet generator ، debug/QA
// tooling (not shipped app UI; consumed by `Tests/MKAssetsTests/
// MKAssetContactSheetTests.swift` to produce the T-asset-01 evidence
// images checked into `docs/impl-log/WS-14-contact-sheets/`). Not gated
// behind `#if DEBUG` (unlike the app-target `PerfHUDView` WS-07 flagged as
// out-of-fence) because this type has no app-target home to live in at
// all ، it is pure `MKAssets` QA tooling, always compiled, simply never
// wired into any shipped UI.
public enum MKAssetContactSheetGenerator {
    /// Lays out every asset in `descriptors` as a `cellSize`-pt thumbnail
    /// grid (task 11: "all assets at 256 px + 1024 px") with its Arabic
    /// name label directly under it is OUT of scope here (text rendering
    /// would pull in Core Text layout complexity this internal rasterizer
    /// deliberately avoids, task 10's own framing) ، grid position order
    /// alone (stable: `MKAssetCategory.browserOrder`, then declaration
    /// order within category) is what a reviewer cross-references against
    /// `descriptors` when reading the sheet, matching how
    /// `MKAssetContactSheetTests` documents the review protocol.
    public static func generate(descriptors: [MKAssetDescriptor], cellSize: CGFloat, columns: Int = 8, library: MKAssetLibrary = .standard) -> CGImage? {
        guard !descriptors.isEmpty else { return nil }
        let rows = Int(ceil(Double(descriptors.count) / Double(columns)))
        let sheetWidth = CGFloat(columns) * cellSize
        let sheetHeight = CGFloat(rows) * cellSize
        guard let ctx = CGContext(
            data: nil, width: Int(sheetWidth), height: Int(sheetHeight), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Paper-neutral backdrop so holes/negative space in a motif are
        // visible against something other than a hard-edged transparent
        // checkerboard when a reviewer opens the PNG directly.
        ctx.setFillColor(CGColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))

        for (index, descriptor) in descriptors.enumerated() {
            let row = index / columns
            let col = index % columns
            // This context has NO top-left flip applied (unlike
            // `MKAssetThumbnailRenderer.makeContext`) ، it uses CG's
            // default bottom-left-origin, y-up space directly. Placing
            // row 0 at `y = row * cellSize` would put the FIRST asset at
            // the BOTTOM of the displayed image and the LAST at the TOP ،
            // exactly backwards for a reviewer reading top-to-bottom in
            // `descriptors` order. (Caught by inspecting an actual
            // generated sheet: the single-item last row appeared at the
            // top.) `sheetHeight - (row + 1) * cellSize` puts row 0 at the
            // highest y (= visual top) instead.
            let cellOrigin = CGPoint(x: CGFloat(col) * cellSize, y: sheetHeight - CGFloat(row + 1) * cellSize)
            guard let thumbnail = MKAssetThumbnailRenderer.render(descriptor: descriptor, size: CGSize(width: cellSize * 0.86, height: cellSize * 0.86), library: library) else { continue }
            let inset = cellSize * 0.07
            // **No manual per-cell flip** (a first-draft `translateBy(0,
            // cellSize)` + `scaleBy(1,-1)` here was itself the bug ، see
            // `docs/impl-log/WS-14.md`'s "real bugs found" list). Verified
            // empirically (not assumed): `CGContext.draw(_:in:)` already
            // orients a `CGImage` correctly with NO extra transform needed
            // when drawing into a context at these coordinates ، adding a
            // "counter-flip" on the (mistaken) assumption that `draw(_:in:)`
            // always renders upside-down actually FLIPPED an
            // already-correctly-oriented thumbnail, so every asset with a
            // vertical asymmetry (e.g. the pointed-arch frame/ornament)
            // rendered upside down in the CONTACT SHEET ONLY ، the real
            // rendering pipeline (`MKAssetThumbnailRenderer.render` on its
            // own, and by extension the actual `MKRender` canvas path) was
            // never affected.
            ctx.draw(thumbnail, in: CGRect(x: cellOrigin.x + inset, y: cellOrigin.y + inset, width: cellSize * 0.86, height: cellSize * 0.86))
        }
        return ctx.makeImage()
    }

    /// The two sizes task 11 names explicitly: 256pt (compact overview) and
    /// 1024pt (detail-review) cell sizes, one sheet each, for `descriptors`.
    public static func generateStandardPair(descriptors: [MKAssetDescriptor], library: MKAssetLibrary = .standard) -> (small: CGImage?, large: CGImage?) {
        (generate(descriptors: descriptors, cellSize: 256, library: library), generate(descriptors: descriptors, cellSize: 1024, columns: 4, library: library))
    }

    /// Writes `image` as a PNG to `url` ، the mechanism
    /// `MKAssetContactSheetTests` uses to save reviewed sheets as evidence
    /// (packet §8 deliverable: "visual QA contact-sheet generator +
    /// reviewed sheets").
    @discardableResult
    public static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}
