# PROJECT_DESCRIPTION.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.

## Overview

Makhtoot / مخطوط is an iPhone-and-iPad-first Arabic typography and design app for
people who want to design *with* the Arabic letter, not around it — calligraphy
lovers, Arabic designers, social-media creators, and small businesses who currently
have to fight general-purpose design tools (built shaping-blind, for Latin scripts)
to get Arabic text to look right.

Its working promise is:

> Where the Arabic letter becomes design.

The app is Arabic-only at launch (UI, RTL, no localization into other languages) —
this is not a gap to close later, it is the strategic bet: be the best possible tool
for Arabic text manipulation rather than an adequate one for many scripts.

**Status:** the iPhone/iPad app is **not yet on the App Store**. As of 2026-07-23 it is
**uploaded to TestFlight** (build `1.0 (20260723.1)`, processing in App Store Connect —
the first build ever archived/uploaded for this project) and needs the founder's own
device verification pass, real legal URLs, and App Store Connect IAP/metadata setup
before App Store submission is realistic. See *Launch direction* below for the exact
remaining list. **Android port status (added 2026-07-30):** the founder authorized an
Android port on 2026-07-30, overriding this document's prior "no Android port" statement.
The port is tracked separately from the iOS status above — it is a from-scratch, 66-agent,
10-batch build against the shipped Swift engine as an executable spec, not yet started as
of this note. Full authority is `ANDROID_SPINE.md` (frozen execution spec) and the `D-300`–
`D-325` decision register in `DECISIONS_LOG.md` (summarized in `FOUNDATION.md` §13); Android
code lives entirely under `android/` and never touches `MakhtootKit/` or `Makhtoot/`.

Its strongest differentiator, unmatched by any general-purpose design app: **Arrange
Mode** — an explicit, reversible step that turns normally-shaped Arabic text into a
fully manipulable composition where every glyph, tashkeel mark, and ligature component
is its own independently transformable object, without ever breaking Arabic shaping
rules unless the user explicitly asks to.

## Product vision

Makhtoot should feel like a design tool built *from* the Arabic letter outward, not a
Latin-first design tool with Arabic support bolted on. Every other mainstream design
app (Canva, Photoshop, Procreate, Adobe Express, etc.) either mishandles Arabic
shaping/joining entirely or treats Arabic text as an opaque, unstyleable text block.
Makhtoot's bet is that real per-glyph control over Arabic composition — the kind
calligraphers and sign-painters have always had by hand — is a defensible product
moat, not a feature checkbox.

The app should help users:
- write real, correctly-shaped Arabic text as easily as any native text field
- go one explicit step further and manipulate that text at the glyph/mark/ligature
  level when they want full creative control
- compose full static designs (posters, social posts, logos, cards) around that text
- export at a quality level (including true print-ready CMYK PDF) that a
  professional printer or serious social presence can actually use

The product should prioritize **correctness of the Arabic engine first**, and
**creative flexibility around it second** — a beautiful canvas with wrong Arabic
shaping is worse than no product at all for this audience.

## Target user

The first design persona is a person who already designs Arabic content today —
social posts, invitation cards, small-business logos, posters — using tools that
were never built for Arabic, and who has learned to work around broken tashkeel
positioning, wrong contextual letterforms, or unstyleable connected text. They know
what "wrong" looks like the instant they see it.

A second persona, served by the same engine, is someone doing genuine Arabic
calligraphic/typographic composition (Thuluth-style phrases, wordmarks, ornamental
arrangements) who wants glyph-level control without hand-tracing every letter in a
vector tool.

## Product principles

1. Correct Arabic shaping/joining/tashkeel is non-negotiable table stakes, not a
   differentiator by itself — Arrange Mode is the differentiator.
2. Arrange Mode is an explicit, reversible user action, never an automatic or
   irreversible transformation of the user's source text.
3. No artificial premium caps on canvas size, glyph count, or object count — premium
   gates *capability* (fonts, export formats/resolution, sync), never scale.
4. The app must be fully useful **offline**. Network is only ever needed for premium
   font downloads, premium iCloud sync, and anonymous opt-in analytics upload.
5. No accounts required. No ads. No tracking beyond opt-in, aggregated font-usage
   analytics that never touches user text or project content.
6. No Qur'anic content or features of any kind, ever, without explicit founder
   approval and a licensing/accuracy review — user-entered text is treated
   identically regardless of content.
7. Never invent or silently soften a quality claim (e.g. CMYK fidelity) beyond what
   the actual rendering pipeline delivers.
8. Zero third-party dependencies in v1 — every subsystem (rendering, sync, StoreKit,
   persistence) is built on first-party Apple frameworks.

## Core user experience goals

After using Makhtoot once, the user should feel:

> I finally have a design tool that respects how Arabic actually works.

The core loop should make it easy to:
- type Arabic (and mixed Arabic/Latin/numerals) exactly as expected, immediately
- explicitly enter Arrange Mode when they want glyph-level control, and trust that
  reverting always gets them back to the original text losslessly
- compose a full static design with shapes, images, ornaments, and multiple text
  objects, then export it at a quality appropriate to where it's going

## MVP feature priorities

### Must-have (v1, locked by the founder's brief)
- Correct Arabic shaping, contextual forms, ligatures, tashkeel, RTL/LTR bidi, mixed
  Arabic-English text, Arabic-Indic + Latin numerals, punctuation
- Arrange Mode: glyph/mark/ligature-level manipulation, joining break/restore with a
  contextual-form selector, ligature decompose/recompose, reversible revert-to-text
- Curved/circular/freeform text on live, editable Bézier paths
- Full canvas: drag/resize/rotate/multi-select, alignment/snapping, layers, grouping,
  lock/hide, undo/redo, zoom/pan
- Local autosave with no-loss crash recovery, project folders, search, duplicate,
  export history
- Curated bundled Arabic fonts (free) + a premium downloadable font catalog +
  premium custom font import
- Reusable placeable assets: shapes, ornaments, frames, calligraphic elements,
  pattern backgrounds
- Export: free (JPEG + rasterized PDF, 2MP cap); premium (opaque/transparent PNG,
  SVG with editable text/vectors where feasible, high-res true-CMYK print PDF)
- StoreKit 2 freemium: $2.99/mo, $29.99/yr, $89.99 lifetime; a 7-day app-side trial
  from first launch (not an Apple introductory offer — see *Monetization* below)
- Premium iCloud project sync (CloudKit, the user's own account)

### Nice-to-have if quality remains high
- Referral flow (architected, compile-time gated OFF by default — see *Monetization*)
- Commercial foundry font licensing (data-model hooks only in v1)

### Delayed / explicitly out of scope for v1
- Animation/video/reels (v2)
- Templates (explicit founder "no" — only a minimal extension seam exists)
- Accessibility work (explicit founder "no" for v1 — no material scope allocated)
- Any Qur'anic content/feature
- Non-Arabic UI localization

## Current feature surface (as built)

The sections above capture original intent (`FOUNDATION.md`/`PRD.md`/`_input/BRIEF.md`,
Run-1 planning). The shipped code (`MakhtootKit/` SwiftPM package + the `Makhtoot`
SwiftUI app target) implements essentially all of it as of the P0–P14 build; this
catalog is descriptive of what exists in the codebase tonight, grounded in
`docs/impl-log/WS-*.md`'s as-built evidence, not aspirational.

### Arabic text & glyph engine
- `MKTextEngine`: shaping via Apple's text APIs (Core Text/TextKit 2), contextual
  forms, ligatures, tashkeel attachment, bidi, mixed Arabic/Latin runs,
  Arabic-Indic/Latin numeral handling.
- `MKArrange`: the Arrange Mode engine — derives an independently-manipulable
  composition (glyphs, marks, ligature groups, joining state) from shaped text;
  join break/restore with a contextual-form selector (isolated/initial/medial/
  final); ligature decompose/recompose with fidelity-clamp auto-refusal where
  recomposition would visibly change the result; reversible revert-to-source-text
  with a confirmation gate; per-child position/rotation/scale/opacity/style edits.
- `MKPathText`: curved/circular/freeform live Bézier path text, editable until
  arranged, with independent glyph adjustments preserved afterward.

### Canvas, rendering & performance
- `MKCanvas`: drag/resize/rotate/multi-select, alignment/snapping, layers panel,
  grouping, lock/hide, full undo/redo, zoom/pan, adaptive iPhone/iPad chrome
  (`NavigationStack` compact / `NavigationSplitView` regular).
- `MKRender`: a custom Core Graphics-based render tree (D-114: no Metal in v1),
  bitmap-cache layer tree, incremental re-rasterization on bucketed zoom scale.
- `MKMemoryGovernor` + `MKDegradationController` (D-116/D-223): a cross-module
  memory-pressure ladder (`.normal → .stage1 → .stage2 → .critical`) that evicts
  offscreen/all cached bitmaps and forces a save-before-degrade autosave/journal
  flush ahead of any eviction — no artificial canvas/object-count caps, engineering
  degradation instead.
- `os_signpost` instrumentation across manipulation-frame, typing-echo, document-open,
  autosave, export, arrange-derive, and render-internal categories for Instruments
  profiling.

### Projects, persistence & sync
- `MKPersistence`: `.makhtoot` package documents (SwiftData-backed metadata index as
  a rebuildable cache, not the source of truth), command-journal crash recovery,
  debounced incremental autosave, project folders/search/duplicate/export history.
- Real `.onOpenURL` document opening (Files.app/AirDrop/"Open In"): imports and
  registers an external `.makhtoot` package idempotently by its own durable id, or
  opens the existing project directly if already known.
- `MKSync`: CloudKit sync engine (`CKSyncEngine`), per-project change tracking,
  last-write-wins with Arabic-numbered conflict copies («نسخة متعارضة»), premium
  gating, account-state machine, quota/error taxonomy.

### Fonts, color & export
- `MKFonts`: bundled open-license starter fonts, a premium downloadable catalog with
  verified redistribution rights and license records, premium custom font import.
- `MKColor`/`MKExport`: JPEG/PDF (free, 2MP cap); premium opaque/transparent PNG, SVG
  (editable text/vectors where feasible), and high-res print PDF in **Apple Generic
  CMYK** (FD-03: the founder-resolved v1 choice — a licensed ICC profile is an
  explicit v1.1 seam, not shipped; v1 CMYK PDFs are whole-page raster, not vector,
  at print resolution — product/App-Store copy is deliberately not overclaiming
  fidelity here, per D-117).
- `MKAssets`: bundled shapes, ornaments, frames, calligraphic elements, pattern
  backgrounds as placeable assets.

### Monetization & analytics
- `MKStore`: full StoreKit 2 — product catalog, purchase controller, paywall state
  machine, entitlement resolver with lifetime > subscribed > grace > billing-retry >
  trial > free precedence, restore, sandbox/StoreKit-Testing coverage.
- App-side 7-day trial (Keychain-persisted, iCloud-KVS-mirrored, clock-rollback
  guarded) — deliberately **not** an Apple introductory offer (D-123; see
  *Monetization direction* below for why both would conflict).
- Referral flow: fully architected (codes, attribution, extension state, anti-abuse)
  but compile-time excluded from Release builds by default (`MAKHTOOT_REFERRAL_ENABLED`,
  D-225) — a CI-style guard script (`Scripts/referral-release-grep.sh`) proves the
  exclusion holds against the actual built binary, not just the source tree.
- `MKAnalytics`: opt-in-only, aggregated, ISO-week-bucketed font-usage analytics via
  a CloudKit public database uploader; a three-layer kill switch (local revoke +
  remote record + a feature flag); a strict payload allowlist gate.

### App shell
- Onboarding, adaptive project browser (grid, folders, search, duplicate), the real
  editor (toolbar, tool rail, layers/inspector panels, path-edit and arrange-mode
  toolbars, zoom controls, memory-pressure banner), settings (privacy consent, sync,
  general, support, font licensing), and the paywall — all real SwiftUI, Arabic
  strings throughout with Latin-gloss comments in source for maintainers.

## Monetization direction

- **Pricing (locked, D-216)**: $2.99/mo and $29.99/yr auto-renewable subscriptions
  (same entitlement tier — not an upgrade path from one to the other), $89.99
  lifetime non-consumable. Apple storefront price localization everywhere; no manual
  per-storefront overrides.
- **Trial (locked, D-123)**: 7 days of premium from first app launch, app-side only —
  no StoreKit purchase, no payment sheet, no Apple-managed introductory offer.
  Deliberately not an Apple introductory offer, because that mechanism requires a
  committed subscription purchase and Apple-managed eligibility (one intro offer per
  subscription group per Apple ID) — running both would create double-trial and
  eligibility-divergence states. Paywall copy must state real billing terms (payment
  starts immediately at purchase) and must never imply an Apple-managed free-trial-then-bill flow.
- **Post-trial free tier**: full editing retained; premium functions blocked; the
  user can always create with free fonts/solid backgrounds and export JPEG/PDF at
  2MP.
- **Family Sharing (FD-06, irreversible, resolved 2026-07-19)**: OFF for all three
  products. OFF→ON stays available later as a marketable upgrade; ON→OFF would
  require product recreation under a new ID, stranding existing purchasers.
- **Referral (FD-05)**: architected, default OFF, compile-time gated out of Release —
  App Review risk was the deciding factor; reactivation needs explicit founder
  reconfirmation against current guidelines, not just a flag flip.
- No ads, no mandatory account, no third-party social logins. Analytics is the only
  network-touching non-premium feature, and it is opt-in and aggregated only.

## Technical direction

- SwiftUI-first (Makhtoot app target) over a local SwiftPM package (`MakhtootKit`,
  16 library targets: `MKFoundation`, `MKModel`, `MKTextEngine`, `MKArrange`,
  `MKPathText`, `MKCanvas`, `MKRender`, `MKColor`, `MKExport`, `MKFonts`,
  `MKPersistence`, `MKSync`, `MKStore`, `MKAnalytics`, `MKDesignSystem`, `MKAssets`).
- **Zero third-party dependencies in v1** (D-101) — every subsystem is built on
  first-party Apple frameworks (Core Text/TextKit 2, Core Graphics, CloudKit,
  StoreKit 2, SwiftData).
- Custom Core Graphics render/layout layer for Arrange Mode built atop Apple's own
  shaping APIs — explicitly not a ground-up Arabic shaper (D-114: no Metal in v1;
  Core Graphics chosen for correctness/maintainability over raw performance
  headroom this app doesn't need).
- Swift 6 strict concurrency throughout.
- Tools: `xcodebuild` + `gh` only — no Fastlane, no XcodeGen/Tuist, no external CI
  (Q49/D-101).
- iOS 18+ deployment target, universal iPhone + iPad, one codebase, adaptive layout
  (not a scaled-up iPhone layout on iPad).

## Launch direction

The target sequence is **archive → TestFlight → founder device verification →
App Store submission**. As of 2026-07-23:

### Done
1. `MakhtootKit` builds clean; 16 of 17 SPM test targets independently re-verified
   green (the 17th, `MKPathTextTests`, hit a reproducible host-process wedge during
   verification, unrelated to any actual test assertion — its own diff is
   comment-only; needs one clean re-run before submission, see `docs/impl-log/
   WS-07-p14-run3.md`).
2. First-ever Release archive, D-225 referral-exclusion guard, and TestFlight upload
   — build `1.0 (20260723.1)`, uploaded and processing, zero warnings.
3. Real `.onOpenURL` document-opening, verified end-to-end on-simulator (not just
   compiled) via a real fixture package and a filesystem-level idempotency check.

### Remaining before App Store submission (see `APP_STORE_CHECKLIST.md` for the full
105-item playbook; these are the load-bearing gaps, not every item)
- **Founder-only, cannot be engineered around:**
  - Real Privacy Policy / Terms of Use URLs + support email (`MKLegalLinks.swift`
    still ships literal placeholders — required by App Store Guideline 3.1.2).
  - Create the 3 IAP products in App Store Connect (product IDs, reference names,
    pricing, and the subscription group are already decided — see
    `APP_STORE_CHECKLIST.md` §3 — this is data entry, not a new decision), Family
    Sharing OFF on each.
  - The founder's own manual Arabic-script verification pass on this TestFlight
    build, on real hardware (shaping, tashkeel, bidi, Arrange Mode fidelity).
  - Device-hardware performance verification (ProMotion 120Hz frame timing, A12-class
    floor, real memory-pressure behavior) — everything measured so far is
    simulator-indicative only.
  - App Store Connect metadata entry (name/subtitle/description/keywords are already
    drafted in `APP_STORE_CHECKLIST.md` §10, just need review + pasting in) and
    screenshot capture/upload (debug fixture hooks exist to seed clean projects for
    this; no screenshots have actually been shot yet).
- **Engineering, still open:**
  - `MKPathTextTests` clean re-run (see above).
  - Post-FD-01 CloudKit sync re-verification against the real container.
  - The sandbox StoreKit test suite (9 tests) is still environment-skipped — needs
    the `Makhtoot` scheme's `TestAction` wired, a known pre-existing gap.

## Summary

Makhtoot should launch as the Arabic design app that finally treats the Arabic
letter as a first-class design object — correct by default, and, through Arrange
Mode, more manipulable than any general-purpose tool offers today — while staying
fully offline-capable, account-free, and honest about what its export pipeline
actually delivers. The engineering foundation (P0–P14) is complete and independently
verified; what remains before an App Store release is founder-owned business/legal
setup and a real-device verification pass, not further core engineering.
