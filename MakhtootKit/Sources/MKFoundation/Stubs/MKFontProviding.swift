import CoreText
import Foundation

/// A stable font pointer good enough to resolve a concrete `CTFont`: a
/// PostScript name plus point size. WS-09's `MKFonts` catalog produces the
/// real `FontReference` (`MKModel/FontReference.swift`) that carries this
/// plus catalog metadata; this minimal struct is the WS-01 seam so
/// `MKTextEngine`/`MKRender` fixture work (P3) can resolve *a* font before
/// the catalog exists.
public struct MKFontHandle: Hashable, Sendable {
    public let postScriptName: String
    public let pointSize: CGFloat

    public init(postScriptName: String, pointSize: CGFloat) {
        self.postScriptName = postScriptName
        self.pointSize = pointSize
    }
}

/// A bold/italic request against a resolved font handle (Phase A: real
/// font-variant resolution). Carries no weight/style granularity beyond the
/// two `MKTextStyle` trait flags it mirrors (`isBold`/`isItalic`) ، the
/// resolver decides, per family, whether a genuine cut or axis exists to
/// satisfy the request. **Never synthesized**: a conformer that cannot
/// satisfy a request must return the base font unchanged rather than
/// fake-embolden/oblique it (synthetic emboldening degrades Arabic letter
/// joins).
public struct MKFontVariantRequest: Hashable, Sendable {
    public var bold: Bool
    public var italic: Bool

    public init(bold: Bool, italic: Bool) {
        self.bold = bold
        self.italic = italic
    }
}

/// Resolves a font handle to a concrete `CTFont`. WS-01 ships this protocol
/// plus `SystemFontStubProvider` (always system SF Arabic) so text-engine
/// and render work can begin before WS-09's real font registry/catalog
/// exists. WS-09 replaces the internals ، see `MakhtootKit/CONTRACTS.md`.
public protocol MKFontProviding: Sendable {
    /// Resolves `handle` to a `CTFont`. Conformers must always return a
    /// usable font (falling back to the system font) rather than `nil` ،
    /// callers should not need to handle a missing-font case at the
    /// protocol boundary; WS-09's real implementation surfaces
    /// unavailable/expired-font states through its own richer API.
    func resolve(_ handle: MKFontHandle) -> CTFont

    /// Resolves `handle` to a `CTFont`, additionally attempting to satisfy
    /// `variant` (bold/italic) with a genuine font-family cut or variable
    /// axis. Conformers that have no such notion (test fixtures,
    /// `SystemFontStubProvider`) can rely on the protocol-extension default
    /// below, which simply ignores `variant` and forwards to
    /// `resolve(_:)` ، so this requirement never ripples out to conformers
    /// that don't care about it.
    func resolve(_ handle: MKFontHandle, variant: MKFontVariantRequest) -> CTFont
}

extension MKFontProviding {
    /// Default: ignore `variant` entirely and resolve as before. Real
    /// variant resolution is `MKRegistryFontProvider`'s job (`MKFonts`);
    /// every other conformer (fixtures, `SystemFontStubProvider`) is
    /// content with the plain, non-variant behavior.
    public func resolve(_ handle: MKFontHandle, variant: MKFontVariantRequest) -> CTFont {
        resolve(handle)
    }
}

/// Resolves the requested `postScriptName` when possible, with an
/// Arabic-capable system-font fallback. This is the WS-01 stub every
/// non-font workstream can build against; WS-09 ships the real
/// `MKFonts.FontRegistry` (bundled catalog + user imports) conforming to
/// the same `MKFontProviding` protocol.
///
/// **Fixed by WS-07 (P4-exit blocker; WS-13 Session 3 Bug 1,
/// `docs/impl-log/WS-13.md`).** The original implementation IGNORED
/// `handle.postScriptName` and always returned
/// `CTFontCreateUIFontForLanguage(.system, size, "ar")`. That broke the
/// shaping↔drawing font-consistency invariant `MKRender` depends on:
/// shaping an Arabic string through that UI font makes Core Text cascade
/// each Arabic run to the SF Arabic member (`.SFArabic-Regular`), and
/// `MKTextEngine` captures THAT font's PostScript name + glyph IDs into
/// the run ، but at draw time, `LiveTextDrawer` resolves the run's
/// captured name back through this provider, which returned the plain
/// system UI font (`.SFNS-Regular`) again, so SF-Arabic glyph IDs were
/// drawn through SF-UI's glyph table → garbled Arabic (WS-13's exact
/// simulator symptom; Latin was unaffected because its glyph IDs were
/// captured from the UI font itself). Verified empirically in the WS-07
/// fix session: run font `.SFArabic-Regular` glyphs `[9, 1244, …]` vs
/// draw-time `.SFNS-Regular` on the macOS host toolchain.
///
/// The fix must NOT naively call `CTFontCreateWithName(dotPrefixedName)`:
/// CoreText refuses dot-prefixed system-font name requests on some
/// runtimes and silently substitutes TimesNewRomanPSMT (observed on the
/// macOS 26 host: ".SFArabic"/".SFArabic-Regular" both → Times, with a
/// "Client requested name … will get TimesNewRomanPSMT" console note ،
/// which also means WS-13's app-side `CTFontCreateWithName(".SFArabic")`
/// workaround is runtime-fragile, working on the iOS 26.5 simulator only
/// because that runtime happens to allow the request). Resolution order
/// here, each step verified by PostScript-name round-trip so a silent
/// substitution can never leak through:
/// 1. By-name (real installed fonts, and runtimes that allow dot names).
/// 2. The language-tagged system UI font itself, when IT is what was
///    requested (Latin runs cascade back to it).
/// 3. The Arabic cascade member resolved via the proper API for exactly
///    this job: `CTFontCreateForStringWithLanguage(seed, "م", "ar")` ،
///    returns the same font object/glyph table Core Text picks during
///    shaping (verified: identical glyph bounding boxes), without ever
///    requesting a dot-prefixed name directly.
/// Unknown/unresolvable names land on step 3's Arabic-capable member ،
/// the right default for an Arabic-first app's pre-WS-09 stub.
public struct SystemFontStubProvider: MKFontProviding {
    public init() {}

    public func resolve(_ handle: MKFontHandle) -> CTFont {
        // Step 1: honest by-name resolution, verified by round-trip.
        let byName = CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        if (CTFontCopyPostScriptName(byName) as String) == handle.postScriptName {
            return byName
        }

        // Step 2: the language-tagged system UI font (SF Arabic cascade
        // seed). If the caller asked for THIS font by its real name
        // (e.g. a Latin run's resolved ".SFNS-Regular"), return it.
        let seed = CTFontCreateUIFontForLanguage(.system, handle.pointSize, "ar" as CFString)
            ?? CTFontCreateWithName("Helvetica" as CFString, handle.pointSize, nil)
        if (CTFontCopyPostScriptName(seed) as String) == handle.postScriptName {
            return seed
        }

        // Step 3: the Arabic cascade member, resolved the supported way.
        // Shaping through this font captures runs carrying ITS PostScript
        // name, and a draw-time resolve of that name lands back here on
        // the same font ، restoring the consistency invariant end to end.
        let sample = "\u{0645}" as CFString   // م
        return CTFontCreateForStringWithLanguage(seed, sample, CFRange(location: 0, length: 1), "ar" as CFString)
    }
}
