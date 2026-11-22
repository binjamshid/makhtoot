# Makhtoot (مخطوط) — Product Requirements Document (PRD.md)

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.

**Run 1 deliverable.** Conforms to `_input/BRIEF.md` (locked requirements digest) and
`FOUNDATION.md` (authoritative decisions D-100…D-126, founder decisions FD-01…FD-07). If this
document contradicts FOUNDATION.md, FOUNDATION.md wins. Market-study citations appear as
`MS[n]`, referring to the numbered references in `docs/makhtoot-market-study.md`. Claims that
cannot be grounded in the market study or Apple's own documented behavior are marked
`VERIFY-AT-SUBMISSION`.

- Product name: **Makhtoot / مخطوط** (never any other name).
- Bundle id: `net.binjamshid.makhtoot` — **FD-01 confirmed**.
- Platform: Universal iPhone + iPad, iOS 18.0 minimum, Arabic-only RTL UI (D-100).
- Document conventions: requirement ids `R-<section>.<n>`; user flows `FL-<n>`; fixtures `F-<n>`.
- Priorities: **P0** = locked by BRIEF/founder Q&A (non-negotiable scope), **P1** = required for
  v1 but detail is this PRD's elaboration (editable without founder re-approval), **P2-seam** =
  architecture seam only; explicitly NOT built in v1.
- Arabic UI strings are given in Arabic with a Latin gloss in parentheses on first use, per
  FOUNDATION §12. All shipped UI strings are Arabic-only (`ar` localization).

> **Status | Built? | Verified against source on 2026-07-20** — intent document,
> largely still authoritative; **not implementation-tracked per requirement.** This
> pass did not attempt to check all 311+ `R-<section>.<n>` requirement ids against
> current code (out of scope for a portfolio-standard git/CI pass; `TEST_MATRIX.md`
> is this repo's own mechanism for that and was not independently re-verified
> either). Confirmed accurate at the platform/scope level: bundle id
> (`net.binjamshid.makhtoot`) matches `Makhtoot.xcodeproj/project.pbxproj`;
> Arabic-only UI matches `Makhtoot/Resources/Localizable.xcstrings`
> (`sourceLanguage: ar`, one language). Where this document and the code disagree,
> the code wins (README "Authority rule").

## Canonical Arabic test fixtures (used by flows and edge cases throughout)

| ID | String | What it exercises |
|---|---|---|
| F-1 | `لا` | Mandatory lam-alif ligature, isolated |
| F-2 | `الله` | Word-ligature candidate (lam-lam-heh with shadda+superscript-alef in many fonts), multi-glyph cluster behavior |
| F-3 | `محمّد` | Shadda (U+0651) on a medial base inside a joined word |
| F-4 | `بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ` | Full tashkeel: kasra, sukun, shadda, superscript alef (U+0670), multiple marks per base, sacred-content-neutral handling (treated identically to all text, Q67–68) |
| F-5 | `مرحبا Hello ١٢٣ 123` | Mixed bidi: RTL base direction, embedded LTR Latin run, Arabic-Indic digits (٠–٩) and European digits in one line |
| F-6 | `حِسّ` and `مُدَرِّسَة` | Shadda + kasra ordering / rendering (kasra below or below-shadda per font), multiple marks on one base |
| F-7 | `سلام` and `الإسلام` | Lam-alif ligature INSIDE a joined word (final/medial contexts), hamza-on-alif forms |
| F-8 | `ًٌٍَُِّْ` | Tashkeel-only input with no base letters (dotted-circle fallback) |
| F-9 | `محمــــد` | Kashida/tatweel U+0640 as a real, shapeable, selectable glyph |
| F-10 | `مخطوط عربي جميل` | Path-text fixture, three words, RTL along Bézier |
| F-11 | `أبجد هوز حطي كلمن سعفص قرشت ثخذ ضظغ` | Full-alphabet joining sweep for form-selector QA |
| F-12 | `ما شاء الله ١٤٤٧هـ` | Ligatures + digits + heh-marker mixed content |

These fixtures MUST appear verbatim in TEST_MATRIX.md test data (cross-reference
T-text-*, T-arrange-*).

---

## 1. Overview & Personas

### 1.1 Product statement

- **R-1.1 (P0)** Makhtoot is a native iOS 18+ iPhone/iPad app for Arabic typographic design:
  the user types Arabic text that behaves exactly like a native text field (shaping, contextual
  forms, ligatures, tashkeel, bidi), then — by explicit action — enters **Arrange Mode
  (وضع التنسيق — waḍʿ at-tansīq)**, where every glyph, tashkeel mark, and ligature component
  becomes an independently selectable, transformable design object, with a lossless path back
  to the original text.
- **R-1.2 (P0)** v1 output is **static image/design compositions only**. Animation, video, and
  reels are v2 (see §23); only clean extension seams exist in v1.
- **R-1.3 (P0)** The entire UI ships in Arabic only, RTL-first, with `ar` as the sole
  localization and development region (D-100).
- **R-1.4 (P0)** The app is fully useful offline. The only three permitted network uses are:
  premium font catalog downloads, premium iCloud (CloudKit) project sync, and anonymous
  opt-in font-usage analytics upload (see §19).
- **R-1.5 (P0)** No preloaded Qur'anic content of any kind: no verse data, no translations, no
  Uthmani text assets, no special warnings, no locks, no sacred-content detection. All
  user-entered text is treated identically (Q67–68; this deliberately overrides the market
  study §6 recommendation of a Tanzil-based Qur'an-quote feature, MS[38][39] — that feature is
  OUT). Fixture F-4 is a user-typed string like any other and receives zero special handling.

### 1.2 The market gap (why this product)

- **R-1.6 (P1)** Positioning: every surveyed Arabic-calligraphy competitor (Ana Muhtarif Al
  Khat MS[1], ArabiKhat MS[2][3], Ana Khattat MS[4]) is a template/generator-style text-stamping
  tool; none exposes per-glyph, per-mark, or per-ligature selection or decomposition. General
  design suites (Canva MS[13], Adobe Express MS[16], Phonto MS[5][12], Procreate MS[17]) treat
  Arabic as opaque generic text; Phonto reviews explicitly complain about missing Arabic fonts
  MS[6]. Makhtoot's differentiator is treating Arabic script as a manipulable typographic
  object graph, which no surveyed competitor does (market study §1–§3).
- **R-1.7 (P1)** App Store copy and marketing claims about competitors must be re-validated
  against current listings before submission (market study §2 note) — VERIFY-AT-SUBMISSION.

### 1.3 Personas

- **R-1.8 (P1)** **P-A "الخطّاط الهاوي" (the hobbyist calligrapher)** — iPad-first, designs
  greeting cards, wedding invitations, Eid/RAMADAN social posts. Needs: beautiful bundled
  fonts, ornaments, per-glyph nudging, JPEG/PNG social exports. Trial→monthly conversion
  target.
- **R-1.9 (P1)** **P-B "صانع المحتوى" (the social content creator)** — iPhone-first, fast
  turnaround, story/status presets, transparent PNG overlays for video thumbnails (static
  only). Needs: speed, presets, mixed Arabic/Latin text (F-5), offline reliability.
- **R-1.10 (P1)** **P-C "المصمّم المحترف" (the professional designer)** — iPad + external
  workflows, print jobs (signage, book covers). Needs: SVG with editable objects, true-CMYK
  300-DPI PDF (Q75), exact custom dimensions, imported brand fonts (premium), numeric
  inspector precision. Annual/lifetime purchaser.
- **R-1.11 (P1)** **P-D "المعلّم/إمام المجتمع" (the teacher / community organizer)** — mixed
  devices, produces educational posters and mosque announcements with heavy tashkeel (F-4,
  F-6). Needs: full Qur'anic-style mark handling as ordinary text (no special content
  features), free tier that remains genuinely usable after trial (Q41).
- **R-1.12 (P1)** Persona-driven acceptance rule: every P0 flow (FL-1…FL-13) must be completable
  by P-A on iPhone SE-class smallest supported screen and by P-C on 13" iPad with the same
  feature set (adaptive layout, no feature forking between devices).

### 1.4 Success criteria (v1)

- **R-1.13 (P1)** A user can go from first launch to an exported design containing manually
  arranged glyphs (at least one broken join, one detached mark, one decomposed ligature, one
  path text) entirely offline, in under 10 minutes, without documentation.
- **R-1.14 (P0)** All performance gates of §22 (D-115 budgets) pass on the oldest supported
  hardware class before submission (Q59 gates).
- **R-1.15 (P1)** Free tier post-trial remains a complete, honest tool: create, edit, autosave,
  organize, and export JPEG/PDF at ≤2 MP with free fonts and solid backgrounds forever (Q41).

### 1.5 Explicit non-goals (v1)

- **R-1.16 (P0)** No accessibility scope (founder Q53). No VoiceOver/Dynamic Type/contrast
  work is planned, allocated, or tested in v1. (Recorded as a deliberate founder decision.)
- **R-1.17 (P0)** No templates (Q61–62). Only the minimal extension seam of §23. Reusable
  shapes/ornaments/frames/calligraphic elements/pattern backgrounds ARE in scope (§11).
- **R-1.18 (P0)** No accounts, no SIWA in v1, no ads, no third-party SDKs (D-101), no
  server backend. CloudKit rides the user's own iCloud identity (§17; MS[56][57]).

---

## 2. Information Architecture & Navigation

### 2.1 Top-level structure

- **R-2.1 (P0)** App structure (RTL-first everywhere):
  1. **متصفح المشاريع (Project Browser)** — root scene (§3).
  2. **المحرّر (Editor)** — full-screen canvas scene (§4–§11).
  3. **الإعدادات (Settings)** — sheet/split detail (§20).
  4. **مخطوط المميّز (Makhtoot Premium — paywall)** — modal sheet, dismissible (§14).
  5. **الترحيب (Onboarding)** — first-launch-only, skippable, ≤3 screens (FL-1).
- **R-2.2 (P0)** Universal layout: one codebase, genuinely adaptive. iPhone: stack navigation,
  bottom toolbars, sheet-based panels. iPad: split/sidebar Project Browser, persistent side
  panels (layers right-edge in RTL = visually left, inspector), multi-column Settings.
  No feature exists on only one device class.
- **R-2.3 (P0)** The entire navigation chrome is RTL: back navigation points right, sidebars
  originate from the right edge, progress and sliders run right-to-left where directional,
  per Apple Arabic design guidance MS[24].
- **R-2.4 (P1)** Scene/state restoration: relaunch restores the last open project and editor
  viewport (zoom/pan/selection cleared, mode preserved as last-committed state) via the
  crash-recovery journal (D-112).
- **R-2.5 (P1)** iPad multitasking: Split View and Stage Manager supported with the same
  adaptive rules; no drag-and-drop between app instances in v1 (P2-seam).
- **R-2.6 (P1)** No URL schemes, no deep links, no widgets, no App Intents in v1 (P2-seam,
  §23).

### 2.2 Modality rules

- **R-2.7 (P1)** Destructive confirmations are always Arabic action sheets with the
  destructive verb first, e.g. revert-to-text (FL-13), delete project, discard conflict copy.
- **R-2.8 (P0)** The paywall is NEVER the first screen: Project Browser and at least one
  editable canvas must be reachable before any paywall appears (Guideline 3.1.2 dark-pattern
  avoidance, MS[50][51]; see R-14.11).
- **R-2.9 (P1)** Onboarding content: 3 cards — (1) اكتب "Type", (2) نسّق "Arrange", (3) صدّر
  "Export" — each with a live rendered sample (F-4 shown as static art), plus the trial
  explanation card of FL-1. Skippable at every card; never shown again (flag in SwiftData
  metadata store).

### 2.3 Editor mode model

- **R-2.10 (P0)** The editor has exactly three interaction modes per selected object context:
  **تحرير النص (Text Editing)** — live typing overlay; **تحريك (Canvas manipulation)** —
  select/transform whole objects; **وضع التنسيق (Arrange Mode)** — per-glyph editing inside
  one Arranged Composition. Mode is always visibly indicated (toolbar state + canvas badge).
- **R-2.11 (P1)** Mode transitions and their guarantees:
  | From → To | Trigger | Guarantee |
  |---|---|---|
  | Manipulation → Text Editing | double-tap Live Text object | overlay opens with full IME (D-104) |
  | Text Editing → Manipulation | tap outside / "تم" (Done) | committed render pixel-identical to overlay metrics |
  | Manipulation → Arrange | explicit button "تنسيق الحروف" (Arrange letters) on a selected Live/Path Text object | snapshot derivation (D-106), FL-4 |
  | Arrange → Manipulation | tap outside / close arrange bar | arrangement persists; NO reflow ever |
  | Arrange → Text (revert) | explicit "العودة إلى النص" (Revert to text) + confirmation | arrangement discarded, source restored (FL-13) |
- **R-2.12 (P0)** Undo/redo is global and crosses mode switches (see R-4.22, edge cases
  R-21.40…R-21.44).

---

## 3. Project Browser & Documents

### 3.1 Project model

- **R-3.1 (P0)** A project = one `.makhtoot` file package (D-112): `manifest.json`
  (schemaVersion=1, ids, canvas size, thumbnail refs), `scene.json` (Codable scene graph),
  `assets/` (content-addressed imported assets), `backups/` (rescue snapshots), and
  `thumbnail.png`. Single canvas per project in v1 (multi-page = P2-seam).
- **R-3.2 (P0)** All users (free and premium): local storage, autosave, duplicate, project
  folders, search, and export history. None of these is gated.
- **R-3.3 (P0)** Autosave: debounced ≤2 s after any mutation; immediate on backgrounding and
  on memory-pressure events; atomic write-temp+rename; crash-recovery journal replays the
  last un-flushed command batch on relaunch with zero data loss (D-112, D-116).
- **R-3.4 (P1)** Autosave is invisible: no "save" button anywhere. A transient toast appears
  only for autosave *failures* (see R-21.60 storage-full).

### 3.2 Browser features

- **R-3.5 (P1)** Grid of project thumbnails (regenerated on close/autosave; placeholder
  ornament when render pending), most-recently-edited first; list view toggle on iPad.
- **R-3.6 (P0)** Folders: create, rename, delete (contents move to root with confirmation),
  move projects between folders (drag on iPad, context menu everywhere). One level deep in
  v1 (nested folders = P2-seam).
- **R-3.7 (P0)** Search: live filter on project name plus indexed searchable text — the
  concatenated source strings of all Live/Path/Arranged text objects (from the SwiftData
  metadata index, never by opening packages). Arabic search is diacritic-insensitive by
  default (F-4 found by typing بسم without marks).
- **R-3.8 (P0)** Duplicate: creates a full deep copy with name suffix "نسخة" (copy); safe
  against concurrent autosave (R-21.59).
- **R-3.9 (P1)** Delete: confirmation sheet; delete is local-immediate. For synced (premium)
  projects, deletion propagates via CKSyncEngine (§17). No trash/undo-delete in v1 —
  confirmation copy states this explicitly: "سيُحذف المشروع نهائيًا" (the project will be
  permanently deleted).
- **R-3.10 (P0)** Export history: per-project list of past exports (date, format, dimensions,
  preset, entitlement tier at time of export) stored in the metadata index; tapping re-opens
  the export sheet pre-configured. History records store settings, not the produced files.
- **R-3.11 (P1)** New-project sheet: canvas preset chooser (see export presets R-13.14 —
  same preset list drives canvas sizes), custom size fields (W×H pt), background color
  (solid; free tier restriction of R-14.6 applies to photo backgrounds only, not solids),
  default name "مشروع جديد" (new project) + auto-increment.
- **R-3.12 (P1)** Project metadata editable: name (rename inline), folder, canvas size
  (resizing existing project re-anchors content top-right — RTL origin — with confirmation).

### FL-2 — Flow: project creation

1. User taps "+" in Project Browser (top toolbar, leading = right side in RTL).
2. New-project sheet opens: preset grid (مربّع/قصة/منشور/غلاف/طباعة… — square/story/post/
   cover/print), custom W×H fields, background color swatch (default paper-white from the
   design system).
3. User picks "قصة ٩:١٦" (Story 9:16). Canvas 1080×1920 pt-equivalent document space.
4. Editor opens with an empty canvas, zoom-to-fit, and a single hint chip "اضغط مرّتين
   للكتابة" (double-tap to type) that disappears after first text object exists.
5. Autosave creates the `.makhtoot` package immediately (empty scene is a valid document).
6. Browser thumbnail appears when the user returns (R-3.5).

Acceptance: steps 1–6 offline; package exists on disk after step 5; kill-app after step 5
relaunches into R-2.4 restoration.

---

## 4. Canvas Editor

### 4.1 Canvas fundamentals

- **R-4.1 (P0)** Canvas capabilities (all locked): drag, resize, rotate, multi-select,
  alignment guides, snapping, visual layers, grouping, lock/hide, full undo/redo, zoom, pan.
- **R-4.2 (P0)** No artificial caps on canvas size, glyph count, or object count — free or
  premium (performance §22 governs via degradation, never via feature caps).
- **R-4.3 (P0)** Rendering: UIKit canvas host (UIScrollView + CALayer per top-level node),
  Core Graphics node content, bitmap caching per zoom scale; committed text always renders
  through MKTextEngine→MKRender so canvas and export are pixel-identical (D-104, D-114).
- **R-4.4 (P1)** Zoom 2.5%–6400%, pinch + double-tap-to-fit; pan with one/two fingers per
  context; zoom indicator chip with tap-to-reset ("ملاءمة" fit).
- **R-4.5 (P1)** Document space is pt-based with export scale factors applied at export
  (§13); positions displayed in the inspector in pt with 0.1 precision.

### 4.2 Selection & transforms

- **R-4.6 (P0)** Selection: tap selects topmost unlocked visible node; tap-again cycles
  through overlapping nodes under the touch; marquee (drag on empty canvas) selects
  intersecting nodes; multi-select via marquee or tap-with-modifier chip "تحديد متعدد"
  (multi-select toggle) on iPhone, two-finger tap adds on iPad.
- **R-4.7 (P0)** Transform handles: 8 resize handles + rotation handle; proportional resize
  default for text/glyph nodes (free resize via handle modifier); rotation snaps at
  0/±45/±90/180° with haptic tick (disableable in Settings).
- **R-4.8 (P0)** Alignment guides & snapping: canvas edges, canvas center lines, other
  nodes' edges/centers, equal-spacing hints; snap threshold 4 pt at current zoom; live guide
  lines in accent color; snapping toggle in canvas toolbar.
- **R-4.9 (P0)** Grouping: group/ungroup any multi-selection; groups nest; transforms apply
  to the group as a unit; line height is a parent-group property for text stacks (Q per
  BRIEF per-object list). Arranged Composition is itself a special group (§6).
- **R-4.10 (P0)** Lock/hide per node and per group from layers panel and context menu;
  locked nodes are skipped by tap selection but selectable from the layers panel (with
  lock badge); hidden nodes don't render, don't hit-test, and are excluded from export.
- **R-4.11 (P1)** Context menu (long-press): قص/نسخ/لصق/تكرار/حذف/تجميع/قفل/إخفاء/ترتيب
  (cut/copy/paste/duplicate/delete/group/lock/hide/z-order). Paste of Makhtoot objects is
  internal-pasteboard scene-node paste; paste of external text creates a Live Text object
  (see R-21.13 for ZWJ/ZWNJ and R-21.15 for RTL/LTR paste marks).
- **R-4.12 (P1)** Nudge: selected node(s) move 1 pt per arrow-chip tap / hardware arrow key,
  10 pt with modifier. In RTL UI the "forward" nudge chip points left (−x). 

### 4.3 Styling model (per object)

- **R-4.13 (P0)** Every node supports: position, rotation, scale, opacity, fill (solid color
  v1), outline/stroke (width + color), shadow (offset, blur, color, opacity). Text-bearing
  nodes add: kerning, tracking, baseline shift, and (on parent group) line height (BRIEF
  per-object list).
- **R-4.14 (P1)** Style copy/paste: "نسخ النمط" (copy style) / "لصق النمط" (paste style)
  applies the intersection of applicable style fields to the target node type.
- **R-4.15 (P1)** Color picker: design-system swatches, P3-aware system color picker
  (D-117), recent colors, opacity slider, eyedropper on canvas. Document stores sRGB
  components (+ optional named swatch id).

### 4.4 Undo/redo

- **R-4.16 (P0)** Full undo/redo across every mutating operation in the editor: transforms,
  style, text edits (grouped per editing session commit), arrange operations, mark
  detach/attach, join break/restore, ligature decompose/recompose, path edits, layer
  operations, group/ungroup, lock/hide, canvas-size change, background change.
- **R-4.17 (P0)** Implementation: in-memory inverse-command stack on the value-type scene;
  gesture coalescing = one command per continuous gesture; unbounded within memory budget
  (D-112); stack survives mode switches (R-2.12) but NOT app termination (journal replays
  committed state, not the undo stack) — documented behavior.
- **R-4.18 (P1)** Undo UI: two toolbar chips تراجع/إعادة (undo/redo) with long-press showing
  the operation name, three-finger swipe gestures on iPad, shake-to-undo disabled.
- **R-4.19 (P0)** Undo across Arrange entry/exit and revert-to-text is defined in
  R-21.40…R-21.44 (edge cases) and is a P0 correctness surface: revert-to-text is itself an
  undoable command that restores the full Arranged Composition.

### 4.5 Canvas background

- **R-4.20 (P0)** Background is a distinguished node: solid color (all tiers); photo/raster
  background (premium-only, Q34); pattern backgrounds from the bundled asset library (§11,
  premium-only per D-215 — free tier backgrounds are solid colors only; placeable vector
  ornaments/shapes remain free, R-11.1).
- **R-4.21 (P1)** Background is always the bottom layer, cannot be reordered above content,
  can be locked (default locked after set), and participates in export exactly as rendered.
- **R-4.22 (P0)** See R-2.12/R-4.19: mode-crossing undo is P0.

---

## 5. Typing & Live Text

### 5.1 Native-fidelity typing (the trust baseline)

- **R-5.1 (P0)** Creating text: double-tap empty canvas (or "نص" text tool) creates a Live
  Text object and opens the editing overlay — a styled UITextView (TextKit 2) for full
  IME/keyboard/selection/dictation correctness (D-104). Committed rendering is always the
  MKTextEngine path (Core Text shaping capture, D-103); overlay and committed render must be
  metrically identical (same font, size, tracking, line height, alignment).
- **R-5.2 (P0)** Typing behaves exactly like a native Arabic text field: contextual shaping
  (initial/medial/final/isolated), mandatory ligatures (lam-alif F-1/F-7), font-defined
  ligatures, tashkeel positioning via the font's GPOS (F-3, F-4, F-6), correct bidi (F-5),
  Arabic-Indic (٠١٢٣٤٥٦٧٨٩) and European (0-9) numerals, Arabic and Latin punctuation,
  kashida U+0640 as typed (F-9). Core Text does all shaping; no custom shaper, ever; no
  Unicode presentation-form codepoints for rendering (D-103, MS[20][21][23]).
- **R-5.3 (P0)** Mixed Arabic-English input: paragraph base direction defaults to RTL;
  embedded Latin runs order correctly per the UBA as implemented by Core Text (D-109,
  MS[24]). Base direction override per text object: تلقائي/يمين-يسار/يسار-يمين
  (auto/RTL/LTR) in the inspector.
- **R-5.4 (P0)** Tashkeel input: standard iOS Arabic keyboard marks (fatha, damma, kasra,
  tanwin ×3, sukun, shadda U+0651, superscript alef U+0670) plus any pasted Qur'anic
  annotation marks in U+0610–061A and U+06D6–06ED render per font support (D-105). No
  special input UI is built for marks in v1; the system keyboard is the input method.
- **R-5.5 (P1)** Multi-line text: hard line breaks (return key); soft wrapping at the text
  object's frame width (drag side handles to re-wrap); alignment يمين/توسيط/يسار/ضبط
  (right/center/left/justify — justify uses Core Text justification; kashida-based
  justification is font/Core-Text default behavior, not custom (P2-seam for custom kashida
  control, §23)).

### 5.2 Live Text styling

- **R-5.6 (P0)** Live Text style surface: font (from §12 catalog), size (pt), fill color,
  tracking, kerning on/off (font kern feature), baseline shift, line height (paragraph),
  opacity, stroke, shadow — all reflow-safe and re-shape-safe.
- **R-5.7 (P0)** Discretionary/contextual ligature toggle per text object: "الوصلات
  الاختيارية" (discretionary ligatures) on/off maps to Core Text font features
  (`kLigaturesType`, OpenType `dlig`/`calt`) BEFORE arrangement (D-108). Mandatory
  ligatures (lam-alif) are never disabled in live text.
- **R-5.8 (P1)** Mixed-style runs inside one Live Text object are NOT in v1: one style per
  Live Text object (split into multiple objects for mixed styling). This keeps the shaped-run
  capture and Arrange derivation unambiguous. (P2-seam: rich runs.)
- **R-5.9 (P0)** Variable fonts: if the selected font is variable, expose registered axes
  (weight/width/optical etc.) as inspector sliders; the chosen instance participates in
  shaping and is recorded in provenance (R-6.8; edge case R-21.24).
- **R-5.10 (P0)** Missing-glyph policy: characters without coverage in the selected font
  render via Core Text font cascade in the *overlay* (system fallback) but the committed
  engine render marks fallback runs with a subtle underline badge and the inspector shows
  "الخط لا يدعم بعض الأحرف" (the font doesn't support some characters). No silent tofu; no
  silent font substitution in committed renders — the fallback font used is recorded per
  run (edge case R-21.23 covers .notdef).
- **R-5.11 (P0)** Rotated Live Text editing (D-201): if a Live Text object is rotated,
  double-tapping it to edit normalizes the UITextView overlay to axis-aligned (unrotated)
  for the duration of editing — the overlay never renders at an arbitrary rotation. On
  commit ("تم" Done), the object's rotation is restored and the newly-shaped/edited
  content renders at the original angle.

### FL-3 — Flow: typing Arabic (shaping, tashkeel, mixed bidi, numerals)

1. In a new project (FL-2), user double-taps the canvas → Live Text object + overlay +
   Arabic keyboard.
2. Types `بسم الله الرحمن الرحيم` — shaping and mandatory ligatures appear as in any native
   field; the word الله renders with the font's word-ligature if defined (F-2).
3. Adds tashkeel from the system keyboard to produce F-4; marks position via the font's
   GPOS; shadda+kasra on الرَّ renders with the font's stacking rule (F-6 semantics).
4. Types return, then `مرحبا Hello ١٢٣ 123` (F-5): Latin run and digits order per UBA; the
   caret moves logically; selection highlights follow visual runs correctly.
5. Taps "تم" (Done): overlay dismisses; committed render is pixel-identical in metrics; the
   object is now selected in manipulation mode.
6. Changes font from القائمة (catalog list) to Amiri: text re-shapes live; tashkeel
   re-positions per Amiri's tables.
7. Double-taps again: overlay re-opens with the same string; editing resumes losslessly.

Acceptance: steps 2–4 verified against a reference native UITextView rendering of the same
attributed string (T-text tests); zero visual divergence in glyph choice and order at
commit; typing echo <50 ms (D-115).

---

## 6. Arrange Mode

### 6.1 Entry & derivation

- **R-6.1 (P0)** Arrange Mode is entered ONLY by explicit user action: select a Live Text or
  Path Text object → tap "تنسيق الحروف" (Arrange letters) → confirmation-free immediate
  derivation (entry is non-destructive; only revert is destructive).
- **R-6.2 (P0)** Derivation (D-105/D-106): the shaped result snapshots into an **Arranged
  Composition** containing:
  - **Glyph Nodes**: glyph id, font reference (incl. variable-axis instance), outline path,
    position, advance, joining state, source codepoint range, cluster id, bidi level +
    visual index.
  - **Mark Nodes**: one per combining mark (categories Mn/Me incl. U+0610–061A,
    U+064B–065F, U+0670, U+06D6–06ED), attached to its base Glyph Node with recorded
    relative offset from shaped GPOS positions, follow-base = true by default.
  - **Ligature Groups**: cluster with >1 codepoint and 1 glyph (e.g., lam-alif) becomes a
    selectable group with constituent codepoints and decomposable flag.
  - **Source Text Backup**: full source string + complete style state, embedded in the node
    (D-112), enabling lossless revert.
- **R-6.3 (P0)** Arranged Compositions NEVER auto-reflow. No font change, style change,
  canvas resize, or app update may re-run shaping on an Arranged Composition. The only
  re-shaping events are the explicit per-letter form realization (R-8.9) and ligature
  decomposition (R-8.12), both scoped to the affected nodes.
- **R-6.4 (P0)** Dual-level model: both the shaped-glyph level AND the underlying
  Unicode-letter level are first-class. The stored codepoint sequence + resolved
  glyph/shaping-form references guarantee that switching selection level loses nothing.
  Selection level control in the arrange toolbar: "حروف" (letters — codepoint clusters) /
  "أشكال" (glyphs — rendered forms). Letter-level selection maps through the cluster map to
  its glyph(s) and vice versa (D-105 bidirectional map).

### 6.2 Selection & manipulation inside Arrange Mode

- **R-6.5 (P0)** Independently selectable/transformable: every Glyph Node, every Mark Node,
  every Ligature Group (as a unit or decomposed, §8). Transform + style surface per node:
  position, rotation, scale, opacity, fill color, outline/stroke, shadow — plus kerning/
  tracking/baseline-shift semantics expressed as positional adjustments recorded per node
  (BRIEF per-object list).
- **R-6.6 (P0)** Multi-select within an Arranged Composition (marquee + additive taps);
  aligned distribute/space tools operate on selected nodes; group transforms apply about
  the selection's common bounds.
- **R-6.7 (P1)** Arrange toolbar (contextual): level toggle (R-6.4), "فك الارتباط" (break
  join, §8), "فك الوصلة/إعادة الوصلة" (decompose/recompose ligature, §8), mark
  attach/detach (§7), form selector (§8), "العودة إلى النص" (revert, FL-13), close.
- **R-6.8 (P0)** Provenance completeness: each node records codepoints, glyph id, font
  reference (postscript name + file hash + variable instance), joining form, cluster id,
  bidi level (D-109, D-111). This is the contract that §13 SVG provenance (`data-mk-*`) and
  revert correctness depend on.
- **R-6.9 (P1)** Hit-testing in Arrange Mode uses glyph outline bounds inflated by 6 pt for
  touch; overlapping marks/base cycle on repeated tap (same rule as R-4.6); a magnifier
  loupe appears during drag of nodes smaller than 12 pt on screen.
- **R-6.10 (P0)** The Arranged Composition as a whole remains one canvas object: selectable,
  transformable, groupable, layer-listed (§10) in manipulation mode; entering Arrange Mode
  again resumes per-node editing with all prior adjustments intact.

### 6.3 Source editing conflicts & revert

- **R-6.11 (P0)** Arrange-then-edit-source: double-tapping an Arranged Composition does NOT
  open the text overlay. It opens a choice sheet: "تعديل النص يتطلب العودة إلى النص —
  ستفقد التنسيق اليدوي" (editing the text requires reverting — you will lose the manual
  arrangement) with actions: **العودة والتعديل** (revert & edit), **نسخ ثم تعديل**
  (duplicate the composition, revert the duplicate for editing, keep the arranged original),
  **إلغاء** (cancel). (Edge case R-21.30.)
- **R-6.12 (P0)** Revert-to-text (FL-13): explicit action + confirmation; discards all
  manual arrangement; restores a Live Text object from the Source Text Backup with full
  original style; re-shapes with current engine; result is placed at the composition's
  transform origin. Revert is one undoable command (undo restores the entire arrangement,
  R-4.19).
- **R-6.13 (P1)** A non-blocking badge on Arranged Compositions in the layers panel: "منسّق"
  (arranged) with a glyph-count subtitle, so users can find arranged objects in complex
  scenes.
- **R-6.14 (P0)** Letter-level range selection across a bidi-run boundary: when a "حروف"
  (letters) selection spans more than one bidi run (e.g., a mixed Arabic/Latin/digit
  string), the selection splits into per-run sub-selections at the run boundary; bounds
  and group transforms are computed per sub-selection about that sub-selection's own
  bounds, not one bounding box spanning both runs (context D-109).

### FL-4 — Flow: entering Arrange Mode

1. User selects the F-4 Live Text object from FL-3, taps "تنسيق الحروف".
2. Derivation runs synchronously (<100 ms for ≤200 glyphs, §22): the object's rendering does
   not visibly change (pixel-identical snapshot), but the canvas badge shows "وضع التنسيق"
   and per-glyph bounds shimmer once as an affordance.
3. The arrange toolbar (R-6.7) replaces the standard object toolbar. Level defaults to
   "أشكال" (glyphs).
4. User taps the ب of بسم: a single Glyph Node selects with its own handles. Its kasra
   (Mark Node) highlights as attached (linked badge).
5. User drags the ب upward 20 pt: the glyph moves; the attached kasra follows (R-7.3); no
   other glyph moves; no reflow (R-6.3).
6. User switches level to "حروف", taps الرحمن: the cluster selection shows the letter
   boundaries; selecting the superscript-alef mark individually is offered via the marks
   list chip (R-7.7).

### FL-5 — Flow: per-glyph / per-mark / per-ligature manipulation

1. Continuing FL-4: user marquee-selects the three glyphs of بسم, scales them to 130% about
   selection center; advances/positions update; marks follow bases.
2. Taps the shadda on الرَّ (F-4): selects the Mark Node alone; rotates it 15°, changes its
   fill to the accent red, increases scale — base glyph untouched (R-7.4).
3. Taps the lam-alif in الرحمن؟ — no; uses F-7 fixture: in a second text object سلام
   arranged, taps لا which selects the **Ligature Group** as one unit (R-8.10); moves it as
   a unit; then decomposes it (FL-7).
4. Applies a shadow to a single glyph via inspector; opacity 60% to another.
5. Exits Arrange Mode (tap outside): composition persists exactly; undo history contains
   each step individually (gesture-coalesced).

### FL-13 — Flow: revert-to-text

1. User selects the arranged F-4 composition (manipulation mode), taps "العودة إلى النص"
   (or reaches it via R-6.11 sheet).
2. Confirmation sheet: title "العودة إلى النص؟" body "سيؤدي هذا إلى حذف جميع التعديلات
   اليدوية على الحروف والحركات. النص الأصلي سيُستعاد كما كان." (This deletes all manual
   glyph/mark adjustments. The original text is restored.) Actions: **العودة** (Revert,
   destructive-styled) / **إلغاء** (Cancel).
3. On confirm: Live Text object restored from Source Text Backup with original string F-4 +
   original style; shaped fresh; positioned at composition origin.
4. Undo restores the full Arranged Composition byte-identically (provenance preserved).

Acceptance: revert→undo→revert round-trip is lossless (T-arrange tests); confirmation copy
exactly as specified; revert of a *path* arranged composition restores a live Path Text
object with its path (R-9.10).

---

## 7. Tashkeel & Marks

### 7.1 Scope of marks

- **R-7.1 (P0)** Full mark coverage (founder Q11: full): standard tashkeel (fathatan U+064B,
  dammatan U+064C, kasratan U+064D, fatha U+064E, damma U+064F, kasra U+0650, shadda U+0651,
  sukun U+0652, plus U+0653–065F extensions), superscript alef U+0670, the honorific/early
  annotation range U+0610–061A, and the Qur'anic annotation range U+06D6–06ED (small waqf
  marks, small high/low letters, sajdah sign, rub el hizb, etc.) — as *character handling*,
  not as content: they render if the font supports them, on any user-typed text (R-1.5).
- **R-7.2 (P0)** Mark identification at derivation: Unicode categories Mn/Me become Mark
  Nodes (D-105). Marks the font renders via precomposed/substituted single glyphs with the
  base (font-internal composition) remain part of the base Glyph Node and are listed as
  non-detachable for that font — the inspector explains: "الخط يدمج هذه الحركة مع الحرف"
  (this font fuses the mark with the letter). No fake decomposition of fused glyphs.

### 7.2 Attachment behavior

- **R-7.3 (P0)** Default: every Mark Node is attached to its base Glyph Node with the
  shaped relative offset; when the base moves/rotates/scales, attached marks follow with
  the base's transform (offset transforms in the base's local space).
- **R-7.4 (P0)** Individual manipulation: any Mark Node is independently selectable and
  transformable (position, rotation, scale, opacity, fill, stroke, shadow) WITHOUT
  detaching — its user delta is stored on top of the follow-base attachment.
- **R-7.5 (P0)** Detach: explicit "فصل الحركة" (detach mark) makes the mark a free node in
  the composition (keeps provenance to its former base). Re-attach: select mark + base →
  "إرفاق بالحرف" (attach to letter) recomputes a relative offset from current positions.
- **R-7.6 (P0)** Multiple marks per base (F-4, F-6): each mark is its own node; z-order among
  a base's marks preserved from shaped order; selecting stacked marks cycles per R-4.6.
- **R-7.7 (P1)** Marks list chip: with a base selected, a chip "الحركات (n)" opens a mini
  list of its marks by name (فتحة، شدّة، …) for precise selection when marks overlap —
  names from a fixed Arabic mark-name table covering R-7.1's ranges.
- **R-7.8 (P0)** Shadda+kasra: fonts differ on whether kasra renders below the letter or
  below the shadda (F-6). Makhtoot preserves whatever the font's shaping produced at
  derivation; both marks are separate nodes at their shaped offsets; no normalization or
  reordering of the stored codepoint sequence is ever performed (edge case R-21.6).
- **R-7.9 (P1)** Mark styling defaults: marks inherit the text object's fill at derivation
  but style independently thereafter; "توحيد لون الحركات" (unify mark color) bulk action on
  the composition applies one fill to all Mark Nodes.
- **R-7.10 (P0)** Marks on decomposed ligatures and broken joins keep correct attachment to
  their constituent base after the operation (R-8.13, edge case R-21.7).

---

## 8. Ligatures & Joining

### 8.1 Joining model

- **R-8.1 (P0)** Joining is preserved by default everywhere: live text always shapes with
  full contextual joining; Arranged Compositions capture the joined forms; moving glyphs
  does not change their letterforms (R-6.3).
- **R-8.2 (P0)** Breaking a join is explicit: select a Glyph Node (or letter at letter
  level) → "فك الارتباط" (break join). The glyph keeps its current (joined) form and
  position; it is now marked join-broken, and the form selector becomes available.
- **R-8.3 (P0)** Form selector: after a break, a visual selector shows the letter's four
  contextual forms rendered in the composition's font: منفصل / بادئ / وسطي / نهائي
  (isolated/initial/medial/final), current form highlighted. Picking one swaps the glyph's
  outline to that form (position preserved at the glyph origin; advance metadata updated).
- **R-8.4 (P0)** Form realization technique (D-107): the chosen form is produced by
  reshaping the single letter in a synthetic ZWJ context (e.g., ZWJ+ح+ZWJ → medial) through
  the same font via Core Text, then harvesting the glyph. Never via Unicode
  presentation-form codepoints. Stored as `JoiningForm` enum + resolved glyph id.
- **R-8.5 (P1)** Letters with fewer than four forms (e.g., د، ر، و — non-connecting after)
  show only their valid forms in the selector; the selector renders live previews with the
  actual font so unsupported/identical forms are visually honest.
- **R-8.6 (P0)** Restore join: "إعادة الارتباط" (restore join) on a join-broken glyph
  returns it to its originally captured form (provenance), not a re-shape of the whole
  composition (R-6.3 scope rule).
- **R-8.7 (P0)** Neighbors are untouched: breaking one letter's join does NOT reshape its
  neighbors — the neighbors keep their captured forms (which may now look "joined toward"
  a moved glyph; this is the documented, intended freeze semantics). A hint appears once:
  "الحروف المجاورة تحتفظ بشكلها — عدّلها يدويًا إذا رغبت" (neighbors keep their forms —
  adjust them manually if desired), with a one-tap shortcut that opens the form selector on
  a neighbor.

### 8.2 Ligatures

- **R-8.8 (P0)** Ligature classes handled: mandatory lam-alif family (لا، لأ، لإ، لآ in all
  joining contexts, F-1/F-7) and font-defined discretionary/contextual ligatures
  (toggleable pre-arrangement per R-5.7).
- **R-8.9 (P0)** In Arrange Mode a ligature is BOTH: (a) a combined selectable object
  (Ligature Group selects/moves/styles as one), and (b) decomposable into constituent
  components on explicit action "فك الوصلة" (decompose ligature).
- **R-8.10 (P0)** Decomposition fidelity default (Q71, D-108; clamp semantics D-221):
  constituents are reshaped with joining-preserving context and placed via the normative
  single-affine fit (uniform scale + per-component offsets, first/last edge-aligned)
  matching the original ligature's visual bounds. Within the fit's [0.85, 1.15] scale
  clamp, the text LOOKS unchanged immediately after decomposition (Δ≤0.5 pt vs. the
  original bounds); the two (or more) parts are now independent Glyph Nodes. If the
  natural fit falls outside the clamp, fidelity mode is REFUSED for that ligature —
  decomposition automatically falls back to default-forms placement with the same notice
  UX as R-21.9, and the "looks unchanged" bound does not apply (stays P0, scope limited to
  within-clamp fits, D-221).
- **R-8.11 (P0)** Fidelity opt-out: a secondary action "استخدام الأشكال الافتراضية" (use
  default forms) re-lays the constituents with default spacing/forms instead of
  ligature-matched placement (explicit user choice, Q71).
- **R-8.12 (P0)** Recomposition: "إعادة الوصلة" (recompose ligature) restores the stored
  original ligature glyph and group (provenance). The dirty check compares each
  constituent's FULL node state — transform (position/rotation/scale) AND style
  (fill/stroke/opacity/shadow) — against its post-decomposition baseline; a confirmation
  fires on ANY delta, however small: "ستفقد تعديلات مكوّنات الوصلة" (you will lose the
  component adjustments) (D-221). Confirmed deltas are discarded; the stored original
  glyph and group are restored exactly.
- **R-8.13 (P0)** Marks riding a ligature (e.g., F-4's اللَّهِ shadda+fatha on the lam-lam
  cluster): at decomposition each mark re-attaches to the constituent that owns its
  codepoint (cluster map); ambiguous font-fused cases follow R-7.2 (non-detachable, stay
  with the glyph they are fused into).
- **R-8.14 (P1)** Word-ligature fonts: fonts that ligate whole words (e.g., الله in many
  Naskh fonts, F-2) produce one Ligature Group with all constituent codepoints; decompose
  applies the same D-108 mechanics; if the font cannot produce sensible constituent forms,
  decomposition falls back to default forms with a notice (edge case R-21.9).

### FL-6 — Flow: join breaking + form selector

1. User arranges the F-11 sweep string; selects the ح in حطي (currently initial form).
2. Taps "فك الارتباط": glyph unchanged visually, badge "مفكوك" (broken) appears on the
   node; form selector sheet opens showing ح in isolated/initial/medial/final rendered in
   the current font (R-8.3).
3. User picks "منفصل" (isolated): the outline swaps to isolated ح at the same origin.
4. Neighbor hint of R-8.7 appears; user taps it, picks the ط neighbor, sets it to initial.
5. User drags the isolated ح away as an independent design element; rotates it 30°.
6. "إعادة الارتباط" on the ح restores the captured initial form (undo-able).

### FL-7 — Flow: ligature decomposition/recomposition

1. User arranges سلام (F-7); taps لا → Ligature Group selects as one unit; moves it 10 pt.
2. Taps "فك الوصلة": visually identical (fidelity default R-8.10), but now ل and ا are two
   Glyph Nodes; the layers panel shows them nested under the former group.
3. User rotates the ا outward 20°, recolors the ل — the "calligraphic logo" gesture no
   competitor supports (R-1.6).
4. Taps "استخدام الأشكال الافتراضية" on a second decomposed lam-alif in الإسلام to compare
   default spacing (R-8.11).
5. Selects both nodes of the first pair → "إعادة الوصلة" → confirmation (deltas exist) →
   original لا ligature glyph restored as a group.

Acceptance: decomposition immediately after action is visually Δ≤0.5 pt vs the original
ligature bounds in fidelity mode (T-arrange); recomposition restores the exact original
glyph id; marks re-attach per R-8.13.

---

## 9. Path Text

### 9.1 Live path text

- **R-9.1 (P0)** Path Text object: text laid on a live Bézier path (Q72). Creation: "نص على
  مسار" (text on path) tool offers قوس/دائرة/موجة/حر (arc/circle/wave/freeform); freeform
  opens a pen-style path editor (tap to add anchors, drag for handles).
- **R-9.2 (P0)** Layout (D-110): arc-length LUT over the path; the pen advances along arc
  length in **visual order, RTL-aware** — the first (rightmost) glyph of the shaped RTL run
  starts at the path start; each glyph gets position = arc point, rotation = local tangent,
  plus user baseline offset. Mixed-bidi strings (F-5) keep sub-run coherence (Latin runs
  advance LTR within their reserved arc span, D-109).
- **R-9.3 (P0)** Live behavior: retype → relayout along the path; font/size/tracking changes
  → relayout; the path itself is editable (anchors/handles) in live mode only, with text
  re-flowing live during path edits.
- **R-9.4 (P1)** Path controls: text start offset (arc position), side (above/below path =
  baseline flip), spacing along path (tracking-on-path), "قلب الاتجاه" (reverse direction).
- **R-9.5 (P1)** Overflow: text longer than the path clips with an overflow badge "+n" at
  the path end; the user lengthens the path or shrinks the text (no auto-shrink).
- **R-9.6 (P0)** Marks on path text follow their bases with the base's rotation (tangent) so
  tashkeel stays correctly oriented relative to each glyph (F-4 on a circle must keep marks
  radially correct).

### 9.2 Arranged path text

- **R-9.7 (P0)** "تنسيق الحروف" on a Path Text object freezes it into an Arranged
  Composition exactly as §6 (same node types, provenance includes the source path);
  per-glyph adjustability is fully retained (position/rotation deltas on top of frozen
  path placements).
- **R-9.8 (P0)** After arrangement the path is no longer editable and the composition never
  re-flows along it (R-6.3); the path geometry is retained in the Source Text Backup.
- **R-9.9 (P1)** The frozen path can be optionally shown as a ghost guide ("إظهار المسار"
  show path) for alignment while arranging; it never renders in export.
- **R-9.10 (P0)** Revert of an arranged path composition restores the live Path Text object
  with its original string, style, AND path (FL-13 acceptance).

### FL-8 — Flow: path text

1. User taps "نص على مسار" → "دائرة" (circle); a circle path appears centered with default
   radius; overlay opens; user types F-10 `مخطوط عربي جميل`.
2. Text flows clockwise starting at the path-start angle, RTL glyph order along the arc,
   each glyph rotated to the tangent; marks orient with bases (R-9.6).
3. User drags the circle's radius handle: text re-flows live to the new circumference.
4. Sets start offset so the text is centered on the top arc; flips side to check
   below-path baseline; flips back.
5. Switches the path type to "حر" (freeform), adjusts two anchors — live reflow.
6. Taps "تنسيق الحروف": composition freezes (R-9.7); user nudges two glyphs off-path for a
   hand-lettered feel; path ghost guide toggled for alignment (R-9.9).
7. Export renders exactly the frozen result (no path visible).

Acceptance: RTL order along path verified with F-10 (rightmost letter مـ at path start);
tangent rotation continuous (no flipped glyphs at inflection points — edge case R-21.36);
arrange→revert restores the editable circle.

---

## 10. Layers & Inspector

### 10.1 Layers panel

- **R-10.1 (P0)** The layers panel lists every top-level node and expands hierarchies:
  groups, Live Text objects, Path Text objects, Arranged Compositions (expandable to their
  Glyph/Mark/Ligature nodes), shapes, images, background. Each row: thumbnail/icon, name,
  visibility toggle (عين eye), lock toggle (قفل lock).
- **R-10.2 (P0)** Reorder via drag; z-order matches list order (top of list = front);
  reordering inside an Arranged Composition changes intra-composition node z-order.
- **R-10.3 (P1)** Row names: auto-generated Arabic names — "نص: بسم الله…" (text: first 12
  chars), "حرف: ب" (glyph), "حركة: شدّة" (mark), "وصلة: لا" (ligature), "شكل" (shape),
  "صورة" (image), "مجموعة" (group) — all renamable inline; virtualized list for 5,000+
  nodes (D-115 heavy budget).
- **R-10.4 (P0)** Panel presentation: iPad — persistent side panel (right edge, RTL);
  iPhone — bottom sheet at half/full detents. Lock/hide semantics per R-4.10.
- **R-10.5 (P1)** Multi-select in the panel (edit mode) supports bulk hide/lock/delete/
  group.

### 10.2 Inspector

- **R-10.6 (P0)** Numeric inspector with editable fields: X, Y, W, H, rotation (degrees),
  plus the style/transform fields relevant to the selected node type (opacity %, scale %,
  fill, stroke width/color, shadow parameters, tracking, kerning toggle, baseline shift,
  line height on parent group, font + size on text nodes, variable axes per R-5.9, path
  fields per R-9.4).
- **R-10.7 (P0)** Fields accept typed values with Arabic-Indic OR European digits (٩٠ and 90
  both accepted); display uses locale-appropriate Arabic-Indic digits; decimal separator
  per `ar` locale; RTL field alignment.
- **R-10.8 (P1)** Mixed selection shows shared fields; differing values display "—"; typing
  a value applies to all selected. Steppers ±1 (±10 with modifier); scrubbing a field label
  adjusts continuously (coalesced undo).
- **R-10.9 (P1)** W/H fields on text nodes: Live Text — W edits wrap width, H is derived
  (read-only); Arranged Composition — W/H scale the composition (aspect locked by default,
  unlockable).
- **R-10.10 (P0)** Every inspector edit is undoable and autosaved per §3.

### FL-9 — Flow: layers & inspector

1. Scene: background (solid), one arranged F-4 composition, one shape ornament, one path
   text. User opens the layers panel: 4 top-level rows in z-order.
2. Expands the arranged composition: glyph/mark/ligature child rows with icons (R-10.3).
3. Hides the ornament (eye toggle) — disappears from canvas and future exports; locks the
   background.
4. Drags the path text row above the composition — z-order updates live.
5. Selects a single shadda Mark Node from the panel (deep selection), opens the inspector:
   sets rotation to ١٥ (15°) typed in Arabic-Indic digits; sets opacity 80%.
6. Selects the composition root, sets X=٦٠, Y=١٢٠ exactly; W scales aspect-locked.
7. Undo ×3 walks back the numeric edits individually.

---

## 11. Shapes / Ornaments / Assets & Imports

### 11.1 Bundled asset library (all tiers unless marked)

- **R-11.1 (P0)** v1 ships reusable placeable vector assets: basic shapes (rectangles,
  ellipses, lines, polygons, stars), Arabic ornaments (زخارف), frames (إطارات),
  calligraphic elements (عناصر خطية), and pattern backgrounds (خلفيات زخرفية). All assets
  are original or license-clear vector artwork bundled in `MKAssets` — every asset has a
  recorded license provenance; NO asset ships without it (same discipline as fonts).
- **R-11.2 (P0)** These are NOT templates (R-1.17): assets are individual placeable objects;
  there are no pre-composed multi-object layouts, no text placeholders, no "start from
  design" gallery. The asset browser inserts exactly one object per tap.
- **R-11.3 (P1)** Asset browser: categorized RTL grid (أشكال/زخارف/إطارات/عناصر/خلفيات),
  search by Arabic tag, favorites. Inserted assets are ordinary shape nodes: full transform
  + style surface of R-4.13 (fill/stroke recolorable; multi-color assets expose per-region
  fills where authored as such).
- **R-11.4 (P1)** Pattern backgrounds are vector tiles applied to the background node
  (R-4.20) with scale + colorway controls; premium-only (D-215 — free tier backgrounds are
  solid colors only, exactly per Q34; pattern assets remain browsable with lock badges for
  free users).
- **R-11.5 (P2-seam)** Asset packs as downloadable premium content: data-model hook only
  (catalog schema field `packId`), no UI, no downloads in v1 (§23).

### 11.2 Imports

- **R-11.6 (P0)** v1 import types: raster images (HEIC/JPEG/PNG/GIF-still), SVG, and PDF
  (as placeable assets/backgrounds); custom font files (§12, premium-only). Sources: Files
  picker, Photos picker, paste, iPad drag-and-drop-in.
- **R-11.7 (P0)** Gating (Q34): photo/raster import is **premium/trial-only** — this covers
  both photo backgrounds and placed raster images. Free tier: solid color backgrounds +
  bundled vector assets only. NOTE: BRIEF Q34 literally gates "photo background import";
  this PRD conservatively gates all raster import (see Traceability note TN-1 — founder
  may relax placed-raster to free without architectural impact).
- **R-11.8 (P0)** SVG import: parsed into a vector node (rendered via an internal SVG→CG
  interpreter for the supported subset: paths, groups, basic shapes, solid fills/strokes,
  transforms). Unsupported constructs (filters, scripts, external refs) rasterize that
  sub-tree with a notice "تم تحويل أجزاء من الملف إلى صورة" (parts converted to image).
  Free-tier availability: yes (vector, not photo).
- **R-11.9 (P0)** PDF import: page 1 (multi-page picker if >1 page) placed as a
  vector-preserving node via CGPDF drawing; usable as background or element. Free-tier: yes.
- **R-11.10 (P0)** Imported assets are copied content-addressed into the project package
  `assets/` (D-112); originals never referenced in place; duplicates deduplicated by hash.
- **R-11.11 (P1)** Import validation: corrupt/oversized files rejected with specific Arabic
  errors; raster images larger than 50 MP are downsampled on import with notice (memory
  protection, §22); SVG/PDF size cap 20 MB per file (soft, with warning).
- **R-11.12 (P1)** Image nodes: crop (rect), corner radius, opacity, stroke, shadow; no
  filters/adjustments in v1 (P2-seam).

---

## 12. Fonts & Catalog

### 12.1 The four mechanisms (all in v1 — locked)

- **R-12.1 (P0)** (1) Curated bundled open-license starter fonts — available to free AND
  premium users. Candidate set (D-120, each gated on the WS-09 verification protocol —
  license file captured + verification record before inclusion): Amiri, Amiri Quran, Noto
  Naskh Arabic, Noto Kufi Arabic, Noto Sans Arabic, Scheherazade New, Lateef, Harmattan,
  Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El Messiri, Markazi Text, Rakkas, Katibeh,
  Jomhuria, Mirza, Qahiri. Verified so far: Amiri (OFL 1.1, MS[28][29][30]), Noto Naskh
  Arabic (OFL 1.1, MS[25][26][27]), broader Noto Arabic family (OFL 1.1, MS[27][33]).
  KFGQPC Uthmanic HAFS is non-commercial freeware and is PROHIBITED from bundling
  (MS[31][32]). Alif Type repos are candidates pending per-repo verification (MS[37]).
- **R-12.2 (P0)** (2) Downloadable premium catalog with verified redistribution rights:
  static JSON manifest + font files on founder-controlled HTTPS storage (FD-04); download
  only after entitlement confirmation; documented fallback = bundle premium fonts in-app
  behind entitlement if hosting is not ready at submission (D-121). App Store compliance
  position: fonts are data, not executable code — direct download post-entitlement is
  compliant; VERIFY-AT-SUBMISSION against current guidelines. v1 premium catalog contains
  OFL-verified fonts only (FD-07 defers commercial foundry licensing).
- **R-12.3 (P0)** (3) User font import via Files picker — **premium-only** (Q64). Accept
  .ttf, .otf, .ttc, variable fonts; validate sfnt tables; reject woff/woff2/bitmap-only/
  corrupt with specific Arabic errors (e.g., "صيغة الخط غير مدعومة — الرجاء استخدام ملف
  TTF أو OTF" unsupported format; "ملف الخط تالف" corrupt file). Content-addressed copy
  into the app container; per-process registration via
  `CTFontManagerRegisterFontURLs(.process)`; catalog entry flagged `userImported`
  (D-122, amended by D-219).
- **R-12.4 (P0)** (4) Data-model/catalog hooks for future commercial foundry licensing:
  catalog schema carries `licenseType`, `embeddingRights`, `foundry`, `commercialStatus`
  fields from day one; no commercial fonts ship in v1 (FD-07; standing warning: never
  trust aggregator "free download" pages as license evidence, MS[35], study §5).

### 12.2 Catalog UX

- **R-12.5 (P0)** Catalog browser: live previews (user-editable preview string, default
  F-12), styles/weights, category chips — النسخ/الرقعة/الثلث/الديواني/الكوفي/المغربي/عرض
  حديث/قرآني الطابع/خط اليد/ثنائي عربي-لاتيني (Naskh/Ruq'ah/Thuluth/Diwani/Kufi/Maghrebi/
  modern display/Qur'anic-style/handwriting/Arabic-Latin bilingual) — tags, favorites,
  search. "Qur'anic-style" is an aesthetic category label only (no content behavior,
  R-1.5).
- **R-12.6 (P0)** Character coverage: each catalog entry records coverage (computed from
  cmap at install/import); the picker shows a coverage badge for the current text
  selection when glyphs would be missing (ties into R-5.10).
- **R-12.7 (P0)** License/attribution/foundry/commercial-status/coverage/source links live
  at **Settings → Support → Licensing** (Q66), NOT in the primary catalog UI (§20). The
  catalog shows only a small "معلومات الترخيص" (license info) link per font that deep-links
  there.
- **R-12.8 (P1)** Premium download UX: size shown before download; progress + cancel;
  resumable; downloaded fonts cached in the container; re-download free after reinstall
  (manifest-driven). Offline: catalog browses cached manifest; downloads queue with a
  clear "بانتظار الاتصال" (waiting for connection) state (§19).
- **R-12.9 (P0)** Font lifecycle events: font deleted/uninstalled while used by projects →
  projects keep rendering via captured outlines for arranged nodes and cached font data
  where available; Live Text in a missing font shows the missing-font badge and renders in
  fallback with an offer to re-download/re-import (edge cases R-21.21/R-21.22).
- **R-12.10 (P0)** Expiry locking (Q27, D-119): on entitlement fall to `free`, premium
  catalog fonts and user-imported fonts LOCK: existing projects stay viewable/editable;
  locked-font Live Text renders from last cached shaping with a lock badge; re-shaping
  (text edits) in a locked font is blocked — the edit sheet offers: replace font with a
  free font / re-subscribe. Arranged Compositions (frozen outlines) remain fully
  manipulable — they no longer depend on the font program; but revert-to-text of such a
  composition lands in locked-Live-Text state (view-only string until font replaced).
  Export gating per §13/§14.
- **R-12.11 (P0)** Catalog manifest fetch & cache (`MKCatalogManifestFetchService`,
  WS-09): the premium catalog manifest fetches on app foreground with a 24-hour
  staleness TTL and is cached to disk; the catalog browser always reads the cached
  manifest first, refreshing in the background when stale. Zero-manifest-ever (fresh
  install/reinstall that has never successfully fetched a manifest, offline): the catalog
  shows an empty state "لا يمكن تحميل قائمة الخطوط دون اتصال" (the font catalog can't be
  loaded without a connection) with a retry action — never a blank or crashed catalog
  screen.

---

## 13. Export

### 13.1 Format matrix

- **R-13.1 (P0)** Single render path: every export renders from the immutable scene
  snapshot through MKRender — never screen capture (D-118). Canvas preview and export are
  pixel-identical by construction (D-104).
- **R-13.2 (P0)** Free tier: JPEG + rasterized PDF only, both capped at **2 MP effective**
  (longest-dimension scaling preserving aspect; e.g., 1080×1920 → ~1061×1886). The cap is
  applied at render, never by downscaling a larger render.
- **R-13.3 (P0)** Premium/trial: opaque PNG, transparent PNG, SVG, high-res print PDF —
  plus JPEG and PDF without the 2 MP cap.
- **R-13.4 (P0)** Premium hi-res: 4K+ dimensions, 300-DPI print rasters, effectively
  unlimited scaling subject ONLY to hardware memory protection (Q76): no artificial caps;
  tiled strip rendering (bounded memory) so output size is limited by disk, not RAM
  (D-116); near-limit warning "الحجم كبير جدًا لذاكرة الجهاز — سيتم الحفظ التلقائي قبل
  المتابعة" (size is very large for device memory — autosave will run before continuing).
- **R-13.5 (P0)** Transparent PNG: alpha preserved; background node excluded when the user
  toggles "خلفية شفافة" (transparent background) in the export sheet (premium).

### 13.2 SVG (premium)

- **R-13.6 (P0)** SVG preserves fully editable text/vector objects wherever feasible (Q73,
  D-118): Live Text → `<text>` elements (with `@font-face` embedding ONLY when the font
  license allows — OFL yes MS[26][28]); shapes/assets → native SVG elements; Arranged/
  transformed glyphs → `<g><path>` groups carrying `data-mk-*` provenance attributes
  (source text, codepoints, font name) so editability intent survives round-trips.
- **R-13.7 (P0)** Outlining is a documented, per-feature fallback ONLY — never silent
  flattening: (a) transformed/arranged glyphs, (b) custom ligature decompositions,
  (c) fonts whose license forbids embedding. The export sheet lists exactly which objects
  will outline and why ("سيتم تحويل هذه العناصر إلى مسارات" these elements will be
  outlined) before export.
- **R-13.8 (P1)** SVG writer is a custom serializer (no system API exists, MS market study
  §7); output validated against the SVG 1.1 static subset; text uses proper
  `direction="rtl"` and Unicode source strings.

### 13.3 Print PDF & CMYK (premium)

- **R-13.9 (P0)** Print PDF: vector paths + live-text runs; 300-DPI floor for raster
  assets; live text in OFL fonts subset-embeds; otherwise outlines per license switch
  (D-118). **True CMYK** with ICC-profile-aware output (Q75 — this deliberately overrides
  the market study §7 recommendation to defer CMYK, MS[40][41][42]).
- **R-13.10 (P0)** Color pipeline (D-117): working space extended sRGB → CMYK via
  `CGColorSpace(iccData:)` with the bundled CMYK profile, relative colorimetric intent;
  profile embedded as PDF OutputIntent. Profile selection + redistribution licensing =
  **FD-03** (candidates: eciRGB/ISO Coated v2-class — license must be verified, never
  assumed; documented fallback: Apple Generic CMYK, lower fidelity). No on-screen
  soft-proofing in v1 (documented limitation; verification via external tooling in
  TEST_MATRIX).
- **R-13.11 (P1)** Export sheet CMYK controls: RGB (شاشة screen) / CMYK (طباعة print)
  toggle; when CMYK, show profile name and the disclaimer "قد تختلف الألوان المطبوعة عن
  ألوان الشاشة" (printed colors may differ from screen colors) — D-117's verbatim
  string.

### 13.4 Presets, history, verification

- **R-13.12 (P0)** Presets at 2 MP baseline (free) with premium exact custom dimensions:
  مربّع (square 1:1), منشور (post 4:5), قصة (story 9:16), ريل ثابت (static reel 9:16),
  حالة (messaging status 9:16), غلاف (cover 16:9), خلفية شاشة (wallpaper per device),
  طباعة (print A-series + common cm sizes at 300 DPI, premium). The same list drives
  new-project canvas presets (R-3.11).
- **R-13.13 (P0)** Every export writes an export-history record (R-3.10) including
  entitlement tier, format, dimensions, color space, and per-feature outline fallbacks
  applied.
- **R-13.14 (P0)** Arabic output sharpness is a release gate: visual verification of
  shaped text, marks, and decomposed ligatures at print resolution across ALL formats
  (manual Arabic-script verification checklist, Q59; TEST_MATRIX T-export).
- **R-13.15 (P1)** Destination: share sheet, Files save, Photos save (raster only);
  filename default = project name + preset + date (Arabic-safe filenames).

### FL-10 — Flow: export (free vs premium)

*Free path:* 1. Free user (post-trial) taps "تصدير" (Export). 2. Sheet shows formats: JPEG,
PDF enabled; PNG/PNG-شفاف/SVG/طباعة rows visible but lock-badged (tapping opens paywall
FL-11 — visible-but-locked is the discovery surface). 3. Preset "قصة" selected → dimensions
shown pre-capped ≤2 MP with note "الدقة محدودة في الخطة المجانية" (resolution limited on
the free plan). 4. Export → JPEG renders (tiled), share sheet opens. 5. History record
written (tier=free).

*Premium path:* 1. Trial/premium user opens the same sheet: all formats enabled. 2. Picks
SVG → the R-13.7 outline-disclosure list shows the arranged F-4 composition will be
outlined-with-provenance; Live Text objects will remain `<text>`. 3. Picks طباعة A4 300
DPI CMYK PDF → FD-03 profile shown; memory estimate ok. 4. Exports both; history records
written (tier=trial). 5. A premium-content project (photo background) exported by an
expired user instead triggers the replace-or-subscribe flow (R-14.9, FL-12).

---

## 14. Free/Premium Gating & Paywall

### 14.1 The gating matrix (exhaustive)

- **R-14.1 (P0)** Entitlement tiers for gating purposes: **Free** (post-trial, no purchase),
  **Trial** (7-day app-side, = full premium), **Premium** (subscribed / grace /
  billingRetry / lifetime), **Expired** (previously premium, now free — same rights as
  Free PLUS the locking behaviors below). Full state model in §15.

| # | Feature | Free | Trial | Premium | Expired |
|---|---|---|---|---|---|
| G1 | Create/edit unlimited projects | ✔ | ✔ | ✔ | ✔ |
| G2 | Full canvas tools (§4), undo/redo, autosave | ✔ | ✔ | ✔ | ✔ |
| G3 | Typing & Live Text, all shaping/bidi/tashkeel | ✔ | ✔ | ✔ | ✔ |
| G4 | Arrange Mode: glyph/mark/ligature editing (§6–§8) | ✔ | ✔ | ✔ | ✔ |
| G5 | Path text (§9) | ✔ | ✔ | ✔ | ✔ |
| G6 | Layers, inspector, groups, guides (§10) | ✔ | ✔ | ✔ | ✔ |
| G7 | Bundled starter fonts (§12.1-1) | ✔ | ✔ | ✔ | ✔ |
| G8 | Premium font catalog download/use | ✖ paywall | ✔ | ✔ | 🔒 locked in-place (R-12.10) |
| G9 | User font import (.ttf/.otf/.ttc/variable) | ✖ paywall | ✔ | ✔ | 🔒 locked in-place |
| G10 | Bundled vector shapes/ornaments/frames (§11.1, excl. pattern backgrounds) | ✔ | ✔ | ✔ | ✔ |
| G10a | Pattern backgrounds (§11.1/R-11.4, D-215) | ✖ solid colors only | ✔ | ✔ | 🔒 locked in-place |
| G11 | Photo/raster import incl. photo backgrounds (Q34) | ✖ solid colors only | ✔ | ✔ | 🔒 existing locked; no new import |
| G12 | SVG/PDF vector import (R-11.8/9) | ✔ | ✔ | ✔ | ✔ |
| G13 | JPEG export ≤2 MP | ✔ | ✔ | ✔ | ✔ |
| G14 | Rasterized PDF export ≤2 MP | ✔ | ✔ | ✔ | ✔ |
| G15 | JPEG/PDF beyond 2 MP | ✖ | ✔ | ✔ | ✖ |
| G16 | Opaque PNG export | ✖ | ✔ | ✔ | ✖ |
| G17 | Transparent PNG export | ✖ | ✔ | ✔ | ✖ |
| G18 | SVG export (editable-preserving) | ✖ | ✔ | ✔ | ✖ |
| G19 | Print PDF (vector, 300 DPI, true CMYK) | ✖ | ✔ | ✔ | ✖ |
| G20 | Custom exact export dimensions | ✖ presets only | ✔ | ✔ | ✖ |
| G21 | Hi-res 4K+/unlimited-scale export | ✖ | ✔ | ✔ | ✖ |
| G22 | Export a project containing premium content | n/a (can't create it) | ✔ | ✔ | ✖ blocked → replace-or-subscribe (R-14.9) |
| G23 | iCloud project sync (§17) | ✖ | ✔ | ✔ | ✖ sync pauses; local intact (R-17.9) |
| G24 | Project folders/search/duplicate/export history | ✔ | ✔ | ✔ | ✔ |
| G25 | Analytics opt-in toggle (§18) | ✔ | ✔ | ✔ | ✔ |
| G26 | Referral UI (§16) | flag OFF for all tiers in v1 | OFF | OFF | OFF |

- **R-14.2 (P0)** No caps anywhere on canvas size/glyph count/object count for ANY tier
  (R-4.2): performance protections are engineering safeguards, never tier features.
- **R-14.3 (P0)** Free tier is permanent and honest (Q41): the G1–G7, G10, G12–G14, G24
  rows can never regress behind a paywall in point updates without founder decision.
- **R-14.4 (P0)** Gating enforcement points: content creation time (G8–G11: pickers hide or
  lock-badge premium options for free users) AND export time (G15–G22: entitlement check
  at render request, D-119). Never enforce by watermarking — no watermarks in v1.
- **R-14.5 (P0)** "Premium content present" project flag (D-119): set when a project
  contains premium fonts, photo backgrounds/rasters, or premium catalog assets; drives G22
  (full walk semantics: R-14.17).
- **R-14.6 (P0)** Free background = solid colors only (D-215; pattern backgrounds are
  premium-only per R-11.4); the color picker itself is never gated.
- **R-14.7 (P1)** Lock badges: a unified 🔒-style "مميّز" (premium) chip renders on gated
  rows/options; tapping ALWAYS explains what's gated before showing the paywall (one
  interstitial line, e.g., "استيراد الخطوط ميزة مميّزة" font import is a premium feature).
- **R-14.8 (P0)** Expired-tier locked content UX (Q27): opening a project with locked fonts
  shows a banner "يحتوي المشروع على خطوط مقفلة" (project contains locked fonts) with
  actions استبدال الخطوط (replace fonts) / الاشتراك (subscribe). Replacement flow: pick a
  free font per locked font; Live Text re-shapes; arranged nodes are untouched (already
  outlines).
- **R-14.9 (P0)** Expired export of premium-content projects: blocked with the
  replace-or-subscribe sheet enumerating the exact premium items (fonts by name, photo
  background, assets). Removing/replacing all listed items clears the flag and re-enables
  free-tier export.

### 14.2 Paywall

- **R-14.10 (P0)** Products: `net.binjamshid.makhtoot.premium.monthly` ($2.99/mo),
  `.premium.annual` ($29.99/yr), `.premium.lifetime` ($89.99 non-consumable) — nearest
  Apple price tiers to the founder's round-number intent (D-216; exact tier availability
  VERIFY-AT-SUBMISSION) — ids confirmed (FD-01 applied); prices always displayed via
  StoreKit localized price strings (Apple storefront localization everywhere — never
  hardcoded numerals).
- **R-14.11 (P0)** Guideline 3.1.2 compliance (MS[45][50][51][52]): title, length, and
  price of each subscription displayed in-binary adjacent to the CTA; functional Privacy
  Policy and Terms/EULA links in-app AND in App Store metadata (URLs =
  VERIFY-AT-SUBMISSION); visible close button at all times; no countdown/urgency
  mechanics; paywall never precedes first app content (R-2.8).
- **R-14.12 (P0)** CTA disclosure copy (Arabic, with Latin gloss for this document only):
  "٢٫٩٩ دولارًا شهريًا بعد التجربة المجانية (٧ أيام) — يتجدد تلقائيًا، الإلغاء في أي وقت من
  الإعدادات" ($2.99/month after the 7-day free trial — auto-renews, cancel anytime in
  Settings). Annual and lifetime rows carry equivalent disclosures; lifetime explicitly
  "دفعة واحدة — بلا تجديد" (one payment — no renewal). Prices rendered from
  `Product.displayPrice`.
- **R-14.13 (P0)** "استعادة المشتريات" (Restore Purchases) is a mandatory, always-visible
  paywall + Settings item (Guideline 3.1.2(c), MS[45]).
- **R-14.14 (P1)** Paywall layout: benefits list mirrors the gating matrix premium rows
  (fonts, import, PNG/SVG/print CMYK, hi-res, sync); a live sample rendered with a premium
  font as the hero; plan selector defaults to annual (best value chip "الأوفر").
- **R-14.15 (P1)** Paywall entry points: lock badges (R-14.7), export sheet locked rows,
  premium catalog, import pickers, sync toggle, Settings "مخطوط المميّز", trial-status
  banner. All entries are user-initiated; no timed popups.
- **R-14.16 (P2-seam)** Win-back/offer-code UI: not in v1; StoreKit offer-code redemption
  sheet reachable from Settings only if trivially enabled (P2-seam, §23).
- **R-14.17 (P0)** `premiumContentPresent` walk completeness (D-229): the project scan
  that sets the flag (R-14.5) iterates ALL nodes in the scene snapshot —
  presence-based, not render-based — regardless of `isHidden`/`isLocked` state; a hidden
  or locked layer containing premium content still sets the flag and still blocks
  free/expired-tier export (G22) until the content is removed or replaced. `MKExportGate`
  additionally enforces G20 (custom export dimensions) as a free-tier preset-membership
  check at the engine level, not UI-only — a free-tier export request for a non-preset
  dimension is rejected by the gate even if it somehow reaches the render call.

### FL-11 — Flow: paywall

1. Free user taps the lock-badged "PNG شفاف" row in the export sheet.
2. Interstitial line explains the gate (R-14.7), button "عرض مخطوط المميّز" (see Makhtoot
   Premium).
3. Paywall sheet: hero sample, benefits, three plans with localized prices + disclosures
   (R-14.12), CTA "ابدأ الآن" (start now) or — if trial already consumed — "اشترك"
   (subscribe), close (×) visible, "استعادة المشتريات" footer link.
4. User picks annual → StoreKit purchase sheet → success → entitlement refreshes
   reactively (§15) → paywall dismisses → the export sheet the user came from now shows
   PNG unlocked; the user's context is never lost.
5. Cancelled purchase returns to the paywall in the same state (R-21.51 interruption edge
   cases).

---

## 15. Trial / Subscription / Lifetime States

### 15.1 Entitlement model

- **R-15.1 (P0)** Entitlement states and precedence (D-113): **lifetime > subscribed >
  inGracePeriod > inBillingRetry > trial > free.** A single resolver
  (`MKEntitlementResolver`) observes `Transaction.currentEntitlements` +
  `Product.SubscriptionInfo.Status` and publishes exactly one effective state; every
  gating check (§14) reads only this resolver.
- **R-15.2 (P0)** Verification: on-device StoreKit 2 JWS verification via
  `VerificationResult` in v1; App Store Server API validation is a documented extension
  seam, NOT v1 (no backend exists) — the decided position required by the BRIEF; the
  market study's server-side-validation recommendation (MS[43], study §8) is consciously
  deferred (§23).
- **R-15.3 (P0)** Premium capability set (G8–G23) is identical for lifetime, subscribed,
  grace, and billingRetry; only the banner messaging differs.
- **R-15.4 (P0)** If both lifetime AND a subscription are present, lifetime wins for state
  display; the subscription is surfaced in Settings with guidance to cancel: "لديك شراء
  دائم — يمكنك إلغاء الاشتراك من إعدادات Apple" (you own lifetime — you may cancel the
  subscription in Apple settings). Never auto-refund, never hide the fact (edge case
  R-21.54).

### 15.2 Trial (app-side, D-123)

- **R-15.5 (P0)** 7-day trial starts at FIRST APP LAUNCH for every user (Q37) — not at
  first purchase attempt, not per-plan. During trial the app is fully premium (G-matrix
  Trial column). Applies conceptually to monthly + annual consideration; lifetime needs no
  trial (it can be bought at any time).
- **R-15.6 (P0)** Persistence: trial-start timestamp in Keychain
  (`kSecAttrAccessibleAfterFirstUnlock`, survives reinstall) mirrored to iCloud KVS;
  earliest timestamp wins across devices/restores; reinstall cannot trivially reset the
  trial.
- **R-15.7 (P0)** Clock-rollback guard: monotonic checks; a device clock set backwards
  never extends the trial (state machine only advances: `active(daysLeft)` → `expired`).
- **R-15.8 (P0)** No App Store Connect introductory offer is configured in v1 (D-123) —
  avoids app-side-trial vs `isEligibleForIntroOffer` divergence and double-trial
  (MS[43][44]). The difference (app-side trial = our gate; Apple intro offer =
  billing-level discount we don't use) is documented for App Review notes and in
  ARCHITECTURE §StoreKit + APP_STORE_CHECKLIST. VERIFY-AT-SUBMISSION: review the ASC
  subscription setup to ensure no accidental intro offer exists.
- **R-15.9 (P1)** Trial UI: status chip in Project Browser toolbar "التجربة: باقي ٥ أيام"
  (trial: 5 days left) → taps to paywall; day-1 onboarding card explains the trial
  honestly; expiry-day banner: "تنتهي تجربتك اليوم" (your trial ends today).

### 15.3 State-by-state UI copy requirements

- **R-15.10 (P0)** Required copy per state (Arabic shipped; gloss for this document):

| State | Where | Required copy (Arabic) | Gloss |
|---|---|---|---|
| trial (active) | browser chip + Settings | التجربة المجانية: باقي n أيام | Free trial: n days left |
| trial → expired moment | one-time sheet | انتهت التجربة المجانية — يمكنك دائمًا الإنشاء والتصدير بالخطة المجانية | Trial ended — you can always create & export on the free plan |
| free | Settings status | الخطة المجانية | Free plan |
| subscribed (monthly/annual) | Settings status | مشترك — يتجدد في {date} | Subscribed — renews on {date} |
| inGracePeriod | persistent banner | توجد مشكلة في الدفع — لا يزال اشتراكك فعّالًا. حدّث وسيلة الدفع | Payment issue — your subscription is still active. Update your payment method |
| inBillingRetry | persistent banner | تعذّر تجديد الاشتراك — جارٍ إعادة المحاولة. حدّث وسيلة الدفع | Renewal failed — retrying. Update payment |
| expired (was premium) | banner on premium touchpoints | انتهى اشتراكك المميّز — جدّد للوصول إلى الميزات المميّزة | Your premium subscription ended — renew for premium features |
| cancelled-but-active | Settings status | ملغى — يبقى فعّالًا حتى {date} | Cancelled — active until {date} |
| lifetime | Settings status | مميّز مدى الحياة | Premium for life |
| revoked/refunded | silent downgrade + Settings status الخطة المجانية | (no accusatory copy) | — |

Copy precedence (D-228): if a user has an active trial AND also carries an
"expired (was premium)" record (e.g., re-entering the trial window after a
refund/lapse within the original 7-day trial period, R-15.13), the active-trial chip
copy ("التجربة المجانية: باقي n أيام") always wins — the "expired (was premium)" banner
never displays while a trial is active.

- **R-15.11 (P0)** Grace/billingRetry banners deep-link to Apple subscription management
  (`showManageSubscriptions` / billing settings). Exact grace-period durations are Apple
  server behavior and must NOT be hardcoded in copy — "commonly up to 16 days" per MS[43]
  is VERIFY-AT-SUBMISSION; UI copy therefore never states a number of days for grace.
- **R-15.12 (P0)** State transitions apply reactively (Transaction.updates listener) —
  mid-session upgrade/downgrade re-evaluates gates without relaunch; an export sheet open
  during a downgrade re-validates at render request (R-21.55).
- **R-15.13 (P0)** Post-purchase redundant-subscription prompt (D-228): on a successful
  lifetime purchase while an active, grace-period, or billingRetry subscription already
  exists, an immediate one-time sheet prompts the user to cancel the now-redundant
  subscription, with a direct manage-subscriptions link (`showManageSubscriptions`) — not
  merely the Settings guidance string of R-15.4. The purchase itself is never
  auto-refunded and the subscription is never auto-cancelled on the user's behalf.

### FL-1 — Flow: first launch & trial start

1. Fresh install, first launch (offline OK). Trial timestamp written (Keychain + KVS
   queue). Onboarding cards (R-2.9); card 4: "تجربة مجانية ٧ أيام بدأت الآن — بعدها خطة
   مجانية دائمة" (7-day free trial starts now — afterwards a permanent free plan), button
   "ابدأ التصميم" (start designing).
2. Project Browser opens (empty state with sample-free hint — NO template gallery,
   R-1.17). Trial chip shows "باقي ٧ أيام".
3. Reinstall scenario: Keychain timestamp survives → remaining days honored; KVS sync may
   pull an earlier timestamp from another device → earliest wins (R-15.6).

### FL-12 — Flow: expiry & locking

1. Day 8, user opens Makhtoot: resolver returns `free`; one-time expiry sheet (R-15.10
   row 2) — dismissible, not a paywall trap (paywall link inside it is optional).
2. User opens a project made during trial containing a premium font + photo background:
   R-14.8 banner appears; canvas fully editable; locked Live Text renders from cached
   shaping with lock badges; arranged compositions manipulate normally (R-12.10).
3. User taps تصدير: G22 blocks — replace-or-subscribe sheet lists "خط أميري الديواني
   (مقفل)، خلفية صورة (مقفلة)" (example items). User replaces the font with bundled
   Amiri, deletes the photo background → flag clears → free JPEG/PDF export ≤2 MP works.
4. Alternatively user re-subscribes (FL-11) → locks lift instantly (R-15.12).
5. Mid-edit expiry (timer crosses while app open): non-blocking; current gesture
   completes; gates re-evaluate on next gated action (R-21.66).

---

## 16. Referral (flag OFF)

- **R-16.1 (P0)** The referral program ships ARCHITECTED BUT DISABLED behind the local,
  server-independent flag `MKFeatureFlags.referralProgram = OFF` (Q78, D-124). No UI, no
  strings, no StoreKit interaction is reachable while OFF. v1 submission goes out with the
  flag OFF; activation requires founder reconfirmation against current App Review
  guidelines (FD-05) — VERIFY-AT-SUBMISSION and at any future activation.
- **R-16.2 (P0)** Designed mechanic (dormant): referrer-only reward — each qualifying
  invited person extends the REFERRER's trial by 7 days; the invitee receives NOTHING for
  downloading/registering (incentivized-download pattern is documented rejection
  territory: Apple review precedent MS[53][54]; study §8). Abuse cap: max 4 extensions
  (+28 days) per user.
- **R-16.3 (P1)** Attribution design (dormant, honest about weakness): local code
  generation (short Arabic-safe code), share sheet link/code, manual code entry by the
  invitee, qualifying event recorded locally; with no server in v1 attribution is
  honor-based code exchange — a documented weakness in the review-risk memo. Qualifying
  event definition (what the invitee must do) is part of FD-05 since "qualifying paid
  action" cannot be verified device-locally — recorded as an open design tension, not
  resolved here.
- **R-16.4 (P0)** Removal path: deleting the `MKStore/Referral` folder + the flag removes
  the feature completely (no dangling schema requirements; referral state tables are
  additive-only).
- **R-16.5 (P0)** Review-risk documentation: a standing memo (APP_STORE_CHECKLIST cross-ref)
  records the MS[53][54][55] precedent, the 3.1.1 circumvention concern, and the rule that
  no referral reward may ever gate core functionality.

---

## 17. iCloud Sync (premium)

- **R-17.1 (P0)** Premium/lifetime feature: CloudKit sync of projects via CKSyncEngine in
  the user's own iCloud account — container `iCloud.net.binjamshid.makhtoot`
  (FD-01 applied). NOT Sign-in-with-Apple; no Makhtoot account of any kind
  (Q77; avoids Guideline 4.8 entirely, MS[56][57][58][59]).
- **R-17.2 (P0)** Record design (D-112): one record per project — manifest+scene as
  encrypted-asset payloads, imported assets as CKAssets; folders and names sync as part of
  metadata records.
- **R-17.3 (P0)** Conflict policy: last-writer-wins per project, with conflict-copy
  fallback — the losing version is preserved as a new project named with suffix
  "(نسخة متعارضة)" (conflicted copy) when both sides changed since common ancestor
  (R-21.61).
- **R-17.4 (P0)** Sync is opt-in via a Settings toggle "مزامنة iCloud" (iCloud sync),
  premium-gated (G23); default OFF even for premium (privacy-respecting default).
- **R-17.5 (P1)** Sync status UI: per-project subtle state glyph (synced/pending/error) in
  the browser; a Settings sync pane shows account state, last sync, quota errors with
  Arabic copies (e.g., "مساحة iCloud ممتلئة" iCloud storage full → link to manage
  storage).
- **R-17.6 (P0)** Account states handled: no iCloud account (toggle disabled with
  explanation), account switch (stop, re-scope local DB to new account per CK account id;
  local projects remain local, R-21.63), sign-out (sync pauses, local data untouched),
  restricted/managed (disabled with copy).
- **R-17.7 (P0)** Offline: full editing offline; changes queue; CKSyncEngine drains when
  connectivity returns (§19). Sync never blocks editing or export.
- **R-17.8 (P1)** Large projects: assets chunk as CKAssets; a project exceeding CloudKit
  per-record/asset limits syncs manifest+scene and marks oversized assets "محلي فقط"
  (local only) with a documented limitation notice — never silent partial sync.
- **R-17.9 (P0)** Expiry: sync PAUSES on entitlement fall to free (no uploads/downloads);
  local projects are never deleted or degraded; re-subscribing resumes and reconciles
  (R-21.46–R-21.50 family).

---

## 18. Analytics & Privacy

- **R-18.1 (P0)** The ONLY analytics: anonymous, aggregated, OPT-IN font-usage data
  (Q43/Q79). Default OFF. Consent is an explicit Settings switch "مشاركة إحصاءات استخدام
  الخطوط (مجهولة)" (share anonymous font-usage statistics), with a versioned consent
  record; flipping OFF stops collection and uploads immediately.
- **R-18.2 (P0)** Data minimization (D-125): on-device counters of fontID → usage-count
  buckets only. Uploaded batches: anonymous, random ephemeral batch UUID, no user record
  linkage, timestamps no finer than ISO week, counts bucketed. Transport: CloudKit public
  database; no third-party SDK; no ATT prompt needed (no tracking, MS[57] study §9).
- **R-18.3 (P0)** NEVER collected/uploaded: user text, project content, identifiers, font
  files, imported assets, device fingerprints, per-project anything.
- **R-18.4 (P0)** No ads. No third-party analytics/crash SDKs. App Privacy nutrition label
  reflects "data not linked to you / usage data (optional)" — exact label entries
  VERIFY-AT-SUBMISSION against the shipped behavior.
- **R-18.5 (P1)** Kill switch: a local flag can disable analytics entirely (compile-time +
  runtime), independent of consent state (D-125).
- **R-18.6 (P0)** Privacy Policy + Terms links live in Settings → الدعم (Support) and App
  Store metadata (R-14.11); documents supplied by founder — VERIFY-AT-SUBMISSION.
- **R-18.7 (P0)** Territory posture: distribute in all territories requiring no extra
  legal documentation/local registration (Q46); a concrete submission-time eligibility
  checklist lives in APP_STORE_CHECKLIST (cross-ref) — VERIFY-AT-SUBMISSION.

---

## 19. Offline Behavior

- **R-19.1 (P0)** Makhtoot is fully useful offline, permanently. The ONLY three network
  uses are: (1) premium font catalog manifest+font downloads (§12), (2) premium CloudKit
  project sync (§17), (3) anonymous opt-in analytics upload (§18). Nothing else may touch
  the network — enforced architecturally (only MKFonts, MKSync, MKAnalytics may own
  networking code) and verified in review gates.
- **R-19.2 (P0)** Per-feature offline matrix:

| Feature | Offline behavior |
|---|---|
| First launch, onboarding, trial start | Fully offline (Keychain write; KVS mirror queues) |
| Project browser, folders, search, duplicate, delete | Fully offline |
| Canvas editing, typing, shaping, Arrange Mode, marks, ligatures, path text | Fully offline (Core Text is on-device) |
| Bundled fonts & assets | Fully offline |
| Downloaded premium fonts (already cached) | Fully offline |
| Premium catalog browsing | Cached manifest browsable; refresh + new downloads queue with "بانتظار الاتصال" (waiting for connection) |
| User font import | Fully offline (Files picker is local) |
| All exports (free & premium, incl. CMYK PDF) | Fully offline (ICC profile bundled) |
| Purchase/restore/paywall | Requires network for the StoreKit transaction itself; paywall renders offline with cached products or a clear "يتطلب الاتصال بالإنترنت" (requires internet) state; entitlement cache keeps current state effective offline |
| Entitlement evaluation | Offline from cached `currentEntitlements`; never downgrades solely because the device is offline |
| Trial countdown/expiry | Fully offline (local monotonic clock guard) |
| iCloud sync | Queues offline; drains on reconnect; never blocks editing |
| Analytics | Counters accrue offline; upload deferred; dropped (not stored indefinitely) after 8 weeks unuploaded |
| Settings, licensing screen | Fully offline (license texts bundled) |

- **R-19.3 (P0)** Airplane-mode acceptance: FL-2…FL-10 and FL-13 must pass end-to-end in
  airplane mode on a fresh install (TEST_MATRIX T-offline).
- **R-19.4 (P1)** No feature ever shows a spinner waiting on network without a cancel/queue
  path; connectivity loss mid-download resumes (R-12.8).

---

## 20. Settings & Licensing

- **R-20.1 (P0)** Settings IA (RTL): الاشتراك (subscription status + manage + restore) ·
  المزامنة (iCloud sync, §17) · التحرير (editing prefs: snapping haptics, guide toggles) ·
  الخصوصية (analytics opt-in, §18) · الدعم (Support: تواصل contact, سياسة الخصوصية privacy
  policy, الشروط terms, **التراخيص Licensing**) · حول (about: version, credits).
- **R-20.2 (P0)** **Settings → الدعم → التراخيص (Support → Licensing)** is the canonical
  home (Q66) for per-font: license name/text (OFL 1.1 full text bundled), attribution and
  copyright notices, foundry, commercial-status, character-coverage summary, and source
  links — for bundled, premium-downloaded, and user-imported fonts (user imports show
  "خط مستورد — التزام الترخيص على المستخدم" imported font — licensing is the user's
  responsibility). Bundled asset (ornaments/patterns) licenses appear here too (R-11.1).
- **R-20.3 (P0)** OFL compliance surface: copyright notice + full OFL license text
  included per font; reserved-font-name rules respected (no modified derivatives shipped)
  (MS[25][26][28][30]).
- **R-20.4 (P1)** Contact = mailto link (founder address, FD-01-adjacent placeholder);
  no in-app forms, no chat.
- **R-20.5 (P1)** About screen shows schemaVersion and a diagnostics export (zip of logs,
  no user content) shareable to support — logs never contain document text (R-18.3).
- **R-20.6 (P0)** Manage subscription opens the system subscription-management sheet;
  cancellation state reflects per R-15.10 copy.

---

## 21. Edge-Case Compendium

Every item is a requirement with expected behavior; TEST_MATRIX maps each to at least one
test id. Grouped by domain. All copy Arabic-only in product.

### 21.1 Text input & Unicode

- **R-21.1 (P0)** Empty text: committing an empty Live Text object deletes it silently; an
  Arranged Composition can never be empty (derivation requires ≥1 glyph); deleting the
  last glyph node of a composition deletes the composition with an undoable command.
- **R-21.2 (P0)** Tashkeel-only input (F-8): marks with no base render on Unicode dotted
  circles (U+25CC) per Core Text default; arrangement treats each dotted-circle+mark as a
  base+mark pair (the dotted circle is a real glyph node); no crash, no stripping.
- **R-21.3 (P0)** Multiple marks on one base (F-4, F-6): unlimited marks per base become
  individual Mark Nodes preserving shaped stacking order (R-7.6); 10+ pathological marks
  on one base must not break hit-testing (cycle selection) or export.
- **R-21.4 (P0)** Shadda+kasra ordering (F-6): both codepoint orders (shadda-then-kasra,
  kasra-then-shadda) are preserved exactly as entered; rendering follows the font;
  NO Unicode normalization (no NFC/NFD rewriting of the user's sequence) anywhere in the
  pipeline — provenance stores the raw sequence (R-7.8).
- **R-21.5 (P0)** Lam-alif inside words (F-7): medial/final-context lam-alif ligatures are
  Ligature Groups exactly like isolated لا; decomposition places constituents with the
  correct joined forms for their context (D-108).
- **R-21.6 (P0)** ZWJ/ZWNJ pasted input: preserved as real (invisible) codepoints; they
  affect shaping per Core Text; at derivation they map into cluster provenance but produce
  no selectable node; the letter-level list shows an "أحرف تحكم" (control characters)
  count badge for transparency; revert restores them byte-exact. The engine's own ZWJ
  synthesis (D-107) never leaks into the user's string.
- **R-21.7 (P0)** Marks across ligature decomposition: mark re-attachment per cluster map
  (R-8.13); a mark whose codepoint attaches between two constituents (font-dependent)
  re-attaches to the constituent owning its base codepoint; never orphaned, never dropped.
- **R-21.8 (P0)** RTL/LTR paste: pasting LTR text into RTL context (and vice versa)
  preserves codepoints exactly; any embedded directional controls (LRM/RLM/LRE/RLE/PDF/
  LRI/RLI/FSI/PDI) are preserved and respected by UBA; the control-character badge
  (R-21.6) surfaces them; no stripping without user action ("إزالة أحرف التحكم" remove
  control characters is an explicit cleanup command).
- **R-21.9 (P0)** Word-ligature fonts that cannot decompose sensibly (R-8.14): fall back
  to default constituent forms with notice; never crash, never emit .notdef.
- **R-21.10 (P0)** Emoji and non-Arabic scripts: render via system font cascade (color
  glyphs supported in raster exports); in Arrange Mode an emoji is a single Glyph Node
  (color bitmap glyph — path unavailable) marked non-outlinable: SVG/print-PDF export
  embeds it as an image element with documented notice (R-13.7 disclosure list); never
  silently dropped. This image-element carve-out applies even when the emoji/color glyph
  is a constituent of an Arranged Composition or Ligature Group — arranged constituents
  otherwise always export as outlines, but a non-outlinable color glyph is the one
  carve-out to that rule (D-227).
- **R-21.11 (P0)** Very long single-line text (10,000+ chars, no breaks): typing remains
  responsive via incremental shaping of the edited line (budget: echo <50 ms up to 1,000
  glyphs; beyond that, documented degradation with a "نص طويل جدًا" long-text hint);
  arrangement of such an object shows a progress HUD and remains cancellable; layers
  panel virtualization holds (R-10.3).
- **R-21.12 (P0)** Kashida/tatweel U+0640 (F-9): a real, shapeable, joining character —
  selectable Glyph Node in arrangement, stretchable via scale-X like any glyph;
  join-breaking around kashida behaves per R-8.2; export identical to canvas.
- **R-21.13 (P0)** Paste of styled/rich text: plain-text codepoints only are taken; style
  comes from the target object (documented; no RTF import).
- **R-21.14 (P1)** Unsupported/newer Unicode (unassigned codepoints, ZWJ emoji sequences):
  render per system; cluster map follows Core Text's clustering; unknown clusters become
  single opaque Glyph Nodes; never crash.
- **R-21.15 (P0)** Mixed-numeral round-trip (F-5): ٢١٣ and 123 keep their codepoints;
  reordering follows UBA; arrangement captures per-digit glyph nodes in visual order with
  correct bidi levels (D-109).

### 21.2 Fonts

- **R-21.20 (P0)** Missing glyphs / .notdef: committed renders never draw tofu silently —
  fallback-run badge per R-5.10; if even cascade fails (.notdef), the glyph renders as
  .notdef WITH the badge and export disclosure; arrangement of a fallback run records the
  actual fallback font in provenance.
- **R-21.21 (P0)** Font deleted while used (premium font removed from catalog cache, or
  user-imported font file lost): Live Text → missing-font badge + fallback render + offer
  to re-download/re-import/replace; Arranged nodes unaffected (outlines captured);
  document NEVER fails to open because a font is missing.
- **R-21.22 (P0)** Imported font invalid: sfnt validation rejects with the specific Arabic
  errors of R-12.3; a font that registers but fails to shape Arabic (no arab script
  tables) imports with a warning badge "قد لا يدعم العربية" (may not support Arabic) —
  not blocked (Latin fonts are legitimate for bilingual work).
- **R-21.23 (P0)** Variable font axes: axis instance recorded in provenance (R-5.9);
  changing axes on Live Text re-shapes; on an Arranged Composition axes are frozen
  (R-6.3) — the inspector shows them read-only with the hint "ثبّت التنسيق قيم المحاور"
  (arrangement froze axis values); a variable font missing named instances still exposes
  raw axes.
- **R-21.24 (P0)** Duplicate font family names (imported font shadowing a bundled one):
  catalog keys fonts by file hash + PostScript name; both appear, disambiguated by source
  chips (مضمّن bundled / مستورد imported); provenance references the hash so documents
  never re-bind to the wrong file.
- **R-21.25 (P0)** Expiry with imported fonts (Q27/Q64): imported fonts lock exactly like
  premium catalog fonts (R-12.10); files are retained (not deleted) so re-subscribing
  restores them instantly.

### 21.3 Arrange Mode & editing lifecycle

- **R-21.30 (P0)** Arrange-then-edit-source conflict: per R-6.11 (choice sheet; duplicate
  option preserves work). Editing via external means is impossible (no external editors).
- **R-21.31 (P0)** Revert confirmation: always required (R-6.12); the confirmation lists
  the count of manual adjustments ("١٢ تعديلًا يدويًا سيُحذف" 12 manual adjustments will
  be deleted) when count ≥1; zero-adjustment reverts skip the count line but still
  confirm.
- **R-21.32 (P0)** Undo across mode switches: the stack is global (R-2.12); undoing past
  the arrangement-entry command restores the pre-arrangement Live Text; redo re-derives
  byte-identically (snapshot stored with the command, not re-computed); undoing a revert
  restores the full composition (R-4.19). Entering text-edit overlay does not clear the
  stack; an in-progress overlay session commits as one command on Done.
- **R-21.33 (P0)** Deleting a base glyph with attached marks: marks follow the base into
  deletion (one command); detached marks (R-7.5) survive independently; undo restores
  base+attachments.
- **R-21.34 (P1)** Scaling a composition to near-zero (<1% or <1 pt bounds): clamped at a
  minimum visual size with haptic feedback; numeric inspector allows exact small values
  but never 0/negative scale (validation error shake).
- **R-21.35 (P0)** Arrange during active text editing: the arrange button is disabled
  while the overlay is open (commit first); no half-committed derivations.
- **R-21.35a (P0)** Neutral-punctuation freeze at capture (INV-1/D-109): bidi neutral
  characters (punctuation, spaces) resolve their visual placement once, at Arrange Mode
  derivation; that resolved position is baked into the neutral's Glyph Node and is immune
  to any later move/reorder of neighboring glyphs — dragging or transforming a neighbor
  never re-triggers neutral placement for the frozen node (scope of the no-auto-reflow
  rule, R-6.3).

### 21.4 Path text

- **R-21.36 (P0)** Path self-intersection: allowed (freeform paths may cross); layout
  follows arc length regardless; glyphs may visually overlap at crossings — no error, and
  tangent rotation stays continuous (no glyph flipping at crossings or inflections).
- **R-21.37 (P0)** Zero-length/degenerate path (all anchors coincident): path editor
  prevents committing a path shorter than 8 pt; programmatic edge (undo chains) renders
  the text stacked at the point with an overflow badge — no NaN transforms, no crash
  (T-path fuzz test).
- **R-21.38 (P1)** Extremely tight curvature (radius ≪ glyph width): glyphs place on
  tangent without collision resolution (documented v1 behavior); no auto-kerning on path.
- **R-21.39 (P0)** Path edit after arrange: impossible by construction (R-9.8); the ghost
  guide is non-interactive.

### 21.5 Persistence, autosave, documents

- **R-21.40 (P0)** Duplicate-project during autosave: duplication snapshots the last
  committed package state plus the in-memory scene (flush-then-copy); the copy is never a
  torn file (atomicity via D-112 write-temp+rename); verified by an interruption test.
- **R-21.41 (P0)** Storage-full autosave failure: autosave failure surfaces a persistent
  (non-dismissable while unresolved) banner "التخزين ممتلئ — تعذّر الحفظ التلقائي. حرّر
  مساحة الآن" (storage full — autosave failed, free up space now); editing may continue
  in memory; the journal keeps the un-flushed batch; export is blocked while unsaved
  (data-loss protection); resolved automatically when space frees.
- **R-21.42 (P0)** Crash/kill mid-edit: relaunch replays the journal; recovery restores
  to the last committed command batch (≤2 s of work at risk, D-112); a recovered project
  opens with a subtle toast "تمت الاستعادة" (recovered).
- **R-21.43 (P0)** Schema forward-compat: opening a document with a NEWER schemaVersion
  than the app supports opens read-only with copy "أُنشئ هذا المشروع بإصدار أحدث"
  (created with a newer version); never destructive rewrite.
- **R-21.44 (P0)** Export during memory pressure: the D-116 ladder runs first (caches
  dropped, autosave forced); export proceeds tiled; if the critical stage fires mid-export
  the export aborts cleanly with "تعذّر التصدير — الذاكرة ممتلئة. أُغلق التطبيقات الأخرى"
  (export failed — memory full, close other apps), the document already safe (autosave
  preceded render); partial output files are deleted.
- **R-21.45 (P1)** Project rename to empty/whitespace: rejected inline, keeps prior name;
  names are not filenames (package names are UUID-based; display name lives in manifest)
  so no filesystem-character issues exist.

### 21.6 Sync & iCloud

- **R-21.46 (P0)** Sync conflicts: last-writer-wins + "(نسخة متعارضة)" conflict copy when
  both sides diverged (R-17.3); the copy appears in the browser next to the winner; no
  merge attempts in v1.
- **R-21.47 (P0)** iCloud account switch: CK account-change notification stops the engine,
  re-scopes sync state to the new account; projects synced under the old account remain
  local copies (never deleted); toggle shows the active account context (R-17.6).
- **R-21.48 (P0)** iCloud sign-out mid-session: sync pauses gracefully; queued changes
  persist locally and resume when an account returns; zero data loss.
- **R-21.49 (P0)** Quota exceeded: per-project error state + Settings copy (R-17.5);
  retries with backoff; editing/export unaffected.
- **R-21.50 (P1)** Same project edited on two devices offline: both sync on reconnect →
  R-21.46 conflict handling; test with arranged compositions specifically (largest
  payloads).

### 21.7 Store, trial, entitlements

- **R-21.51 (P0)** Purchase interrupted (network drop, parental approval "Ask to Buy",
  app kill mid-sheet): StoreKit 2 `Transaction.updates` delivers the eventual result on a
  later launch; pending states show "قيد الانتظار" (pending) in Settings; the paywall
  never double-charges (StoreKit-native) and never blocks on a pending transaction.
- **R-21.52 (P0)** Trial clock rollback: monotonic guard (R-15.7); rolling the clock back
  shows the true remaining days (never more than the legitimate remainder); rolling
  forward expires normally (no un-expire on rollback after that).
- **R-21.53 (P0)** Restore on a new device: "استعادة المشتريات" re-syncs entitlements
  (subscription/lifetime via Apple Account); the app-side trial pulls the earliest KVS
  timestamp — a trial consumed on device A is consumed on device B (R-15.6).
- **R-21.54 (P0)** Lifetime + subscription both present: R-15.4 (lifetime wins; cancel
  guidance; nothing hidden).
- **R-21.55 (P0)** Grace-period expiry mid-export: entitlement checks bind at render
  request (R-15.12); an export already rendering completes and is delivered (the check
  passed when it started); the NEXT export re-evaluates; no mid-render aborts for
  entitlement reasons (only memory, R-21.44).
- **R-21.56 (P0)** Refund/revocation: `revocationDate` transactions drop entitlement
  reactively; locked-content behavior = expired tier; no accusatory messaging (R-15.10).
  The R-21.55 mid-export completion rule extends to revocation: an export already
  rendering when a `revocationDate` transaction arrives completes and is delivered; the
  NEXT export re-evaluates entitlement (D-228).
- **R-21.57 (P0)** Referral flag OFF behavior: with `referralProgram` OFF, zero referral
  UI/strings/StoreKit surface exists anywhere (R-16.1); QA gate greps release UI for
  referral strings; codes entered in any text field are just text.
- **R-21.58 (P1)** StoreKit sandbox/product-load failure on paywall: cached product info
  renders if available, else the paywall shows "يتطلب الاتصال بالإنترنت" with retry —
  never a blank sheet, never fabricated prices.

### 21.8 Canvas, layers, import

- **R-21.59 (P0)** Locked/hidden layer interactions: locked → skipped by canvas taps,
  selectable in panel, transform fields read-only until unlocked; hidden → excluded from
  render, hit-testing, AND export (R-4.10); locking/hiding a group applies to descendants;
  a hidden node inside a selected group is excluded from group transform previews; undo
  restores lock/hide states.
- **R-21.60 (P0)** Deleting a group with mixed locked/unlocked children: blocked with
  choice — "المجموعة تحتوي عناصر مقفلة" (group contains locked items): unlock-and-delete
  or cancel.
- **R-21.61 (P0)** Imported SVG with unsupported constructs: partial rasterization notice
  per R-11.8; imported PDF with transparency groups renders via CGPDF fidelity; encrypted
  PDFs rejected with "ملف PDF محمي" (protected PDF).
- **R-21.62 (P1)** Pasting an image while free (Q34 gating): paste routes through the same
  gate as import — lock badge + paywall path, clipboard untouched.
- **R-21.63 (P1)** 5,000-node scenes: panel virtualization, marquee performance, and the
  D-115 heavy-open budget (<3 s) are the acceptance gates; degradation ladder engages
  before jank (§22).

### 21.9 Memory, system, lifecycle

- **R-21.64 (P0)** Memory-pressure staged response (D-116): 70% — drop offscreen caches +
  autosave; 85% — half-res previews + banner "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا"
  (memory nearly full — autosaved); critical — synchronous autosave + journal flush;
  relaunch restores exactly.
- **R-21.65 (P0)** Backgrounding during export: export continues under a background task
  assertion; if the OS reclaims time, the export aborts cleanly per R-21.44 semantics and
  a local notification is NOT used (no notification permission in v1) — the export sheet
  reports on return.
- **R-21.66 (P0)** Expiry mid-edit (trial or subscription lapse while editing): current
  operation completes; gates re-evaluate lazily (R-15.12, FL-12 step 5); an arranged
  composition using premium fonts remains editable (outlines) — only re-shape and export
  gates engage.
- **R-21.67 (P0)** App update mid-project (schema migration): additive JSON migrations at
  open with pre-migration rescue snapshot into `backups/` (D-112); failed migration =
  read-only open + intact backup, never data loss.
- **R-21.68 (P1)** Device rotation / Stage Manager resize mid-gesture: gesture cancels
  cleanly (no partial command), viewport re-fits, selection preserved.

---

## 22. Non-Functional Requirements

### 22.1 Performance budgets (D-115 — release gates)

- **R-22.1 (P0)** Manipulation frame time ≤8.3 ms on ProMotion hardware; ≤16.6 ms floor on
  A12-class devices (oldest iOS 18 class).
- **R-22.2 (P0)** Typing echo <50 ms (keystroke → overlay glyph visible).
- **R-22.3 (P0)** Project open: typical (≤100 nodes) <1 s; heavy (5,000 nodes) <3 s.
- **R-22.4 (P0)** Incremental autosave <100 ms, off the main thread.
- **R-22.5 (P0)** 4K PNG export <10 s on A15-class hardware.
- **R-22.6 (P0)** Peak editor memory <60% of `os_proc_available_memory` before the
  degradation ladder begins (D-116).
- **R-22.7 (P0)** These budgets are quantitative gates for ALL iOS 18 devices in
  TEST_MATRIX (profiling evidence required per Q59 — build success, performance profiling
  vs budgets, StoreKit sandbox tests, and the manual Arabic-script verification checklist
  are the four release gates; no mandatory accessibility/UI/snapshot suites in v1).
- **R-22.18 (P0)** Cold launch to interactive project browser <1 s on A15-class devices
  (D-115 as amended by D-218; enforcement: TEST_MATRIX T-PRF-13).

### 22.2 Reliability & integrity

- **R-22.8 (P0)** Zero-data-loss guarantee: any crash/kill/memory termination loses at
  most the last un-journaled batch (≤2 s); verified by automated kill-during-mutation
  tests.
- **R-22.9 (P0)** Determinism: identical scene snapshot → identical export bytes
  (modulo format metadata timestamps) across runs on the same device/OS; canvas preview
  and export pixel-identical by the single-render-path rule (R-13.1).
- **R-22.10 (P1)** Degradation is always soft and reversible (preview fidelity, list
  virtualization) — never feature caps (R-14.2).

### 22.3 Engineering constraints

- **R-22.11 (P0)** SwiftUI-first; UIKit/Core Text/TextKit 2/Core Graphics permitted where
  needed; Metal is an extension seam only (D-114). Custom native arrange layer sits ATOP
  Apple shaping — never a ground-up shaper (Q47, D-103).
- **R-22.12 (P0)** Toolchain: Xcode 16.x, `xcodebuild`, `gh` only; no
  XcodeGen/Tuist/Fastlane/external CI unless later justified (Q49, D-101). No third-party
  runtime dependencies in v1.
- **R-22.13 (P0)** Swift 6 strict concurrency (D-100/D-102): `@MainActor` UI + document
  model; `Sendable` engine services; renderer consumes immutable snapshots.
- **R-22.14 (P0)** Persistence per D-112 (file packages + JSON scene + SwiftData metadata
  index) — the decisive recommendation with alternatives recorded in DECISIONS_LOG.
- **R-22.15 (P0)** Codebase-memory conventions (Q58): durable ADRs, implementation logs,
  and verification evidence per phase.
- **R-22.16 (P0)** Distribution automation (Q56/Q84): App Store prep and submission
  automated where technically possible; pauses only for founder credentials, legal
  acceptances, license purchases, provisioning, and final visual approval.
- **R-22.17 (P1)** Security: no dynamic code, no remote config execution; downloaded font
  files sfnt-validated before registration (R-12.3 validation also applies to catalog
  downloads); all network calls TLS; no secrets in the client (there is no server).

---

## 23. Out of Scope / v2 Seams

Everything here is explicitly NOT built in v1. Only the named seam exists.

- **R-23.1 (P2-seam)** **Animation/video/reels export**: scene graph nodes carry stable
  UUIDs and value-type snapshots suitable for future keyframing; `MKRender` isolates
  frame rendering behind a snapshot API. No animation model, timeline UI, or video
  encoder in v1 (BRIEF: v2).
- **R-23.2 (P2-seam)** **Templates**: the document model can serialize a scene as a
  starting point (that's all — duplicating a project already does this). No template
  gallery, no placeholder semantics, no template content (Q61–62 locked no).
- **R-23.3 (P2-seam)** **Multi-page projects**: `manifest.json` reserves a `pages` array
  (length 1 in v1); scene loading takes a page index. No multi-page UI.
- **R-23.4 (P2-seam)** **App Store Server API entitlement validation**: `MKStore` isolates
  verification behind a protocol so a server validator can be added; v1 is on-device JWS
  only (D-113). Requires a backend that does not exist in v1.
- **R-23.5 (P2-seam)** **Commercial foundry pipeline**: catalog schema fields
  (`licenseType`, `embeddingRights`, `foundry`, `commercialStatus`) exist from v1
  (R-12.4); acquisition/licensing process is FD-07, post-v1; v1 ships OFL-verified fonts
  only.
- **R-23.6 (P2-seam)** **Sacred-text assets (Qur'anic content, Uthmani fonts/text)**:
  nothing ships in v1 (R-1.5); ANY future sacred-text asset requires explicit founder
  approval plus licensing/accuracy review (BRIEF; KFGQPC prohibition MS[31][32]; Tanzil
  terms MS[38][39] recorded for future reference only).
- **R-23.7 (P2-seam)** Also explicitly out (recorded for completeness): accessibility
  scope (R-1.16), Metal renderer (D-114 seam), custom kashida-justification controls
  (R-5.5), rich mixed-style text runs (R-5.8), image filters (R-11.12), asset packs
  (R-11.5), nested folders (R-3.6), trash/undo-delete (R-3.9), deep links/widgets/App
  Intents (R-2.6), offer codes UI (R-14.16), collaborative editing (market study §11 v2),
  Family Sharing decision execution (FD-06 — configuration decision at ASC setup,
  irreversible per product, MS[46][47][48][49]; VERIFY-AT-SUBMISSION).

---

## Traceability — BRIEF.md → PRD requirements

Tension notes (resolved during Run-1 self-review): **TN-1** — BRIEF Q34 gates "photo
background import" premium-only with "free = solid colors only"; whether free users may
place imported raster images as non-background elements was ambiguous. This PRD
conservatively gated ALL raster import premium (R-11.7, G11) — resolved by D-217: all
raster-image import (background or placed element) and SVG/PDF import are premium,
founder-editable pre-P11. **TN-2** — D-124's local honor-based referral attribution
cannot verify the market-study-compliant "qualifying paid action" (MS[53]); recorded
inside R-16.3/FD-05 — disposition folded into FD-05.

| BRIEF bullet (§, paraphrase) | PRD requirements |
|---|---|
| Identity: name Makhtoot/مخطوط only | Front matter, R-1.1 |
| Identity: bundle id placeholder | Front matter, R-14.10 |
| Identity: themeable Arabic-first design system, swappable tokens, baseline aesthetic subject to founder approval | R-2.1–R-2.3 (RTL-first UI per D-126); design-system detail lives in ARCHITECTURE §22 (D-126, FD-02) |
| Platform: universal iPhone+iPad, iOS 18, adaptive | R-1.1, R-2.2, R-1.12 |
| Platform: v1 static only, animation v2 seam | R-1.2, R-23.1 |
| Platform: Arabic-only RTL UI | R-1.3, R-2.3, R-20.1 |
| Platform: offline + only 3 network uses | R-1.4, R-19.1–R-19.4 |
| Platform: no accessibility scope | R-1.16, R-23.7 |
| Platform: no templates; shapes/ornaments/frames/patterns in v1 | R-1.17, R-11.1–R-11.4, R-23.2 |
| Engine: native-field typing (shaping/forms/ligatures/tashkeel/bidi/numerals/punctuation) | R-5.1–R-5.5, FL-3, R-21.15 |
| Engine: Arrange Mode derivation + retained reversible source + confirmed revert | R-6.1–R-6.3, R-6.12, FL-4, FL-13, R-21.31 |
| Engine: no auto-reflow; every glyph/mark/ligature-component independently transformable (position/rotation/scale/opacity/fill/outline/shadow) | R-6.3, R-6.5, R-7.4, R-8.9 |
| Engine: both glyph level and Unicode-letter level, lossless switching | R-6.4, R-6.8 |
| Engine: joining preserved by default; explicit break; form selector (isolated/initial/medial/final) | R-8.1–R-8.7, FL-6 |
| Engine: full tashkeel + Qur'anic/Uthmani-style marks attach/follow/selectable/detachable/movable | R-7.1–R-7.10 |
| Engine: ligatures as combined objects AND decomposable; fidelity default; opt-out (Q71) | R-8.8–R-8.14, FL-7 |
| Engine: per-object kerning/tracking/baseline/line-height/scale/rotation/opacity/outline/shadow/fill | R-4.13, R-5.6, R-6.5, R-10.6 |
| Engine: live Bézier path text; reflowable until arranged; arranged keeps per-glyph adjustments (Q72) | R-9.1–R-9.10, FL-8 |
| Engine: no preloaded Qur'anic content; identical treatment; future assets need founder approval | R-1.5, R-12.5 (label only), R-23.6 |
| Canvas: drag/resize/rotate/multi-select/guides/snapping/layers/grouping/lock-hide/undo-redo/zoom/pan | R-4.1–R-4.12, R-4.16–R-4.19 |
| Canvas: layers panel (text/arranged glyphs/marks/images/shapes; visibility/lock/reorder) | R-10.1–R-10.5, FL-9 |
| Canvas: numeric inspector X/Y/W/H/rotation + style fields | R-10.6–R-10.10 |
| Canvas: all users autosave/duplicate/folders/search/export history; premium iCloud sync | R-3.2–R-3.10, R-17.1–R-17.9, G23/G24 |
| Canvas: imports raster/SVG/PDF; custom fonts premium-only | R-11.6–R-11.12, R-12.3 |
| Fonts: four mechanisms in v1 | R-12.1–R-12.4 |
| Fonts: formats ttf/otf/ttc/variable; reject unsafe with clear errors | R-12.3, R-21.22 |
| Fonts: catalog previews/styles/tags/favorites/search + 10 categories | R-12.5 |
| Fonts: licensing surface at Settings→Support→Licensing (Q66) | R-12.7, R-20.2–R-20.3 |
| Fonts: expiry locks premium+imported; export falls to free until re-subscribe/replace (Q27) | R-12.10, R-14.8–R-14.9, FL-12, R-21.25 |
| Fonts: acquisition/verification process, never invent licenses; Amiri/Noto verified; KFGQPC prohibited; Alif Type pending | R-12.1, R-12.2, R-20.3 (protocol in WS-09) |
| Export: free JPEG+rasterized PDF 2 MP | R-13.2, G13–G14 |
| Export: premium PNG/transparent-PNG/SVG/hi-res print PDF | R-13.3–R-13.5, G16–G19 |
| Export: 4K+/300-DPI/unlimited-with-memory-protection (Q76) | R-13.4, R-21.44 |
| Export: SVG editable-preserving; documented outline fallbacks; never silent (Q73) | R-13.6–R-13.8 |
| Export: true CMYK ICC PDF + full color-management design (Q75) | R-13.9–R-13.11 (FD-03) |
| Export: presets incl. static-reel etc. + premium custom dims | R-13.12, G20 |
| Export: free gating incl. photo backgrounds premium (Q34) | R-14.1 matrix, R-14.4–R-14.6, R-11.7 (TN-1) |
| Export: verify sharp Arabic output at print res | R-13.14 |
| Performance: no artificial caps; memory monitoring/warnings/autosave/recovery; soft degradation; quantitative budgets | R-4.2, R-14.2, R-21.64, R-22.1–R-22.10 |
| Monetization: $3/$30/$90 + storefront localization | R-14.10, R-14.12 (mapped per D-216) |
| Monetization: 7-day trial at first launch, monthly+annual, reinstall-resistant, documented vs intro offers (Q37) | R-15.5–R-15.9, FL-1 |
| Monetization: post-trial free tier fully honest (Q41) | R-1.15, R-14.3, G-matrix Free column |
| Monetization: lifetime = permanent premium | R-14.10, R-15.4, R-21.54 |
| Monetization: referral architected, flag OFF, referrer-only, anti-abuse, review-risk docs, easy removal (Q78) | R-16.1–R-16.5, G26, R-21.57 (TN-2) |
| Monetization: full StoreKit 2 (status/restore/precedence/grace/retry/messaging/testing/verification position) | R-15.1–R-15.4, R-15.10–R-15.13, R-14.13, R-21.51–R-21.58, R-23.4 |
| Accounts: no mandatory account; SIWA not in v1; CloudKit on user iCloud (Q77) | R-1.18, R-17.1 |
| Privacy: only opt-in anonymous font-usage analytics; never content; consent/aggregation/minimization | R-18.1–R-18.5 |
| Privacy: no ads | R-18.4 |
| Territories: all without extra legal docs + checklist (Q46) | R-18.7 |
| Engineering: SwiftUI-first + permitted lower layers; arrange atop Apple shaping | R-22.11, R-22.13, D-103 refs in §5–§6 |
| Engineering: Xcode/xcodebuild/gh only | R-22.12 |
| Engineering: persistence recommendation (Q50) | R-22.14, R-3.1 (D-112) |
| Engineering: gates (build/profiling/StoreKit sandbox/manual Arabic checklist; no a11y/UI suites) | R-22.7, R-13.14 |
| Engineering: automated distribution with founder-only pauses (Q56/Q84) | R-22.16 |
| Engineering: codebase-memory ADR conventions (Q58) | R-22.15 |
| Research gaps: grace durations, per-font OFL, ICC licensing, referral guideline text, foundry licenses | R-15.11, R-12.1, R-13.10, R-16.1, R-23.5 — each marked VERIFY-AT-SUBMISSION or FD-gated |

*End of PRD.md — Run 1. Cross-references: FOUNDATION.md (D-100…D-126, FD-01…FD-07),
ARCHITECTURE.md (engineering mechanics), TEST_MATRIX.md (T-ids for every R/FL/fixture),
APP_STORE_CHECKLIST.md (submission-time verifications), DECISIONS_LOG.md (rationale).*


