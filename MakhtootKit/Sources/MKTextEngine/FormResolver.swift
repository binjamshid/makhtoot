import CoreText
import CoreGraphics
import Foundation
import MKFoundation
import MKModel

/// The result of a D-107 form harvest: the requested `MKJoiningForm` (or
/// the nearest valid form when the letter cannot realize the requested
/// one), the harvested glyph, its advance, and its outline.
public struct MKResolvedForm: Hashable, Sendable {
    /// The form actually realized.
    public var form: MKJoiningForm
    /// The form the caller asked for.
    public var requestedForm: MKJoiningForm
    /// `true` when `form != requestedForm` ، right-joining letters (د ذ ر
    /// ز و ا …) have no initial/medial, so those requests coerce to the
    /// nearest valid form (initial→isolated, medial→final) and WS-04's
    /// form selector uses this flag to disable invalid options.
    public var wasCoerced: Bool
    public var glyphID: UInt16
    public var advance: CGSize
    /// 1000/em-normalized outline (`MKGlyphPathProvider`); `nil` when the
    /// glyph has no outline.
    public var outline: MKPathData?

    public init(form: MKJoiningForm, requestedForm: MKJoiningForm, wasCoerced: Bool, glyphID: UInt16, advance: CGSize, outline: MKPathData?) {
        self.form = form
        self.requestedForm = requestedForm
        self.wasCoerced = wasCoerced
        self.glyphID = glyphID
        self.advance = advance
        self.outline = outline
    }
}

/// D-107 ZWJ joining-form resolver (WS-03 packet §5 task 11): "reshape the
/// single letter in a synthetic context using U+200D ZWJ (e.g., ZWJ+ح+ZWJ
/// for medial) through the same font, then harvest that glyph."
///
/// Synthetic contexts: isolated `L` · initial `L+ZWJ` · medial `ZWJ+L+ZWJ`
/// · final `ZWJ+L`. The harvest shapes with the same font/features but
/// **without** kerning/tracking (packet: "minus kerning/tracking" ، those
/// perturb the advance without changing the form), then picks the glyph
/// whose cluster contains the letter's string index (ZWJ-produced glyphs
/// map to the ZWJ indices and are ignored).
///
/// **Per-font caveat (documented, docs/impl-log/WS-03.md):** the system SF
/// font (`.SFNS`/SF Arabic via `CTFontCreateUIFontForLanguage`) does not
/// honor a *leading* ZWJ ، medial/final synthetic contexts come back in
/// initial/isolated form. Real Arabic fonts (Geeza Pro, Damascus ، and the
/// WS-09 fixture set Amiri/Noto Naskh) honor D-107 fully, harvested forms
/// matching natural-context glyph ids exactly. The resolver is
/// font-agnostic; per-font verification is the WS-09 fixture re-run's job
/// (DEPENDENCY_GRAPH stub S2 flip).
public actor MKFormResolver {
    private struct Key: Hashable {
        var postScriptName: String
        var pointSize: Double
        var scalar: UInt32
        var form: MKJoiningForm
        // Phase A: `postScriptName` here is the UNRESOLVED face
        // (`style.font.postScriptName`), but `MKShapingEngine.resolvedFont
        // (for:)` now resolves bold/italic to a genuinely different font
        // for the same `MKFontRef`. Without these, a regular and a bold
        // harvest of the same family would share a cache entry and hand
        // back each other's glyph IDs/outlines.
        var isBold: Bool
        var isItalic: Bool
    }

    private let engine: MKShapingEngine
    private let paths: MKGlyphPathProvider
    private var cache: [Key: MKResolvedForm] = [:]

    public init(fonts: MKFontProviding = SystemFontStubProvider()) {
        self.engine = MKShapingEngine(fonts: fonts)
        self.paths = MKGlyphPathProvider(fonts: fonts)
    }

    /// Resolves `form` for `letter` in `style`'s font. Returns `nil` when
    /// the letter produced no glyph at all (not a letter the font can
    /// shape). Cached per (font, size, scalar, form) ، packet task 11.
    public func resolve(letter: Unicode.Scalar, form requestedForm: MKJoiningForm, style: MKTextStyle) async -> MKResolvedForm? {
        // Coerce to the nearest valid form FIRST (right-joining letters
        // have no initial/medial; non-joining letters only isolated), so
        // the cache never stores an impossible-form entry.
        let validForms = MKJoiningTypeTable.validForms(for: letter)
        let effectiveForm: MKJoiningForm
        if validForms.contains(requestedForm) {
            effectiveForm = requestedForm
        } else {
            switch requestedForm {
            case .initial: effectiveForm = validForms.contains(.isolated) ? .isolated : requestedForm
            case .medial: effectiveForm = validForms.contains(.final) ? .final : .isolated
            case .final, .isolated: effectiveForm = .isolated
            }
        }
        let wasCoerced = effectiveForm != requestedForm

        let key = Key(
            postScriptName: style.font.postScriptName,
            pointSize: style.pointSize,
            scalar: letter.value,
            form: effectiveForm,
            isBold: style.isBold,
            isItalic: style.isItalic)
        if var hit = cache[key] {
            hit.requestedForm = requestedForm
            hit.wasCoerced = wasCoerced
            return hit
        }

        // Synthetic context (D-107).
        let zwj = "\u{200D}"
        let letterString = String(letter)
        let context: String
        let letterUTF16Index: Int
        switch effectiveForm {
        case .isolated:
            context = letterString
            letterUTF16Index = 0
        case .initial:
            context = letterString + zwj
            letterUTF16Index = 0
        case .medial:
            context = zwj + letterString + zwj
            letterUTF16Index = 1
        case .final:
            context = zwj + letterString
            letterUTF16Index = 1
        }

        // Same font/features, minus kerning/tracking (packet task 11).
        var harvestStyle = style
        harvestStyle.tracking = 0
        harvestStyle.kerningOverrides = []
        harvestStyle.baselineShift = 0

        let line = engine.shapeSingleLine(MKShapingRequest(string: context, style: harvestStyle))

        // The letter's glyph: the one whose cluster covers the letter's
        // UTF-16 index (ZWJ clusters map to the ZWJ indices ، ignored).
        // Within that cluster, prefer the glyph whose own string index IS
        // the letter's (guards against a font fusing a ZWJ glyph into the
        // letter's cluster); fall back to the cluster's first glyph.
        guard let clusterIndex = line.clusterMap.utf16ToCluster[letterUTF16Index] else { return nil }
        let cluster = line.clusterMap.clusters[clusterIndex]
        let address: MKGlyphAddress? = cluster.glyphs.first {
            line.runs[$0.run].stringIndices[$0.glyph] == letterUTF16Index
        } ?? cluster.glyphs.first
        guard let address else { return nil }

        let run = line.runs[address.run]
        let glyphID = run.glyphs[address.glyph]
        let advance = run.advances[address.glyph]
        // Phase A: use the run's RESOLVED font (`run.font`, captured
        // post-shape from `CTRunGetAttributes[.font]`), not
        // `harvestStyle.fontHandle` (the unresolved base `MKFontRef`).
        // `harvestStyle.isBold`/`isItalic` already drove the shape above
        // via `MKShapingEngine.resolvedFont(for:)`, so the run's captured
        // font IS the bold/italic variant when one was realized ، tracing
        // the outline from the unresolved handle here would silently harvest
        // the regular face's glyph outline for a bold/italic request,
        // mirroring the bug `ArrangeDeriver`'s `run.font`-based call sites
        // already avoid.
        let outline = await paths.path(for: glyphID, font: run.font)

        let resolved = MKResolvedForm(
            form: effectiveForm,
            requestedForm: requestedForm,
            wasCoerced: wasCoerced,
            glyphID: glyphID,
            advance: advance,
            outline: outline)
        cache[key] = resolved
        return resolved
    }

    /// Drops the harvest cache (font re-registration hook, WS-09).
    public func invalidate() {
        cache.removeAll()
    }
}
