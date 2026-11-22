# Makhtoot (مخطوط) — FOUNDATION.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
## Authoritative Architectural Decisions & Cross-Document Conventions (Run 1)

This document is the single source of truth that every other deliverable in this package
(PLAN.md, PRD.md, ARCHITECTURE.md, FILE_MAP.md, DEPENDENCY_GRAPH.md, TEST_MATRIX.md,
APP_STORE_CHECKLIST.md, AGENT_TASK_PACKETS/*, DECISIONS_LOG.md) must conform to. If a
deliverable contradicts FOUNDATION.md, the deliverable is wrong. Decisions here are
expanded with full rationale/alternatives in DECISIONS_LOG.md using the same D-### ids.

Inputs: `_input/BRIEF.md` (locked requirements digest), `docs/founder Q&A.pdf`,
`docs/makhtoot-market-study.md` (research report with citations).

---

## Current access policy (D-328)

All implemented features are free to use. The iPhone and iPad app supplies that access
through the existing editor, font, export, and sync contracts at startup. The contracts
retain their legacy state and flag names for compatibility. StoreKit and app-managed
trials are inactive in the app, and the paywall and referral trial rewards are removed
from its user experience. Apple Account settings remain available for managing
subscriptions from earlier versions. Project sync is off by default and requires a
saved opt-in and an available iCloud account. Font licenses, import validation, and
exporter resource limits still apply.

The Android scaffold follows the free-access policy without Play Billing, an app
trial, or a paywall. The editor and project-sync implementation are still pending.

D-328 takes precedence over the paid access, trial, and referral requirements in the
original decisions, planning and release documents. Those records, including the
original product requirements and Android spine, preserve their historical
context. [Read D-328](DECISIONS_LOG.md#d-328--free-access-for-all-implemented-features).

## 0. Naming, identifiers, vocabulary

| Item | Value |
|---|---|
| Product name | Makhtoot / مخطوط (never Masoon) |
| App target | `Makhtoot` |
| Bundle ID | `net.binjamshid.makhtoot` ← **FD-01 confirmed** |
| Local Swift package | `MakhtootKit` |
| Module prefix | `MK` |
| Document package extension | `.makhtoot` (UTI `net.binjamshid.makhtoot.project`, FD-01 confirmed) |
| Scene schema version key | `schemaVersion` (integer, starts at 1) |
| Historical IAP product ids | `net.binjamshid.makhtoot.premium.monthly` / `.premium.annual` / `.premium.lifetime` (FD-01 confirmed) |
| Historical subscription group | `Makhtoot Premium` |
| CloudKit container | `iCloud.net.binjamshid.makhtoot` (FD-01 confirmed) |
| Feature flags | `MKFeatureFlags` (compile-time + local runtime) |

Canonical glossary (use these exact terms everywhere):
- **Live Text object** — reflowable, Core-Text-shaped text bound to a source string.
- **Arrange Mode** — explicit mode converting a Live Text object into an **Arranged
  Composition**.
- **Arranged Composition** — non-reflowing structure of Glyph Nodes, Mark Nodes,
  Ligature Groups with provenance back to the retained **Source Text Backup**.
- **Glyph Node / Mark Node / Ligature Group** — independently transformable scene nodes.
- **Joining Form** — isolated / initial / medial / final contextual form of a letter.
- **Path Text object** — live text laid on a Bézier path (still reflowable) until arranged.
- **Entitlement state** — legacy module contract with `lifetime`, `subscribed`,
  `inGracePeriod`, `inBillingRetry`, `trial`, and `free` states (D-113). The free-access
  app uses its unrestricted capabilities (D-328).

---

## 1. Locked platform & toolchain decisions

- **D-100 Platform**: Universal iPhone+iPad, iOS 18.0 minimum, Swift 6 language mode
  (strict concurrency), Xcode 16.x, SwiftUI app shell + UIKit canvas host. Arabic-only
  RTL UI (`ar` as the only localization; development region `ar`).
  Amended for Android by D-300 (`DECISIONS_LOG.md`) — D-100 remains authoritative for
  iOS; see §13 "Android platform" for the Android platform baseline.
- **D-101 Project layout**: One `Makhtoot.xcodeproj` app target + one local SPM package
  `MakhtootKit` containing all engine/feature modules as library targets (listed in §2).
  No third-party dependencies in v1. No XcodeGen/Tuist/Fastlane/CI services; build and
  distribute with `xcodebuild` + `gh` + App Store Connect (Chrome-driven where API-less).
  Amended for Android only by D-304's third-party carve-out (`DECISIONS_LOG.md`) —
  D-101's zero-third-party-dependency rule is unamended and fully in force for iOS.
- **D-102 Concurrency model**: `@MainActor` UI + document model; engines
  (shaping capture, export, sync, font install) are `Sendable` services running on
  structured-concurrency task groups; renderer works on immutable scene snapshots
  (value-type scene graph) so export/preview never race the editor.

## 2. Module map (targets inside MakhtootKit)

| Target | Responsibility | Depends on |
|---|---|---|
| `MKFoundation` | geometry, transforms, RTL utilities, ids, logging, errors, feature flags | — |
| `MKModel` | scene-graph value types, styles, provenance, Codable schema, migration | MKFoundation |
| `MKTextEngine` | Core Text shaping capture: attributed-string build, CTTypesetter/CTLine/CTRun introspection, glyph geometry, cluster→codepoint mapping, bidi run map, joining analysis, form resolution (ZWJ technique), font feature control | MKFoundation, MKFonts (font handles), MKModel (edge added in Run 3 per PLAN P3 entry criteria; ADR WS03-A5 in docs/impl-log/WS-03.md) |
| `MKArrange` | Live Text → Arranged Composition derivation; mark attachment; ligature grouping/decomposition/recomposition; join break/restore; form selection; revert-to-text | MKModel, MKTextEngine |
| `MKPathText` | arc-length parameterized Bézier layout for RTL/bidi text; live path editing; arrange-on-path | MKModel, MKTextEngine |
| `MKCanvas` | UIKit canvas view (UIScrollView + CALayer tree), gestures, selection, marquee, handles, guides, snapping, group transforms, zoom/pan, text-editing overlay (UITextView) | MKModel, MKRender |
| `MKRender` | scene renderer (Core Graphics), layer-backed preview, tile/bitmap caches, degradation ladder, hit testing geometry | MKModel, MKTextEngine |
| `MKColor` | color model (sRGB working space + P3 display), ICC profile handling, RGB→CMYK conversion, export color pipelines | MKFoundation |
| `MKExport` | JPEG/PNG(opaque+alpha)/SVG writer/PDF (vector, print CMYK), presets, tiled huge-raster rendering, export history records | MKModel, MKRender, MKColor, MKFonts, MKFoundation (access protocol) |
| `MKFonts` | bundled-font registry, optional hosted catalog and downloads, user import (validation, sandbox copy, process registration), favorites/tags/search, character coverage, license metadata, legacy access state | MKFoundation, MKPersistence (catalog store) |
| `MKPersistence` | `.makhtoot` file-package documents, atomic autosave + journaling, crash recovery, undo/redo command stack, SwiftData metadata index (projects, folders, search, export history, font catalog state, analytics counters), asset store | MKModel, MKFoundation |
| `MKSync` | opt-in CKSyncEngine project sync, conflict policy, account state, quota/errors | MKPersistence, MKFoundation (access protocol) |
| `MKStore` | legacy StoreKit 2 and trial contracts, implementations, and test fixtures | MKFoundation |
| `MKAnalytics` | opt-in consent, on-device aggregation of font-usage counters, anonymous batched upload via CloudKit public DB, kill switch | MKFoundation, MKPersistence |
| `MKDesignSystem` | theme protocol + default theme, semantic colors, Arabic type ramp, spacing/radius/motion tokens, RTL-first components (panels, inspector fields, sliders, chips) | MKFoundation |
| `MKAssets` | bundled shapes, Arabic ornaments, frames, calligraphic elements, pattern backgrounds (vector, license-clear), asset browser model | MKModel |
| App target `Makhtoot` | scenes, navigation (project browser, editor, settings, onboarding), panel/inspector UI, Settings→Support→Licensing | everything above |

### 2.1 Android module map (D-301, added 2026-07-30)

18 Gradle modules under `android/`, mirroring the 16 `MakhtootKit` targets above 1:1 plus
`:mk-native` (JNI facade, no Swift equivalent) and `:app`. Kotlin package root
`net.binjamshid.makhtoot`. Full rationale, dependency edges, and per-module LOC estimates are
in `ANDROID_SPINE.md` §3; this table exists so a `FOUNDATION.md` reader sees the Android
module boundary without leaving this document.

| Gradle module | Ports (Swift target) | Depends on |
|---|---|---|
| `:mk-native` | *(new)* HarfBuzz/FreeType/lcms2/hb-subset JNI facade | — |
| `:mk-foundation` | MKFoundation | — |
| `:mk-model` | MKModel | `:mk-foundation` |
| `:mk-color` | MKColor | `:mk-foundation`, `:mk-native` |
| `:mk-store` | MKStore legacy interfaces and stubs | `:mk-foundation` |
| `:mk-persistence` | MKPersistence | `:mk-model`, `:mk-foundation` |
| `:mk-fonts` | MKFonts | `:mk-foundation`, `:mk-persistence`, `:mk-native` |
| `:mk-textengine` | MKTextEngine | `:mk-foundation`, `:mk-fonts`, `:mk-model`, `:mk-native` |
| `:mk-arrange` | MKArrange | `:mk-foundation`, `:mk-model`, `:mk-textengine`, `:mk-persistence` |
| `:mk-pathtext` | MKPathText | `:mk-foundation`, `:mk-model`, `:mk-textengine`, `:mk-persistence`, `:mk-arrange` |
| `:mk-render` | MKRender | `:mk-foundation`, `:mk-model`, `:mk-textengine`, `:mk-pathtext`, `:mk-native` |
| `:mk-canvas` | MKCanvas | `:mk-foundation`, `:mk-model`, `:mk-render`, `:mk-designsystem` |
| `:mk-export` | MKExport | `:mk-foundation`, `:mk-model`, `:mk-render`, `:mk-color`, `:mk-fonts`, `:mk-textengine`, `:mk-pathtext`, `:mk-native` |
| `:mk-sync` | MKSync → Google Drive `appDataFolder` | `:mk-persistence`, `:mk-foundation` |
| `:mk-analytics` | MKAnalytics | `:mk-foundation`, `:mk-persistence` |
| `:mk-designsystem` | MKDesignSystem | `:mk-foundation` |
| `:mk-assets` | MKAssets | `:mk-foundation`, `:mk-model` |
| `:app` | `Makhtoot` app target | feature modules, with free access from `:mk-foundation` |

Entitlement access from any module (including `:mk-export`) is via the `MKEntitlementProviding`
protocol in `:mk-foundation` — there is **no** `:mk-export → :mk-store` edge and **no**
`:mk-sync → :mk-store` edge, mirroring the iOS table's own `MKEntitlementProviding` seam
(D-230) above.

## 3. Text/glyph engine decisions (the differentiator)

- **D-103 Shaping source of truth**: Apple Core Text does all shaping. Build
  `NSAttributedString` (font, features, kerning/tracking, baseline) →
  `CTTypesetterCreateWithAttributedString` → `CTLine`/`CTRun`. Extract per run:
  `CTRunGetGlyphs`, `CTRunGetPositions`, `CTRunGetAdvances`, `CTRunGetStringIndices`,
  attributes, `kCTRunStatusRightToLeft`. Glyph outlines via `CTFontCreatePathForGlyph`.
  Never write a shaper; never use Unicode presentation-forms codepoints for rendering.
- **D-104 Typing mode**: In-canvas editing uses a UITextView (TextKit 2) overlay for
  IME/keyboard/selection correctness; committed rendering of Live Text objects is always
  the MKTextEngine→MKRender path so canvas and export are pixel-identical. The overlay
  is styled to match metrics; on commit (end editing) the overlay disappears and the
  engine-rendered object remains.
- **D-105 Cluster model**: Build a bidirectional map — codepoint index ↔ cluster ↔
  glyph(s) — from `CTRunGetStringIndices`. A cluster with >1 codepoint and 1 glyph =
  ligature candidate (e.g., lam-alif); combining marks (Unicode categories Mn/Me, incl.
  U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED Qur'anic annotation range) become Mark
  Nodes attached to their base Glyph Node with recorded relative offset (GPOS result
  captured from shaped positions).
- **D-106 Arrange derivation**: Entering Arrange Mode snapshots the shaped result into
  an Arranged Composition: Glyph Nodes (glyph id, font ref, path, position, advance,
  joining state, source codepoints), Mark Nodes (attached, relative offset, follow-base
  default), Ligature Groups (member glyph node + constituent codepoints + decomposable
  flag). Source string + full style state stored as Source Text Backup; revert requires
  confirmation and discards arrangement.
- **D-107 Joining forms after explicit break**: To realize a chosen form for a letter,
  reshape the single letter in a synthetic context using U+200D ZWJ (e.g., ZWJ+ح+ZWJ for
  medial) through the same font, then harvest that glyph. Guarantees font-consistent
  contextual forms without presentation-form cmap dependence. Store as
  `JoiningForm` enum + resolved glyph id.
- **D-108 Ligature decomposition**: Decomposing a Ligature Group reshapes constituents
  with joining-preserving context, then places them with computed offsets matching the
  original ligature bounds (visual fidelity default); user opt-out switches to default
  spacing/forms. Recomposition restores the stored original ligature glyph. Discretionary
  ligatures toggled via Core Text font features (`kLigaturesType` /
  OpenType `dlig`/`calt` feature settings) before arrangement.
- **D-109 Bidi**: Preserve CTLine run order and `kCTRunStatusRightToLeft` per run;
  arranged nodes keep `bidiLevel` + visual index so Latin/Arabic sub-runs stay coherent;
  paragraph base direction from `NSParagraphStyle` (default RTL).
- **D-110 Path text**: Arc-length LUT over the Bézier path; pen advances along arc length
  in visual order (RTL-aware), each glyph gets position = arc point, rotation = local
  tangent, plus user offset. Live Path Text stays reflowable (retype → relayout); Arrange
  freezes to Arranged Composition with per-glyph adjustability retained. Path remains
  editable (control points) in live mode only.

## 4. Scene graph, persistence, documents

- **D-111 Scene graph**: Immutable value-type tree (`MKScene` → `MKNode` enum cases:
  `group`, `liveText`, `pathText`, `arranged(text)`, `shape`, `image`, `background`).
  Node: `id: UUID`, transform (position/rotation/scale, decomposed, not raw matrix),
  z-order, opacity, style (fill: solid color v1; stroke; shadow), locked/hidden, name.
  Arranged children: glyph/mark/ligature nodes with provenance (codepoints, glyph id,
  font reference, joining form, cluster id). Single canvas per project in v1 (multi-page
  is an extension seam).
- **D-112 Persistence (the decisive recommendation)**: **File-package documents + JSON
  scene + SwiftData metadata index.**
  - Project = `.makhtoot` file package: `manifest.json` (ids, schemaVersion, canvas size,
    thumbnail refs), `scene.json` (Codable scene graph), `assets/` (imported
    raster/SVG/PDF, content-addressed), `backups/` (Source Text Backups are embedded in
    scene nodes; `backups/` holds rescue snapshots), `thumbnail.png`.
  - Atomic writes: write-temp + rename; debounced autosave (≤2 s after mutation, plus
    immediate on background/memory-pressure); crash-recovery journal of the last
    un-flushed command batch.
  - Undo/redo: in-memory command stack of inverse operations on the value-type scene
    (unbounded within memory budget, coalesced gestures = single command).
  - SwiftData store (app support dir) holds ONLY metadata: project list, folders, names,
    search text (project titles + layer names only — never scene text content), export
    history, font catalog/favorites/download state, analytics
    counters, and consent records. Never the scene graph.
  - Optional CloudKit sync: CKSyncEngine, one record per project (manifest+scene as
    encrypted-asset payloads, assets as CKAssets); last-writer-wins per project with
    conflict copy fallback ("(نسخة متعارضة)").
  - Rejected alternatives (full rationale in DECISIONS_LOG D-112): pure SwiftData/Core
    Data scene storage (object-graph churn vs undo/value semantics, migration risk,
    poor huge-blob behavior), GRDB/SQLite scene rows (adds dependency, no benefit at v1
    scale), NSDocument/UIDocument+iCloud Drive (weaker control than CKSyncEngine for
    selective project sync).

## 5. Rendering, canvas, performance

- **D-114 Renderer**: Core Graphics scene renderer; canvas = UIScrollView-zoomable
  UIView with a CALayer per top-level node (transform changes are layer-property
  updates → cheap 60/120 Hz manipulation); node content drawn by CG into layer contents
  at current zoom scale with bitmap caching. Metal is a documented extension seam only
  (adopt only if profiling gates fail).
- **D-115 Budgets** (gates in TEST_MATRIX): manipulation frame time ≤8.3 ms on
  ProMotion hardware, ≤16.6 ms floor on A12-class; typing echo <50 ms; open typical
  project (≤100 nodes) <1 s, heavy (5 000 nodes) <3 s; incremental autosave <100 ms off
  main thread; 4K PNG export <10 s on A15; cold launch to interactive browser <1 s on
  A15-class; editor working-set design target <60 % of `os_proc_available_memory`
  (the D-116 degradation ladder is the enforcement mechanism and begins at 70 % used —
  60 % is the engineering target, 70 % the first ladder trigger).
- **D-116 Memory-pressure ladder**: monitor `DispatchSource` memory-pressure events +
  periodic `os_proc_available_memory` sampling. Stages: (1) 70 % — drop offscreen bitmap
  caches, autosave now; (2) 85 % — degrade preview fidelity (half-res layer bitmaps,
  simplified shadows), warn user banner "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا";
  (3) critical event — synchronous **journal-only** flush (append-only, no re-encode;
  full-scene autosave stays at stages 1–2 and the normal debounced path only, per
  D-223); recovery on relaunch restores exactly. Huge exports render tiled (bounded
  strips) so output size is limited only by disk, not RAM.

## 6. Color & export

- **D-117 Color pipeline**: working space = extended sRGB; UI picks/display in P3-aware
  SwiftUI/UIKit colors; document stores sRGB components (+ optional named swatch).
  Print PDF export converts through ICC: source sRGB → CMYK via
  `CGColorSpace(iccData:)` CMYK profile with relative colorimetric intent by CG
  conversion; profile embedded in PDF (OutputIntent). Bundled profile choice =
  **FD-03 founder decision** (candidates: eciRGB/ISO Coated v2 class profiles —
  redistribution license must be verified, never assumed; fallback: Apple Generic CMYK,
  documented as lower fidelity). **RESOLVED 2026-07-19: Apple Generic CMYK for v1
  (licensed profile = v1.1 seam)**. v1 has no on-screen soft-proofing; documented limitation
  + verification via external tooling in TEST_MATRIX.
- **D-118 Export matrix (access amended by D-328)**: single render path from the scene
  snapshot (never screen capture). The app makes all implemented formats and resolutions
  available for free, including JPEG, opaque and transparent PNG, SVG, vector and
  raster PDF, and CMYK print PDF. The print preset uses 300 DPI for raster content.
  Raster export uses tiled CGBitmapContext strips. PDF: vector paths + live-text runs; live text
  in OFL fonts draws as text with subset embedding, otherwise outlines (per-license
  switch). SVG: custom serializer; Live Text → `<text>` (+`@font-face` embed only when
  license allows); Arranged/transformed glyphs → `<g><path>` with
  `data-mk-*` provenance attributes (source text, codepoints, font name) so editability
  intent is preserved; every outline fallback is per-feature documented, never silent.
- **D-119 Gating (superseded by D-328)**: the app makes implemented import, editing,
  and export features available for free, including for projects carrying legacy paid
  content flags. Technical and font-license checks still apply.

## 7. Fonts

- **D-120 Bundled starter set**: OFL-verified only; initial candidates (each requires
  the WS-09 verification protocol before inclusion): Amiri, Amiri Quran, Noto Naskh
  Arabic, Noto Kufi Arabic, Noto Sans Arabic, Scheherazade New, Lateef, Harmattan,
  Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El Messiri, Markazi Text, Rakkas,
  Katibeh, Jomhuria, Mirza, Qahiri. No font ships without a captured license file +
  verification record. KFGQPC/Uthmani fonts are prohibited (non-commercial EULA).
  Per-font fidelity gate (D-222): at the moment a font passes WS-09 license
  verification it must also pass the arrange-fidelity block (T-AR-31/32/33 +
  decompose/recompose round-trip T-AR-36..38), not just the reduced sweep T-AR-58,
  before it ships.
- **D-121 Catalog delivery (access amended by D-328)**: the checked-in configuration
  uses bundled delivery. The catalog module supports a hosted HTTPS manifest and
  font files for deployments configured with an endpoint and distribution rights.
- **D-122 Registration & import (amended by D-219)**: all non-system fonts register per-process via
  `CTFontManagerRegisterFontURLs(.process)` at launch/on-demand. User import is free.
  The Files picker leads to sfnt validation (accept ttf/otf/ttc/variable, reject
  woff/woff2/bitmap-only/corrupt with specific Arabic errors), then content-addressed
  copying to the container, registration, and a catalog entry flagged `userImported`.

## 8. Feature access, sync, analytics

- **D-113 Entitlement precedence (historical)**, **D-123 Trial (superseded)** and
  **D-124 Referral (superseded)** describe the earlier access model. D-328 governs
  the app's access and subscription settings. Earlier trial records may still exist
  in Keychain or iCloud key-value storage.
- **D-125 Analytics**: default OFF; explicit opt-in switch in Settings (consent record
  versioned). On-device counters: (fontID → usage count buckets). Upload: anonymous
  batches to CloudKit **public** database with random ephemeral batch UUID, no user
  record link, no timestamps finer than week, counts bucketed; no third-party SDK.
  Never: text, projects, identifiers, font files.

## 9. Design system

- **D-126**: Token-based `MKTheme` (semantic colors, Arabic type ramp — UI font: system
  SF Arabic; display/preview fonts from catalog — spacing 4-pt grid, radii, elevation,
  motion durations), RTL-first components, all UI strings in `ar` only.
  Baseline aesthetic (editable founder decision FD-02): "حبر ورق" (Ink & Paper) — modern
  Arabic editorial minimalism: warm paper neutrals, ink-dark foregrounds, one deep accent
  (madder red family), generous whitespace, calligraphy-forward previews. Chosen for
  contrast with competitor skeuomorphism and neutrality for later re-theme.

## 10. Founder decision register

| ID | Decision needed | Blocking |
|---|---|---|
| FD-01 | Real bundle id, team, repo name/org (`git init` by founder) | Distribution phase |
| FD-02 | Approve/edit baseline aesthetic "حبر ورق" after design run | Visual polish phase |
| FD-03 | CMYK ICC profile selection + license verification (or Apple Generic CMYK fallback) | Print-PDF export QA |
| FD-04 | Font hosting location (static HTTPS) or bundled delivery | Optional hosted catalog |
| FD-05 | Referral activation | Historical (superseded by D-328) |
| FD-06 | Family Sharing ON/OFF for lifetime + subscriptions (irreversible per product) | Historical App Store product setup |
| FD-07 | Paid commercial foundry licensing budget/process (v1.1+; v1 = OFL only) | Post-v1 |

### 10.1 Android founder decisions (FDA-01…FDA-08, added 2026-07-30)

Decided or defaulted by the founder alongside the 2026-07-30 Android-port authorization
(`ANDROID_SPINE.md` §1). FDA-01/FDA-02/the FDA-03 carve-out were founder-decided directly;
the rest carry defaults chosen so the port never stalls mid-batch — each is revisable later
without invalidating completed work.

| ID | Decision | Blocking |
|---|---|---|
| FDA-01 | Planned project sync mechanism on Android: Google Drive `appDataFolder` (D-310). Android↔Android only — never iOS↔Android | Batch 6 (G6) |
| FDA-02 | Android code lives in `android/` inside this monorepo (D-301) | Batch 1 (G1) |
| FDA-03 | CMYK ICC profile for Android: lcms2 synthetic generic CMYK default (D-315); Apple Generic CMYK is not redistributable in an Android APK | Print-PDF export QA (G5) |
| FDA-04 | Analytics upload endpoint: no-op uploader by default, never a third-party SDK (D-320) | Never blocks v1 |
| FDA-05 | Play product ids: `net.binjamshid.makhtoot.premium` with base plans `monthly`/`annual`; lifetime INAPP `net.binjamshid.makhtoot.premium.lifetime` (D-311) | Historical (superseded by D-328) |
| FDA-06 | Play Console + merchant account — founder-only | First blocks G6 (OAuth consent screen), binds fully at G9 |
| FDA-07 | minSdk 29 (Android 10) — deletes the API 26–28 render fallback entirely (D-305) | Batch 1 (G1) |
| FDA-08 | iOS gains zipped-`.makhtoot` import/export (D-309), one iOS-side agent in Batch 9 | Batch 9 (G9) |

## 11. Canonical document outlines (cross-reference targets)

Cross-references between deliverables MUST use these section titles.

**PRD.md**: 1 Overview & Personas · 2 Information Architecture & Navigation · 3 Project
Browser & Documents · 4 Canvas Editor · 5 Typing & Live Text · 6 Arrange Mode ·
7 Tashkeel & Marks · 8 Ligatures & Joining · 9 Path Text · 10 Layers & Inspector ·
11 Shapes/Ornaments/Assets & Imports · 12 Fonts & Catalog · 13 Export · 14 Free/Premium
Gating & Paywall · 15 Trial/Subscription/Lifetime States · 16 Referral (flagged) ·
17 iCloud Sync · 18 Analytics & Privacy · 19 Offline Behavior · 20 Settings & Licensing ·
21 Edge-Case Compendium · 22 Non-Functional Requirements · 23 Out of Scope / v2 Seams

**ARCHITECTURE.md**: 1 System Overview · 2 Module Architecture · 3 Scene Graph & Data
Model · 4 Text Engine (Shaping Capture) · 5 Arrange Mode Engine · 6 Tashkeel/Marks
Mechanics · 7 Ligature & Joining Mechanics · 8 Bidi Model · 9 Path Text Engine ·
10 Canvas & Interaction · 11 Rendering & Preview · 12 Performance & Memory ·
13 Persistence & Documents · 14 Undo/Redo & Autosave · 15 Color Management ·
16 Export Pipelines (JPEG/PNG/PDF/SVG/CMYK) · 17 Fonts Subsystem · 18 StoreKit &
Entitlements · 19 Trial & Referral · 20 CloudKit Sync · 21 Analytics · 22 Design System ·
23 Security & Privacy · 24 Extension Seams (v2) · 25 Risks & Mitigations

**PLAN.md phases**: P0 Scaffold · P1 Design System & Shell · P2 Model & Persistence ·
P3 Text Engine · P4 Canvas Core · P5 Arrange Mode · P6 Marks/Ligatures/Forms · P7 Path
Text · P8 Assets & Imports · P9 Fonts · P10 Export · P11 Store & Gating · P12 Sync ·
P13 Analytics/Settings · P14 Performance Hardening · P15 Distribution.

**Workstreams / AGENT_TASK_PACKETS** (file names): `WS-01-scaffold-designsystem.md`,
`WS-02-model-persistence.md`, `WS-03-text-engine.md`, `WS-04-arrange-engine.md`,
`WS-05-path-text.md`, `WS-06-canvas-interaction.md`, `WS-07-rendering-performance.md`,
`WS-08-export-pipeline.md`, `WS-09-fonts-licensing.md`, `WS-10-storekit-entitlements.md`,
`WS-11-cloudkit-sync.md`, `WS-12-analytics-settings.md`, `WS-13-app-shell-browser.md`,
`WS-14-assets-ornaments.md`, `WS-15-distribution.md`.

## 12. Conventions for all deliverables

- Arabic UI strings appear in Arabic with a Latin gloss in parentheses on first use.
- Requirement IDs: PRD uses `R-<section>.<n>` (e.g., R-6.12); architecture invariants
  `INV-<n>`; tests `T-<area>-<n>`; decisions `D-1xx` (foundation) and `D-2xx+`
  (per-document expansions); founder decisions `FD-0x`.
- No invented legal/policy facts: licensing and App Review claims must cite the market
  study reference numbers or be marked `VERIFY-AT-SUBMISSION`.
- Every deliverable ends with a "Traceability" section mapping its content to BRIEF.md
  requirement bullets.

## 13. Android platform (D-300…D-325, added 2026-07-30)

Founder-authorised 2026-07-30. This section summarizes the Android decision register at the
same density as §1–§9; full rationale, alternatives, and consequences for every `D-3xx` id
are in `DECISIONS_LOG.md` Part II, and the frozen execution spec is `ANDROID_SPINE.md`. Where
this section and `DECISIONS_LOG.md`/`ANDROID_SPINE.md` disagree, those documents are right and
this summary has a bug — the same authority-chain rule §0 of this document already implies.

**Platform and layout.** Phone + tablet + foldable, minSdk 29, compileSdk/targetSdk 36,
Kotlin 2.1, Jetpack Compose, AGP 8.7+, JDK 17, NDK r27, Arabic-only UI forced to `ar` (D-300,
amends D-100 for Android only). `android/` Gradle build, 18 modules mirroring `MakhtootKit`
1:1 plus `:mk-native`/`:app` (D-301, §2.1 above). Kotlin coroutines + `StateFlow`, immutable
value-type scene graph — the same race-free guarantee `@MainActor` gives iOS (D-302, mirrors
D-102). No KMP, no Flutter, no React Native — the shipped Swift engine is ported, not
rewritten (D-323). A narrow, named carve-out to D-101's zero-third-party-dependency rule
applies **on Android only** — HarfBuzz, FreeType, and lcms2 are vendored (no platform
equivalent exists), plus JVM-side AndroidX/Play Billing/Drive/kotlinx-serialization/OkHttp;
no analytics SDK, ever, is not part of the carve-out and stays absolute (D-304; D-101 itself
is unedited and stays zero-dependency for iOS).

**Shaping and rendering.** HarfBuzz (`hb_shape`) + FreeType + ICU BiDi via one JNI facade
replaces Core Text **on Android only** — D-103 stays the shaping source of truth for iOS,
unedited (D-303). This is the plan's highest-risk substitution: two independent OpenType
shapers will diverge on edge cases, mitigated by fixture-based parity (D-324) and a
three-class shaping-delta register where **Class-B deltas (dropped/added/reordered marks,
changed glyph ids, broken ligatures, changed joining forms, tashkeel loss) can never be
registered and are always a hard gate failure** (D-325) — the mechanical expression of this
document's own "never write a shaper" invariant across two shaper stacks instead of one.
Rendering is Skia via `android.graphics.Canvas`, one `RenderNode` per top-level node, no
fallback below API 29 (D-305, mirrors D-114). Canvas host is a custom `MkCanvasView` with an
owned pan/zoom transform matrix, not `ScrollView` (D-306). Text editing is a transparent
`EditText` + custom `InputConnection` overlay; committed rendering always goes through the
engine, mirroring D-104 (D-307).

**Persistence, interchange, sync.** `.makhtoot` as a directory, byte-identical layout to iOS;
Room replaces SwiftData for metadata only, never the scene graph (D-308, mirrors D-112).
Zipped `.makhtoot` is the cross-platform interchange format; iOS gains zip import/export in
Batch 9 (D-309, FDA-08). Planned project sync uses Google Drive `appDataFolder` — Credential Manager for
identity, a separate GIS `AuthorizationClient` step for the Drive scope; Android↔Android only,
never iOS↔Android (D-310, replaces the CloudKit clause of D-112 on Android only; FDA-01).

**Access, fonts, colour, export.** D-328 supersedes the original Play Billing (D-311),
trial (D-312), and 2 MP access cap in the raster export design (D-313).
The port's design opens bundled fonts directly from `AssetManager` via HarfBuzz/FreeType
blobs and imports fonts through SAF with the same sfnt validator (D-316). The design
uses lcms2 via NDK for sRGB→CMYK (D-315) and an in-house print PDF writer in
`:mk-export` for CMYK output intents (D-314).

**Design system, localisation, accessibility, analytics, referral, distribution.** `MkTheme`
via Compose `CompositionLocal`s, not `MaterialTheme`; all 5 themes ported with identical
tokens (D-317, mirrors D-126). `resConfigs("ar")` + per-app locale pinned to `ar` regardless
of device locale — a new platform for the same Arabic-only product, not a new localization
(D-318). TalkBack replaces VoiceOver, 48dp touch-target floor replacing 44pt (D-319, Android
elaboration of this document's accessibility quality bar). Analytics ports verbatim: default
OFF, on-device counters, kill switch; only the upload transport differs (D-320, mirrors
D-125; FDA-04). D-328 supersedes the referral trial-reward design. Distribution is
AAB + Play App Signing + Play Data Safety
form, an internal → closed → production track ladder (D-322; FDA-06).

**Verification.** Parity is enforced by golden fixtures exported from the iOS engine, not by
human review — this document's own "shaping regressions are invisible in review" principle,
extended to a two-shaper world (D-324).
