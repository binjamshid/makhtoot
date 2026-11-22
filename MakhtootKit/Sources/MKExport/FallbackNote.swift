import MKFoundation

// WS-08 packet §5 task 4 / §6 "Never silently flatten" (Q73/D-118).
// `FallbackNote` is the "never silent" carrier every `ExportResult` (and
// eventually `MKExportReport`, ARCHITECTURE §16.7) surfaces. The full CASE
// LIST below is shipped now (P10-EARLY) even though most PRODUCERS
// (arranged-content outlining, font-embedding restriction, path-text
// outlining, low-DPI raster assets, emoji rasterization, locked-font
// blocking) are SVG/PDF writer concerns deferred to P10-completion ،
// shipping the model now means every later writer targets a stable,
// already-reviewed API instead of inventing its own ad hoc reason type.
// See `Sources/MKExport/ExportFallbacks.md` for the Arabic user-facing
// string mapped to each case (D-227's two new rows included) and which
// rows this session's producers can ACTUALLY trigger vs. which are
// P10-completion-only.
public enum FallbackReason: Sendable, Codable, Hashable, Equatable {
    /// Arranged/transformed glyphs, decomposed ligatures ، geometry that is
    /// no longer a text run (§16.5 "always outlines").
    case arrangedGeometry
    /// A custom ligature was decomposed into constituent glyph outlines.
    case customLigatureDecomposition
    /// Live text set in a font whose `MKEmbeddingRights` lacks the target
    /// format's bit (D-227(1)) ، drawn as outlines instead of embedded text.
    case fontEmbeddingRestricted(fontName: String)
    /// Path text exported as placed glyph outlines rather than
    /// `<textPath>`/live text, for our-own-layout fidelity (D-118 core;
    /// WS08-A5 ADR ، "no textPath").
    case pathTextFidelity
    /// User explicitly toggled "دقة المسار" (path fidelity) to prefer
    /// outline-exactness over SVG editability.
    case userFidelityToggle
    /// A raster asset's effective density fell below the 300 DPI print
    /// floor (D-118) ، a WARNING, not an error (export still completes).
    case rasterBelowPrintDPI
    /// A vector-PDF image asset was rasterized into the SVG output because
    /// no `<pdf-in-svg>` embedding exists (§16.6).
    case pdfAssetRasterized
    /// An emoji/color glyph (COLR/CBDT/sbix) was rasterized to an `<image>`/
    /// embedded-raster element ، in ALL contexts, including inside an
    /// otherwise-vector arranged group (D-227(4), the explicit carve-out to
    /// the "arranged content is always outlined" rule; R-21.10).
    case colorGlyphRasterized
    /// D-227(6): live text set in a locked (non-owned/unsubscribed) font
    /// had no `lastShapedCache` snapshot to export from ، the EXPORT WAS
    /// BLOCKED at `ExportGate`, never silently substituted with a system
    /// font. This case exists for `ExportFallbacks.md`'s documentation
    /// completeness; it surfaces as an `MKExportBlockReason`
    /// (`ExportGate.swift`), never as an `ExportResult.fallbacksApplied`
    /// entry (a blocked export produces no result to attach notes to).
    case lockedFontNoShapedCache(fontName: String)
    /// Free-tier 2 MP clamp (task 6) resized the requested/preset pixel
    /// dimensions down to fit the effective budget ، not a defect, but
    /// "never silent" (Q73) extends to this too: the user should be told
    /// the delivered file is smaller than requested.
    case downscaledForFreeTierBudget(requestedPixelWidth: Int, requestedPixelHeight: Int)
    /// P10-COMPLETION finding (Run-3, `docs/impl-log/WS-08.md` "Spike C"):
    /// the CMYK print PDF's page content is a single, whole-page RASTER
    /// image (not true per-element vector/text) ، because per-color CMYK
    /// conversion requires intercepting `MKRender`'s drawers'
    /// `ctx.setFillColor(color.cgColor)` calls, which are outside this
    /// packet's fence (`MKRender` sources), and empirical probing confirmed
    /// a CMYK-space `CGContext`/PDF context does NOT auto-convert an sRGB
    /// `CGColor` handed to it (verified by inspecting the produced PDF's
    /// raw content stream ، CoreGraphics tags the fill operator with the
    /// CGColor's OWN embedded colorspace resource instead of the context's
    /// declared space). The raster IS a real, explicit, ground-truth-
    /// verified CMYK conversion (`CMYKConverter.convertWholeImage`,
    /// `.relativeColorimetric` intent set explicitly) at ≥300 DPI print
    /// resolution with a real embedded `OutputIntent` ، but it is
    /// flattened, not vector/searchable text. Document-level (`nodeID ==
    /// nil`) ، applies to the whole export, not one node.
    case cmykContentRasterized
    /// Task 14: live text whose font HAS `.svg` embedding rights but no
    /// actual font-file bytes were available from
    /// `MKExportFontDataProviding` (v1 stub `MKNoFontDataProviding`
    /// always answers `nil` ، a real conformer is composition-root
    /// territory) ، the node STILL exports as live `<text>` (not
    /// outlined; rights allow it), just without an embedded `@font-face`,
    /// so a viewer without the font installed falls back to its own
    /// font substitution. Distinct from `.fontEmbeddingRestricted`
    /// (which means the RIGHTS themselves are absent and the node is
    /// outlined instead).
    case fontNotEmbedded(fontName: String)

    /// An `MKAssetProviding` lookup for a raster/vector-PDF asset returned
    /// `nil` (undecoded/missing) at export time, so the node (or the canvas
    /// background slot) was skipped and left as an honest, visibly-empty
    /// placeholder rather than a silently-embedded blank. Distinct from
    /// `.rasterBelowPrintDPI` (which means the asset WAS resolved, just at
    /// too low a density) and from `.pdfAssetRasterized` (which means the
    /// asset resolved fine but had to be flattened to a bitmap).
    case assetUnresolved(assetRef: String)

    /// Stable machine-readable event name, matching ARCHITECTURE §16.7's
    /// `MKExportReport.Entry.event` vocabulary ("outlined",
    /// "rasterBelowPrintDPI", "pdfAssetRasterized", …) for cross-reference.
    public var eventName: String {
        switch self {
        case .arrangedGeometry, .customLigatureDecomposition, .fontEmbeddingRestricted, .pathTextFidelity, .userFidelityToggle:
            return "outlined"
        case .rasterBelowPrintDPI: return "rasterBelowPrintDPI"
        case .pdfAssetRasterized: return "pdfAssetRasterized"
        case .colorGlyphRasterized: return "colorGlyphRasterized"
        case .lockedFontNoShapedCache: return "lockedFontNoShapedCache"
        case .downscaledForFreeTierBudget: return "downscaledForFreeTierBudget"
        case .cmykContentRasterized: return "cmykContentRasterized"
        case .fontNotEmbedded: return "fontNotEmbedded"
        case .assetUnresolved: return "assetUnresolved"
        }
    }

    /// The Arabic user-facing message (never silent, Q73). Mirrors
    /// `ExportFallbacks.md`'s table verbatim ، kept as code too so
    /// `ExportResult` consumers (WS-13's pre-export disclosure sheet,
    /// D-227(7)) never need to re-derive strings from the doc file.
    public var arabicMessage: String {
        switch self {
        case .arrangedGeometry, .customLigatureDecomposition:
            return "تم تحويل النص إلى مسارات للحفاظ على الشكل"
        case .fontEmbeddingRestricted(let fontName):
            return "تعذّر تضمين الخط \"\(fontName)\" بسبب قيود الترخيص؛ تم تحويل النص إلى مسارات"
        case .pathTextFidelity:
            return "تم تصدير النص على المسار كمسارات ثابتة للحفاظ على شكل التخطيط"
        case .userFidelityToggle:
            return "تم تحويل النص إلى مسارات حسب إعداد \"دقة المسار\""
        case .rasterBelowPrintDPI:
            return "دقة إحدى الصور أقل من ٣٠٠ نقطة في البوصة عند الطباعة"
        case .pdfAssetRasterized:
            return "تم تحويل صورة PDF إلى صورة نقطية داخل ملف SVG"
        case .colorGlyphRasterized:
            return "تم تصدير الرمز التعبيري كصورة نقطية"
        case .lockedFontNoShapedCache(let fontName):
            return "الخط \"\(fontName)\" مقفل ولا توجد نسخة محفوظة من التنضيد؛ تم حظر التصدير"
        case .downscaledForFreeTierBudget:
            return "تم تصغير حجم التصدير ليتوافق مع الحد المجاني (٢ ميجابكسل)"
        case .cmykContentRasterized:
            return "تم تحويل الصفحة بالكامل إلى صورة نقطية عالية الدقة لتحويلها إلى CMYK؛ النص والأشكال لم تعد عناصر متجهية"
        case .fontNotEmbedded(let fontName):
            return "لم يتم تضمين الخط \"\(fontName)\" في الملف؛ قد يظهر النص بخط مختلف عند فتحه على جهاز آخر"
        case .assetUnresolved:
            // Latin gloss: "Failed to resolve an image; it was not embedded in the file"
            return "تعذّر العثور على إحدى الصور؛ لم يتم تضمينها في الملف"
        }
    }
}

/// One "never silent" event attached to an `ExportResult`. `nodeID == nil`
/// for document-wide notes (e.g. `downscaledForFreeTierBudget`).
public struct FallbackNote: Sendable, Codable, Hashable, Equatable {
    public var nodeID: MKNodeID?
    public var reason: FallbackReason
    /// Optional free-form detail beyond `reason`'s associated values
    /// (e.g. measured DPI for `.rasterBelowPrintDPI`).
    public var detail: String?

    public init(nodeID: MKNodeID? = nil, reason: FallbackReason, detail: String? = nil) {
        self.nodeID = nodeID
        self.reason = reason
        self.detail = detail
    }

    public var arabicMessage: String { reason.arabicMessage }
    public var eventName: String { reason.eventName }
}
