# Makhtoot — Master Plan

**One document. Supersedes `BUGFIX-PLAN.md` and `INTEGRATION-PLAN.md`.**

Two inputs are merged here:

1. **18 reported bugs**, each traced to real code before being written down.
2. **A reference app's feature set** (12 screenshots — an Arabic calligraphy
   designer with, in the founder's words, "better functionality but worse
   design"), converted into features to absorb.

The output is a single sequenced programme. Where a root cause is **confirmed by
reading the source**, it says so. Where it is a hypothesis needing an on-device
check, it says that too.

---

# Part 1 — Diagnosis

## 1.1 The five root causes

Fourteen of the eighteen reported bugs, plus most of the "missing
functionality", reduce to five defects.

### RC-1 — The scene graph is invisible to SwiftUI Observation ⚠️ **highest impact**

`MakhtootDocument` is a plain `final class` — **not** `@Observable`:

```
MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift:26
    public final class MakhtootDocument {
    public private(set) var scene: MKScene
```

`CanvasSession` *is* `@Observable`, but exposes the scene as a **computed
passthrough** to that non-observable object:

```
MakhtootKit/Sources/MKCanvas/CanvasSession.swift:47
    public var scene: MKScene { document.scene }
```

The Observation macro only instruments *stored* properties, and the chain
terminates at a non-observable class. **Therefore no SwiftUI view ever
invalidates when the scene changes.** Every `InspectorModel` read
(`fillValue`, `pointSizeValue`, `highlightColorValue`, `fontRefValue`,
`isBoldValue`, `textStyleValue`…) and every `MKArrangeInteractionModel` read
(`isActive`, `activeOwnerNode`, all the `can…` gates) goes through
`session.scene`.

This is precisely the reported symptom "unresponsive **but fire in the
background**": the mutation lands, the CALayer tree redraws (driven by
`document.sceneUpdates`, an AsyncStream that bypasses SwiftUI entirely), and the
SwiftUI chrome never re-reads.

Corroborating evidence that the team already hit this and patched it
one-property-at-a-time: a manual `refreshUndoRedoState()` mirror with the comment
"an untracked read through a non-`@Observable` nested object left this button
permanently stale"
([EditorScene.swift:485](Makhtoot/AppShell/Scenes/Editor/EditorScene.swift:485)),
plus **three polling loops** (150 ms zoom, 100 ms mode, 1 s memory) that exist
purely to work around missing observation.

### RC-2 — Floating bars use `ScrollView` + a fixed `maxWidth`, so content packs to the RTL trailing edge

```
Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift:19-22
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: theme.spacing.sm) { content }
    }
    .frame(maxWidth: 260)
```

The `ScrollView` greedily takes the full 260 pt; the four 32 pt buttons occupy
~152 pt. The pill background/shadow is applied *outside* the scroll view, so it
draws at the full width while the buttons sit flush against the scroll view's
leading origin — which under `layoutDirection == .rightToLeft` is the **right**
edge. `ArrangeToolbarView.swift:29` has the identical `.frame(maxWidth: 320)`.

### RC-3 — The text-edit overlay lives inside the zoomable content view, and nothing scrolls it clear of the keyboard

```
Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift:1522
    vc.contentHostView.addSubview(overlay)
```

`contentHostView` is the scroll view's `viewForZooming` target. Consequences:

- The overlay is frame-positioned in canvas coordinates but inherits the zoom
  transform, so at any zoom ≠ 1 the `UITextView` and its font are scaled.
- `keyboardWillShow` ([MKCanvasViewController.swift:151](MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift:151))
  only adjusts `scrollView.contentInset.bottom`. There is **no**
  `scrollRectToVisible`. An inset change does not move existing content.
- No tap-outside recognizer exists. The only dismissal paths are the "تم"
  accessory button and `textViewDidEndEditing` — and `commit()` calls
  `resignFirstResponder()`, which **re-enters** `commit()` through that delegate.
  Teardown then waits on the 100 ms mode poll.

### RC-4 — Features whose plumbing exists but has no caller

| Capability | Model/engine support | App-layer caller |
|---|---|---|
| Project thumbnails | `DocumentPackage.writeThumbnail(_:)` ✅ | **zero callers** ❌ |
| Background image | `MKBackgroundContent.image(MKAssetRef)` ✅ | no picker ❌ |
| Font import | `MKFontImporter.importFont(from:originalFilename:)` ✅ | no `.fileImporter` ❌ |
| Alternate app icon | — ❌ | no `setAlternateIconName` ❌ |
| Text highlight paint | `MKTextStyle.highlightColor` ✅ | **no renderer reads it** ❌ |
| Tashkeel insertion | — ❌ | menu item is a copy-paste stub ❌ |

Verified: `grep -rn "PhotosPicker\|PHPicker\|fileImporter\|UIImagePicker"` across
`Makhtoot/` and `MakhtootKit/Sources/` returns **nothing**. Same for
`setAlternateIconName`. `writeThumbnail` and `highlightColor` have no production
readers/callers outside their own definitions.

### RC-5 — A complete, tested asset library that no UI can reach and no renderer will draw

`MakhtootKit/Sources/MKAssets/Resources/assets-manifest.json` contains
**57 assets** across the exact five categories the reference app's pickers show:

| Category | Count | Reference-app equivalent |
|---|---|---|
| `ornaments` | 16 | "Collection" rosettes, dots, swirls |
| `basicShapes` | 15 | The shape grid (~35 shapes) |
| `calligraphicElements` | 10 | Swashes/dividers (see the content-gap note in §3.3) |
| `frames` | 8 | *no equivalent — Makhtoot-only* |
| `patternBackgrounds` | 8 | *no equivalent — Makhtoot-only* |
| | **57** (27 premium) | |

`MKAssetBrowserModel` is a **complete browser backend**: `setSearchQuery`,
`toggleFavorite`, `favoriteDescriptors()`, `recentDescriptors()`, `sections()`,
`isLocked()`, and `select(_:at:canvasSize:) -> PlacementOutcome` with a
`.premiumRequired(capability:)` case for paywall routing. Supported by
`MKAssetThumbnailRenderer`, `MKAssetSearchNormalizer`, `MKAssetProvenanceStore`,
`MKPremiumContentLedger` — all with test suites.

**Two things block all of it:**
1. `ShapeDrawer` refuses `.asset` geometry outright:
   > `.asset(MKAssetRef)` shape geometry needs `MKAssetVectorProgram` (MKAssets,
   > WS-14 ، not yet built)
   ([ShapeDrawer.swift:17](MakhtootKit/Sources/MKRender/Drawers/ShapeDrawer.swift:17))
2. No view exists.

## 1.2 Symptom → cause map

| # | Reported symptom | Root cause | Confirmed? |
|---|---|---|---|
| 1 | Projects show default icon, not a preview | RC-4 | ✅ `writeThumbnail` has zero callers |
| 2 | No background image import (premium) | RC-4 | ✅ no picker API anywhere |
| 3 | All 3 zoom buttons dead | Own defect + RC-1 | ✅ 150 ms unconditional observable write |
| 4 | Pill-bar buttons offset right | RC-2 | ✅ by construction |
| 5 | Buggy keyboard hide | RC-3 | ✅ no tap-outside; re-entrant commit |
| 6 | Can't preview text under keyboard | RC-3 | ✅ no `scrollRectToVisible` |
| 7 | Buttons above pill bar illegible | Own defect | ✅ `ZoomControlsView` lacks the surface backing every sibling bar has |
| 8 | Font size ± unresponsive, "fires in background" | RC-1 | ✅ verbatim description of RC-1 |
| 9 | B/I/U/S do nothing | RC-1 + renderer gap | ✅ display; ⚠️ traits partly legitimate |
| 10 | Text colour stuck on black | RC-1 + picker defect | ✅ **picker ships no saturation control** |
| 11 | Highlight colour unsettable | RC-1 + RC-4 | ✅ zero `highlightColor` hits in `MKRender` |
| 12 | Install font doesn't work | Silent `try?` + wrong placement | ⚠️ needs entitlement check |
| 13 | Can't add any shape | Own defect | ✅ shape is created **1 pt × 1 pt** |
| 14 | Can't add any tashkeel | RC-4 | ✅ menu item is a copy-paste stub |
| 15 | Text on shape very buggy | Suspected coordinate-space defect | ❌ **needs a repro** |
| 16 | Wand freezes; no button works | Main-thread derive + RC-1 | ✅ both |
| 17 | Can't change app icon | RC-4 | ✅ not implemented |
| 18 | No premium font import | RC-4 | ✅ importer referenced only in a *comment* |

---

# Part 2 — Reference app feature inventory

Everything below is what is **visible** in the screenshots; inferred behaviour is
marked.

## 2.1 Top toolbar (9 persistent items)

☰ menu · **T** text · **ج̆** calligraphic glyph picker · **▪▲★** shape picker ·
**🖼** image · ↶ undo · ↷ redo · ⤴ share · **?** help · **⋯** edit menu

## 2.2 App menu (☰)

`New Design` · `My Designs` · **`Merge Design`** · `Save Design` —
**`Show Grid`** · **`Background Color`** — `Fit to Screen` · `Actual Size` —
`Settings` · `Help` · `Terms and Conditions` · `Privacy Policy`

## 2.3 Edit menu (⋯)

`Copy` · `Paste` · `Delete` · `Select All` · `Deselect All` ·
`Flip Horizontally` · `Flip Vertically` *(ships as "Fip Vertically")*

## 2.4 Text insertion dialog

Multi-line Arabic field **above the keyboard** · font button (`Diwan Naskh`) ·
size stepper (`▼ 384 ▲` — note the display-type default) · alignment ·
line-spacing · toggle **`Split text by spaces`** · toggle **`Group lines`** ·
`Preview` / `Cancel` / `Insert` · **live canvas preview rendered below**

## 2.5 Image menu

`Choose…` → then `Fit`, `Edit…`, `Remove` (greyed until an image exists)

## 2.6 Calligraphic glyph picker — their strongest feature

Tabs: **`Collection`** | **`Thuluth`**

**Thuluth** — dropdown of Arabic letter groups (Beh Teh Theh ب ت ث · Jeem Hah
Khah ج ح خ · Dal Thal د ذ · Reh Zain ر ز · Seen Sheen س ش · Sad Dhad ص ض · Tah
Zah ط ظ · Ain Ghain ع غ · Feh Qaf ف ق · Kaf ك · Lam ل · Meem م · Noon ن ·
Heh هـ · … · **Marks**). Selecting one shows a grid of hand-drawn **alternate
calligraphic forms** — ~25 variants for Kaf alone. `Marks` shows tashkeel and
decorative marks.

**Collection** — ornaments, ligatures, compound forms, kashida/stroke variants,
rosettes, dot clusters. Several screens of scrolling.

Estimated: **several hundred vector glyph variants.**

## 2.7 Shape picker

~35 shapes: line, square, rounded square, rectangle, rounded rectangle, circle,
ellipse, triangle, right triangle, pentagon, hexagon, octagon, squircle,
**8-point Islamic star**, arrow, 5-star, rounded star, **crescent**, hearts ×2,
flower, 5-/6-petal flowers, leaves ×2, maple leaf, branch, curve, clouds ×2,
**brush strokes ×3**, speech bubble, trapezoid.

## 2.8 Contextual bottom bar (object selected)

`тT` size · **`< Style`  `Style >`** (cycle alternate forms) · duplicate ·
delete · move · rotate · fill · stroke · ≡

## 2.9 Token strip

A strip of blue chips below the canvas — one per word token
(`تجر` `بة` `عبد` `ا` `لقد` … `ما` `جه`) — mirroring the per-word objects created
by *Split text by spaces*. Each canvas token carries its own dotted selection
box. Tap a chip to select on canvas.

## 2.10 Colour picker

2-D saturation/brightness square · full hue strip · **alpha strip with
checkerboard** · current swatch · **`Favorites` / `Custom`** tabs ·
**eyedropper** · **heart (save favourite)** · numeric sliders · close.

## 2.11 Canvas

Transparent checkerboard (honest alpha) · per-object dotted selection boxes ·
multi-select.

---

# Part 3 — Gap analysis

## 3.1 Bucket A — Makhtoot has it, built and tested, with **no UI**

The highest-leverage bucket in the plan.

| Reference feature | Makhtoot's existing implementation |
|---|---|
| Shape picker (§2.7) | `MKBasicShapeGenerator` — 15 shapes, manifested |
| Collection ornaments (§2.6) | `MKOrnamentGenerator` — 16 |
| Calligraphic elements (§2.6) | `MKCalligraphicGenerator` — 10 |
| *(no equivalent)* | `MKFrameGenerator` — 8, with nine-slice insets |
| *(no equivalent)* | `MKPatternTileGenerator` — 8 (hexagonal lattice, 8-star tessellation, zellij interlock) |
| Picker search / favourites / recents | `MKAssetBrowserModel` — complete, zero views |
| Premium gating on assets | `MKPremiumContentLedger`, `PlacementOutcome.premiumRequired` |
| Asset thumbnails | `MKAssetThumbnailRenderer`, `MKAssetContactSheetGenerator` |
| Licence provenance | `MKAssetProvenanceStore` + `provenance-records.json` |
| Font import | `MKFontImporter` — tested `public actor`, referenced only in a **comment** |
| `< Style` / `Style >` cycler (§2.8) | `MKArrangeFormSelectorModel` + `FormSelectorPopoverView` — richer, but trapped inside Arrange Mode, whose toolbar is dead (Bug 16) |

## 3.2 Bucket B — Partial: model or engine exists, UI/render path missing

| Reference feature | Exists | Missing |
|---|---|---|
| Background image (§2.5) | `MKBackgroundContent.image`, `CanvasContentAPI.addImage`, `MKImageDrawer` | Picker, ingestion, Fit/Edit/Remove |
| Background colour (§2.2) | `MKBackgroundContent.solid` | Entry point |
| Transparent canvas (§2.11) | Alpha throughout render + export | Checkerboard presentation |
| Colour picker (§2.10) | `MKColorSpec`, `CMYKConverter`, `ICCProfileStore` — **better colour science than theirs** | No saturation control, no alpha, no favourites, no eyedropper |
| Text dialog (§2.4) | `TextEditingOverlayController`, live shaping | Pre-insert dialog, size/font/align at insert, live preview, split/group |
| Marks & tashkeel (§2.6) | `MarkAttachmentController`, R-7.5 attach-to-letter, tests | Palette; the "+" item is a stub |
| Fit to Screen / Actual Size | `zoomToFit()`, `zoomTo100Percent()` | Broken (Bug 3) and in no menu |
| Token strip (§2.9) | `LayersPanelView` over `LayersModel` | Flat token strip; split-on-insert to populate it |

## 3.3 Bucket C — Genuinely absent

Show Grid · Merge Design · Copy/Paste/Select All/Deselect All · Flip H/V ·
Split text by spaces · Group lines · form cycler outside Arrange Mode ·
alignment & line-spacing at insert · app-icon switching.

> **Content gap, stated plainly.** Makhtoot's 10 `calligraphicElements` are
> *dividers, swashes, finials, dot clusters* — **not per-letter alternates**.
> The reference app's Thuluth palette is a different asset class: ~25 hand-drawn
> variants **per letter** across 14+ letter groups. Matching it is a
> **commissioning and licensing project measured in months**, not an engineering
> task. Phase 3 delivers the *mechanism*; filling the library is separate work
> that no phase below claims to cover.

## 3.4 Bucket D — Makhtoot capabilities the reference app does **not** have

Do not regress these chasing parity. They are the moat.

- **Arrange Mode** — per-glyph/per-letter manipulation, join break/restore,
  ligature decompose/recompose, mark detach/re-attach, revert-to-text. Their
  `< Style >` cycler is a toy by comparison.
- **Path Text** — text on arc/circle/wave/freeform Béziers with a real path editor.
- **Vector export** — SVG and vector PDF with glyph outlines. Theirs appears raster-only.
- **iCloud sync**, crash recovery, journalled undo, atomic package format.
- **Design-system themes** with a type ramp and token gallery.
- **Arabic-first UI.** Their entire chrome is English — "New Design", "Split text
  by spaces", "Insert", "Close" — in an *Arabic calligraphy app*, shipping a
  visible typo ("Fip Vertically").
- **Font import + system-wide install**, licence auditing, CMYK/ICC colour.

---

# Part 4 — Design direction

Take their **interaction model**, not their visual language.

## Take

1. **One picker, five categories.** They split glyphs and shapes across two
   toolbar buttons and two tabs. `MKAssetCategory` already models five categories
   in one browser — ship a single sheet with segments, search, favourites and
   recents. Strictly better than the screenshots.
2. **Insert-time text configuration** with live preview — beats "insert a blank
   field, then hunt for the أء sheet".
3. **Split text by spaces** — one toggle to per-word objects.
4. **The token strip** — more discoverable on a phone than a layers panel behind
   a menu.
5. **A complete colour picker** — SB square + hue + **alpha** + favourites + eyedropper.
6. **The transparent-canvas checkerboard** — honest about alpha.
7. **Display-type default sizes.** Theirs defaults to 384 pt. Makhtoot's `36` is
   a text-editor assumption.

## Do not take

Dense navy chrome · sub-44 pt hit targets · English-only labels · modal grids
with no search · panels overlapping the canvas edge-to-edge · two toolbar buttons
for one asset library · `Preview` as a separate button (preview should be live) ·
greyed-out items that never explain themselves.

## Rules for everything built below

| Rule | Why |
|---|---|
| Arabic-first labels, `MKTypeRamp`, RTL by default | The core differentiator; they fail it completely |
| ≥44 pt hit targets on every control | Theirs are well under |
| One shared `MKFloatingBar` treatment for all floating chrome | Fixes Bug 7 and prevents the drift that caused it |
| Sheets with `.presentationDetents`, never full-screen modal grids | Keeps the canvas visible while picking |
| Every premium gate through `presentPaywall(.premiumFeatureTap(…))` | One paywall path, already used by export formats |
| Every disabled control states *why* | Replaces their silent grey-out |
| Canvas ⇄ export parity in the same PR | Any trait/fill added to a drawer lands in `SVGSerializer` too |

---

# Part 5 — The programme

```
P0  Observable scene ──────────────────────── blocks everything
P1  Quick wins (zoom · centring · legibility · shapes · zoom menu)
P2  Text: insert dialog · split · token strip · keyboard
P3  Assets: render .asset · browser sheet · marks · form palette   ← biggest payoff/effort
P4  Arrange Mode unfrozen
P5  Colour · image · background · grid · highlight · traits
P6  Copy/paste · flip · select-all
P7  Thumbnails · font import · merge design · app icon
P8  Path-text migration ─────────────────────  last; needs a repro first
```

P1 and P2 may run in parallel with P3 once P0 lands. P8 must not start before P0.2.

---

## Phase 0 — Unblock

### P0.1 — Make the scene observable *(RC-1; fixes bugs 8, 9, 10, 11, and 16's dead toolbar)*

**Causes.** (1) ✅ **Confirmed** — RC-1 above. (2) Selection empty →
`InspectorModel` values return `.empty` and setters iterate an empty selection,
a real secondary failure the UI never states. (3) Sheets presented from
`ToolRailView` sit inside the 150 ms re-render storm, compounding staleness.

**Remedies.** (1) **Preferred** — make `MakhtootDocument` `@Observable`, or box
the scene in an `@Observable` type that `CanvasSession` *stores*. Single change;
fixes bugs 8–11 and 16's toolbar, and lets all three polling loops be deleted.
(2) **Tactical fallback** if touching `MKPersistence` is too invasive now: add an
`@Observable private(set) var sceneRevision: Int` stored on `CanvasSession`,
bumped in `perform(_:)`, read alongside each value. Ugly but surgical.
(3) Empty-state the inspector and أء sheet when the selection is empty, so
"no-op" is honest rather than silent.

**Files.** `MKPersistence/MakhtootDocument.swift` · `MKCanvas/CanvasSession.swift` ·
`MKCanvas/InspectorModel.swift` · `Editor/EditorViewModel.swift` (delete
`startModePolling`, the `refreshUndoRedoState` mirror, the zoom poll's observable
write) · `Editor/FontSettingsSheet.swift` · `MKCanvasTests/InspectorModelTests.swift`

**Risks.**

| Risk | Mitigation |
|---|---|
| **Highest blast radius in the programme** — the persistence spine touches autosave, journal, crash recovery, sync | Land alone, on its own branch, full `MKPersistenceTests` + `MKCanvasTests` green before anything stacks |
| Over-invalidation (whole-scene writes per keystroke) | Text edits already coalesce per 700 ms burst; measure with `PerfHUDView` and `debugMeasureManipulationFrames()` |
| Observation + AsyncStream double-notify | Keep the stream for the CALayer path — it is not SwiftUI; only SwiftUI reads change |
| Deleting polls removes an accidental safety net | Delete one at a time, each with a smoke test of the paths its comment enumerates |

### P0.2 — Capture a repro for Bug 15 (text-on-shape)

The only item in the programme that cannot be diagnosed from source. Which
preset, which gesture, expected vs actual. `MKPathTextTests` and
`MKCanvasTests/PathTextInteractionModelTests` are extensive — a failing case
there is the fastest route to a real fix. **Phase 8 does not start without this.**

---

## Phase 1 — Quick correctness wins

### P1.1 — Zoom buttons *(Bug 3)*

**Causes.** (1) ✅ **Confirmed contributor** — `startZoomBucketPolling` assigns
`currentZoomScale` **unconditionally** every 150 ms, *before* the change guard:
```
EditorViewModel.swift:391-393
    let scale = vc.scrollView.zoomScale
    self.currentZoomScale = scale                    // ← always fires
    guard abs(scale - self.lastPolledZoomScale) > 0.0001 else { continue }
```
`@Observable` notifies on every set, equal or not → the whole floating-bar VStack
invalidates 6.7×/s; SwiftUI `Button`s recreated mid-touch drop taps.
(2) **Likely co-cause** — `.buttonStyle(.plain)` over a `Color.clear` background
inside a `ScrollView`, whose touch-delay swallows short taps.
(3) `canvasViewController` is a **`weak var`** (`EditorViewModel.swift:171`); if
nil, `step()` and both fit calls silently return. Zoom limits themselves are sane
(0.1×–64×).

**Remedies.** (1) **Required regardless** — guard the assignment. Audit
`startModePolling` and the memory poll (`memoryBannerText` is written every second
with the same defect). (2) `.contentShape(Rectangle())` + ≥44 pt frames; or move
the buttons out of the `ScrollView` (P1.2 does this anyway). (3) One `#if DEBUG`
log run in `step(by:)` and `attach(canvasViewController:)` distinguishes
"tap lost" from "tap lands, no-op".

**Files.** `Editor/EditorViewModel.swift` · `Editor/ZoomControlsView.swift` ·
`MKDesignSystem/Components/MKToolbarButton.swift`

**Risks.** Changing `MKToolbarButton`'s hit shape affects every bar at once —
re-verify the Arrange toolbar's disabled/`.opacity(0.4)` states. Prefer keeping
`canvasViewController` weak and asserting on nil over making it strong.

### P1.2 — Pill-bar centring *(Bug 4, RC-2)*

**Remedies.** (1) **Preferred** — `ViewThatFits`: size to content, scroll only on
genuine overflow. (2) Drop the `ScrollView` entirely at compact width — the rail
is 4 items and the scroll adds only the touch-delay that also hurts P1.1.
(3) Move the pill background *inside* the scroll content so the capsule always
hugs the buttons.

**Files.** `ToolRailView.swift` · `ArrangeToolbarView.swift` ·
`PathEditToolbarView.swift` · `EditorScene.swift`

**Risks.** The Arrange toolbar genuinely has more items and needs its scroll
fallback — `ViewThatFits` preserves it. Test both size classes. Kufi theme has
`radius == 0`: keep `theme.radius.sheet`, never hardcode `Capsule()`.

### P1.3 — Floating-bar legibility *(Bug 7)*

✅ **Confirmed** — `ToolRailView` and `ArrangeToolbarView` apply
`.padding + .background(theme.surface, in:) + .shadow`. `ZoomControlsView`
([:18-37](Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift:18)) applies
**none**, drawing bare `theme.ink` glyphs onto the canvas backdrop — and in
compact layout it sits directly above the pill.

**Remedies.** (1) **Preferred** — extract `MKFloatingBar` into `MKDesignSystem`;
adopt in all four bars. One definition, no drift. (2) Add
`.ultraThinMaterial` behind floating chrome — the right answer once background
images ship (P5.3). (3) Assert WCAG AA 4.5:1 against `theme.canvasBackdrop` and a
worst-case photo background in `TokenResolutionTests`.

**Risks.** Vertical space on iPhone SE — the bars are already stacked; measure.
Material over a live canvas is expensive; use it only on small bars and profile
with `PerfHUDView`. Screenshot-diff all themes via `DesignSystemGallery`.

### P1.4 — Shapes are 1 pt × 1 pt *(Bug 13)*

✅ **Confirmed.** `ShapeDrawer` paints **unit-square geometry** scaled by
`core.transform.scale` — its own comment says so
([:27-30](MakhtootKit/Sources/MKRender/Drawers/ShapeDrawer.swift:27)) — but
`addRectangleAtCenter()` builds `MKTransform2D(position:)` and **never sets
`scale`**, whose default is `CGSize(width: 1, height: 1)`
([MKTransform2D.swift:21](MakhtootKit/Sources/MKFoundation/Geometry/MKTransform2D.swift:21)).
Result: a one-point dark-red rectangle at canvas centre — added, selected,
invisible.

**Remedies.** (1) **One line** — pass a real scale, sized off
`min(canvas.width, canvas.height)` as `addPathText` already does with `shortSide`.
(2) Add a `size:` parameter to `CanvasContentAPI.addShape` so the default lives
with the API, not the caller. (3) Phase 3 replaces the single "شكل" item with the
full 15-shape library anyway.

**Risks.** Check `MKArrangeTests`/`MKRenderTests` fixtures for anything relying on
unit-sized shapes before changing the default. `MKStylePainting.paint(strokeWidthCompensationScale:)`
already handles non-1 scale — verify with a fixture.

### P1.5 — Surface Fit to Screen / Actual Size *(§2.2)*

Now that P1.1 makes them work, put them in a menu. Today they are reachable only
by an undiscoverable tap on the zoom percentage badge.

---

## Phase 2 — Text entry, done properly

### P2.1 — Insert-time text dialog *(§2.4)*

Replace "insert a blank field" with a sheet: Arabic text field, font picker
(reuse `FontBrowserSheet`), size stepper, alignment, line-spacing, **live
preview**, Insert/Cancel. This also sidesteps much of RC-3 by putting the field
**above** the keyboard — exactly what the reference app does.

**Files.** New `Editor/TextInsertSheet.swift` · `ToolRailView.swift` ·
`EditorViewModel.swift` · reuse `FontBrowserSheet.swift`

### P2.2 — `Split text by spaces` *(§2.4)*

Tokenise on whitespace at insert; emit one `liveText` node per token. Far cheaper
than Arrange-Mode derivation and delivers the reference app's core workflow.

### P2.3 — `Group lines` *(§2.4)*

Wrap per-line tokens in the existing `MKGroupNode`.

### P2.4 — Token strip *(§2.9)*

A horizontal chip strip over `LayersModel`, filtered to top-level text nodes;
tap selects on canvas. Keep `LayersPanelView` for the full tree.

**Risk.** Depends on P0.1 — without it the strip never reflects scene changes.

### P2.5 — Keyboard: dismissal and visibility *(Bugs 5 & 6, RC-3)*

**Bug 5 causes** — all three ✅ confirmed: no tap-outside recognizer; re-entrant
`commit()` via `resignFirstResponder()` → `textViewDidEndEditing`; teardown
polled at 100 ms (the code's own comment documents the overlay getting "visibly
stuck on screen").

**Bug 5 remedies.** (1) **Preferred** — tap-outside recognizer on
`MKCanvasViewController.view` that commits; swipe-down on the accessory toolbar.
(2) Set `isActive = false` *before* `resignFirstResponder()`; let
`textViewDidEndEditing` tear down the view only. (3) Replace the mode poll with a
direct `onCommit` callback.

**Bug 6 causes.** (1) ✅ nothing calls `scrollRectToVisible` — an inset change
does not move content. (2) ✅ the overlay is inside the zoomable view, so at
fit-zoom (typically ≪ 1×) both it and its font are scaled down. (3) Possible
z-ordering against the input accessory — check after (1) and (2).

**Bug 6 remedies.** (1) **Preferred, low risk** — `scrollRectToVisible` on
`keyboardWillShow`, using the active overlay's frame in scroll-view space.
(2) Host the overlay in `vc.view` above the scroll view, positioned by converting
the world OBB through the current zoom — also makes point size WYSIWYG.
(3) Temporarily zoom/pan so the edit region occupies the band above the keyboard,
restoring on commit.

**Files.** `MKCanvas/TextEditingOverlay.swift` · `MKCanvas/MKCanvasViewController.swift` ·
`MKCanvas/Gestures/` · `Editor/EditorViewModel.swift`

**Risks.** New tap recognizer vs existing double-tap-to-edit — `require(toFail:)`,
and extend `TextEditingOverlayTests`. Never commit while `markedTextRange != nil`
(IME). Land remedy 1 of Bug 6 before the riskier re-host.

### P2.6 — Display-type default size *(§2.4)*

Raise the `36` pt default to a canvas-scaled display size. Theirs defaults to 384.

---

## Phase 3 — The asset browser *(highest payoff per unit of work)*

### P3.1 — Make `.asset` geometry render *(RC-5, blocker for all 57 assets)*

Wire `MKAssetGeometry` → `CGPath` in `MKRender`; add `HitTester` parity (it
already shares `ShapeDrawer.localPath`) and `SVGSerializer` export parity.

**Files.** `MKRender/Drawers/ShapeDrawer.swift` · `MKRender/HitTester.swift` ·
`MKExport/SVGSerializer.swift` · `MKAssets/Model/MKAssetGeometry.swift` ·
`MKRenderTests/`

**Risk.** ⚠️ **Unsized.** I confirmed `ShapeDrawer` refuses `.asset` and that
`MKAssetGeometry` exists, but did not read its representation closely enough to
estimate the conversion. **Size this before committing the phase.**

### P3.2 — `MKAssetBrowserSheet` *(§2.6, §2.7 — this is a view over a finished backend)*

Category segments (أشكال / زخارف / عناصر خطية / إطارات / خلفيات) · search field ·
favourites and recents rows · premium badges via `isLocked` · placement via
`select(_:at:canvasSize:)` · paywall on `.premiumRequired`.

**Files.** New `Editor/MKAssetBrowserSheet.swift` · `ToolRailView.swift` ·
`AppContainer.swift` (expose `MKAssetBrowserModel`) · `PaywallView.swift` (copy)

**Risks.** Thumbnail rendering for 57 assets on sheet open — `MKAssetThumbnailRenderer`
exists; cache and render lazily. Premium gating must hold at the *command* layer,
not just the button, matching the export-format precedent.

### P3.3 — Marks & tashkeel *(§2.6 Marks; Bug 14)*

✅ **Confirmed defect** — the menu item is a copy-paste stub:
```
ToolRailView.swift:58-60
    Button(addTextFieldLabel) { viewModel.addLiveTextAtCenter() }
    Button(addShapeLabel)     { viewModel.addRectangleAtCenter() }
    Button(addTashkeelLabel)  { viewModel.addLiveTextAtCenter() }   // ← identical
```

**Remedies.** (1) **Preferred** — a tashkeel palette as an input accessory in the
text overlay, inserting the diacritic at the caret. This is what users mean.
(2) A canvas-level entry that inserts a standalone mark and arms the existing
R-7.5 attach-to-letter flow (`pendingMarkReattachID` — already built and tested).
(3) If neither ships this cycle, **remove the menu item**; a button that silently
does the wrong thing is worse than no button.

**Risks.** A combining mark with no base character renders a dotted circle —
disable palette entries when the caret has no valid base (`JoiningAnalyzer`
already models this). Marks must survive shaping, arrange derivation and export.

### P3.4 — Alternate-form palette and cycler *(§2.6 Thuluth, §2.8 `< Style >`)*

Lift `MKArrangeFormSelectorModel` out of Arrange Mode: with a glyph selected,
offer alternate forms as a grid **and** as prev/next cycler buttons. Needs Phase 4.

**Risk.** ⚠️ Unverified whether the form selector can serve a general *insertion*
palette or only substitution within an already-derived composition. And see the
content-gap note in §3.3 — this ships the mechanism, not the library.

---

## Phase 4 — Arrange Mode, unfrozen *(Bug 16)*

**Causes.** (1) ✅ **Confirmed (freeze)** — `MKArrangeInteractionAdapter` is
`@MainActor`; `deriveArrangeCommand` awaits `shapingService.captureResult` (a
true `actor`, which hops off) and then calls `deriver.derive(...)`. But
`ArrangeDeriver` is a plain `struct … : Sendable` with no actor isolation, so it
**inherits `@MainActor` and runs full CoreText shaping plus per-glyph outline
extraction synchronously on the main thread.** (2) ✅ **Confirmed (dead buttons)**
— every gate (`canBreakOrRestoreJoinForSelection`, `canDecomposeSelection`,
`interaction.granularity`, `activeOwnerNode`) resolves through `session.scene`
(RC-1): the toolbar renders once with nothing selected, computes `disabled: true`
everywhere, and never re-evaluates. (3) ✅ `enterArrangeMode` has four silent
early returns that set `lastErrorMessage` — **which nothing in the UI displays**.

**Remedies.** (1) Make `ArrangeDeriver` an `actor`, or run `derive` detached —
`MKShapingService` is already an actor, so the pattern exists in-repo. Add a
progress indicator and a size guard for very long strings. (2) P0.1 — nothing
else makes those buttons usable. (3) Surface `lastErrorMessage`; the strings
(`arrangeEngineUnavailableMessage`, `deriveFailedMessage`) already exist.

**Files.** `MKArrange/ArrangeDeriver.swift` · `Editor/MKArrangeInteractionAdapter.swift` ·
`MKCanvas/Arrange/MKArrangeInteractionModel.swift` · `ArrangeToolbarView.swift` ·
`EditorScene.swift` · `MKArrangeTests/`

**Risks.**

| Risk | Mitigation |
|---|---|
| `MKPathTextInteractionAdapter` almost certainly has the identical main-actor defect | Audit and fix both in the same pass, or the freeze just moves to the path-text button |
| Actor isolation may expose races masked by main-actor serialisation | Strict concurrency build; `DerivationFidelityTests` guards output equivalence |
| A long derive now needs cancellation (double-tap the wand) | Store the `Task` on the model; cancel the prior on re-entry |
| Flagship feature — regressions are expensive | Land behind the `-mkE2EArrangeDrive` launch-arg harness; re-run the drive before/after |

---

## Phase 5 — Colour, image, canvas

### P5.1 — Rebuild the colour picker *(§2.10, Bug 10)*

**Causes.** (1) ✅ RC-1 for the swatch — `currentTextColor` reads
`inspector.fillValue` and falls back to hardcoded near-black
`(0.114, 0.098, 0.086, 1)` ([FontSettingsSheet.swift:274](Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:274)),
never re-reading. (2) ✅ **Confirmed and decisive** — `MKColorPickerSheet` derives
`saturation` from the initial colour (`delta/maxC ≈ 0` for near-black), and
**ships only hue and brightness sliders — there is no saturation control at
all.** With saturation pinned at ~0, hue does nothing and brightness produces
only greys. That is literally "can't set anything other than black".
(3) Fill may not reach `LiveTextDrawer` — unlikely, since `addLiveTextAtCenter`
deliberately sets a default ink fill through the same `setFill` primitive.

**Remedies.** (1) Rebuild with SB square + hue + **alpha** + favourites +
eyedropper (§2.10), backed by the existing `MKColorSpec`/`CMYKConverter` for
colour accuracy the reference app lacks. (2) Minimum viable: add a saturation
control and clamp the neutral-colour floor, mirroring what `previousHue` already
does for hue. (3) Or adopt the system `ColorPicker` already used in
`InspectorPanelView.swift:40`, plus preset ink swatches.

**Also fix:** `static var previousHue` on `MKColorPickerSheet` is **shared mutable
state across every instance** — a latent cross-sheet bug.

### P5.2 — Background colour *(§2.2)* — menu entry → the new picker → `MKBackgroundContent.solid`

### P5.3 — Background image *(§2.5, Bug 2)*

✅ **Confirmed** — the model fully supports it (`MKBackgroundContent.image(MKAssetRef)`,
`CanvasContentAPI.addImage(assetRef:kind:at:isPhotoBackgroundUse:)`), and
`MKImageDrawer` renders it. There is **no photo picker anywhere in the codebase**.

**Remedies.** (1) `PhotosPicker` entry in the `+` menu, gated on
`isEntitled(.premiumBackgrounds)` with the standard paywall fallback.
(2) Same entry in `NewProjectSheet` so a project can start from a photo.
(3) A `.fileImporter` for image UTTypes so Files/iCloud Drive work too.
Add Fit / Edit / Remove per §2.5.

**Risks.** Missing `NSPhotoLibraryUsageDescription` is a **hard crash on tap** —
add before shipping. Downscale to canvas × 2 on ingest and register with
`MKMemoryGovernor`. Add the photo-library reason code to the existing privacy
manifest. Gate at the *command* layer so undo/redo can't bypass entitlement.

### P5.4 — Transparent-canvas checkerboard *(§2.11)* — present alpha honestly

### P5.5 — Show Grid *(§2.2)* — a display layer over the existing `SnapEngine`/`GuideRenderer`

### P5.6 — Highlight colour actually paints *(Bug 11)*

**Causes.** (1) ✅ **Confirmed** — `MKTextStyle.highlightColor` exists and
`setHighlightColor` persists it, but `grep -rn "highlightColor" MKRender/`
returns **zero hits**. No drawer paints it; invisible on canvas and in export.
(2) ✅ `InspectorPanelView.swift:87-97` renders highlight as a **read-only**
circle + label — no button, no picker. Only the أء sheet can set it.
(3) The "shows yellow" report: `none` renders as a dashed circle in the sheet and
`Color.gray.opacity(0.2)` in the inspector — **neither is yellow**. Most likely
the picker seeds `(0.5, 0.5, 0.5, 0.3)`, whose neutral hue falls back to the
shared `previousHue` with saturation 0, under the yellow band of the hue strip.
⚠️ **Needs a device screenshot** rather than being asserted from source.

**Remedies.** (1) Implement highlight painting in `LiveTextDrawer`/`PathTextDrawer`
(line-fragment rects behind glyph runs) plus `SVGSerializer` parity — without
this the feature cannot work at all. (2) Add a real setter to `InspectorPanelView`
and a clear action in both places — `setHighlightColor` currently cannot express
*nil*. (3) Fix picker seeding via P5.1.

**Risks.** Highlight rects under RTL/bidi runs and on curved path text are
non-trivial — ship live-text first and **say so in the UI** rather than shipping
path-text highlight broken. Widening `setHighlightColor` to optional is a public
`MKCanvas` API change (source-compatible as an overload).

### P5.7 — Text traits *(Bug 9)*

**Causes.** (1) ✅ RC-1 for the display — `isBold`/`isItalic`/`isUnderline`/
`isStrikethrough` all read through `session.scene`; the toggle applies but the
button styling never flips. (2) **Likely and legitimate** — Arabic faces
overwhelmingly lack real bold/italic cuts. The sheet already computes
`boldSupported`/`italicSupported` via `CTFontGetSymbolicTraits` and draws a red
slash — so for most Arabic fonts **B and I are correctly no-ops, just without
saying why**. (3) Underline/strikethrough may have no drawing path — needs a
targeted check (⚠️ only `highlightColor` was *confirmed* to have none).

**Remedies.** (1) P0.1. (2) Disable unsupported traits with a one-line
explanation ("هذا الخط لا يوفّر وزنًا عريضًا") instead of only a slash;
optionally offer clearly-labelled synthetic emboldening. (3) Verify and
implement underline/strikethrough painting + export parity.

**Risks.** Synthetic bold degrades Arabic joins — prefer a real family member;
if synthesising, stroke-based with a capped width and a "محاكاة" label. Underline
placement under descenders/marks needs the font's `underlinePosition`/
`underlineThickness`, not a hardcoded offset.

---

## Phase 6 — Editing operations *(§2.3 — all absent)*

Copy · Paste · Delete · Select All · Deselect All · Flip Horizontally · Flip
Vertically.

Flip is a sign change on `MKTransform2D.scale`. Clipboard needs an `MKNode`
pasteboard representation — the `Codable` conformance already exists.

---

## Phase 7 — Library, settings, polish

### P7.1 — Project thumbnails *(Bug 1)*

**Causes.** (1) ✅ **Confirmed** — the UI path is correct
([ProjectBrowserView.swift:434](Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift:434))
and falls back to `Image(systemName: "doc.richtext")` when `thumbnailURL` is nil.
`writeThumbnail(_:)` exists at `DocumentPackage.swift:143` with **zero callers**;
`thumbnailPath` is never assigned in production code. (2) Metadata not refreshed
— ruled out, nothing writes them at all. (3) iCloud placeholder not materialised
— a *future* risk once (1) lands, not the current cause.

**Remedies.** (1) **Preferred** — generate on editor close: in
`EditorScene.finish(_:)`, render ~600 pt via the existing `MKSnapshotRenderer`
(already used by `exportPNGForSharing`), `writeThumbnail`, update
`thumbnailPath`. (2) Also generate at project creation, so a never-opened project
shows its template. (3) Lazy backfill for visible cards with nil thumbnails.

**Risks.** Snapshot on close must not block dismissal — render off the main
actor, cap at 600 pt, time-box and skip. **The current synchronous
`Data(contentsOf:)` in `body` will stutter scrolling once thumbnails exist** —
move to an async cache keyed by URL + mtime. Stamp with the scene revision so
edits outside the close path regenerate.

### P7.2 — Font import *(Bug 18)*

✅ **Confirmed** — `MKFontImporter` is a full `public actor` with
`importFont(from:originalFilename:)`, backed by `MKFontImporterTests`,
`MKFontValidatorTests`, `MKFontStorageManagerTests`. The **only** reference from
`Makhtoot/` is a mention inside a code comment (`RootShellView.swift:84`).

**Remedies.** (1) New Settings → **الخطوط** section with an import row opening
`.fileImporter` for font UTTypes, gated on `isEntitled(.premiumFonts)`.
(2) Surface imported fonts in `FontBrowserSheet` under "خطوطي", showing
`MKFontValidator` failures instead of `try?`-swallowing them. (3) Accept fonts
via share sheet / "Open in Makhtoot".

**Risks.** Licence-restricted imports — record as "user-supplied, licence
unknown" and show it in `LicensingView` (`MKLicensingDataSource` and
`FontLicenseAuditTests` already exist). Make `MKFontValidator` a hard gate.
Copy inside the `startAccessingSecurityScopedResource` bracket. Decide explicitly
whether imported fonts sync, reusing the `isOrphaned` pattern.

### P7.3 — Relocate system-wide font install *(Bug 12)*

**Causes.** (1) **Most likely** — silent failure: `try?` discards every error
([FontSettingsSheet.swift:398-402](Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:398)),
so a failed install and a successful one look identical. (2) **Wrong placement,
which the founder already diagnosed** — a device-scoped, one-time action inside a
per-selection formatting sheet, and it only appears when a text node is selected.
(3) Missing capability/entitlement configuration.

**Remedies.** (1) Move into P7.2's Settings section. (2) Surface `MKFontError` in
an alert with a progress state. (3) Verify registration scope and entitlements
end-to-end; extend `MKFontRegistryTests`.

**Risk.** ⚠️ **Determine first whether system-wide install is permitted for this
app's entitlements at all.** If not, remove the affordance rather than ship a
button that cannot work. Gate on the licence record. Leave an "إدارة الخطوط…"
deep link in the أء sheet for discoverability.

### P7.4 — Merge Design *(§2.2)* — import a saved project's nodes into the current scene

### P7.5 — App icon switching *(Bug 17)*

✅ **Confirmed not implemented** — no `setAlternateIconName`, no
`CFBundleAlternateIcons`, no alternate assets anywhere.

**Remedies.** (1) 3–5 icons, one per design-system theme (the repo already has
themes and a `BrandMark` component), declared in `Info.plist`, with a picker in
`GeneralSettingsView`. (2) Gate extras as a premium perk. (3) If icons won't ship
this cycle, don't advertise the option.

**Risks.** Alternate icons have strict packaging rules — **loose files at the
bundle root, not an asset-catalog set**, exact naming, every @2x/@3x size. Verify
on device, not just the simulator; a wrong name fails silently. The system alert
on switch cannot be suppressed — explain it in the copy.

### P7.6 — Save Design / My Designs parity *(§2.2)*

Makhtoot autosaves. Verify the mental model is clear; **do not** add a redundant
Save button just for parity.

---

## Phase 8 — Path Text structural work *(Bug 15)*

**Gated on P0.2.**

**Causes.** (1) **Most likely** — presets place geometry in **absolute canvas
coordinates** while the node's transform stays at `.zero`
([EditorViewModel.swift:738-754](Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift:738)).
The code argues this is correct because `PathTextDrawer` ignores
`core.transform.position` — but that means **moving a path-text node via the
inspector or a drag cannot work**: selection chrome moves, glyphs don't. A
textbook "very buggy" symptom. (2) RC-1 — `PathOptionsPopoverView` and
`PathEditToolbarView` gate on `session.scene`-derived state. (3) Path-edit chrome
is drawn in `MKCanvas` (`PathEditChromeLayer`) while the ghost guide is drawn in
**SwiftUI** (`PathGhostGuideOverlay`) — two coordinate systems, two zoom
responses, likely visible drift.

**Remedies.** (1) **Diagnose precisely first** — this is the least specific
report of the eighteen. (2) Make path text obey `core.transform` like every other
node: store the path in **local** space and apply the node transform in
`PathTextDrawer`. (3) Unify the chrome into `PathEditChromeLayer` with an
explicit never-in-export flag, retiring the parallel SwiftUI overlay.

**Risks.** Remedy 2 is a **document-format migration** — existing projects store
absolute paths. Version the scene format and migrate on open (`MKPersistence`
already has journal/recovery infrastructure). This has the heaviest test coverage
in the repo (`MKPathTextTests`, `WS16CursiveTests`) — treat any red test as a
blocker, not a fixture to update. **Do not start without a repro.**

---

# Part 6 — Traceability

| Bug | Phase | | Feature | Phase |
|---|---|---|---|---|
| 1 Thumbnails | P7.1 | | Shape picker §2.7 | P3.1–P3.2 |
| 2 Background image | P5.3 | | Glyph/ornament picker §2.6 | P3.1–P3.2 |
| 3 Zoom buttons | P1.1 | | Marks palette §2.6 | P3.3 |
| 4 Pill offset | P1.2 | | `< Style >` cycler §2.8 | P3.4 |
| 5 Keyboard hide | P2.5 | | Text insert dialog §2.4 | P2.1 |
| 6 Text under keyboard | P2.5 | | Split by spaces §2.4 | P2.2 |
| 7 Illegible buttons | P1.3 | | Group lines §2.4 | P2.3 |
| 8 Font size | P0.1 | | Token strip §2.9 | P2.4 |
| 9 B/I/U/S | P0.1 + P5.7 | | Colour picker §2.10 | P5.1 |
| 10 Text colour | P0.1 + P5.1 | | Background colour §2.2 | P5.2 |
| 11 Highlight | P0.1 + P5.6 | | Image Fit/Edit/Remove §2.5 | P5.3 |
| 12 Install font | P7.3 | | Transparent canvas §2.11 | P5.4 |
| 13 Add shape | P1.4 | | Show Grid §2.2 | P5.5 |
| 14 Add tashkeel | P3.3 | | Copy/Paste/Select/Flip §2.3 | P6 |
| 15 Text on shape | P0.2 → P8 | | Merge Design §2.2 | P7.4 |
| 16 Wand | P4 (needs P0.1) | | Fit/Actual Size §2.2 | P1.5 |
| 17 App icon | P7.5 | | | |
| 18 Font import | P7.2 | | | |

---

# Part 7 — Programme-level risks

| Risk | Mitigation |
|---|---|
| **P0.1 destabilises persistence** and blocks everything behind it | Land alone with full suites green; the `sceneRevision` fallback is the escape hatch if the `@Observable` change proves too invasive |
| **P3.1 is unsized** and gates the entire asset browser | Size it before committing Phase 3; if large, P3.2 can ship against `basicShapes` only via the existing `MKShapeGeometry` cases |
| **The Thuluth content gap** gets mistaken for an engineering task | §3.3 states it explicitly; track library commissioning as a separate, non-engineering workstream |
| Parity chasing regresses the moat (§3.4) | Arrange Mode, path text, vector export and Arabic-first UI are acceptance criteria on every phase, not optional |
| Canvas/export divergence as drawers gain features | Any trait, fill or asset added to a drawer lands in `SVGSerializer` in the **same PR** |
| Premium gates bypassed via undo/redo | Gate at the command layer everywhere, matching the export-format precedent |
| Missing `Info.plist` usage strings crash on tap | P5.3 (photo library) and P7.2 (documents) both need entries before their first build |

---

# Part 8 — What was not verified

- **Bug 15** — no repro; the only item that cannot be diagnosed from source (P0.2).
- **P3.1 sizing** — `MKAssetGeometry`'s representation was not read closely enough
  to estimate the `CGPath` conversion.
- **Bug 11's "shows yellow"** — source says grey/dashed; needs a device screenshot.
- **Bug 3 causes 1/2 vs 3** — whether zoom taps are *lost* or *land and no-op*.
  One `#if DEBUG` log run settles it.
- **Bug 9 cause 3** — whether underline/strikethrough have drawing paths. Only
  `highlightColor` was *confirmed* to have none.
- **Bug 12** — whether system-wide font install is permitted for this app's
  entitlements at all.
- **P3.4** — whether `MKArrangeFormSelectorModel` can serve a general insertion
  palette or only substitution within a derived composition.
- **Reference-app behaviour beyond the screenshots** — `Group lines`,
  `Merge Design`, `Fit`, `Edit…` and the `< Style >` cycler are labelled but
  their behaviour is inferred. Their asset count is estimated, not counted.
- **No build or test run** was performed for any of this analysis.
