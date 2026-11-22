# Makhtoot — Feature Integration Plan

**Goal:** the reference app's functionality, Makhtoot's design, and the 18 bugs
from [BUGFIX-PLAN.md](BUGFIX-PLAN.md) fixed — as one sequenced programme.

**Source of the feature inventory:** 12 screenshots of the reference app
(Arabic calligraphy designer, iOS). Everything in Part 1 is what is *visible* in
those screenshots; where I inferred behaviour rather than saw it, it says so.

**The headline finding:** Makhtoot already contains a complete, manifested,
unit-tested asset library — **57 assets across the exact five categories the
reference app's pickers show** — with a full browser backend (search, favourites,
recents, premium gating, placement API). **None of it has any UI, and the
renderer refuses to draw it.** A large share of the "missing functionality" is a
wiring job, not a build job.

---

# Part 1 — Feature inventory of the reference app

## 1.1 Top toolbar (persistent, 9 items)

| Icon | Feature |
|---|---|
| ☰ | App menu (§1.2) |
| **T** | Insert/edit text → the text dialog (§1.3) |
| ج̆ | **Calligraphic glyph picker** → Collection / Thuluth palettes (§1.5) |
| ▪▲★ | **Shape picker** → geometric shape grid (§1.6) |
| 🖼 | **Image**: Choose… / Fit / Edit… / Remove (§1.4) |
| ↶ ↷ | Undo / Redo |
| ⤴ | Share / export |
| ? | Help |
| ⋯ | Edit menu: Copy, Paste, Delete, Select All, Deselect All, Flip Horizontally, Flip Vertically |

## 1.2 App menu (☰)

`New Design` · `My Designs` · **`Merge Design`** · `Save Design` — then
**`Show Grid`** · **`Background Color`** — then `Fit to Screen` · `Actual Size`
— then `Settings` · `Help` · `Terms and Conditions` · `Privacy Policy`.

Notable: **Merge Design** (import another saved design into the current canvas)
and **Show Grid** have no Makhtoot analogue.

## 1.3 Text insertion dialog

A single modal that does everything:

- Multi-line Arabic text field (large, top of screen — **above** the keyboard)
- Font selector button (`Diwan Naskh`)
- Point-size stepper (`▼ 384 ▲`) — note the *huge* default size, appropriate for calligraphy
- Alignment control · line-spacing control
- **`Split text by spaces`** toggle — inserts each word as its own independent object
- **`Group lines`** toggle
- `Preview` · `Cancel` · `Insert`, with a **live preview of the canvas rendered below the dialog**

## 1.4 Image handling

Menu: `Choose…` (enabled) → `Fit`, `Edit…`, `Remove` (greyed until an image
exists). So: import, fit-to-canvas, adjust, remove.

## 1.5 Calligraphic glyph picker — the reference app's strongest feature

Two tabs: **`Collection`** and **`Thuluth`**.

**Thuluth tab** — a dropdown of Arabic letter groups:
> Beh Teh Theh ب ت ث · Jeem Hah Khah ج ح خ · Dal Thal د ذ · Reh Zain ر ز ·
> Seen Sheen س ش · Sad Dhad ص ض · Tah Zah ط ظ · Ain Ghain ع غ · Feh Qaf ف ق ·
> Kaf ك · Lam ل · Meem م · Noon ن · Heh هـ · (scrolls further) · **Marks**

Selecting a group shows a grid of **hand-drawn alternate calligraphic forms** —
~25 variants for Kaf alone. `Marks` shows tashkeel and decorative marks
(strokes, dots, a large circle, dashes).

**Collection tab** — mixed ornaments, ligatures, compound forms, kashida/stroke
variants, rosettes, dot clusters, zigzags, swashes. Several screens of scrolling.

Every panel ends in `Insert` / `Close`.

**Estimated inventory: several hundred vector glyph variants.** This is a
*content* asset, not an engineering one.

## 1.6 Shape picker

~35 shapes in a grid: line, square, rounded square, rectangle, rounded
rectangle, circle, ellipse, triangle, right triangle, pentagon, hexagon,
octagon, squircle, **8-point Islamic star**, arrow, 5-point star, rounded star,
**crescent**, hearts ×2, flower, 5- and 6-petal flowers, leaves ×2, maple leaf,
branch, curve, clouds ×2, **brush strokes ×3**, speech bubble, trapezoid.
`Insert` / `Close`.

## 1.7 Contextual bottom bar (object selected)

`тT` (size) · **`< Style`  `Style >`** (cycle the selected object through
calligraphic style variants) · duplicate · delete · move · rotate · fill · stroke/pen · ≡ (more)

`< Style` / `Style >` is a fast **alternate-form cycler** — tap through variants
of the selected letter without opening a picker.

## 1.8 Token strip

Below the canvas, a strip of blue chips — one per word/token
(`تجر` `بة` `عبد` `ا` `لقد` `و` `س` `ا` / `بن` `أ` `بي` `ما` `جه`) — mirroring
the per-word objects created by *Split text by spaces*. Each canvas token also
shows its own dotted selection box. The strip is a **flat object selector**:
tap a chip to select that token on canvas.

## 1.9 Colour picker

A proper one: 2-D saturation/brightness square · full hue strip · **alpha strip
with checkerboard** · current-colour swatch · **`Favorites` / `Custom`** tabs ·
**eyedropper** · **heart (save to favourites)** · sliders (numeric entry) · close.

## 1.10 Canvas

Transparent checkerboard background (real alpha, not white) · per-object dotted
selection boxes · multiple objects selected simultaneously.

---

# Part 2 — Gap analysis

## Bucket A — Makhtoot already has it, built and tested, with **no UI**

This is the highest-leverage bucket in the entire plan.

| Reference feature | Makhtoot's existing implementation | Status |
|---|---|---|
| Shape picker (§1.6) | `MKBasicShapeGenerator` — **15 shapes**, manifested | No UI; `ShapeDrawer` returns nil for `.asset` |
| Collection ornaments (§1.5) | `MKOrnamentGenerator` — **16 ornaments** | Same |
| Calligraphic elements (§1.5) | `MKCalligraphicGenerator` — **10** (swashes, dividers, finials, dot clusters) | Same |
| Frames | `MKFrameGenerator` — **8**, with nine-slice insets | Same; reference app has no equivalent |
| Pattern backgrounds | `MKPatternTileGenerator` — **8** (hexagonal lattice, 8-star tessellation, zellij interlock) | Same |
| Picker search / favourites / recents | `MKAssetBrowserModel`: `setSearchQuery`, `toggleFavorite`, `favoriteDescriptors()`, `recentDescriptors()`, `sections()`, `isLocked()`, `select() -> PlacementOutcome` | **Complete backend, zero views** |
| Premium gating on assets | `MKPremiumContentLedger`, `PlacementOutcome.premiumRequired(capability:…)` | Wired in the model, unreachable |
| Asset thumbnails | `MKAssetThumbnailRenderer`, `MKAssetContactSheetGenerator` | Built, unused |
| Licence provenance | `MKAssetProvenanceStore` + `provenance-records.json` | Built, unused |
| Font import (§Settings) | `MKFontImporter` — a tested `public actor` | Referenced only inside a **code comment** |
| `< Style` / `Style >` cycler (§1.7) | `MKArrangeFormSelectorModel` + `FormSelectorPopoverView` — alternate-form selection per glyph | Exists, but only inside Arrange Mode, and its toolbar is dead (**Bug 16**) |

**Manifest totals: 57 assets, 27 premium.** Verified from
`MakhtootKit/Sources/MKAssets/Resources/assets-manifest.json`.

## Bucket B — Partial: model or engine support exists, UI/render path missing

| Reference feature | What exists | What's missing |
|---|---|---|
| Background image (§1.4) | `MKBackgroundContent.image(MKAssetRef)`, `CanvasContentAPI.addImage`, `MKImageDrawer` | Picker, ingestion, Fit/Edit/Remove |
| Background colour (§1.2) | `MKBackgroundContent.solid` | No UI entry point |
| Transparent canvas (§1.10) | Alpha throughout the render/export stack | Checkerboard presentation not shown |
| Colour picker (§1.9) | `MKColorSpec`, `CMYKConverter`, `ICCProfileStore` (**stronger colour science than the reference app**) | `MKColorPickerSheet` has **no saturation control** (Bug 10), no alpha, no favourites, no eyedropper |
| Text dialog (§1.3) | `TextEditingOverlayController`, live shaping | No pre-insert dialog, no size/font/align controls at insert, no live preview, no split/group toggles |
| Marks / tashkeel (§1.5) | `MarkAttachmentController`, R-7.5 attach-to-letter, `MarkAttachmentTests` | No palette; the "+" menu item is a **copy-paste stub** (Bug 14) |
| Fit to Screen / Actual Size (§1.2) | `zoomToFit()`, `zoomTo100Percent()` | Present but **broken** (Bug 3) and absent from any menu |
| Token strip (§1.8) | `LayersPanelView` over `LayersModel` | No flat per-token strip; no split-on-insert to populate it |

## Bucket C — Genuinely absent from Makhtoot

Show Grid · Merge Design · Copy/Paste/Select All/Deselect All · Flip
Horizontally/Vertically · Split text by spaces · Group lines · alternate-form
cycler outside Arrange Mode · alignment & line-spacing controls at insert time ·
app-icon switching (Bug 17).

## Bucket D — Makhtoot capabilities the reference app does **not** have

Do not regress these while chasing parity. They are the product's actual moat:

- **Arrange Mode** — per-glyph/per-letter manipulation, join break/restore,
  ligature decompose/recompose, mark detach/re-attach, revert-to-text. Nothing
  in the reference app comes close; its `< Style >` cycler is a toy by comparison.
- **Path Text** — text on arc/circle/wave/freeform Bézier paths with a real
  path editor.
- **Vector export** — SVG and vector PDF with glyph outlines. The reference app
  appears raster-only.
- **iCloud sync**, crash recovery, journalled undo, atomic package format.
- **Design-system themes** with a type ramp and token gallery.
- **Arabic-first UI.** The reference app's entire chrome is in English —
  "New Design", "Split text by spaces", "Insert", "Close" — in an *Arabic
  calligraphy app*. (It also ships a visible typo: "Fip Vertically".)
- **Font import + system-wide install**, licence auditing, CMYK/ICC colour.

---

# Part 3 — Design direction

The instruction is "better functionality, worse design" — so take the reference
app's **interaction model**, not its visual language.

## Take

1. **One picker, five categories.** The reference app splits glyphs and shapes
   across two toolbar buttons and two tabs. Makhtoot's `MKAssetCategory` already
   models five categories in one browser — ship a single `MKAssetBrowserSheet`
   with category segments, search, favourites, and recents. Strictly better
   than what the screenshots show.
2. **Insert-time text configuration.** Font, size, alignment, line-spacing and a
   live preview *before* committing beats Makhtoot's current "insert a blank
   field and hunt for the أء sheet".
3. **Split text by spaces.** A one-toggle path to per-word objects. Makhtoot can
   only get there today via full Arrange-Mode derivation, which is heavier and
   currently freezes the app (Bug 16).
4. **The token strip.** A flat, always-visible object selector is more
   discoverable on a phone than a layers panel behind a menu.
5. **A complete colour picker** — SB square + hue + **alpha** + favourites +
   eyedropper.
6. **The transparent-canvas checkerboard.** Honest about alpha; Makhtoot's white
   default hides it.
7. **Huge default point sizes** (theirs defaults to 384 pt). Calligraphy is
   display type; Makhtoot's `36` default is a text-editor assumption.

## Do not take

- The visual chrome: dense navy bars, ~28 pt hit targets, English-only labels,
  modal grids with no search, panels that overlap the canvas edge-to-edge.
- Two separate toolbar buttons for what is one asset library.
- `Preview` as a *separate button* — preview should be live.
- Greyed-out menu items with no explanation of what would enable them.

## Design rules for everything built below

| Rule | Why |
|---|---|
| Arabic-first labels, `MKTypeRamp`, RTL by default | The product's core differentiator; the reference app fails this completely |
| ≥44 pt hit targets on every control | The reference app's toolbars are well under this |
| One shared `MKFloatingBar` treatment for all floating chrome | Fixes Bug 7 and prevents the drift that caused it |
| Sheets use `.presentationDetents`, never full-screen modal grids | Keeps the canvas visible while picking |
| Every premium gate routes through the existing `presentPaywall(.premiumFeatureTap(…))` | One paywall path, already used by export formats |
| Every disabled control states *why* | Replaces the reference app's silent grey-out |

---

# Part 4 — The integration plan

Bug numbers below refer to [BUGFIX-PLAN.md](BUGFIX-PLAN.md).

---

## Phase 0 — Unblock (prerequisite for everything)

**P0.1 — Fix RC-1: make the scene observable.**
`MakhtootDocument` is not `@Observable` and `CanvasSession.scene` is a computed
passthrough to it, so **no SwiftUI view invalidates when the scene changes**.
Every picker, every panel, and every toolbar built in later phases will be
silently stale until this is fixed.

Fixes bugs 8, 9, 10, 11, and the dead Arrange toolbar in 16. Lets three polling
loops be deleted.

> **Land this alone.** It touches the persistence spine — autosave, journal,
> crash recovery, sync. Full `MKPersistenceTests` + `MKCanvasTests` green before
> anything stacks on it.

**P0.2 — Capture a repro for Bug 15** (text-on-shape). The only item in either
document that cannot be diagnosed from source.

---

## Phase 1 — Quick correctness wins (small diffs, high visibility)

| Item | Source | Work |
|---|---|---|
| Zoom buttons | Bug 3 | Guard the unconditional 150 ms `currentZoomScale` write that rebuilds the bar ~7×/s |
| Pill-bar centring | Bug 4 | `ViewThatFits` instead of `ScrollView` + fixed `maxWidth`, in all three toolbars |
| Illegible floating buttons | Bug 7 | Extract `MKFloatingBar`; apply to zoom controls, tool rail, arrange + path toolbars |
| Shapes are 1 pt | Bug 13 | `addShape` takes a real size; default off `min(canvas.w, canvas.h)` |
| **Fit to Screen / Actual Size in a menu** | §1.2 | Surface the (now working) `zoomToFit()` / `zoomTo100Percent()` — currently reachable only by an undiscoverable tap on the % badge |

---

## Phase 2 — Text entry, done properly

**P2.1 — Insert-time text dialog** (§1.3). Replace "insert a blank field" with a
sheet: Arabic text field, font picker (existing `FontBrowserSheet`), size
stepper, alignment, line-spacing, **live preview**, Insert/Cancel.

**P2.2 — `Split text by spaces`** (§1.3). On insert, tokenise on whitespace and
emit one `liveText` node per token. Far cheaper than Arrange-Mode derivation and
gives the reference app's core workflow immediately.

**P2.3 — `Group lines`** (§1.3). Wrap per-line tokens in the existing
`MKGroupNode`.

**P2.4 — Token strip** (§1.8). A horizontal chip strip over `LayersModel`,
filtered to top-level text nodes; tap selects on canvas, matching the
screenshots. Keep `LayersPanelView` for the full tree.

**P2.5 — Keyboard fixes** (Bugs 5, 6). Tap-outside-to-commit;
`scrollRectToVisible` on `keyboardWillShow`; make `commit()` non-re-entrant.
Note that P2.1 sidesteps much of this by moving text entry into a sheet with the
field **above** the keyboard — which is exactly what the reference app does.

**P2.6 — Default point size.** Raise the `36` default to a display-type default
scaled to canvas size.

---

## Phase 3 — The asset browser (largest payoff per unit of work)

**P3.1 — Make `.asset` geometry render.** `ShapeDrawer` currently bails:
> `.asset(MKAssetRef)` shape geometry needs `MKAssetVectorProgram` (MKAssets,
> WS-14 ، not yet built)

Wire `MKAssetGeometry` → `CGPath` in `MKRender`, plus `HitTester` parity and
`SVGSerializer` export parity. **Until this lands, all 57 assets are invisible.**

**P3.2 — `MKAssetBrowserSheet`.** One sheet over the existing
`MKAssetBrowserModel`: category segments (أشكال / زخارف / عناصر خطية / إطارات /
خلفيات), search field, favourites and recents rows, premium badges via
`isLocked`, placement via `select(_:at:canvasSize:)`, paywall on
`.premiumRequired`. **The backend is done and tested — this is a view.**

**P3.3 — Marks & tashkeel palette** (§1.5 Marks, Bug 14). Two entry points:
inline diacritic insertion in the text overlay (caret-position combining marks),
and decorative marks from the asset browser. Delete the stub menu item that
currently calls `addLiveTextAtCenter()`.

**P3.4 — Alternate-form palette** (§1.5 Thuluth, §1.7 `< Style >`). Lift
`MKArrangeFormSelectorModel` out of Arrange Mode: with a glyph selected, offer
its alternate forms as a grid *and* as prev/next cycler buttons. Requires
Phase 4's fix to be usable.

> **Content gap, stated plainly.** Makhtoot's 10 `calligraphicElements` are
> *dividers, swashes and finials* — not per-letter alternates. The reference
> app's Thuluth palette is a different asset class: ~25 hand-drawn variants
> **per letter**, across 14+ letter groups. Matching that is a
> **commissioning/licensing project measured in months**, not an engineering
> task. P3.4 delivers the *mechanism*; the library has to be filled separately.
> Do not let the plan imply otherwise.

---

## Phase 4 — Arrange Mode, unfrozen

**P4.1 — Move derivation off the main thread** (Bug 16). `ArrangeDeriver` is a
plain struct called from a `@MainActor` adapter, so full CoreText shaping and
per-glyph outline extraction run **synchronously on the main thread** — that is
the freeze. Make it an `actor` (`MKShapingService` already is one). Audit
`MKPathTextInteractionAdapter` for the identical defect.

**P4.2 — Surface `lastErrorMessage`.** Three silent early-return paths already
set it; nothing renders it.

**P4.3 — Add cancellation** — a second wand tap should cancel the in-flight derive.

---

## Phase 5 — Canvas, colour and image

| Item | Source | Notes |
|---|---|---|
| **Rebuild the colour picker** | §1.9 + Bug 10 | SB square + hue + **alpha** + favourites + eyedropper. Fixes the confirmed defect where saturation initialises to 0 with **no control to change it** — the real reason "text colour can't be set to anything but black/grey". Back it with the existing `MKColorSpec`/`CMYKConverter` for colour accuracy the reference app doesn't have. Also fix the shared `static previousHue` cross-sheet leak. |
| **Background colour** | §1.2 | Menu entry → the new picker → `MKBackgroundContent.solid` |
| **Background image** | §1.4 + Bug 2 | `PhotosPicker` + `.fileImporter` → asset ingest → `MKBackgroundContent.image`. Add Fit / Edit / Remove. Premium-gated. Needs `NSPhotoLibraryUsageDescription` — **missing it is a hard crash**. |
| **Transparent-canvas checkerboard** | §1.10 | Present alpha honestly |
| **Show Grid** | §1.2 | Display layer over the existing `SnapEngine`/`GuideRenderer` |
| **Highlight colour actually paints** | Bug 11 | `MKTextStyle.highlightColor` persists but **no renderer reads it** — zero hits in `MKRender`. Add to `LiveTextDrawer` + `SVGSerializer`. |
| **Text traits** | Bug 9 | Underline/strikethrough drawing + export; make unsupported bold/italic explain itself rather than silently no-op |

---

## Phase 6 — Editing operations

Copy · Paste · Delete · Select All · Deselect All · Flip Horizontally · Flip
Vertically (§1.1). All absent from Makhtoot. Flip is a sign change on
`MKTransform2D.scale`; clipboard needs an `MKNode` pasteboard representation
(the `Codable` conformance already exists).

---

## Phase 7 — Library, settings, polish

| Item | Source | Notes |
|---|---|---|
| **Project thumbnails** | Bug 1 | `writeThumbnail()` exists with **zero callers**; generate on editor close. Directly fixes "projects show a default icon" |
| **Font import** | Bug 18 | `MKFontImporter` is a tested actor referenced only in a *comment*. Add `.fileImporter` in a new Settings → الخطوط section |
| **Relocate system-wide font install** | Bug 12 | Move out of the أء sheet into the same Settings section; stop swallowing errors with `try?` |
| **Merge Design** | §1.2 | Import a saved project's nodes into the current scene |
| **App icon switching** | Bug 17 | Alternate icons per design-system theme; premium-gated |
| **Save Design / My Designs parity** | §1.2 | Makhtoot autosaves — verify the mental model is clear, don't add a redundant Save button |

---

## Phase 8 — Path Text structural work

Bug 15, gated on P0.2's repro. Likely a document-format migration (path text
stores absolute canvas coordinates and `PathTextDrawer` ignores
`core.transform.position`, so moving a path-text node cannot work). Heaviest
test coverage in the repo — last, deliberately.

---

# Part 5 — Sequencing at a glance

```
P0  Observable scene ─────────────── blocks everything
P1  Quick wins (zoom/centring/legibility/shapes)     ← ship immediately after P0
P2  Text dialog + split + token strip + keyboard
P3  Asset rendering + browser sheet + marks     ← biggest payoff per unit of work
P4  Arrange unfrozen
P5  Colour + image + background + grid + highlight
P6  Copy/paste/flip/select-all
P7  Thumbnails + font import + merge + app icon
P8  Path text migration                          ← last, needs a repro first
```

P1 and P2 can run in parallel with P3 once P0 lands. P8 must not start before P0.2.

---

# Part 6 — What I did not verify

- **Reference-app behaviour beyond what the screenshots show.** `Group lines`,
  `Merge Design`, `Fit`, `Edit…`, and the `< Style >` cycler are labelled but
  their behaviour is inferred, not observed.
- **The reference app's true asset count** — estimated from visible grid density
  and the letter-group dropdown, not counted.
- **Whether `MKAssetGeometry` → `CGPath` is a small or large job.** I confirmed
  `ShapeDrawer` refuses `.asset` and that the geometry type exists; I did not
  read `MKAssetGeometry`'s representation closely enough to size P3.1.
- **`MKArrangeFormSelectorModel`'s alternate-form coverage** — whether it can
  serve a general insertion palette (P3.4) or only substitution within an
  already-derived composition.
- No build or test run was performed for either document.
