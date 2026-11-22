import CoreText
import Foundation
import MKFoundation

/// T5 ، drives `MKFontRegistry.loadBundled()` at app bootstrap, off the
/// main actor, before the project browser renders font previews (per the
/// packet: "before the project browser renders font previews"). A thin
/// wrapper so the app composition root (WS-13) has one obvious call site.
public struct MKFontRegistrar: Sendable {
    private let registry: MKFontRegistry

    public init(registry: MKFontRegistry) {
        self.registry = registry
    }

    @discardableResult
    public func registerBundledFontsAtLaunch() async -> [MKFontID] {
        let signposter = MKSignpost.signposter
        let interval = signposter.beginInterval("fontsBundledRegistration")
        defer { signposter.endInterval("fontsBundledRegistration", interval) }
        do {
            return try await registry.loadBundled()
        } catch {
            MKLog.logger(for: "MKFonts").error("Bundled font registration failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}

/// T1/§17.2 ، the `MKFontProviding` conformer that replaces
/// `SystemFontStubProvider` everywhere WS-03/WS-07 default-inject it
/// (`MKGlyphPathProvider`, `MKFormResolver`, `MKShapingEngine`,
/// `ShapingService`, `MKSceneRenderer`, `MKSnapshotRenderer` ، see
/// `MakhtootKit/CONTRACTS.md`). `resolve(_:)` must be synchronous
/// (protocol requirement), so this cannot itself be actor-isolated state ،
/// it relies on `CTFontManagerRegisterFontURLs(.process)` having already
/// made every registered PostScript name resolvable process-wide via plain
/// `CTFontCreateWithName`, which is exactly the D-122 registration
/// contract. Falls back to `SystemFontStubProvider` (same round-trip-
/// verified resolution WS-07 shipped) for any name not yet registered, so
/// the "always return a usable font" invariant holds even mid-boot, before
/// `MKFontRegistrar` finishes.
public struct MKRegistryFontProvider: MKFontProviding {
    private let fallback = SystemFontStubProvider()

    public init() {}

    public func resolve(_ handle: MKFontHandle) -> CTFont {
        let byName = CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        if (CTFontCopyPostScriptName(byName) as String) == handle.postScriptName {
            return byName
        }
        return fallback.resolve(handle)
    }

    // MARK: - Phase A: real bold/italic variant resolution
    //
    // "Genuine cut or nothing" ، never synthesize (synthetic emboldening
    // degrades Arabic letter joins). Two real mechanisms, tried per trait:
    //   1. A static family member with the symbolic trait
    //      (`CTFontCreateCopyWithSymbolicTraits`), which itself returns
    //      `nil` when no such member exists ، that IS the "or nothing"
    //      signal, so `nil` here falls through untouched.
    //   2. A variable-font axis the font actually reports
    //      (`wght` for bold, `slnt` for italic ، e.g. Cairo/CairoPlay),
    //      a genuine designer-drawn interpolation, not synthesis. Only
    //      applied when the font's own `CTFontCopyVariationAxes()` lists
    //      the axis; `MKFontFace.isVariable` records that a face is
    //      variable but not which axes it exposes, so this queries the
    //      live `CTFont` rather than trusting the catalog flag alone.
    // This runs lazily at resolve time (not at registry load time), so it
    // does not touch `MKFontRegistryTests.registrationUnder150Milliseconds
    // For15Families`'s load-time perf budget.
    public func resolve(_ handle: MKFontHandle, variant: MKFontVariantRequest) -> CTFont {
        var current = resolve(handle)
        if variant.bold {
            current = Self.applyingTrait(.traitBold, axisTag: Self.wghtAxisTag, preferredAxisValue: 700, to: current)
        }
        if variant.italic {
            current = Self.applyingTrait(.traitItalic, axisTag: Self.slntAxisTag, preferredAxisValue: -10, to: current)
        }
        return current
    }

    /// Tries the static symbolic-trait cut first, then the variable-axis
    /// fallback; returns `font` unchanged if neither mechanism finds a
    /// genuine realization of `trait`.
    private static func applyingTrait(
        _ trait: CTFontSymbolicTraits, axisTag: Int, preferredAxisValue: CGFloat, to font: CTFont
    ) -> CTFont {
        // Size 0 preserves the original point size (documented
        // `CTFontCreateCopyWithAttributes`/`CTFontCreateCopyWithSymbolicTraits`
        // convention, already relied on by `MKFontFeatureControl.font(_:
        // applying:)`).
        if let styled = CTFontCreateCopyWithSymbolicTraits(font, 0, nil, trait, trait) {
            return styled
        }
        return applyVariationAxis(tag: axisTag, preferredValue: preferredAxisValue, to: font) ?? font
    }

    /// Applies `preferredValue` (clamped to the axis's own reported
    /// min/max) on the variation axis identified by `tag`, but only when
    /// `font` actually exposes that axis. Mirrors the descriptor-copy
    /// idiom `MKFontFeatureControl.font(_:applying:)` uses for OpenType
    /// feature settings (`FontFeatureControl.swift:55-61`):
    /// `CTFontDescriptorCreateWithAttributes` + `CTFontCreateCopyWithAttributes`.
    private static func applyVariationAxis(tag: Int, preferredValue: CGFloat, to font: CTFont) -> CTFont? {
        // Read back as `[String: Any]` (not `[CFString: Any]`) ، the
        // dictionaries `CTFontCopyVariationAxes` hands back are NSDictionary
        // under the hood with NSString keys, which bridges reliably to
        // Swift `String`; the `kCTFontVariationAxis*Key` CFString constants
        // are used here only as `as String` lookup keys, mirroring the
        // common CoreText-in-Swift idiom for reading (as opposed to
        // constructing, where `[CFString: Any]` is what
        // `MKFontFeatureControl.font(_:applying:)` already uses).
        guard let axes = CTFontCopyVariationAxes(font) as? [[String: Any]] else { return nil }
        let identifierKey = kCTFontVariationAxisIdentifierKey as String
        let minimumKey = kCTFontVariationAxisMinimumValueKey as String
        let maximumKey = kCTFontVariationAxisMaximumValueKey as String
        guard let axis = axes.first(where: { ($0[identifierKey] as? NSNumber)?.intValue == tag }) else {
            return nil
        }

        var value = preferredValue
        if let minValue = (axis[minimumKey] as? NSNumber)?.doubleValue {
            value = max(value, CGFloat(minValue))
        }
        if let maxValue = (axis[maximumKey] as? NSNumber)?.doubleValue {
            value = min(value, CGFloat(maxValue))
        }

        let variation: [NSNumber: NSNumber] = [NSNumber(value: tag): NSNumber(value: Double(value))]
        let attributes: [CFString: Any] = [kCTFontVariationAttribute: variation]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateCopyWithAttributes(font, 0, nil, descriptor)
    }

    /// `wght` axis tag: the OpenType `fvar` four-character code packed
    /// big-endian into a 32-bit integer (`'w' 'g' 'h' 't'` →
    /// `0x77676874`), the standard identifier `CTFontCopyVariationAxes`/
    /// `kCTFontVariationAxisIdentifierKey` and
    /// `CTFontDescriptorCreateCopyWithVariation` use for this axis.
    private static let wghtAxisTag = 0x77676874
    /// `slnt` axis tag, same packing (`'s' 'l' 'n' 't'` → `0x736C6E74`).
    private static let slntAxisTag = 0x736C6E74
}
