import CoreGraphics
import Foundation

// WS-08 packet §5 task 1 (AGENT_TASK_PACKETS/WS-08-export-pipeline.md,
// P10-EARLY slice, Run-3). `MKColorSpec` ، the `MKColor` *module's* own
// sRGB component-storage/conversion type. D-117: "working space = extended
// sRGB; UI picks/display in P3-aware SwiftUI/UIKit colors; document stores
// sRGB components". This mirrors `MKModel.MKSolidColor`'s field shape
// exactly (r/g/b/a Doubles, extended range ، components MAY exceed `0...1`
// from a P3-aware picker, preserved verbatim per D-117) but lives in this
// module because `MKColor` owns *conversion* (display CGColor, and later
// CMYK) ، `MKModel` deliberately owns no CoreGraphics-conversion code
// (MKNodeStyle.swift's own header: "MKModel imports no CoreGraphics beyond
// value types"), so a value from a scene's `MKSolidColor` is bridged into
// an `MKColorSpec` at the export/render boundary ، `MKExport` (which
// depends on both `MKModel` and `MKColor`) owns that one-line bridge
// (`MKColorSpec(r:g:b:a:swatch:)` from `MKSolidColor`'s same-named
// fields), not this module (which must not depend on `MKModel`).
//
// **P10-EARLY scope note** (docs/impl-log/WS-08.md has the full
// breakdown): this file is the WHOLE of the "MKColor pipeline" slice this
// session ships. `ICCProfileStore`/`CMYKConverter`/`PDFOutputIntent`
// (packet tasks 2/3/12) are explicitly OUT of this slice ، CMYK conversion
// itself is deferred to P10-completion ، but the two D-226
// VERIFY-AT-IMPLEMENTATION spikes that gate task 12 were run NOW per this
// session's instructions (empirical CoreGraphics probes on the iOS
// simulator, not assumed) and are written up in `docs/impl-log/WS-08.md`
// plus regression-locked in `Tests/MKColorTests/CMYKSpikeEvidenceTests.swift`
// so their findings survive independent of the prose.

/// Color working space tag ، same vocabulary as `MKModel.MKColorSpace`
/// (kept as a SEPARATE type: `MKModel` must not import `MKColor`, and
/// `MKColor` must not import `MKModel` for a single enum ، DEPENDENCY_GRAPH
/// draws no edge between the two `MKColor`-adjacent targets in either
/// direction). Only `.srgb` is a real value in v1; `.displayP3` exists so
/// `cgColor(in:)` below has a typed destination for the DISPLAY-ONLY P3
/// path (D-117: "P3 is display-only, never stored").
public enum MKColorSpaceTag: String, Hashable, Sendable, Codable {
    case srgb
    case displayP3
}

/// The document/working-space color value: extended sRGB components (may
/// exceed `0...1`, D-117), plus an optional named-swatch reference ، field
/// shape matches `MKModel.MKSolidColor` deliberately (task 1 accept:
/// "round-trip tests"; a lossless bridge in both directions is the whole
/// point of keeping the two types' fields identical).
public struct MKColorSpec: Hashable, Sendable, Codable, Equatable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double
    public var swatch: String?

    public init(r: Double, g: Double, b: Double, a: Double = 1, swatch: String? = nil) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
        self.swatch = swatch
    }

    public static let black = MKColorSpec(r: 0, g: 0, b: 0)
    public static let white = MKColorSpec(r: 1, g: 1, b: 1)
    public static let clear = MKColorSpec(r: 0, g: 0, b: 0, a: 0)

    // MARK: - CGColor conversions (D-117 §15.1)

    /// The canonical DISPLAY/EXPORT-sRGB path: every JPEG/PNG/SVG/RGB-PDF
    /// pixel in the pipeline is produced from this conversion (§15.4's
    /// "clamp extended → sRGB at encode" row ، the clamp happens here, at
    /// the extended-sRGB → sRGB `CGColor` boundary, not earlier, so
    /// document values stay unclamped/extended until the moment a
    /// concrete output format needs a finite `0...1` component).
    public func cgColor() -> CGColor {
        let space = CGColorSpace(name: CGColorSpace.extendedSRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGColor(colorSpace: space, components: [r, g, b, a]) ?? CGColor(srgbRed: clampedUnit(r), green: clampedUnit(g), blue: clampedUnit(b), alpha: clampedUnit(a))
    }

    /// The DISPLAY-ONLY P3 path (D-117: "P3 is display-only, never
    /// stored" ، this method exists purely so SwiftUI/UIKit call sites that
    /// want a P3-space `CGColor` for on-screen rendering have one; no
    /// persisted document state, no export pipeline, ever calls this).
    public func cgColorDisplayP3() -> CGColor {
        let space = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        return CGColor(colorSpace: space, components: [r, g, b, a]) ?? cgColor()
    }

    /// A finite `0...1`-clamped sRGB `CGColor` ، the form every raster
    /// encoder (`RasterEncoders.swift`) actually paints into a
    /// `CGBitmapContext` with, since `CGContext.setFillColor` on an
    /// 8-bit-per-component DeviceRGB/sRGB context expects components in
    /// range (extended values silently clamp inside CoreGraphics anyway,
    /// but doing it explicitly here keeps the clamp point auditable in one
    /// place, matching the file-header note above).
    public func cgColorClampedSRGB() -> CGColor {
        CGColor(srgbRed: clampedUnit(r), green: clampedUnit(g), blue: clampedUnit(b), alpha: clampedUnit(a))
    }

    private func clampedUnit(_ v: Double) -> CGFloat {
        CGFloat(min(1, max(0, v)))
    }
}
