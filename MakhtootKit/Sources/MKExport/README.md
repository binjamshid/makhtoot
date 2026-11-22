# MKExport

Owner: WS-08 (`AGENT_TASK_PACKETS/WS-08-export-pipeline.md`). Export
request/gate/coordinator/writers for JPEG, PNG (opaque + transparent),
rasterized PDF, vector PDF (RGB/CMYK), and SVG.

## Status: every format has a real writer (P10-EARLY + P10-COMPLETION, Run-3)

P10-EARLY (concurrent with P6-P9, per DEPENDENCY_GRAPH.md) shipped the
raster formats (jpeg/pngOpaque/pngAlpha) plus every request/gate/preset
model FULLY (so gating logic was completely testable before the remaining
writers existed). P10-COMPLETION (this session) adds the four remaining
writers: `PDFRasterExporter` (task 10), `PDFVectorExporter` (task 11),
`PDFPrintCMYKExporter` (task 12), `SVGSerializer`+`SVGTextWriter`+
`SVGProvenance` (tasks 13-16).

## Format-vs-entitlement matrix (current)

| Format | Free tier | Premium | Writer | Fidelity note |
|---|---|---|---|---|
| `jpeg` | ✅ (≤2 MP) | ✅ | ✅ | — |
| `pdfRaster` | ✅ (≤2 MP) | ✅ | ✅ | single raster image XObject, no text objects |
| `pngOpaque` | ❌ | ✅ | ✅ | — |
| `pngAlpha` | ❌ | ✅ | ✅ | — |
| `svg` | ❌ | ✅ | ✅ | full-font `@font-face` (no subsetting, deferred — `SUBSETTING_FOLLOWUP.md`) |
| `pdfVectorRGB` | ❌ | ✅ | ✅ | REAL vector paths + embedded/subset text (CoreGraphics auto-subsets) |
| `pdfVectorCMYK` | ❌ | ✅ | ✅ | **whole-page RASTER embed, not per-element vector** — "Spike C" deviation, see below |

## Pipeline diagram (all formats)

```
MKExportRequest ──▶ MKExportGate.evaluate(scene:entitlement:) ──▶ allowed(pixelSize) | blocked(reason)
                                                                        │
                                                          preparedScene (transparent → background.isHidden)
                                                                        │
                        ┌─────────────────┬──────────────────┬─────────┴──────────┬───────────────┐
                        │                 │                  │                    │
                  jpeg/png*         pdfRaster           pdfVectorRGB         pdfVectorCMYK        svg
                        │                 │                  │                    │               │
              MKTiledRasterExporter  (raster, then    MKSceneRenderer.render  MKTiledRaster-  SVGSerializer
              .renderAssembled        wrap in 1-page   directly into a PDF    Exporter render  (recursive tree
              (tiled/mmap, D-210)     PDF, no text)    CGContext (real        → CMYKConverter  walk, own <g>
                        │                 │             vector ops) +         .convertWhole-   nesting, no
              MKRasterEncoders      PDFRasterExporter   MKEmbeddingRestriction Image → embed    flat-CTM step
              .writeJPEG/writePNG                       Walker/MKOutline-     w/ OutputIntent  needed)
                        │                 │             SubstitutePainter    (Spike B shape)        │
                        └─────────────────┴──────────────────┴────────────────────┴────────────────┘
                                                                        │
                                                                MKExportResult (+ fallbacksApplied)
```

## The license-outline-substitution seam (task 11/14)

`MKRender`'s drawers have no embedding-rights concept (by design). The
per-license text-vs-outline switch (D-118/§16.5) is implemented entirely
in THIS module:

- `MKEmbeddingRestrictionWalker` — finds every `.liveText`/`.pathText`
  node whose font lacks the target format's `MKEmbeddingRights` bit,
  computes its full world transform (PDF's flat-CTM approach), and
  produces a scene copy with those nodes hidden.
- `MKTextOutlining` — re-shapes via the SAME `MKShapingEngine`/
  `MKPathText.PathLayoutEngine` the renderer's own drawers use, extracting
  `CTFontCreatePathForGlyph` outlines instead of calling
  `CTFontDrawGlyphs`. Also detects color glyphs (emoji,
  `isEmojiCluster`) and rasterizes them via `CTFontDrawGlyphs` into a
  small PNG (D-227(4)'s image-element carve-out).
- `MKOutlineSubstitutePainter` — paints the outline substitutes directly
  into a PDF `CGContext` (fill + stroke only, no shadow — documented
  simplification).
- `SVGSerializer` reuses `MKTextOutlining` directly with NO flat-CTM step
  (SVG's native nested `<g transform>` composes automatically).

Arranged/path-text content needs NO license switch at all: arranged nodes
are ALWAYS outline (INV-13, pre-persisted `MKPathData`); path text is
ALWAYS outlined in SVG (WS08-A5 ADR, "no `<textPath>`") but draws as real
embedded text in the PDF vector writer (the SAME positions/rotations our
own `PathLayoutEngine` computed, via the unmodified `PathTextDrawer`).

## CMYK print PDF — "Spike C" (a real, fence-driven architectural finding)

**This writer does NOT produce true per-element vector CMYK content.**
Verified empirically this session: a PDF `CGContext` has no fixed native
colorspace — color is entirely per-operator, and `ctx.setFillColor(_
color: CGColor)` (the exact call every `MKRender` drawer makes) tags its
operator with the CGColor's OWN colorspace, ignoring the context's prior
`setFillColorSpace` state AND `ctx.setRenderingIntent`. True per-element
CMYK requires the DRAWERS themselves to construct CMYK `CGColor`s before
painting — a `MKRender` source change, outside this packet's fence.

**What `PDFPrintCMYKExporter` does instead**: renders the WHOLE PAGE via
the existing tiled-raster pipeline (RGBA, correct opacity compositing per
Spike A), converts it ONCE via `MKColor.CMYKConverter.convertWholeImage`
(explicit `.relativeColorimetric`), and embeds that single CMYK image with
a real, OutputIntent-carrying PDF page. Every CMYK export carries
`FallbackReason.cmykContentRasterized` (never silent, Q73). This is a
genuine, load-bearing deviation from the packet's literal ask — flagged
prominently, not silently substituted. Full writeup:
`PDFPrintCMYKExporter.swift`'s header, `docs/impl-log/WS-08.md`.

## Spike D — `kCGPDFXOutputIntentSubtype` must be the literal `"GTS_PDFX"`

CoreGraphics silently discards the ENTIRE OutputIntent dictionary for any
other subtype string (verified — a custom "not a claim" string was tried
first and produced no `/OutputIntents` key at all). D-226(4)'s "no PDF/X
claim under fallback" is honored at the Swift/app-copy level
(`MKICCProfileProvenance.mayClaimPDFX`) instead — see
`PDFOutputIntent.swift`.

## SVG font subsetting — deferred (see `SUBSETTING_FOLLOWUP.md`)

Ships FULL-font `@font-face` embedding for OFL-licensed fonts (D-227(3))
this session — a correct minimal sfnt subsetter was assessed as too large
to build safely within this session; shipping a half-correct one (risking
a malformed embedded font) was explicitly rejected per the packet's own
instruction. Subsetting is a recorded follow-up.

## FD-03 integration steps

See `MKColor/README.md`/`MKColor/Resources/ICC/README.md`. Once a
licensed profile is bundled, `PDFPrintCMYKExporter`'s default
`profile:` parameter (`ICCProfileStore.loadBundled()`) picks it up with
NO code change, and `MKICCProfileProvenance.mayClaimPDFX` flips to `true`
for that profile — the OutputIntent's `/OutputConditionIdentifier`/`/Info`
text and the export report's color-provenance string both reflect the
real profile name automatically.

## External CMYK verification procedure

`MKColor/README.md`'s "D-226 verification protocol" section — littleCMS
`transicc`, ground-truth corpus checked into `CMYKConverterTests.swift`,
plus the two empirical findings (pure-black CMM divergence; Apple Generic
CMYK's own lack of intent differentiation) discovered while building that
corpus.

## Export history (task 5/18 — `MetadataStore.exportHistory` seam)

`MKExport` does not (and per DEPENDENCY_GRAPH.md should not) depend on
`MKPersistence` directly. `MKExportHistoryRecording`'s shape and
`MKExportFormat.metadataFormatString` exist specifically so a composition-
root conformer can bridge 1:1 to `MetadataStore.recordExport(projectID:
format:pixelWidth:pixelHeight:presetID:wasPremium:success:)` (already
shipped by WS-02) — no format-vocabulary logic needs to live at that call
site. `MKExportCoordinator`'s no-op default (`MKNoOpExportHistoryRecording`)
remains the default until that composition-root wiring lands (WS-13/app
layer, outside this fence).
