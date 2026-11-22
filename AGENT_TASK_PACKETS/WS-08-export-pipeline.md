# WS-08 — Export Pipeline & Color

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns `MKExport`
and `MKColor`: all output formats, presets, free-tier 2 MP gating, tiled huge-raster
rendering, the ICC color pipeline, and export-history recording.

## 1. Mission

Build the export subsystem on top of WS-07's single render path (never screen capture —
D-118): free tier gets JPEG + rasterized PDF capped at 2 MP effective; premium gets
opaque PNG, transparent PNG, SVG, and vector print PDF at 300 DPI with true CMYK via an
ICC-profile-aware pipeline embedding an OutputIntent (D-117, Q75 — deliberately
overriding the market study §7 defer-CMYK recommendation). Raster exports of any size
run through tiled CGBitmapContext strips so output is bounded by disk, not RAM (D-116),
with no artificial caps beyond the free-tier gate — warn near memory limits (BRIEF Q76).
Entitlement checks happen at export time via `MKEntitlementProviding` plus content
gating: a free user exporting a premium-content project hits the replace-or-subscribe
contract (D-119; flow UI is WS-13's, detection and blocking are yours).

The vector formats carry the differentiator's fidelity promise. PDF: vector paths + live
text as real text runs with subset embedding when the font license permits (OFL),
outlined otherwise — a per-license switch fed by WS-09 metadata (stub: all OFL). SVG:
no system writer exists, so you implement the custom serializer — Live Text becomes
`<text>` (`@font-face` embed only when licensed); arranged/transformed glyphs become
`<g><path>` groups carrying `data-mk-*` provenance (source text, codepoints, font name)
so editability intent survives; every outline fallback is documented per feature and
surfaced to the user, never silent (Q73/D-118). Presets cover the locked social/print
ratio list at 2 MP baseline plus premium custom exact dimensions, and every export
writes an `ExportRecord` into WS-02's metadata store.

## 2. Scope

**IN**
- `MKColor`: sRGB working-space model (P3 display awareness documented),
  `ICCProfileStore` (bundled slot + Apple Generic CMYK fallback, FD-03 placeholder),
  RGB→CMYK via `CGColorSpace(iccData:)`, PDF OutputIntent, per-format pipeline choice.
- `ExportCoordinator`: request model (format, preset/custom size, DPI, background,
  pipeline), entitlement + content gating, progress/cancellation, memory-pressure
  cooperation, history recording.
- Raster exporters: JPEG (quality), opaque PNG, transparent PNG — all via tiled strips
  into CGBitmapContext; free-tier 2 MP math; DPI metadata stamping (72/150/300).
- PDF exporters: free rasterized PDF (≤2 MP full-page raster); premium vector PDF —
  vector paths for shapes/arranged/path-text, live text as runs w/ subset embedding or
  outlines per license switch, ≥300 DPI raster assets, sRGB or CMYK + ICC OutputIntent.
- SVG serializer (custom, no dependency): shapes, embedded-base64 images, live
  `<text>`, arranged `<g><path>` with `data-mk-*`, path-text as placed glyph paths,
  fallback documentation map.
- Preset catalog: locked ratio list at 2 MP baseline; premium custom exact dimensions;
  last-used preset per project.
- Export history: `ExportRecord`s (WS-02 store) — format, pixel size, preset, outcome.
- Huge-export memory strategy + near-limit warning event; Arabic print-sharpness
  verification harness.

**OUT**
- Share sheet / export UI, replace-or-subscribe flow UI (WS-13).
- Real entitlement resolution (WS-10) and font license truth (WS-09) — you consume the
  `MKEntitlementProviding` and `FontLicenseProviding` seams.
- Rendering internals (WS-07 region render API is your renderer).
- On-screen CMYK soft-proofing (documented v1 limitation per D-117).
- Export analytics (WS-12 reads history if consented; you just record).

## 3. Dependencies

**Upstream:** WS-01 (`MKEntitlementProviding` + always-premium `StubEntitlementResolver`;
`MKPremiumCapability.premiumExportFormats/.hiResExport`), WS-02 (scene snapshots,
`ExportRecord`, asset store, `premiumContentPresent` flag), WS-03 (shaped runs for PDF
text), WS-05 (path placements), WS-07 (SnapshotRenderer + region render API, memory
monitor events). **Stub strategy:** develop premium paths against the always-premium
stub; gating tests use a scripted `FakeEntitlement(state:)` — free AND premium behavior
tested before WS-10 lands. Font license seam stub: `AllOFLLicenseStub`.

**Downstream consumers:** WS-13 (export sheet calls `ExportCoordinator`), WS-10 (real
resolver), WS-09 (real license provider), WS-15 (print QA uses the harness).

## 4. Locked decisions binding this packet (quoted)

- **D-117**: "working space = extended sRGB; UI picks/display in P3-aware SwiftUI/UIKit
  colors; document stores sRGB components… Print PDF export converts through ICC:
  source sRGB → CMYK via `CGColorSpace(iccData:)` CMYK profile with relative
  colorimetric intent by CG conversion; profile embedded in PDF (OutputIntent). Bundled
  profile choice = **FD-03 founder decision** (candidates: eciRGB/ISO Coated v2 class
  profiles — redistribution license must be verified, never assumed; fallback: Apple
  Generic CMYK, documented as lower fidelity). v1 has no on-screen soft-proofing;
  documented limitation + verification via external tooling in TEST_MATRIX."
- **D-118**: "single render path from the scene snapshot (never screen capture). Free:
  JPEG, rasterized PDF, both ≤2 MP effective. Premium: opaque PNG, transparent PNG,
  SVG, vector print PDF (300 DPI raster assets floor, CMYK). Raster export uses tiled
  CGBitmapContext strips. PDF: vector paths + live-text runs; live text in OFL fonts
  draws as text with subset embedding, otherwise outlines (per-license switch). SVG:
  custom serializer; Live Text → `<text>` (+`@font-face` embed only when license
  allows); Arranged/transformed glyphs → `<g><path>` with `data-mk-*` provenance
  attributes (source text, codepoints, font name) so editability intent is preserved;
  every outline fallback is per-feature documented, never silent."
- **D-119**: "entitlement checks at export time + content gating (premium fonts, photo
  backgrounds, premium assets mark the project 'premium content present'); free tier
  exporting a premium-content project is blocked with replace-or-subscribe flow."
- **D-116** (final sentence): "Huge exports render tiled (bounded strips) so output size
  is limited only by disk, not RAM."
- **D-115** (export budget): "4K PNG export <10 s on A15."
- BRIEF "Export": presets list, "Premium Hi-Res = 4K+ dims, 300-DPI print, effectively
  unlimited scaling subject only to hardware memory protection (Q76: no artificial
  caps; warn near memory limits + autosave)"; "Never silently flatten" (Q73).

## 5. Task breakdown (ordered)

1. **`MKColorSpec`** (MKColor): sRGB component storage type (matches WS-02 `MKFill`),
   `CGColor` conversions in extended-sRGB and display-P3; document the working-space
   rule (D-117). *Accept:* round-trip tests; P3 is display-only, never stored.
2. **`ICCProfileStore`**: bundle slot `Resources/ICC/` — v1 ships NO third-party
   profile (FD-03 unresolved; never invent licenses); `cmykSpace() -> CGColorSpace`
   returns the bundled profile if present (post-FD-03), else Apple Generic CMYK
   (`CGColorSpace(name: kCGColorSpaceGenericCMYK)`); `profileProvenance` metadata
   (`bundledICC(name:)` / `appleGenericCMYK`) surfaced into PDF metadata + export
   report. *Accept:* fallback works today; dropping in a profile file switches output
   with no code change; provenance lands in the export report.
3. **`CMYKConverter`**: sRGB → CMYK via `CGColor.converted(to:intent:
   .relativeColorimetric, options:)`; batch conversion for the scene palette.
   Verification protocol (D-226, supersedes tolerance-band verification — bands
   language removed): reference CMYK values are computed ONCE with an external
   ICC-aware tool (littleCMS `transicc` or Argyll `xicclu` — exact tool recorded at
   implementation time) using the same profile + relative colorimetric intent, and
   checked into the fixture corpus as ground truth; our conversion must match ground
   truth within ±1% per channel. New discriminator fixture: a fully saturated
   out-of-gamut primary (#00FF00) converted under `.relativeColorimetric` is asserted
   to differ from the same color converted under `.perceptual` by MORE than the ±1%
   tolerance (proves the two intents are not silently interchangeable). *Accept:* ±1%
   match against external-tool ground truth for both fallback and a test-injected
   profile; out-of-gamut discriminator fixture passes; intent unit test converts a
   near-gamut-edge boundary color under `.perceptual` vs `.relativeColorimetric` and
   asserts measurable divergence; conversion intent is relative colorimetric per D-117.
4. **`ExportRequest`/`ExportResult` models**: format enum (`jpeg(quality)`, `pngOpaque`,
   `pngAlpha`, `svg`, `pdfRaster`, `pdfVectorRGB`, `pdfVectorCMYK`), target size
   (preset | custom pt+scale | dpi), background (`canvas` | `transparent` where legal);
   `ExportResult {url, pixelSize, format, fallbacksApplied: [FallbackNote],
   colorProvenance, duration}` — `FallbackNote` is the "never silent" carrier.
   *Accept:* model review vs D-118; Codable for history.
5. **`ExportGate`** (D-119): `(request, entitlementState, contentFlags) -> allowed |
   blocked(reason)`; content scan computes `premiumContentPresent` (premium/imported
   fonts via license seam, photo backgrounds = any image-node background, premium
   assets flag from WS-14) and stores it on the project record (WS-02 field). Free
   allowances: jpeg + pdfRaster ≤2 MP, no premium content. Blocked reasons typed for
   WS-13's replace-or-subscribe flow. *Accept:* truth-table tests across entitlement
   states (`FakeEntitlement`) × formats × content flags; grace/billingRetry behave as
   premium (D-113).
6. **2 MP math**: `effectivePixelBudget = 2_000_000`; free-export sizes scaled down
   aspect-preserving to fit; actual size reported. *Accept:* 1080×1080 untouched;
   4096×4096 → ~1414×1414; aspect-preservation property test.
7. **Preset catalog**: square 1:1 (1080), story/reel 9:16 (1080×1920), portrait 4:5,
   landscape 16:9, messaging-status 9:16, wallpaper (device-class sizes), print
   A5/A4/A3 at 300 DPI, business card 90×55 mm; each preset = ratio + free-baseline
   pixel size + premium print size; premium custom exact dimensions validated (≥16 px,
   disk-feasibility warning threshold). *Accept:* table matches the BRIEF preset list;
   unit tests on pt↔px DPI math.
8. **`TiledRasterExporter`** (the memory-safety core): render scene → CGBitmapContext
   strips of height `64 MB / bytesPerRow`; per strip call WS-07 region render (export
   quality); assemble strips into an `mmap`-backed temp-file bitmap, then ImageIO
   one-shot encode (bounded by disk, not RAM — document per-format choice). Cooperates
   with WS-07 `MemoryPressureMonitor`: stage ≥2 halves strip height; emits
   `nearMemoryLimit` warning event (WS-13 shows banner; autosave handled by ladder).
   *Accept:* 8192×8192 PNG export peaks <300 MB resident (instrumented); 512×512
   tiled-vs-untiled pixel-identical; cancellation between strips leaves no temp files.
9. **JPEG/PNG encoders**: ImageIO destinations with DPI metadata
   (`kCGImagePropertyDPIWidth/Height`), JPEG quality 0.85 default, opaque PNG
   composites canvas background, alpha PNG renders clear background (premium only).
   *Accept:* correct DPI in Preview/Photos; alpha PNG truly transparent (checker
   test); free 2 MP JPEG passes the task-17 sharpness check.
10. **Rasterized PDF (free)**: single-page CG PDF context at preset pt size embedding
    the ≤2 MP raster. *Accept:* correct page size in Preview; no text objects present.
11. **Vector PDF (premium, RGB)**: CG PDF context; WS-07 export path with `.pdfVector`
    option — shapes/arranged/path-text as vector paths; live text via
    `CTFontDrawGlyphs` in the PDF context (subset-embeds automatically); license
    switch: no-embed fonts → outlines + `FallbackNote.outlinedText(reason:
    .fontLicense(fontName))`. Raster assets at native resolution;
    `FallbackNote.lowResAsset` if effective <300 DPI. *Accept:* PDF text selectable/
    copyable for OFL-stubbed fonts (extraction of "بسم الله" matches logical order);
    arranged content pure vector (6400 % zoom, no pixelation); subset (not full) font
    embedded.
12. **CMYK PDF (premium print)** — gated by two BLOCKING VERIFY-AT-IMPLEMENTATION
    spikes (D-226); resolve both before building the rest of this task:
    a. **Spike A** — confirm whether `CGContext(data:width:height:...:space:
       <CMYK CGColorSpace>,...)` bitmap-context creation is actually supported on the
       target iOS floor (CMYK bitmap contexts have historically been macOS-only in some
       CoreGraphics paths). Record the finding; if unsupported, record the fallback
       strategy (e.g., render an RGB strip and convert per-pixel via `CMYKConverter`
       before writing).
    b. **Spike B** — determine the exact CGPDFContext OutputIntent auxiliary-key name
       and value shape (dict vs array) actually accepted by CoreGraphics's PDF writer
       on the target OS. Record with a minimal PDF produced and inspected (not assumed
       from the PDF spec alone).
    Then: same vector pass with all fill/stroke colors through `CMYKConverter`; page
    drawn in CMYK context space (per Spike A's resolved strategy); ICC embedded via PDF
    OutputIntent per Spike B's findings (`DestOutputProfile` stream = active profile;
    subtype `GTS_PDFX` only when a real profile is bundled post-FD-03 — the Apple
    Generic fallback emits an OutputIntent with documented provenance, NOT claimed as
    PDF/X). Raster assets converted to CMYK through TWO documented, intent-matched
    conversion sites (D-226 — amends the prior "single conversion point" claim): the
    vector per-color path via `CMYKConverter` as above, AND the raster whole-image path,
    which explicitly calls `ctx.setRenderingIntent(.relativeColorimetric)` before
    redraw so the whole-image conversion matches the vector path's intent. Live text:
    same license switch; glyph color in CMYK. *Accept:* both spikes' findings are
    written up BEFORE the rest of the task proceeds; external verification procedure
    documented + executed once against the ±1% ground-truth fixtures from task 3
    (`T-EXPORT-CMYK-*`): colorspace reports CMYK, OutputIntent present with the
    Spike-B-verified key shape, no PDF/X claim under fallback profile, raster
    whole-image conversion intent matches vector per-color conversion intent.
13. **SVG serializer — structure**: hand-rolled XML writer (escaping, indent, no deps);
    root `<svg xmlns viewBox width height>` in px; `<defs>` for reused assets; z-order
    = document order; one group per top-level node with `transform="matrix(…)"`,
    `data-mk-node-id`, `data-mk-kind`. *Accept:* xmllint well-formed; renders correctly
    in Safari/Chrome (manual check logged).
14. **SVG — live text**: `<text>` with `direction="rtl"`, x/y baseline per line,
    `font-family`, `font-size`, fill; kerning/tracking via `letter-spacing`
    approximation (documented fidelity note); `@font-face` with base64 raw TTF ONLY
    when the license seam allows (`FallbackNote.fontNotEmbedded(fontName)` otherwise —
    still `<text>` with family name; system-fallback risk documented). One `<text>` per
    line. *Accept:* SVG live text is editable text in Illustrator-class tools; RTL
    renders correctly in browsers for "بسم الله"; fallback notes populated when the
    stub is set to no-embed.
15. **SVG — arranged/transformed/path text** (D-118 core; schema now CANONICAL per
    D-227 — ARCHITECTURE §16.6 has been corrected to match this packet's implementation
    verbatim, so this task is the confirmed source of truth, not a candidate to be
    reconciled against ARCHITECTURE): each glyph/mark → `<path d="…">` inside
    `<g data-mk-schema="1" data-mk-source-text="…" data-mk-codepoints="0644 0627"
    data-mk-font="Amiri" data-mk-cluster="…" data-mk-kind="glyph|mark|ligature">`;
    ligature groups nest constituents post-decomposition; attributes XML-escaped,
    codepoints space-separated hex — this space-separated-hex, per-glyph-group-`<g>`
    attribute shape is canonical (D-227); do not switch to a per-glyph or
    comma-separated scheme. Path text exports as placed glyph paths with per-glyph
    transforms — NO `<textPath>` (fidelity to our own layout; deliberate fallback note
    `.pathTextOutlined(reason: .layoutFidelity)`). *Accept:* round-trip audit — parse
    own SVG, reconstruct codepoints from `data-mk-*`, equals the source backup for "لا"
    and "الله" fixtures; rasterized diff vs PNG export ≤1 %; `data-mk-schema="1"` is
    present on every provenance-carrying `<g>`.
16. **Fallback documentation map**: `ExportFallbacks.md` enumerating every case —
    transformed glyphs, custom ligature decomposition, font-embedding restriction,
    path text, low-res print asset, PLUS two new rows (D-227):
    - **Emoji/color-glyph**: exports as an `<image>` element (SVG) / embedded raster
      (PDF) per R-21.10, in ALL contexts — including as a child of an otherwise-vector
      arranged group (explicit carve-out to the "arranged content is always outlined"
      rule; an emoji inside an arranged composition stays an image element, never an
      outline).
    - **Locked-font-during-export**: export of live text set in a locked (non-owned/
      unsubscribed) font uses the `lastShapedCache` snapshot and NEVER re-shapes at
      export time; if no shaped cache exists for that locked-font live-text node,
      export is BLOCKED at `ExportGate` (task 5) with the replace-or-subscribe flow
      (WS-13 UI), never silently substituted with a system font.
    Each row mapped to its `FallbackNote` + Arabic user-facing string (e.g., "تم تحويل
    النص إلى مسارات للحفاظ على الشكل" — text outlined to preserve appearance).
    *Accept:* doc complete incl. the two new rows; WS-13 consumes strings; every note
    reaches `ExportResult` ("never silently flatten"); emoji-inside-arranged-group
    fixture exports as image element (not outlined); locked-font-no-cache fixture
    asserts export is blocked, not silently substituted.
17. **Arabic print-sharpness harness**: scripted exports of a QA scene (Naskh live text
    small + large, arranged "لا", tashkeel stacks "شَدَّةٌ", path circle, mixed digits
    "١٢٣/123") to every format at free/2 MP and premium/300-DPI A4; produce a review
    contact sheet + zoomed crops. *Accept:* `T-ARABIC-M-EXPORT-*` rows executed with
    evidence: no clipped marks, no broken joins, crisp 300-DPI edges, RTL order correct
    in PDF extraction.
18. **`ExportCoordinator` orchestration**: async task with progress (strips/pages),
    cancellation, temp-file hygiene, gate check → pipeline dispatch → `ExportRecord`
    (incl. failures), `export` signpost per run + phase. Exports run off-main on
    snapshots (D-102), serialized one at a time. *Accept:* integration tests per
    format; scene edits mid-export don't affect output (snapshot isolation); history
    visible via WS-02 query.
19. **D-115 export budget test**: 4K (3840×2160) PNG of the 100-node QA scene;
    simulator timing recorded + on-device A15 procedure documented for P14. *Accept:*
    simulator well under 10 s; procedure filed (`T-PERF-EXPORT-*`).
20. **Docs**: `MKExport/README.md` + `MKColor/README.md` — pipeline diagrams,
    format-vs-entitlement matrix, FD-03 integration steps (dropping in the licensed
    ICC profile), external CMYK verification procedure. *Accept:* reviewed against
    ARCHITECTURE.md §15/§16 outlines.

## 6. Arabic-correctness notes

- PDF text extraction: "بسم الله الرحمن الرحيم" must extract as logical-order Unicode
  (Core Text embedding handles this; verify — if extraction is visual-order garbage,
  file as a known limitation with evidence; never reorder codepoints to compensate).
- SVG `<text>` needs `direction="rtl"` + correct `text-anchor`; mixed "عام ٢٠٢٦ Design"
  must render in WebKit within tolerance of our PNG.
- Arabic-Indic digits survive every format (no ASCII normalization in serialization).
- Transparent PNG: tashkeel anti-aliased edges must not halo (premultiplied alpha);
  inspect "شَدَّةٌ" over transparency at 400 %.
- CMYK conversion of the madder-red accent must stay visually red (sanity band test) —
  guards the classic magenta/red channel-swap bug.
- Default export filename = project name, Arabic-safe sanitized; test "مشروعي الأول.png".

## 7. Packet acceptance criteria (gates)

- **Build gate**: `MKExportTests` + `MKColorTests` green (`T-EXPORT-*`, `T-COLOR-*`).
- **Gating gate**: D-119 truth-table suite — entitlement states × formats × content
  flags (`T-EXPORT-GATE-*`).
- **Fidelity gates**: tiled-vs-untiled identity; SVG provenance round-trip; SVG-vs-PNG
  diff ≤1 %; preview-vs-export identity with WS-07 (`T-EXPORT-FID-*`).
- **CMYK gate** (D-226): ±1% match against external-ICC-tool ground-truth fixtures
  (task 3); out-of-gamut discriminator + intent-divergence unit test pass; Spikes A/B
  (task 12) resolved and written up before CMYK PDF work proceeds; OutputIntent present
  with the Spike-B-verified key shape, colorspace externally verified, provenance
  correct under fallback; raster whole-image intent (`setRenderingIntent`) matches
  vector per-color intent; no invented profile licenses — FD-03 documented
  (`T-EXPORT-CMYK-*`).
- **D-115/D-116 gates**: 4K budget procedure; 8192² memory ceiling (`T-PERF-EXPORT-*`,
  `T-PERF-MEM-*`).
- **Manual Arabic checklist**: task-17 contact-sheet review (`T-ARABIC-M-EXPORT-*`).

## 8. Deliverables

- `MakhtootKit/Sources/MKColor/MKColorSpec.swift`, `ICCProfileStore.swift`,
  `CMYKConverter.swift`, `ColorPipelines.swift`, `README.md`
- `MakhtootKit/Sources/MKExport/ExportRequest.swift`, `ExportResult.swift`,
  `ExportGate.swift`, `ExportPresets.swift`, `ExportCoordinator.swift`,
  `TiledRasterExporter.swift`, `RasterEncoders.swift`, `PDFRasterExporter.swift`,
  `PDFVectorExporter.swift`, `PDFOutputIntent.swift`, `SVGSerializer.swift`,
  `SVGTextWriter.swift`, `SVGProvenance.swift`, `FontLicenseProviding.swift`
  (+ `AllOFLLicenseStub`), `ExportFallbacks.md`, `ExportHistoryRecorder.swift`,
  `README.md`
- `MakhtootKit/Tests/MKExportTests/*`, `MakhtootKit/Tests/MKColorTests/*`
  (truth tables, tiling identity, SVG round-trip, CMYK verification helpers, QA-scene
  generator)
- `Makhtoot/Resources/ICC/` (empty slot + FD-03 README, no unverified profiles)
- CONTRACTS.md update (license seam; region-render usage).

## 9. References

- ARCHITECTURE.md: §15 Color Management, §16 Export Pipelines (JPEG/PNG/PDF/SVG/CMYK),
  §11 Rendering & Preview, §12 Performance & Memory, §18 StoreKit & Entitlements,
  §25 Risks & Mitigations.
- PRD.md: §13 Export, §14 Free/Premium Gating & Paywall, §21 Edge-Case Compendium,
  §22 Non-Functional Requirements.
- BRIEF.md: "Export" (all bullets incl. Q73/Q75/Q76), "Known research gaps" (ICC
  profile licensing — never invent; FD-03).
- Market study §7 export feasibility matrix (SVG custom serializer; CMYK medium-low
  feasibility + deferral recommendation that D-117/Q75 overrides — implement CMYK,
  keep conservative claims)[^40][^41][^42]; §5/§6 font-embedding cautions[^26][^28][^31].

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS08-A1: tiled strips + mmap assembly", "WS08-A2: FallbackNote
  'never silent' enforcement", "WS08-A3: OutputIntent provenance & no-PDF/X-under-
  fallback rule", "WS08-A4: SVG data-mk-* provenance schema (versioned)",
  "WS08-A5: no textPath — path text exported as placed glyphs".
- Implementation log after tasks 8, 12, 15, 18 (memory ceilings, external CMYK
  verification output, round-trip results).
- Verification evidence: QA contact sheets, PDF extraction transcript, gating
  truth-table results, 4K timing.
- Record FD-03 integration instructions + provenance state as durable memory; flag to
  WS-15 that print-QA blocks on FD-03.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Free: JPEG + rasterized PDF only, 2 MP effective cap | Tasks 6, 9, 10 |
| Premium: opaque PNG, transparent PNG, SVG, high-res print PDF | Tasks 9, 11, 13–15 |
| Premium Hi-Res: 4K+ dims, 300-DPI print, no artificial caps, warn near memory limits + autosave | Task 8 (rest: WS-07 ladder/autosave) |
| Premium SVG preserves editable text/vector objects; documented fallbacks; never silently flatten | Tasks 13–16 |
| Premium PDF: vector/300-DPI, true CMYK, ICC-profile-aware pipeline | Tasks 1–3, 11, 12 |
| Presets: locked social/print aspect ratios at 2 MP baseline; premium custom exact dimensions | Task 7 |
| Free-tier gating: resolution, formats, premium layers/elements, locked fonts, photo backgrounds | Task 5 |
| Verify sharp Arabic output visually at print resolution across all formats | Task 17 |
| Canvas & projects: export history | Task 18 (rest: WS-02 store) |
| Known research gap: ICC CMYK profile redistribution licensing (never invent) | Task 2 (`ICCProfileStore`, FD-03) |
