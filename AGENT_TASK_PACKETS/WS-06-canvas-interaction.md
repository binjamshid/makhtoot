# WS-06 — Canvas & Interaction

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns
`MKCanvas`: the UIKit canvas host, gestures, selection, guides/snapping, layers-panel
data source, inspector bindings, and the UITextView editing overlay.

## 1. Mission

Build the editor surface: a UIScrollView-based zoomable/pannable canvas hosting the
CALayer tree rendered by WS-07, with the full v1 interaction set the founder locked —
tap/marquee selection, drag/resize/rotate handles, multi-select, group transforms,
alignment guides + snapping, lock/hide respect, and numeric-inspector two-way bindings.
Every mutation goes through WS-02's `MKCommand` stack with gesture coalescing
(`beginGesture`/`endGesture`) so a full drag is one undo step, and every frame of
manipulation must hit D-115's budget (≤8.3 ms ProMotion / ≤16.6 ms floor) by updating
CALayer properties only — never re-rendering content during a gesture (that contract is
shared with WS-07).

The second half is text-editing UX per D-104: in-canvas typing happens in a styled
UITextView (TextKit 2) overlay positioned over the Live Text object so IME, Arabic
keyboard, caret, and selection behave natively; on commit the overlay disappears and the
engine-rendered object remains, pixel-matched. You also ship the interaction entry points
for the differentiator features — entering Arrange Mode, per-glyph/mark/ligature
selection inside arranged nodes (including the glyph-level vs letter-level selection
switch), the join-break form-selector popover, decompose/recompose menus, mark
detach/re-attach dragging, and path-text control-point editing — all thin UI over
WS-04/WS-05 engines. The layers panel data source and inspector bindings are headless
view-models here; WS-13 wraps them in app chrome.

## 2. Scope

**IN**
- `MKCanvasViewController` (UIKit, `UIViewRepresentable`-wrapped for the SwiftUI shell):
  UIScrollView zoom (0.1×–64×), pan, double-tap zoom, canvas backdrop, safe-area-correct
  RTL layout.
- Gesture system: tap select, drag move, marquee, pinch/rotate on selection, handle
  drags (8 resize + rotate handle), two-finger canvas pan/zoom disambiguation,
  long-press context menu hooks.
- Selection model: single/multi, additive tap, marquee (intersect/contain modes),
  selection inside `arranged` nodes (glyph/mark/ligature granularity + letter-level
  switch via WS-04 `LevelMapping`), locked/hidden exclusion.
- Handles/chrome overlay layer (selection rects, rotation cursor, group bounds).
- Group transforms: move/resize/rotate a multi-selection about its common center;
  group/ungroup commands.
- Alignment guides + snapping: canvas edges/center, node edges/centers, equal-spacing
  hints, angle snap (0/45/90…), snap toggle, guide rendering.
- Numeric inspector bindings: X/Y/W/H/rotation/opacity + style fields as a headless
  `InspectorModel` (two-way, command-emitting, coalescing).
- Layers panel data source: ordered node list w/ names, type icons kind, visibility/
  lock toggles, reorder (z), rename — headless `LayersModel` (virtualized for 5 000
  nodes).
- UITextView editing overlay (D-104) incl. creation flow ("add text" places a Live Text
  object and opens the overlay).
- Arrange-mode UX entry points (mode toggle per text object, form-selector popover
  binding, decompose/recompose/revert menus with confirmation dialogs, Arabic strings).
- Path-text editing UX (control-point handles bound to WS-05 `PathEditModel`).
- Hit-testing calls into WS-07's `HitTester` (you own priority/policy, WS-07 owns
  geometry).

**OUT**
- Rendering, layer content drawing, caches, degradation (WS-07).
- App chrome: toolbars, panels' SwiftUI containers, navigation (WS-13) — you ship
  models + the canvas VC only.
- Shaping/arrange/path algorithms (WS-03/04/05). Export UI (WS-08/WS-13).
- Asset browser (WS-14). Accessibility work (not v1 per BRIEF).

## 3. Dependencies

**Upstream:** WS-01 (`MKDesignSystem` tokens for chrome colors/handles), WS-02 (document,
commands, undo, fixtures), WS-03 (cluster map for caret mapping), WS-04 (arrange
commands + models), WS-05 (`PathEditModel`), WS-07 (`LayerTreeBuilder` output + 
`HitTester` — develop against WS-07's `RenderTreeProviding` protocol; a flat-color stub
renderer conforming to it ships in WS-07's first milestone; coordinate via CONTRACTS.md).
**Stubs you may rely on:** `StubEntitlementResolver` (canvas itself never gated),
`SystemFontStubProvider`.

**Downstream consumers:** WS-13 (embeds canvas VC + models into the editor scene), WS-07
(receives visible-rect/zoom notifications for cache decisions), WS-08 (selection-frame
"export selection" seam — v1 exports whole canvas; keep the seam only).

## 4. Locked decisions binding this packet (quoted)

- **D-104**: "In-canvas editing uses a UITextView (TextKit 2) overlay for IME/keyboard/
  selection correctness; committed rendering of Live Text objects is always the
  MKTextEngine→MKRender path so canvas and export are pixel-identical. The overlay is
  styled to match metrics; on commit (end editing) the overlay disappears and the
  engine-rendered object remains."
- **D-114**: "canvas = UIScrollView-zoomable UIView with a CALayer per top-level node
  (transform changes are layer-property updates → cheap 60/120 Hz manipulation)."
- **D-115**: "manipulation frame time ≤8.3 ms on ProMotion hardware, ≤16.6 ms floor on
  A12-class; typing echo <50 ms."
- **D-112** (undo contract): "coalesced gestures = single command."
- **D-111**: node fields "locked/hidden" and z-order are the canvas's authority surface.
- BRIEF "Canvas & projects": "drag, resize, rotate, multi-select, alignment guides,
  snapping, visual layers, grouping, lock/hide, full undo/redo, zoom, pan"; "Layers panel
  showing text objects, arranged glyphs, tashkeel marks, images, shapes; visibility/
  lock/reorder"; "Numeric inspector: editable X/Y/W/H/rotation + relevant style/transform
  fields".

## 5. Task breakdown (ordered)

1. **`MKCanvasViewController` + scroll host**: UIScrollView with content view sized to
   canvas + margin, zoom 0.1×–64×, `viewForZooming`, double-tap zoom-to-fit/100 %,
   backdrop from theme `canvasBackdrop`. RTL note: canvas coordinates are geometric
   (LTR math space); only chrome/panels mirror. *Accept:* opens WS-02
   `fixture-100-nodes` with WS-07 stub renderer; pinch zoom smooth on simulator;
   content inset centers small canvases.
2. **View-model spine** `CanvasSession` (`@MainActor`): holds document ref, selection
   state, mode (`browse/editText/arrange/pathEdit`), publishes to SwiftUI; single funnel
   `perform(_ command:)` → document apply + undo stack. *Accept:* unit tests drive
   selection/mode transitions without UIKit.
3. **Hit-test policy**: tap → `HitTester.node(at:)` respecting z-order (topmost first),
   `isLocked`/`isHidden` skip, 44 pt minimum touch slop for thin strokes; inside an
   `arranged` node in arrange mode, hit at glyph/mark granularity (WS-07 geometry);
   otherwise arranged node is one object. *Accept:* fixture taps select expected nodes;
   locked node taps fall through to node below.
4. **Selection model + chrome**: `SelectionState {ids, granularity: .object/.glyph/
   .letter}`; overlay CALayer drawing selection outlines (theme `selectionStroke`),
   multi-select union bounds + 8 resize handles + rotate handle above-top-center
   (RTL-agnostic placement). Handles hit-tested before nodes. *Accept:* selection chrome
   updates < 1 frame after selection change; handles scale-invariant (constant screen
   size across zoom).
5. **Move gesture**: pan on selection → `beginGesture()`, per-frame transform commands
   (coalescing key `move-<gestureID>`), CALayer position updated by WS-07 fast-path
   (`applyTransientTransform(nodeID:transform:)` on the render tree — no content
   redraw), `endGesture()` commits. *Accept:* Instruments/os_signpost shows no
   `draw(in:)` during drag; one undo entry per drag; 60-item multi-select drag within
   frame budget on device-class run recorded.
6. **Resize + rotate gestures**: handle drags compute anchored scaling (opposite
   handle/center with option), aspect lock (corner default proportional; edge free),
   rotation about selection center with angle snap (5° increments while snapping on,
   plus exact 0/45/90 magnetics); pinch/rotate two-finger equivalents on selection.
   All coalesced. *Accept:* resizing a rotated node behaves correctly (anchor math in
   node-local space); numeric inspector reflects live values during gesture.
7. **Marquee**: drag on empty canvas → marquee rect; intersect mode default, ⌥/long-drag
   toggles contain mode; excludes locked/hidden. *Accept:* marquee over fixture selects
   expected set; auto-scroll near edges works.
8. **Group transforms + group/ungroup**: `group` command wraps selection into `group`
   node (preserving world transforms), ungroup unwraps; transforms on group apply to
   the group node only. *Accept:* group→transform→ungroup leaves children at correct
   world positions (property test vs matrix math).
9. **Snapping engine** `SnapEngine`: candidate sources — canvas edges/center, other
   nodes' edges/centers (visible, unlocked, non-selected), equal-spacing between
   neighbor pairs; snap radius 6 pt screen-space (zoom-adjusted); returns snapped delta
   + guide descriptors; angle snapping for rotation. Guides drawn in chrome layer
   (accent color, hairline). *Accept:* unit tests on snap math (edge/center/spacing);
   drag near another node's center shows both guides; toggle disables all.
10. **`LayersModel`** (headless): flattened ordered list (top-first) with sections for
    arranged-node children (glyphs "حرف", marks "تشكيل", ligatures "لام-ألف/رباط") when
    expanded; operations: select, toggle visible/lock, rename, reorder (drag) →
    z-order commands, delete, duplicate. Virtualized windowing API for 5 000 nodes
    (`rows(in range:)`). *Accept:* reorder emits correct z commands; 5 000-node fixture
    scrolls without materializing all rows (measured allocations).
11. **`InspectorModel`** (headless): two-way fields X/Y/W/H (world frame of selection),
    rotation (degrees), opacity, fill color, stroke, shadow, text-style fields when a
    text object is selected (font size, kerning, tracking, baseline shift, line height),
    per-glyph fields in arrange granularity. Numeric entry accepts Latin + Arabic-Indic
    digits (WS-01 `MKInspectorField`); edits emit coalescable commands; multi-select
    shows mixed-value state ("—") and applies to all. *Accept:* typing W=200 resizes
    about selection center; mixed-value editing applies delta correctly; bindings unit-
    tested headless.
12. **Add-content entry points**: API for WS-13 toolbar — `addLiveText(at:)` (default
    "اكتب هنا" placeholder text, opens overlay immediately), `addPathText(preset:)`,
    `addShape(_:)`, `addImage(assetRef:)`. *Accept:* each returns the new node id and
    selects it.
13. **Text editing overlay (D-104)** `TextEditingOverlay`: UITextView (TextKit 2) added
    at the Live Text node's frame, ZOOM-matched (canvas zoom applied via
    `overlay.transform`); rotation is NOT applied to the overlay — a rotated object
    normalizes to axis-aligned while editing (per D-201, DF-1) and restores its stored
    rotation when the overlay commits/dismisses; font/kerning/line-height matched from
    `MKTextStyle`, RTL text alignment; engine-rendered node hidden while editing; live
    typing publishes text changes (throttled to keystroke) so inspector/layout stay
    current; commit on tap-outside/Done → final text command + overlay removal + node
    re-render; Esc/cancel restores pre-edit text. *Accept:* overlay caret/selection
    behave natively with iOS Arabic keyboard incl. tashkeel long-press input; commit
    leaves engine rendering whose bounds match overlay text within 1 pt (pixel-identity
    itself is WS-07-verified, `T-CANVAS-EDIT-*`); typing echo signpost < 50 ms; a
    rotated text object entering edit mode shows an axis-aligned overlay and restores
    its original rotation on commit (`T-CANVAS-EDIT-ROTATE`).
14. **Caret/selection mapping**: when entering edit mode from a double-tap on a specific
    glyph, position the overlay caret at the tapped cluster via WS-03 cluster map
    (glyph → codepoint index → UTF-16 offset). *Accept:* double-tap the م of "محمد"
    places caret adjacent to that letter (either side per bidi caret rules — use
    UITextView's own positioning from the mapped index).
15. **Arrange mode UX**: mode toggle on selected text object ("ترتيب" arrange /
    confirmation-gated "عودة إلى النص" revert via WS-04 `RevertService` preflight);
    inside arrange mode: granularity switch (glyph ⇄ letter via `LevelMapping`),
    context menu: break join here ("فصل الاتصال"), form selector popover bound to
    `FormSelectorModel` (4 previews, disabled invalid forms), decompose ligature
    ("تفكيك الرباط", fidelity toggle from `DecomposeOptions`), recompose, detach mark
    ("فصل التشكيل"), re-attach (drag mark onto base → attach command). *Accept:*
    integration test: full flow on "لا" fixture — arrange → decompose → move parts →
    undo ×3 → revert; every dialog string Arabic with gloss comments.
16. **Path-edit mode UX**: selected path-text node → "تحرير المسار" toggles pathEdit
    mode; anchors/handles drawn in chrome layer, drags routed to WS-05 `PathEditModel`
    (coalesced); insert point (tap on curve), delete (context menu); curvature warning
    banner when WS-05 reports it. *Accept:* control-point drag relayouts live within
    frame budget on the circle fixture; undo per drag.
17. **Keyboard & shortcuts (iPad)**: arrow-key nudge (1 pt / ⇧10 pt), ⌘Z/⇧⌘Z undo/redo,
    ⌘G/⇧⌘G group/ungroup, ⌘D duplicate, Delete removes selection (respecting locks).
    *Accept:* UIKeyCommand list wired; nudge emits coalesced commands per key-repeat
    burst.
18. **Mode/lifecycle integration**: entering background → commit any open overlay +
    endGesture; document close guarded against mid-gesture state. *Accept:* backgrounding
    during drag leaves consistent scene + single undo entry.
19. **Perf verification pass**: with WS-07 real renderer, run D-115 manipulation
    scenarios (drag 1/10/60 nodes at max zoom-out on the 5 000-node fixture) capturing
    `manipulationFrame` signposts; file results for WS-07 hardening. *Accept:* simulator
    numbers recorded; regressions block merge.

## 6. Arabic-correctness notes

- Overlay editing fixtures: type "بسم الله" then add tashkeel via long-press keyboard;
  mixed "عام ٢٠٢٦ vs 2026" caret traversal must follow system bidi caret behavior
  (trust UITextView; do not intercept).
- Selection labels in the layers panel use Arabic node names by default ("نص", "نص على
  مسار", "مجموعة", "شكل", "صورة", "خلفية") with user rename support (Arabic input).
- Form-selector previews must render actual resolved glyphs (WS-04 model paths), not
  presentation-form characters.
- Marquee/handles are geometry — no mirroring; panels/inspector ARE mirrored (labels
  right of fields per RTL convention from `MKInspectorField`).
- Angle display in inspector: degrees with Arabic-Indic digit option, counter-clockwise
  positive documented ("الاتجاه الموجب عكس عقارب الساعة").
- Mark dragging: dropping a mark far from any base keeps it detached — never snap-attach
  without an explicit drop-on-base (hit radius = base glyph bounds + 8 pt).

## 7. Packet acceptance criteria (gates)

- **Build gate**: `MKCanvasTests` (headless models + math) green; app editor scene runs
  with fixtures (`T-CANVAS-*`).
- **D-115 gates**: manipulation frame ≤8.3/16.6 ms scenarios of task 19 (`T-PERF-FRAME-*`,
  final device sign-off shared with WS-07); typing echo <50 ms end-to-end through the
  overlay (`T-PERF-TYPE-*`).
- **Undo gate**: every gesture class = exactly one undo entry; property test over
  scripted gesture sequences (`T-CANVAS-UNDO-*`).
- **Manual Arabic checklist**: §6 flows on device/simulator with screenshots — overlay
  typing, arrange flow on "لا"/"محمد", form selector, mark detach/attach, path edit
  (`T-ARABIC-M-CANVAS-*`).
- **Snapping/geometry**: unit suites for snap math, anchored resize, group round-trip
  (`T-CANVAS-SNAP-*`, `T-CANVAS-XFORM-*`).

## 8. Deliverables

- `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift`, `CanvasSession.swift`,
  `HitTestPolicy.swift`, `SelectionState.swift`, `SelectionChromeLayer.swift`,
  `Gestures/GestureCoordinator.swift`, `Gestures/MoveGesture.swift`,
  `Gestures/HandleGestures.swift`, `Gestures/MarqueeController.swift`,
  `SnapEngine.swift`, `GuideRenderer.swift`, `LayersModel.swift`, `InspectorModel.swift`,
  `TextEditingOverlay.swift`, `ArrangeInteraction.swift`, `PathEditInteraction.swift`,
  `KeyCommands.swift`, `CanvasContentAPI.swift`
- `MakhtootKit/Tests/MKCanvasTests/*` (snap/transform/undo/model tests, scripted gesture
  harness)
- CONTRACTS.md update (`RenderTreeProviding` consumption, transient-transform fast path).

## 9. References

- ARCHITECTURE.md: §10 Canvas & Interaction, §11 Rendering & Preview (fast-path
  contract), §5 Arrange Mode Engine, §9 Path Text Engine, §14 Undo/Redo & Autosave.
- PRD.md: §4 Canvas Editor, §5 Typing & Live Text, §6 Arrange Mode, §9 Path Text,
  §10 Layers & Inspector, §21 Edge-Case Compendium.
- BRIEF.md: "Canvas & projects" (all bullets), "Arabic text & glyph engine" (arrange
  interaction bullets), "Performance".
- Market study: §3 gap rows "Layers panel + numerical inspector + snapping" (parity
  feature) and §4 caret/bidi mapping groundwork[^23][^24]; §12 canvas-architecture
  guidance[^61].

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS06-A1: transient-transform fast path contract with MKRender",
  "WS06-A2: selection granularity model (object/glyph/letter)", "WS06-A3: snapping
  sources & radii", "WS06-A4: overlay commit semantics (D-104) incl. cancel path".
- Implementation log after tasks 5, 13, 15, 19 with signpost evidence.
- Verification evidence: gesture-undo property test output, D-115 scenario table,
  manual Arabic checklist screenshots (arrange + overlay flows).
- Record any deviation discovered in WS-07's stub-vs-real renderer behavior as memory
  notes for the hardening phase (P14).

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Canvas & projects: drag/resize/rotate/multi-select/alignment guides/snapping/visual layers/grouping/lock-hide/full undo-redo/zoom/pan | Tasks 1, 4–9 |
| Layers panel: text/arranged glyphs/tashkeel marks/images/shapes; visibility/lock/reorder | Task 10 |
| Numeric inspector: editable X/Y/W/H/rotation + relevant style/transform fields | Task 11 |
| Normal typing behaves like a native text field (shaping/IME/caret/selection) | Tasks 13–14 |
| Arrange Mode: explicit user action, reversible revert with confirmation | Task 15 |
| Arranged compositions never auto-reflow; every glyph/mark/ligature independently selectable/transformable | Tasks 4, 15 |
| Both glyph-level and Unicode-letter-level manipulation supported | Task 15 (granularity switch, `LevelMapping`) |
| Joining preserved by default; explicit break + isolated/initial/medial/final form selector | Task 15 |
| Tashkeel + Qur'anic marks attach/follow base by default, individually selectable/detachable/movable | Task 15 |
| Ligatures: combined selectable objects and decomposable components, fidelity default + opt-out | Task 15 |
| Per-object kerning/tracking/baseline shift/line height/scale/rotation/opacity/outline/shadow/fill | Task 11 |
| Curved/circular/freeform text on dynamic live Bézier paths, editable until arranged | Task 16 |
| Performance: quantitative frame-time/latency budgets (all iOS 18 devices) | Task 19 (rest: WS-07) |
