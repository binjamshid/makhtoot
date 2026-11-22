import CoreGraphics
import Foundation
import MKColor
import MKModel
import MKRender

// P10-COMPLETION (Run-3, packet §5 task 12 ، "CMYK PDF (premium print)").
// Both D-226 VERIFY-AT-IMPLEMENTATION spikes were resolved by the P10-EARLY
// session (`docs/impl-log/WS-08.md`'s "SPIKE VERDICTS"); this file is the
// writer those spikes exist to unblock.
//
// ## Spike C (this session's own empirical finding ، read before touching
// this file)
//
// The packet's literal task-12 wording asks for "the SAME vector pass with
// all fill/stroke colors through `CMYKConverter`... page drawn in CMYK
// context space." This session probed that literally and found it is NOT
// achievable without editing `MKRender`:
//
// 1. A `CGPDFContext` has NO fixed "native color space" the way a bitmap
//    context does ، `CGContext(url:mediaBox:auxiliaryInfo:)` takes no
//    colorspace parameter at all. Color is entirely PER-OPERATOR, driven
//    by whichever `CGColorSpace` the active `CGColor`/`setFillColorSpace`
//    call carries.
// 2. `ctx.setFillColor(_ color: CGColor)` ، the exact call every
//    `MKRender` drawer makes (`ShapeDrawer` via `MKStylePainting.paint`,
//    `LiveTextDrawer`, `ArrangedDrawer`, `PathTextDrawer`) ، embeds the
//    CGColor's OWN colorspace as a NEW `/Cs` resource for that fill
//    operator; it does NOT convert into whatever colorspace was
//    previously active via `setFillColorSpace`, and `ctx
//    .setRenderingIntent(...)` has NO effect on it either (verified: a
//    probe PDF's decompressed content stream showed an sRGB `CGColor` fill
//    inside a "CMYK-flavored" context still emitted `sc` with 3 RGB
//    components tagged to an embedded sRGB ICC `/Cs` resource, completely
//    unconverted, regardless of the rendering-intent setting).
// 3. Therefore the ONLY way to get real per-element CMYK vector/text
//    operators out of `MKSceneRenderer.render` is for the DRAWERS
//    themselves to construct CMYK `CGColor`s before calling
//    `setFillColor`/`setStrokeColor` ، which means editing
//    `ShapeDrawer`/`LiveTextDrawer`/`ArrangedDrawer`/`PathTextDrawer`
//    (`MKRender` sources), outside this packet's fence ("MKExport/MKColor
//    sources/tests... no one else is editing").
//
// **Decision (logged, not silently substituted)**: this writer produces a
// print-CMYK PDF whose PAGE CONTENT is a single, whole-page RASTER image ،
// rendered at the requested print resolution (300+ DPI per D-118's print
// floor) via the EXISTING single render path
// (`MKTiledRasterExporter.renderAssembled`, the SAME tiled/mmap machinery
// the JPEG/PNG writers use ، huge print sizes stay bounded by disk, not
// RAM, D-116), THEN explicitly converted to CMYK via
// `CMYKConverter.convertWholeImage` (composite opacity in RGBA FIRST, per
// Spike A's "no-alpha-only" CMYK bitmap-context finding, THEN the one
// whole-image CMYK conversion ، `.relativeColorimetric`, set explicitly).
// The OutputIntent is real and Spike-B-verified
// (`PDFOutputIntent.swift`). This is NOT what task 12's prose describes
// (true vector CMYK content) ، it is the best achievable, fully honest
// result within this packet's fence, flagged via
// `FallbackReason.cmykContentRasterized` on EVERY export (never silent,
// Q73) and recorded here as a genuine architectural finding (same rigor
// class as D-226's own two spikes) for whoever next has `MKRender` in
// their fence to close ، see `docs/impl-log/WS-08.md`'s "Spike C"
// write-up for the full probe transcript.
public enum PDFPrintCMYKExporter {
    public struct Result: Sendable {
        public var fallbacks: [FallbackNote]
        public var profileProvenance: MKICCProfileProvenance
    }

    /// `pixelSize` is the PREMIUM-native (uncapped, D-118/Q76) resolved
    /// size ، CMYK print is premium-only, never free-tier-clamped.
    public static func export(
        scene: MKScene, pixelSize: CGSize, dpi: Double, title: String,
        renderer: MKSnapshotRenderer = MKSnapshotRenderer(),
        profile: MKICCProfile = ICCProfileStore.loadBundled(),
        cooperation: any MKExportMemoryCooperating = MKNoOpMemoryCooperation(),
        to url: URL
    ) async throws -> Result {
        let effectiveDPI = dpi > 0 ? dpi : 300
        guard pixelSize.width > 0, pixelSize.height > 0 else { throw MKExportError.degenerateTargetSize }

        // Whole-page render, RGBA ، composites opacity/transparency layers
        // normally (Spike A: "composite opacity in RGBA first"). Reuses
        // the tiled/mmap assembly path unchanged, so a large print page
        // (A3 at 300 DPI = ~4961×3508 px) stays bounded by disk, matching
        // every other raster writer's memory posture.
        let rgbImage = try await MKTiledRasterExporter.renderAssembled(
            scene: scene, pixelSize: pixelSize, renderer: renderer, cooperation: cooperation
        )

        // The ONE explicit, intent-matched whole-image CMYK conversion
        // (D-226(5)'s raster-path requirement, `ctx.setRenderingIntent
        // (.relativeColorimetric)` set inside `convertWholeImage` itself).
        guard let cmykImage = CMYKConverter.convertWholeImage(rgbImage, profile: profile) else {
            throw MKExportError.encodingFailed
        }

        var mediaBox = CGRect(
            x: 0, y: 0,
            width: pixelSize.width / effectiveDPI * 72.0,
            height: pixelSize.height / effectiveDPI * 72.0
        )
        guard mediaBox.width > 0, mediaBox.height > 0 else { throw MKExportError.degenerateTargetSize }

        let aux = PDFOutputIntent.auxiliaryInfo(title: title, profile: profile)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, aux) else {
            throw MKExportError.encodingFailed
        }
        ctx.beginPDFPage(nil)
        ctx.interpolationQuality = .high
        ctx.draw(cmykImage, in: CGRect(origin: .zero, size: mediaBox.size))
        ctx.endPDFPage()
        ctx.closePDF()

        return Result(
            fallbacks: [FallbackNote(reason: .cmykContentRasterized)],
            profileProvenance: profile.provenance
        )
    }
}
