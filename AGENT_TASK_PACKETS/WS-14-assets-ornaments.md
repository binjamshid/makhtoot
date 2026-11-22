# WS-14 — Assets & Ornaments (MKAssets)

Run-1 agent task packet · Makhtoot (مخطوط) · Target module: `MKAssets` (MakhtootKit) + asset browser model. Consumes FOUNDATION.md module map §2 (MKAssets), D-111, D-119, D-126; BRIEF assets scope (Q61–62 template prohibition).

---

## 1. Mission

Build `MKAssets`: the bundled library of placeable vector design elements — reusable shapes, Arabic ornaments (زخارف), frames (إطارات), calligraphic decorative elements (فواصل وحليات خطية), and pattern backgrounds (خلفيات زخرفية) — plus the asset browser model that the editor (WS-13) renders and the premium/free flagging that gates content (D-119). Every asset is vector (paths, not bitmaps, except tiled pattern definitions which are vector tiles), original or license-clear under sourcing rules defined in this packet that **forbid unverified third-party art**, and drops into the scene graph as a standard `shape` node (D-111) so selection, transform, styling, grouping, undo, export, and sync all work with zero special cases.

This packet is explicitly **NOT templates**: BRIEF Q61–62 locks templates out of v1. Assets are individual placeable elements; nothing in this module may compose multiple elements plus text into a pre-arranged design. The only template-related deliverable is respecting the minimal extension seam owned by WS-13 (T15 there) — MKAssets adds no seam of its own beyond clean data-model separation that would let a future template system reference assets by stable id. Like fonts, assets carry provenance: each bundled asset has an origin record (original-by-agent, or derived-from-verified-source with license capture), and premium assets mark projects "premium content present" exactly like premium fonts do, feeding the same D-119 gating WS-08/WS-10 enforce.

## 2. Scope

**IN:**
- `MKAssets` target: asset model (`MKAssetDescriptor`, categories, premium flags, provenance records), bundled asset library (vector path data), pattern-background tiling model, asset browser view-model (categories, search, favorites, premium badges), instantiation into `MKNode.shape`/`background` scene nodes, thumbnail generation for the browser, sourcing-rules document + provenance audit.
- Initial v1 asset set production: geometric shapes, Arabic-motif ornament set, frame set, calligraphic divider/flourish set, pattern-background tile set — authored as original vector data (see T4–T8 sourcing rules).
- Premium/free flagging per asset + project premium-content marking integration.
- Asset search/tags in Arabic; favorites persistence via MKPersistence metadata.

**OUT:**
- Templates in any form (prohibited — Q61/Q62); user-imported assets (raster/SVG/PDF import is WS-02/WS-06/WS-08 pipeline territory per BRIEF "v1 imports" — MKAssets covers only the *bundled* library and its browser; the browser MAY list user-imported images via MKPersistence's asset store as a separate section, contract only); downloadable asset catalog (v2 seam — v1 assets are bundled only); AI-generated-content pipelines; app icon/branding art (FD-02, separate design run); Qur'anic/religious textual content inside ornaments (assets must be aniconic geometry/floral motifs — no verses, no مصحف frames marketed as such).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream:**
- `MKModel` (WS-02): `MKNode` value types — assets instantiate as `shape` (path + style) and `background` (pattern fill) nodes; if `MKNode.shape`'s path payload type (`MKBezierPath` Codable wrapper) lacks multi-subpath/even-odd support needed by ornaments, extend it in MKModel via coordinated addition, not a parallel type here.
- `MKFoundation`: ids, logging.
- `MKPersistence` (WS-02): favorites + browser metadata. **Stub:** in-memory favorites until integrated.
- `MKStore` (WS-10) via `MKEntitlementProviding` for premium gating. **Stub:** `AlwaysPremiumEntitlementStub`, then real; tests must inject `free` to verify gating.
- `MKRender` (WS-07) renders the nodes — no direct dependency; thumbnails use a small internal CG rasterizer over path data (or WS-07's snapshot API if available at build time — prefer reuse).

**Downstream consumers:** WS-13 (asset browser panel UI renders this model; placement dispatches to canvas), WS-06 (placed nodes manipulated like any shape), WS-08 (assets export as vectors in SVG/PDF; premium assets trigger gating), WS-11 (assets ride along in scene.json — bundled asset references serialize by stable id + inline path fallback, see T3), WS-15 (provenance audit is submission evidence).

## 4. Locked decisions binding this packet

- Module map §2: "`MKAssets` — bundled shapes, Arabic ornaments, frames, calligraphic elements, pattern backgrounds (vector, license-clear), asset browser model. Depends on MKModel."
- **D-111**: scene nodes are value types; `shape` node: path + transform + style (fill solid color v1, stroke, shadow), z-order, opacity, locked/hidden, name — assets must fit this exactly (no new node kinds without FOUNDATION change).
- **D-119**: "content gating (premium fonts, photo backgrounds, premium assets mark the project 'premium content present'); free tier exporting a premium-content project is blocked with replace-or-subscribe flow."
- **D-126**: browser UI data follows MKDesignSystem tokens (WS-13 renders); Arabic-first naming.
- BRIEF: "Reusable shapes/ornaments/frames/calligraphic elements/pattern backgrounds ARE in v1 as placeable assets"; "No templates in v1 (founder Q61–62: explicit no). Only a minimal extension seam"; free tier = solid color backgrounds only (Q34) — pattern backgrounds interact with this (see T8).
- FOUNDATION §12: no invented legal facts — asset licensing claims must be provable or the asset is not shipped.

## 5. Task breakdown (ordered)

**T1 — Asset model.** `MKAssetDescriptor`: `assetID` (stable string, e.g. `"ornament.islamic-star-8"`), `nameAr` ("نجمة ثمانية"), `category: MKAssetCategory` enum — `basicShapes (أشكال أساسية), ornaments (زخارف), frames (إطارات), calligraphicElements (حليات خطية), patternBackgrounds (خلفيات زخرفية)` — `tags: [String]` (Arabic), `isPremium: Bool`, `pathData: MKAssetGeometry` (vector: subpaths, fill rule, default styleable regions), `defaultAspect`, `provenanceRef`. Codable; library manifest `assets-manifest.json` in module resources. **AC:** decode test; every field documented; category enum locked to the five BRIEF classes (no invented categories).

**T2 — Provenance record + sourcing rules (the legal core).** `MKAssetProvenance`: `origin: enum {originalWork(author: String, date), derivedVerified(sourceURL, sourceLicense, licenseFilePath, transformationNote)}`, `verifiedBy`, `notes`. Write `Resources/ASSET_SOURCING_RULES.md`: (1) DEFAULT = original geometry authored for Makhtoot (procedurally constructed Islamic geometric patterns — girih/star-polygon constructions from mathematical definitions are not copyrightable as such; the *specific authored path data* is ours); (2) derivation permitted ONLY from sources with verified redistribution licenses (public-domain heritage pattern documentation, CC0, OFL font glyphs are NOT permitted as decorative assets without verifying OFL scope — avoid entirely in v1); (3) **forbidden**: clip-art sites, "free vector" aggregators, other apps' asset dumps, AI-image-tracing of unknown-provenance images, anything without a captured license file; (4) every shipped asset requires a provenance record; missing record = excluded by audit (T12). **AC:** rules doc complete; provenance schema tested; audit hook defined.

**T3 — Scene instantiation & serialization strategy.** `MKAssetInstantiator.place(asset:) -> MKNode`: shapes/ornaments/frames/calligraphic → `.shape` node with path payload + default style (theme-aware default fill from MKDesignSystem ink color) + `name = nameAr`; patternBackgrounds → `.background` node with pattern fill (T8 model). Serialization: placed nodes embed the FULL path data in scene.json (self-contained documents — a `.makhtoot` file must render on a device/app-version lacking that asset id), plus `assetID` provenance attribute for future dedup/re-link. Size: ornament paths target <30 KB JSON each; complex patterns use tile-reference + inline tile. **AC:** placed asset round-trips through scene Codable; document opens correctly with the asset id stripped (fallback to inline path proven by test); node behaves as plain shape to MKModel consumers.

**T4 — Basic shapes set (free).** Author programmatic generators: rectangle (+rounded), ellipse, triangle, polygon(n), star(n, innerRatio), line/arrow, crescent (هلال — two-arc boolean), semicircle/arc, drop/teardrop. Generated at instantiation with parameters where sensible (polygon/star keep params in node metadata for inspector editing seam — document, param editing UI is WS-06 scope). All FREE tier. **AC:** ≥10 shapes; geometry unit tests (winding, bounds); crescent renders correct even-odd fill.

**T5 — Arabic ornament set (mixed free/premium).** Author ≥16 original vector ornaments as procedural constructions + hand-authored paths: 8-point star (خاتم), 12-point star rosette, girih strapwork motif, arabesque scroll corner, palmette border unit, mandorla/lozenge medallion, interlaced band unit, muqarnas-silhouette frieze element, floral tawriq spray, simple mihrab-arch outline (architectural, non-textual). Free: 6; Premium: rest. Every asset: provenance `originalWork` with construction notes (e.g., "12-fold rosette from {12/5} star polygon, recorded in WS-14, 2026"). **AC:** each ornament has provenance + thumbnail + Arabic name/tags; visual QA sheet rendered (T11) reviewed for quality (no self-intersection artifacts, clean fills at 4K raster).

**T6 — Frames set.** ≥8 frames: rectangular rule frames (single/double/thick-thin), corner-ornamented frame (reuses T5 corner units as composed *single* path assets — composition at authoring time, still ONE asset, not a template), arch frame, circular/oval frames, cartouche (مخطوطة) outline. Frames scale-aware: authored as 9-slice-like path groups metadata (corners fixed-scale, edges stretch) — v1 simplification: uniform scale allowed, non-uniform documented as seam; keep model field now. **AC:** frames place + transform correctly; non-uniform-scale behavior documented; ≥3 free.

**T7 — Calligraphic decorative elements.** ≥10 divider/flourish elements: tarwīsa-style swash dividers, teardrop finial, bismillah-LENGTH rule (a plain ornamental rule — NO text, aniconic), knot motif, vine divider, dot-cluster (ثلاث نقاط) motif. These are drawn paths evoking calligraphic strokes (variable-width outlines baked as filled paths) — NOT font glyphs, NOT derived from any font file (avoids OFL-scope questions entirely — record in provenance). **AC:** zero font-derived paths (provenance audit greps origin notes); stroke-quality visual QA at large scale.

**T8 — Pattern backgrounds + free-tier interaction.** `MKPatternFill` model: vector tile (path set) + tile size + repeat mode (grid, half-drop) + two styleable colors (background/motif). ≥8 tiles: hexagonal lattice, 8-star tessellation, zellij-like interlock, diagonal qanat lines, dot grid, chevron, scallop (فلس), khatam repeat. Gating decision (per DECISIONS_LOG D-215): BRIEF Q34 locks *photo* backgrounds premium and free = "solid colors only" for backgrounds ⇒ pattern backgrounds are PREMIUM assets in v1 (consistent with locked text; solid colors remain the free background). Free users can still place ornaments as objects. **AC:** pattern renders tiled in preview + export paths (WS-07/08 contract: pattern fill rasterizes deterministically; SVG export emits `<pattern>` — coordinate contract note to WS-08); all patternBackgrounds `isPremium == true`; gating test with `free` entitlement stub blocks placement with paywall route.

**T9 — Asset browser model.** `MKAssetBrowserModel` (@Observable-friendly, UI in WS-13): sections by category (Arabic titles), search over nameAr/tags (reuse shared Arabic normalizer), favorites (toggle, persisted), premium badge state (from entitlement stream — lock badge when free), recently-used list (last 12, persisted metadata). Placement API: `select(asset:) -> MKNode` via instantiator + premium gate check → `.premiumRequired` routes paywall context `.premiumFeatureTap(.premiumAsset)`. **AC:** model unit tests: search "نجمة" finds stars; favorites persist (stub store); free-entitlement lock behavior; recents order.

**T10 — Thumbnails.** Deterministic thumbnail rasterizer: each asset → 200×200 pt template-rendered PNG at build/test time (checked-in generated resources) OR runtime-cached CG render (choose runtime render + LRU cache to avoid stale checked-in art; document). Theme-aware: thumbnails render with ink-on-paper token colors. **AC:** browser fixture shows all assets <16 ms/thumbnail first render, cached after; pattern thumbnails show 2×2 tile preview.

**T11 — Visual QA sheet.** Debug-only generator producing a contact-sheet image (all assets at 256 px + 1024 px) for manual review; forms the T-asset-01 evidence. **AC:** sheet generates; review notes recorded (artifacts fixed or asset pulled).

**T12 — Provenance audit.** Test target `AssetProvenanceAudit`: fails if any manifest asset lacks provenance; any `derivedVerified` lacks a captured license file; any provenance notes mention forbidden sources; category outside the locked five; premium flags missing. Mirrors WS-09 T20 pattern. **AC:** audit green; tamper test fails correctly.

**T13 — Premium-content project marking.** On placing any `isPremium` asset, the document gains `premiumContent.assets` flag entry (MKModel manifest field — coordinate: WS-02 owns manifest schema; WS-09/WS-08 use the same mechanism for fonts/photo backgrounds). Removing last premium asset clears it. Free-tier export of a marked project → WS-08 replace-or-subscribe flow lists the offending assets by Arabic name. **AC:** integration test: place premium ornament → flag set; delete → cleared; export gate sees the list.

**T14 — Arabic naming & tags pass.** Every asset: idiomatic Arabic name + ≥2 tags (e.g., نجمة ثمانية: ["هندسي", "إسلامي", "نجمة"]); no transliterated-English names. Reviewed against MKDesignSystem tone. **AC:** manifest lint: nameAr non-empty, Arabic-script regex; tag coverage.

**T15 — Docs + v2 seams note.** Module README: model, sourcing rules pointer, gating summary, explicit NON-goals (no templates — cite Q61–62; downloadable asset packs = v2 seam via manifest versioning field `libraryVersion`). **AC:** doc complete; seam limited to the version field + stable ids (no dormant download code).

## 6. Compliance & licensing notes

- Original-authorship posture: all v1 assets are original vector works recorded per-asset; no market-study citation needed because nothing is redistributed — the sourcing rules exist to keep it that way. Any future `derivedVerified` asset must follow the capture discipline of WS-09's protocol (license file + record) — same standard.
- Competitors ship ornament/shape libraries (Diwan's app: vector ornaments/shapes[^1]; Ana Khattat: arabesque decorations[^4]) — parity feature, but Makhtoot must not imitate their specific proprietary artwork; T5–T8 constructions must be independently authored (provenance notes are the evidence).
- No Qur'anic/religious text in assets (BRIEF Q67–68: no preloaded Qur'anic content of any kind — extends to decorative assets containing verses; aniconic geometry only). Mihrab/arch outlines are architectural forms, acceptable; anything text-bearing is excluded.
- Pattern-background premium gating derives from BRIEF Q34 free-tier "solid colors only" — documented as DECISIONS_LOG D-215, not an invention (see T8).
- Font-glyph-derived decorations avoided entirely in v1 (T7) — sidesteps OFL reserved-name/scope analysis; if ever revisited, run WS-09's verification protocol first. **VERIFY-AT-SUBMISSION:** nothing to verify externally if all provenance is `originalWork`; audit output is the submission evidence.

## 7. Packet acceptance criteria (gates)

1. **Build gate:** module + tests green, Swift 6 strict, no third-party deps; assets manifest decodes; total bundled asset payload <2 MB.
2. **Audit gate:** `AssetProvenanceAudit` green; zero assets without provenance; zero forbidden-source mentions; contact-sheet QA notes resolved.
3. **Manual Arabic checks (TEST_MATRIX `T-asset-*`):** T-asset-01 contact-sheet visual QA (both sizes); T-asset-02 browser: categories/search/favorites/recents in RTL; T-asset-03 place-transform-style each category on canvas (via WS-06) incl. undo; T-asset-04 premium gating with free entitlement (lock badges, paywall route, export block lists names); T-asset-05 pattern background tiling correctness at 3 canvas sizes + export spot-check; T-asset-06 document self-containment (open scene with assetIDs stripped).
4. **Export tie-in:** premium SVG export of an ornament yields vector `<path>` (not raster) — coordinated check with WS-08 (T-export cross-ref).
5. **Performance:** browser first-open <100 ms model build; thumbnail budget per T10.

## 8. Deliverables

- `MakhtootKit/Sources/MKAssets/**` (model, instantiator, pattern fill, browser model, thumbnail renderer, generators).
- `Resources/assets-manifest.json`, vector path resources, `Resources/ASSET_SOURCING_RULES.md`, provenance records store.
- `AssetProvenanceAudit` test target; unit/integration tests T1–T14; visual QA contact-sheet generator + reviewed sheets.
- Module README with seams/non-goals; DECISIONS_LOG D-215 (pattern backgrounds premium-gated) cited for pattern-background gating.
- Coordination notes: MKModel path-payload extension (if needed), WS-08 `<pattern>` export contract, manifest premium-content field (WS-02).

## 9. References

- FOUNDATION.md §2 module map (MKAssets), §4 D-111, §6 D-119, §9 D-126, §12 conventions.
- ARCHITECTURE.md: §3 Scene Graph & Data Model; §11 Rendering & Preview; §16 Export Pipelines (pattern/vector contract); §24 Extension Seams (asset packs v2).
- PRD.md: §11 Shapes/Ornaments/Assets & Imports; §14 Free/Premium Gating & Paywall; §13 Export; §21 Edge-Case Compendium.
- APP_STORE_CHECKLIST.md: content-provenance evidence item.
- BRIEF.md assets scope + Q34/Q61–62/Q67–68; market study §2 competitor asset features [^1][^4].
- TEST_MATRIX.md `T-asset-*` (+ T-export cross-refs).

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS-14-A1: self-contained serialization (inline paths + assetID) vs referenced assets"; "WS-14-A2: pattern backgrounds premium per Q34 derivation"; "WS-14-A3: original-authorship sourcing posture + forbidden sources"; "WS-14-A4: runtime thumbnails vs checked-in art".
- Implementation logs per task T1–T15.
- Verification evidence: provenance audit output, contact-sheet QA images + review notes, gating integration test results, self-containment test proof, asset payload size report.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Reusable shapes/ornaments/frames/calligraphic elements/pattern backgrounds ARE in v1 as placeable assets | §1 Mission; T4–T8 |
| No templates in v1 (Q61–62); only a minimal extension seam | §1 Mission (explicit NOT-templates statement); §2 OUT; T15 (seam owned by WS-13 T15, respected here) |
| Free tier = solid colors only for backgrounds; photo backgrounds premium-only (Q34) | T8 (pattern-background premium-gating derivation) |
| Free-tier gating: premium layers/elements | T13 (premium-content project marking) |
| No preloaded Qur'anic content of any kind (Q67–68) | §2 OUT; T7 (aniconic calligraphic elements, no text-bearing motifs) |
| Never invent licenses/permissions (extended to non-font provenance) | T2, T12 (sourcing rules + provenance audit) |
| v1 imports: raster/SVG/PDF as placeable assets/backgrounds (browser-listing boundary only) | §2 OUT; T9 (browser MAY list user-imported images, contract only — import pipeline is WS-02/06/08) |
| Gates (Q59): manual Arabic-script verification checklist | Gate 3, T-asset-* |
| Codebase-memory MCP conventions: durable ADRs, implementation logs, verification evidence per phase (Q58) | §10 |
