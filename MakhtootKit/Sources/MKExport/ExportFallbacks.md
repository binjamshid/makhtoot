# MKExport — fallback documentation map

WS-08 packet §5 task 16 / Q73/D-118 "never silently flatten". Every row
below maps a `FallbackReason` case (`FallbackNote.swift`) to its
user-facing Arabic string and its producer.

**Status as of P10-COMPLETION (Run-3, `docs/impl-log/WS-08.md`)**: every
row now has a real producer EXCEPT `.lockedFontNoShapedCache` (blocked on
a model-layer follow-up — `lastShapedCache` does not exist in `MKModel`
yet, a cross-fence gap, unchanged from P10-EARLY).

| `FallbackReason` case | Arabic user-facing string | Producer | Status |
|---|---|---|---|
| `.arrangedGeometry` | "تم تحويل النص إلى مسارات للحفاظ على الشكل" | `ArrangedDrawer` (MKRender, unmodified) draws arranged content as vector outlines automatically in both PDF and SVG writers — no separate producer call site emits this note this session (arranged content never routes through the outline-substitution helpers `MKEmbeddingRestrictionWalker`/`MKTextOutlining` at all, since it is ALREADY outline-shaped data per INV-13); reserved for a future producer if/when the writers need to explicitly flag it | Model-only (behavior correct, note not separately emitted) |
| `.customLigatureDecomposition` | "تم تحويل النص إلى مسارات للحفاظ على الشكل" | Decomposed-ligature arranged children render as plain outline glyphs via the same unmodified `ArrangedDrawer`/`SVGSerializer.renderArranged` path — same status as `.arrangedGeometry` above | Model-only |
| `.fontEmbeddingRestricted(fontName:)` | "تعذّر تضمين الخط \"…\" بسبب قيود الترخيص؛ تم تحويل النص إلى مسارات" | `PDFVectorExporter` (via `MKEmbeddingRestrictionWalker`/`MKOutlineSubstitutePainter`) and `SVGSerializer.renderLiveText` — both check `FontLicenseProviding.embeddingRights(_:).contains(.pdf / .svg)` per node | **Shipped** |
| `.pathTextFidelity` | "تم تصدير النص على المسار كمسارات ثابتة للحفاظ على شكل التخطيط" | `SVGSerializer.renderPathText` (WS08-A5 ADR — no `<textPath>`, always outlined) | **Shipped** |
| `.userFidelityToggle` | "تم تحويل النص إلى مسارات حسب إعداد \"دقة المسار\"" | UI-driven toggle (WS-13 territory) — no `MKExport`-side producer exists; `SVGSerializer` always outlines path text unconditionally (the ADR's default), so the toggle's OFF state has no distinct code path to opt back into `<textPath>` this session | Deferred (needs WS-13 UI wiring) |
| `.rasterBelowPrintDPI` | "دقة إحدى الصور أقل من ٣٠٠ نقطة في البوصة عند الطباعة" | Not computed this session — `PDFVectorExporter` embeds raster assets via the unmodified `MKRender.ImageDrawer` at native resolution without a DPI-floor check (needs `MKAssetProviding`'s resolved image's own intrinsic size vs. the print target's effective DPI, deferred) | Deferred |
| `.pdfAssetRasterized` | "تم تحويل صورة PDF إلى صورة نقطية داخل ملف SVG" | `SVGSerializer.renderImage`'s `.vectorPDF` case (`rasterizePDFPage`, 2× target per §16.6) | **Shipped** |
| `.colorGlyphRasterized` | "تم تصدير الرمز التعبيري كصورة نقطية" | `SVGSerializer.renderGlyphOutlines`/`renderArrangedElement` (outlined live/path text and arranged groups) and `MKOutlineSubstitutePainter.paint` (PDF outline-substitution path) — `MKTextOutlining.isEmojiCluster` detects `Extended_Pictographic` codepoints; D-227(4)'s "emoji stays an image even inside an arranged group" carve-out is honored (arranged nodes emit `data-mk-kind="emojiGlyph"` wrapping the persisted, provenance-only outline — no live font/glyph-id access survives into a frozen `MKArrangedTextNode`, so the arranged case cannot rasterize a REAL color bitmap this session — see `SVGSerializer.renderArrangedElement`'s own note; live-text/path-text outline cases DO rasterize a real color bitmap via `CTFontDrawGlyphs`) | **Shipped** (arranged case: provenance-marked, not a real bitmap — documented limitation) |
| `.lockedFontNoShapedCache(fontName:)` | "الخط \"…\" مقفل ولا توجد نسخة محفوظة من التنضيد؛ تم حظر التصدير" | `ExportGate` block (D-227(6)) — needs `lastShapedCache`, which does not exist in `MKModel` yet (cross-fence gap, unchanged from P10-EARLY) | Deferred (model-layer follow-up) |
| `.downscaledForFreeTierBudget(requestedPixelWidth:requestedPixelHeight:)` | "تم تصغير حجم التصدير ليتوافق مع الحد المجاني (٢ ميجابكسل)" | `ExportCoordinator` (task 6/18) | **Shipped** (P10-EARLY) |
| `.cmykContentRasterized` (P10-COMPLETION new case) | "تم تحويل الصفحة بالكامل إلى صورة نقطية عالية الدقة لتحويلها إلى CMYK؛ النص والأشكال لم تعد عناصر متجهية" | `PDFPrintCMYKExporter.export` — appended on EVERY CMYK print export (document-level, not per-node) per the "Spike C" finding (`docs/impl-log/WS-08.md`): true per-element vector CMYK requires editing `MKRender`, outside this packet's fence | **Shipped** (documents a real, load-bearing deviation) |
| `.fontNotEmbedded(fontName:)` (P10-COMPLETION new case) | "لم يتم تضمين الخط \"…\" في الملف؛ قد يظهر النص بخط مختلف عند فتحه على جهاز آخر" | `SVGTextWriter.renderLiveText` — a font HAS `.svg` rights but `MKExportFontDataProviding` (v1 stub `MKNoFontDataProviding`) returned no bytes; text still exports live, just without `@font-face` | **Shipped** (v1 stub always triggers this — no font bytes are wired until a real `MKExportFontDataProviding` conformer exists at the composition root) |
| `.assetUnresolved(assetRef:)` (post-P10-COMPLETION follow-up) | "تعذّر العثور على إحدى الصور؛ لم يتم تضمينها في الملف" | `SVGSerializer.renderImage`'s `.raster` case AND `SVGSerializer.renderBackground`'s `.image` case — an `MKAssetProviding.resolveRasterImage` lookup returned `nil` (or PNG re-encoding failed). The canvas-background `.image` case now embeds the resolved photo as a base64 `<image>` (mirroring `MKRender/Drawers/BackgroundDrawer.swift`'s `MKImageAspect.cover`/`MKGeometryMath.aspectFit` fitting exactly, clipped to the canvas via a `<clipPath>`); this note fires ONLY when resolution fails, leaving the same honest, visibly-empty `fill="none"` marker rect (`data-mk-outlined="imageBackgroundNotEmbedded"`) as before. Vector PDF export (`PDFVectorExporter`) already embedded background images correctly before this change (verified by `PDFVectorExporterTests`), so it needed no fix. | **Shipped** |

## Subset-embedding deferral (task 14 / D-227(3))

See `SVGTextWriter.swift`'s file header and `SUBSETTING_FOLLOWUP.md` for
the full "why a native sfnt subsetter was assessed as too large to ship
correctly this session" writeup — v1 ships FULL-font `@font-face` embedding
for OFL-verified fonts (larger files, but a definitely-valid font), never a
half-correct subsetter.
