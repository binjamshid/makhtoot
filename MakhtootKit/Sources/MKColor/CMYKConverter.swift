import CoreGraphics
import Foundation

// P10-COMPLETION (Run-3, packet §5 task 3). "sRGB → CMYK via
// CGColor.converted(to:intent:.relativeColorimetric, options:); batch
// conversion for the scene palette." D-226 tightens D-117's execution:
// relative colorimetric is EXPLICIT at every call site (never a Core
// Graphics default), and this is one of the two documented, intent-matched
// conversion sites (the "vector per-color" site) ، §15.3/D-226(1).
//
// **Cross-fence limitation, recorded honestly (not silently worked
// around)**: this converter is invoked directly wherever `MKExport` owns
// the color-setting call (the CMYK PDF writer's own drawing code ، see
// `PDFPrintCMYKExporter.swift`). It is NOT wired into `MKRender`'s
// drawers (`ShapeDrawer`/`LiveTextDrawer`/`ArrangedDrawer`/`PathTextDrawer`
// all call `ctx.setFillColor(color.cgColor)` with MKModel's own sRGB
// `CGColor` factory, and `MKRender` is outside this packet's fence) ، see
// `docs/impl-log/WS-08.md`'s "Spike C" write-up for the empirical
// confirmation that a CMYK-space `CGContext`/PDF context does NOT
// auto-convert an sRGB `CGColor` handed to `setFillColor` into its own
// native space (CoreGraphics tags the fill operator with the CGColor's
// OWN embedded colorspace resource instead, verified by inspecting the
// produced PDF's raw content stream). `CMYKConverter` therefore remains
// exactly what task 3 asks for ، a correct, ground-truth-verified sRGB→CMYK
// conversion utility ، and this session's CMYK PDF writer uses it at the
// one color-setting site it DOES own (the whole-page raster embed's pixel
// conversion), not per-vector-element (which would require editing
// `MKRender`).
public enum CMYKConverter {
    /// The one call every whole-image / per-swatch CMYK conversion in this
    /// module goes through ، relative colorimetric, EXPLICIT (D-226(1)),
    /// matching `ctx.setRenderingIntent(.relativeColorimetric)`'s own
    /// explicitness requirement on the raster whole-image path
    /// (`PDFPrintCMYKExporter.swift`).
    public static let intent: CGColorRenderingIntent = .relativeColorimetric

    /// Converts one `MKColorSpec` (extended sRGB) to CMYK components
    /// `[C, M, Y, K]` (each `0...1`) against `profile`. Returns `nil` only
    /// if CoreGraphics itself fails the conversion (not expected for any
    /// well-formed sRGB source + CMYK-model destination ، `CMYKConverterTests`
    /// asserts this never happens for the fixture corpus).
    public static func cmyk(from color: MKColorSpec, profile: MKICCProfile) -> [CGFloat]? {
        let src = color.cgColor()
        guard let dst = src.converted(to: profile.colorSpace, intent: intent, options: nil),
              let components = dst.components, components.count >= 4
        else { return nil }
        return Array(components.prefix(4))
    }

    /// Batch conversion for the scene palette (task 3: "batch conversion
    /// for the scene palette") ، de-duplicates identical colors so a scene
    /// with many nodes sharing one fill color converts it once.
    public static func cmykPalette(_ colors: [MKColorSpec], profile: MKICCProfile) -> [MKColorSpec: [CGFloat]] {
        var result: [MKColorSpec: [CGFloat]] = [:]
        for color in colors where result[color] == nil {
            result[color] = cmyk(from: color, profile: profile)
        }
        return result
    }

    /// The `.perceptual`-intent conversion of the SAME color/profile pair ،
    /// exists only so `MKColorTests`' intent-divergence fixtures can
    /// compare it against `cmyk(from:profile:)` (D-226(3)/(5): "a new
    /// intent unit test converts a boundary color under `.perceptual` vs
    /// `.relativeColorimetric` and asserts divergence"). Never used by any
    /// production export path ، v1's pipeline is `.relativeColorimetric`
    /// only, per D-117.
    public static func cmykPerceptual(from color: MKColorSpec, profile: MKICCProfile) -> [CGFloat]? {
        let src = color.cgColor()
        guard let dst = src.converted(to: profile.colorSpace, intent: .perceptual, options: nil),
              let components = dst.components, components.count >= 4
        else { return nil }
        return Array(components.prefix(4))
    }

    /// Converts a whole `CGImage` (the raster-asset / whole-page path,
    /// §15.3(b)/D-226(5)) into a CMYK bitmap. Per Spike A
    /// (`docs/impl-log/WS-08.md`): a CMYK `CGBitmapContext` supports ONLY
    /// `CGImageAlphaInfo.none` ، so this function has NO alpha channel in
    /// its output; callers that need opacity/transparency compositing MUST
    /// do it in an RGBA context BEFORE calling this (matching the packet's
    /// own "composite opacity in RGBA first" instruction). Sets
    /// `ctx.setRenderingIntent(.relativeColorimetric)` EXPLICITLY before
    /// the redraw (D-226(1)) so this whole-image conversion is
    /// intent-matched to `cmyk(from:profile:)`'s own explicit intent.
    public static func convertWholeImage(_ image: CGImage, profile: MKICCProfile) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: profile.colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ctx.setRenderingIntent(intent)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}

extension MKColorSpec {
    /// `Hashable`/`Equatable` already conform (see `MKColorSpec.swift`) ،
    /// this is just documentation that `cmykPalette`'s dictionary key usage
    /// is safe: two `MKColorSpec` values compare equal iff every stored
    /// component (`r,g,b,a,swatch`) is equal, so de-duplication never
    /// merges visually-identical-but-differently-encoded colors
    /// incorrectly (there is no alternate encoding in this type).
}
