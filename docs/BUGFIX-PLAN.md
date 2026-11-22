# Makhtoot — Bug Triage & Fix Plan

Every entry below was traced to real code in this repo before being written.
Where a root cause is **confirmed by reading the source**, it says so. Where it
is a hypothesis that still needs an on-device check, it says that too.

---

## 0. The four root causes behind ~14 of the 18 reported symptoms

Before the per-bug tables, four cross-cutting defects. Fixing these four is
most of the work; the rest are genuinely-unbuilt features.

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
(`isActive`, `activeOwnerNode`, and all the `can…` gates) goes through
`session.scene`.

This is *exactly* the reported symptom "unresponsive **but fire in the
background**": the mutation lands, the CALayer tree redraws (it is driven by
`document.sceneUpdates`, an AsyncStream, bypassing SwiftUI entirely), and the
SwiftUI chrome never re-reads. It explains bugs **8, 9, 10, 11**, the dead
Arrange toolbar in **16**, and stale inspector fields.

Corroborating evidence that the team already hit this and patched it
one-property-at-a-time: `EditorViewModel` maintains a manual
`refreshUndoRedoState()` mirror with a comment about "an untracked read through
a non-`@Observable` nested object left this button permanently stale"
([EditorScene.swift:485](Makhtoot/AppShell/Scenes/Editor/EditorScene.swift:485)),
plus **three separate polling loops** (`startZoomBucketPolling` 150 ms,
`startModePolling` 100 ms, memory 1 s) that exist purely to work around missing
observation.

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
draws at the full 260 + padding, while the buttons sit flush against the
scroll view's leading origin — which under `layoutDirection == .rightToLeft`
is the **right** edge. `ArrangeToolbarView.swift:29` has the identical
`.frame(maxWidth: 320)`. This is bug **4**, confirmed by construction.

### RC-3 — The text-edit overlay lives inside the zoomable content view and nothing scrolls it clear of the keyboard

```
Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift:1522
    vc.contentHostView.addSubview(overlay)
```

`contentHostView` is the scroll view's `viewForZooming` target. Consequences:

- The overlay is frame-positioned in canvas coordinates but inherits the zoom
  transform, so at any zoom ≠ 1 the `UITextView` is scaled and its
  `.systemFont(ofSize: pointSize)` no longer matches what it will render as.
- `keyboardWillShow` ([MKCanvasViewController.swift:151](MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift:151))
  only adjusts `scrollView.contentInset.bottom`. There is **no**
  `scrollRectToVisible` for the node being edited. Adjusting an inset does not
  move existing content. → bug **6**.
- There is no tap-outside-to-dismiss recognizer. The only dismissal paths are
  the "تم" accessory button and `textViewDidEndEditing`, and `commit()` calls
  `resignFirstResponder()` which *re-enters* `commit()` via that delegate.
  Teardown then waits on the 100 ms `startModePolling` tick. → bug **5**.

### RC-4 — Features that were never built (plumbing exists, no caller)

| Capability | Model/engine support | App-layer caller |
|---|---|---|
| Project thumbnails | `DocumentPackage.writeThumbnail(_:)` ✅ | **zero callers** ❌ |
| Background image | `MKBackgroundContent.image(MKAssetRef)` ✅ | no picker ❌ |
| Font import | `MKFontImporter.importFont(from:originalFilename:)` ✅ | no `.fileImporter` ❌ |
| Alternate app icon | — ❌ | no `setAlternateIconName` ❌ |
| Text highlight paint | `MKTextStyle.highlightColor` ✅ | **no renderer reads it** ❌ |
| Tashkeel insertion | — ❌ | menu item is a copy-paste stub ❌ |

Verified: `grep -rn "PhotosPicker\|PHPicker\|fileImporter\|UIImagePicker"` over
`Makhtoot/` and `MakhtootKit/Sources/` returns **nothing**. Same for
`setAlternateIconName`. `writeThumbnail` and `highlightColor` have no
production readers/callers outside their own definitions.

---

# Main screen

## Bug 1 — Projects show a default icon, not a preview of the project

**(A) Three possible causes**

1. ✅ **CONFIRMED — thumbnails are never generated.** The UI path is correct
   ([ProjectBrowserView.swift:434](Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift:434))
   and falls back to `Image(systemName: "doc.richtext")` when
   `project.thumbnailURL` is nil. `DocumentPackage.writeThumbnail(_:)` exists
   at `MKPersistence/DocumentPackage.swift:143` and **has zero callers**;
   `MKProjectRecord.thumbnailPath` is never assigned anywhere in production
   code. So the URL is always nil.
2. Thumbnails written but the metadata record not refreshed — ruled out, since
   nothing writes them at all.
3. File exists but `FileManager.fileExists` fails under an iCloud
   not-yet-materialised placeholder — a *future* risk once (1) is fixed, not
   the current cause.

**(B) Three suggested remedies**

1. **Preferred.** Generate on editor close. In `EditorScene.finish(_:)`, before
   `viewModel.close()`, render a ~600 pt-wide PNG via the existing
   `MKSnapshotRenderer` (already used by `exportPNGForSharing`), call
   `package.writeThumbnail(_:)`, and update `MKProjectRecord.thumbnailPath`.
   Cheap, no background infrastructure, always fresh at the moment the user
   looks at the grid.
2. Also generate at project *creation* (`NewProjectSheet` → library) so a
   never-opened project still shows its template/canvas rather than the
   generic doc icon.
3. Lazy backfill: `ProjectBrowserViewModel` enqueues a low-priority render for
   any visible card whose `thumbnailURL` is nil, so the existing library
   populates without opening each project.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` (close hook)
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`writeThumbnail()` method)
- `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift` (set `thumbnailPath`)
- `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserViewModel.swift` (backfill, remedy 3)
- `MakhtootKit/Sources/MKPersistence/Metadata/MetadataModels.swift` (record write path)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Snapshot render blocks the close animation on a heavy document | Render off the main actor via the existing `MKSnapshotRenderer` async path; cap at 600 pt long edge; time-box and skip on timeout — a stale thumbnail beats a hung dismissal |
| Package bloat / iCloud sync cost | PNG at 600 pt ≈ 60–150 KB; already inside the package format spec (`thumbnail.png`); exclude from journal replay |
| Reading `Data(contentsOf:)` synchronously in `body` for every visible card | Move to an async `@State` image cache keyed by URL + mtime; the current synchronous read in `body` will stutter scrolling once thumbnails actually exist |
| Thumbnail goes stale after edits made outside the close path (autosave, sync) | Stamp `thumbnailPath` with the scene revision; regenerate when it differs |

---

## Bug 2 — No way to import a picture as a background (premium)

**(A) Three possible causes**

1. ✅ **CONFIRMED — the feature does not exist in the app layer.** The model
   fully supports it (`MKBackgroundContent.image(MKAssetRef)`,
   `MKNode.swift:265`; `CanvasContentAPI.addImage(assetRef:kind:at:isPhotoBackgroundUse:)`,
   `CanvasContentAPI.swift:56`), and `MKImageDrawer` renders it. But there is
   **no photo picker anywhere in the codebase**.
2. Entitlement gate silently swallowing the action — not applicable; there is
   no action to gate.
3. Asset-store ingestion missing — partially true and a real sub-task: the
   content-addressed `assets/` write path must be exercised to produce the
   `MKAssetRef` the model needs.

**(B) Three suggested remedies**

1. **Preferred.** Add a `PhotosPicker` (SwiftUI, PhotosUI) entry in the tool
   rail's `+` menu → "صورة خلفية", gated on
   `container.entitlementProvider.isEntitled(.premiumBackgrounds)` with the
   existing `nav.presentPaywall(.premiumFeatureTap(...))` fallback used by the
   SVG/PDF export buttons.
2. Add the same entry to `NewProjectSheet` so a project can start from a photo.
3. Also expose it as a `.fileImporter` for `.image` UTTypes, so Files/iCloud
   Drive images work, not only the photo library (shares the ingestion code).

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift` (menu entry + picker)
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`setBackgroundImage(_:)`, asset ingestion)
- `Makhtoot/AppShell/Scenes/Browser/NewProjectSheet.swift` (remedy 2)
- `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift` (asset write, if not already exposed)
- `Makhtoot/Config/Info.plist` (`NSPhotoLibraryUsageDescription`)
- `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` (feature list copy)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Missing `NSPhotoLibraryUsageDescription` → **hard crash on tap** | Add before shipping; `PhotosPicker` with `.images` filter avoids the full-library permission in most cases |
| Multi-MB HEIC images inflate the package and break the memory ladder | Downscale to canvas size × 2 on ingest; register with `MKMemoryGovernor` like the layer tree already is |
| Privacy manifest / App Store review | The repo already has a privacy manifest (commit `e5d5a65`); add the photo-library API reason code |
| Entitlement bypass via undo/redo of a premium background | Gate at the *command* layer, not just the button, matching the export-format pattern |

---

# Edit screen

## Bug 3 — All 3 zoom buttons not working

**(A) Three possible causes**

1. ✅ **CONFIRMED CONTRIBUTOR — the whole floating-bar VStack is rebuilt ~7×/second.**
   `startZoomBucketPolling` assigns `self.currentZoomScale = scale`
   **unconditionally** every 150 ms, *before* the change-guard:
   ```
   EditorViewModel.swift:391-393
       let scale = vc.scrollView.zoomScale
       self.currentZoomScale = scale                       // ← always fires
       guard abs(scale - self.lastPolledZoomScale) > 0.0001 else { continue }
   ```
   `@Observable` notifies on *every* set, equal value or not. `ZoomControlsView`
   reads `currentZoomScale`, so it — and the enclosing `canvasArea` VStack —
   invalidates 6.7×/s. SwiftUI `Button`s recreated mid-touch routinely drop
   the tap.
2. **Likely co-cause — hit-testing.** The bars live in a `VStack` inside the
   canvas `ZStack` alongside `Spacer()`s, layered over a `UIViewControllerRepresentable`.
   `MKToolbarButton` uses `.buttonStyle(.plain)` over a `Color.clear`
   background — a plain button's hit area is its *rendered* content, and inside
   a `ScrollView` the scroll view's touch-delay can swallow short taps.
3. **The action does run but has no visible effect.** `step(by:)` calls
   `scrollView.setZoomScale(...)`, and `zoomToFit()`/`zoomTo100Percent()` are
   correct. Limits are sane (0.1×–64×,
   [MKCanvasViewController.swift:66-67](MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift:66)).
   But if `canvasViewController` (a **`weak var`**,
   `EditorViewModel.swift:171`) is nil, `step` and both fit calls silently
   `return`/no-op. Needs a one-line log to confirm on device.

**(B) Three suggested remedies**

1. **Preferred, and required regardless.** Guard the assignment:
   `if abs(scale - lastPolledZoomScale) > 0.0001 { currentZoomScale = scale; … }`.
   Kills the 150 ms invalidation storm. Do the same audit on
   `startModePolling` and the memory poll (`memoryBannerText` is assigned every
   second, same defect).
2. Give the zoom buttons a real hit target: replace `.buttonStyle(.plain)` with
   `.contentShape(Rectangle())` + a ≥44 pt frame, and add
   `.simultaneousGesture`/`.highPriorityGesture` or move them out of the
   `ScrollView` when content fits (see RC-2 fix, which does this anyway).
3. Add `#if DEBUG` logging in `step(by:)` and `attach(canvasViewController:)`
   to prove whether the action fires and whether the VC reference is live —
   this distinguishes cause 1/2 (tap lost) from cause 3 (tap lands, no-op) in
   one run.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (poll guards; consider making `canvasViewController` strong or `unowned`)
- `Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift`
- `MakhtootKit/Sources/MKDesignSystem/Components/MKToolbarButton.swift` (hit shape, shared by every bar)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Guarding the poll makes the % badge stop updating during pinch | The guard uses the same 0.0001 epsilon already there; pinch changes the value continuously so the badge still tracks |
| Changing `MKToolbarButton`'s hit shape affects Arrange/Path/Zoom bars at once | That is the intent — but re-verify the Arrange toolbar's disabled/`.opacity(0.4)` states still read correctly |
| Making `canvasViewController` strong could retain-cycle | Prefer keeping it `weak` and instead assert/log on nil; SwiftUI already retains the VC for the representable's lifetime |

---

## Bug 4 — Pill-bar buttons offset to the right instead of centred

**(A) Three possible causes**

1. ✅ **CONFIRMED — `ScrollView` + fixed `maxWidth`, content packs to the RTL
   trailing edge.** See **RC-2**. `ToolRailView.swift:22` `.frame(maxWidth: 260)`
   with ~152 pt of content; `ArrangeToolbarView.swift:29` `.frame(maxWidth: 320)`
   with the same shape.
2. `.frame(maxWidth: .infinity, alignment: .center)` applied at the call site
   ([EditorScene.swift:392-394](Makhtoot/AppShell/Scenes/Editor/EditorScene.swift:392))
   centres the **pill**, not the buttons inside it — so it masks the real
   problem and makes it look like a padding bug.
3. RTL mirroring of an asymmetric padding — ruled out; padding is symmetric
   (`.padding(theme.spacing.sm)`).

**(B) Three suggested remedies**

1. **Preferred.** Let the bar size to its content and only scroll when it
   genuinely overflows: put the `HStack` in a `ViewThatFits`, or add
   `.frame(maxWidth: .infinity)` **on the inner `HStack`** so short content
   centres inside the scroll view. Cap with `.frame(maxWidth: 260)` unchanged.
2. Drop the `ScrollView` entirely at compact width and use a wrapping/flow
   layout — the rail is only 4 items; the horizontal scroll adds nothing but
   the touch-delay that also hurts bug 3.
3. Move the pill background/shadow *inside* the scroll view's content so the
   capsule always hugs the buttons — visually honest at any content width.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift`
- `Makhtoot/AppShell/Scenes/Editor/ArrangeToolbarView.swift`
- `Makhtoot/AppShell/Scenes/Editor/PathEditToolbarView.swift` (same pattern — check)
- `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` (call-site alignment)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Arrange toolbar has genuinely more items and *needs* to scroll | `ViewThatFits` keeps the scroll fallback; only the fits-case changes |
| Regression on iPad (`isRegularWidth`), which uses a different `HStack` branch | Test both size classes; the iPad branch pins the rail to the leading edge deliberately |
| Kufi theme has `radius == 0`, so a "capsule" is a rectangle | Keep using `theme.radius.sheet`, don't hardcode `Capsule()` |

---

## Bug 5 — Buggy way to hide the keyboard

**(A) Three possible causes**

1. ✅ **CONFIRMED — no tap-outside dismissal exists.** The only affordances are
   the `UIToolbar` "تم" accessory button
   ([TextEditingOverlay.swift:166-170](MakhtootKit/Sources/MKCanvas/TextEditingOverlay.swift:166))
   and `textViewDidEndEditing`. Tapping the canvas does nothing.
2. ✅ **CONFIRMED — re-entrant commit.** `commit()` calls
   `textView.resignFirstResponder()`, which synchronously fires
   `textViewDidEndEditing` → `commit()` again. The second pass is a no-op only
   because `TextEditingOverlayController.commit` guards on `isActive`, but
   `session.endGesture()` / `commitTransients()` ordering during re-entry is
   fragile.
3. ✅ **CONFIRMED — teardown is polled, not driven.** Overlay removal happens in
   `syncOverlay()`, reached only from `startModePolling`'s 100 ms tick
   ([EditorViewModel.swift:340](Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift:340)).
   The code's own comment documents the overlay getting "visibly stuck on
   screen". The poll is a workaround for **RC-1**, not a fix.

**(B) Three suggested remedies**

1. **Preferred.** Add a tap-outside recognizer on `MKCanvasViewController.view`
   that commits the active overlay, plus a swipe-down-to-dismiss on the
   accessory toolbar. Standard, discoverable, matches every comparable editor.
2. Make commit idempotent and non-re-entrant: set `isActive = false` *before*
   `resignFirstResponder()`, and have `textViewDidEndEditing` only tear down
   the view, never re-invoke the controller.
3. Replace the 100 ms mode poll with a direct callback:
   `TextEditingOverlayView.onCommit` → `EditorViewModel.dismissOverlayIfNeeded()`.
   Removes the latency and one of the three polling loops. (Fully removing the
   poll depends on **RC-1**.)

**(C) Files touched**
- `MakhtootKit/Sources/MKCanvas/TextEditingOverlay.swift`
- `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift` (tap-outside recognizer)
- `MakhtootKit/Sources/MKCanvas/Gestures/` (recognizer arbitration with existing tap/double-tap)
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (callback wiring, poll removal)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| New tap recognizer conflicts with select/double-tap-to-edit | Use `require(toFail:)` against the existing double-tap; add to `MKCanvasTests/TextEditingOverlayTests` |
| Committing on every stray tap loses in-progress IME/marked text | `textViewDidChange` already suspends mirroring while `markedTextRange != nil`; also skip commit while marked text is present |
| Removing the poll before RC-1 is fixed breaks other mode transitions it happens to cover | Fix RC-1 first, or keep the poll until the callback is proven across all three entry paths (canvas double-tap, toolbar add-text, DEBUG hook) |

---

## Bug 6 — Can't preview text typed under the keyboard

**(A) Three possible causes**

1. ✅ **CONFIRMED — nothing scrolls the edited node into view.**
   `keyboardWillShow` only sets `scrollView.contentInset.bottom`
   ([MKCanvasViewController.swift:151-172](MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift:151)).
   An inset change does not move already-laid-out content. There is **no**
   `scrollRectToVisible` / `setContentOffset` call anywhere in the keyboard
   path.
2. ✅ **CONFIRMED CONTRIBUTOR — the overlay is inside the zoomable view.**
   `vc.contentHostView.addSubview(overlay)` (**RC-3**). Its frame is canvas-space
   and gets the zoom transform, so at fit-zoom (typically ≪ 1×) the text view
   and its font are scaled down — text can be legible-in-principle yet
   unreadable in practice, independent of the keyboard.
3. The overlay may sit *behind* the keyboard's own input accessory ordering —
   secondary, but worth checking once (1) and (2) land.

**(B) Three suggested remedies**

1. **Preferred.** In `keyboardWillShow`, after the inset animation, call
   `scrollView.scrollRectToVisible(overlayFrameInScrollView, animated: true)`
   using the active overlay's frame converted into scroll-view space. Expose
   the active overlay frame from `EditorViewModel` or hold a weak reference in
   the VC.
2. Host the overlay in `vc.view` (above the scroll view) instead of
   `contentHostView`, positioned by converting the node's world OBB through the
   current zoom. Fixes the scaled-font problem too, and makes point-size WYSIWYG.
3. If the node still can't clear the keyboard on a small device, temporarily
   zoom/pan the canvas so the edit region occupies the visible band above the
   keyboard, restoring on commit.

**(C) Files touched**
- `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift`
- `MakhtootKit/Sources/MKCanvas/TextEditingOverlay.swift`
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`presentOverlay`, `overlayFrame(for:)`)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Auto-scroll fights the user's own pan mid-edit | Only scroll on `keyboardWillShow` and on overlay presentation, never continuously |
| Re-hosting the overlay in `vc.view` (remedy 2) breaks the existing coordinate math and D-201 rotation notes | Land remedy 1 first (low risk, high payoff); treat remedy 2 as a separate change with `TextEditingOverlayTests` extended for zoom ≠ 1 |
| Floating keyboard / Stage Manager / iPad split give odd overlap values | `max(0, …)` clamp is already there; add an explicit `overlap == 0` early-out |

---

## Bug 7 — Buttons above the pill bar are illegible against the same-coloured background

**(A) Three possible causes**

1. ✅ **CONFIRMED — `ZoomControlsView` has no surface backing.** `ToolRailView`
   and `ArrangeToolbarView` both apply
   `.padding + .background(theme.surface, in: RoundedRectangle…) + .shadow(…)`.
   `ZoomControlsView` ([ZoomControlsView.swift:18-37](Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift:18))
   applies **none** of that — bare `theme.ink` glyphs and `theme.inkMuted` text
   drawn straight onto the canvas backdrop. In compact layout it sits directly
   above the pill ([EditorScene.swift:391](Makhtoot/AppShell/Scenes/Editor/EditorScene.swift:391)),
   which is precisely "the buttons above the pill bar".
2. `MKChip` in `panelToggleRow` (iPad only) may have the same problem —
   worth auditing in the same pass.
3. Theme contrast: `theme.ink` on a white canvas is fine, but on a dark or
   photo background it vanishes. A surface chip fixes both cases at once.

**(B) Three suggested remedies**

1. **Preferred.** Give `ZoomControlsView` the identical pill treatment —
   extract the `.padding/.background/.shadow` trio into a shared
   `MKFloatingBar` view modifier in `MKDesignSystem` and apply it to the tool
   rail, arrange toolbar, path-edit toolbar, and zoom controls. One definition,
   no drift.
2. Add a subtle scrim/vibrancy (`.background(.ultraThinMaterial)`) behind
   floating chrome so it stays legible over arbitrary canvas content — the
   right answer once background images (bug 2) ship.
3. Audit every floating control for the WCAG AA 4.5:1 contrast floor against
   both `theme.canvasBackdrop` and a worst-case photo background; add a
   contrast assertion to `MKDesignSystemTests/TokenResolutionTests`.

**(C) Files touched**
- `MakhtootKit/Sources/MKDesignSystem/Components/` (new `MKFloatingBar` modifier)
- `Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift`
- `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift`, `ArrangeToolbarView.swift`, `PathEditToolbarView.swift` (adopt the shared modifier)
- `MakhtootKit/Tests/MKDesignSystemTests/TokenResolutionTests.swift`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Adding a pill around zoom controls eats scarce vertical space on small iPhones | The bars are already stacked in compact layout; measure on iPhone SE |
| `.ultraThinMaterial` is expensive over a live-rendering canvas | Use it only on the small floating bars, never full-width; profile with the existing `PerfHUDView` |
| Five call sites adopting one modifier risks a visual regression across themes | Screenshot-diff all themes via `DesignSystemGallery` before/after |

---

# أء (font settings) menu

> **All five bugs in this section share RC-1.** `FontSettingsSheet` holds a
> plain `let inspector: InspectorModel`, and every value it displays
> (`pointSizeValue`, `isBoldValue`, `fillValue`, `highlightColorValue`,
> `fontRefValue`) is a computed property reading `session.scene` — which is
> **not observable**. The setters all work. The sheet never re-reads.

## Bug 8 — Font size +/− and presets unresponsive (but fire in the background)

**(A) Three possible causes**

1. ✅ **CONFIRMED — RC-1.** `currentPointSize` reads `inspector.pointSizeValue`
   → `session.scene` → non-observable `MakhtootDocument`. `setPointSize` runs,
   the command applies, the canvas redraws via the AsyncStream, the sheet's
   `Text("\(Int(currentPointSize)) pt")` and the preset highlight never update.
   The reported behaviour — "unresponsive **but fire in the background**" — is
   a verbatim description of this.
2. Selection empty → `pointSizeValue` returns `.empty` → display falls back to
   the hardcoded `36` and `setPointSize` iterates an empty selection and
   returns early. A real second failure mode if the sheet is opened with
   nothing selected (the sheet does not currently say so).
3. Sheet presented from `ToolRailView`, which is itself inside the 150 ms
   re-render storm (**RC-1/bug 3**) — sheet identity churn could compound the
   staleness.

**(B) Three suggested remedies**

1. **Preferred — fix RC-1 at the source.** Make `MakhtootDocument`
   `@Observable` (or add an `@Observable` scene box that `CanvasSession` stores
   and mutates). Single change, fixes bugs 8–11, the Arrange toolbar in 16,
   the inspector panel, and lets all three polling loops be deleted.
2. **Tactical fallback** if touching `MKPersistence` is too invasive right now:
   add an `@Observable private(set) var sceneRevision: Int` stored property on
   `CanvasSession`, bumped in `perform(_:)`, and have views read it alongside
   the value (`_ = session.sceneRevision`). Ugly but surgical and testable.
3. Disable/empty-state the sheet when `pointSizeValue == .empty` so the
   no-selection case is honest instead of silently no-op.

**(C) Files touched**
- `MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift` (remedy 1)
- `MakhtootKit/Sources/MKCanvas/CanvasSession.swift` (`scene` accessor / revision counter)
- `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift`
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (delete `startModePolling`, `refreshUndoRedoState` mirror, zoom poll's observable write)
- `MakhtootKit/Tests/MKCanvasTests/InspectorModelTests.swift`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| **Highest-blast-radius change in this plan** — `MakhtootDocument` is the persistence spine, touched by autosave, journal, crash recovery, and sync | Land it alone, on its own branch, with the full `MKPersistenceTests` + `MKCanvasTests` suites green before anything else stacks on it |
| Making the scene observable could cause *over*-invalidation (whole-scene writes on every keystroke) | Text edits already coalesce per 700 ms burst; measure with `PerfHUDView` and the existing `debugMeasureManipulationFrames()` |
| Observation + `@MainActor` + the AsyncStream may now double-notify | Keep the stream for the CALayer path (it is not SwiftUI); only SwiftUI reads change |
| Deleting the polls removes an accidental safety net | Delete them one at a time, each with a manual smoke test of the paths their comments enumerate |

---

## Bug 9 — B/I/U/S buttons do nothing

**(A) Three possible causes**

1. ✅ **CONFIRMED — RC-1 for the *display*.** `isBold`/`isItalic`/`isUnderline`/
   `isStrikethrough` ([FontSettingsSheet.swift:38-56](Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:38))
   all read through `session.scene`. The toggle applies; the button's
   `isOn` styling never flips. Indistinguishable from "does nothing".
2. **Likely — the renderer may not apply the traits.** `setBold`/`setItalic`
   write to `MKTextStyle`, but Arabic faces overwhelmingly lack real bold/italic
   cuts. The sheet already computes `boldSupported`/`italicSupported` via
   `CTFontGetSymbolicTraits` and draws a strike-through when unsupported — so
   for most Arabic fonts **B and I are legitimately no-ops**, just without
   telling the user why.
3. Underline/strikethrough may have no drawing path in `LiveTextDrawer` —
   needs a targeted check (the same gap that is *confirmed* for
   `highlightColor` in bug 11).

**(B) Three suggested remedies**

1. Fix RC-1 (remedy 1 of bug 8) so the toggle state is visible.
2. Make the unsupported case explicit rather than silent: when
   `boldSupported == false`, disable the button and show a one-line
   explanation ("هذا الخط لا يوفّر وزنًا عريضًا") instead of only a red slash.
   Optionally offer synthetic emboldening via stroke, clearly labelled.
3. Verify and, if missing, implement underline/strikethrough painting in
   `LiveTextDrawer`/`PathTextDrawer` — and add SVG/PDF export parity so
   exports match the canvas.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift`
- `MakhtootKit/Sources/MKRender/Drawers/LiveTextDrawer.swift`, `PathTextDrawer.swift`
- `MakhtootKit/Sources/MKExport/SVGTextWriter.swift` (export parity)
- `MakhtootKit/Sources/MKCanvas/InspectorModel.swift`
- `MakhtootKit/Tests/MKRenderTests/`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Synthetic bold on Arabic script degrades joins and looks wrong | Prefer selecting a real bold family member; if synthesising, use stroke-based emboldening and cap the width, with a visible "محاكاة" label |
| Underline placement under Arabic descenders/marks is genuinely hard | Use the font's `underlinePosition`/`underlineThickness` metrics, not a hardcoded offset; add fixtures to `MKRenderTests` |
| Canvas/export divergence | Any trait added to the drawer must land in `SVGSerializer` in the same PR |

---

## Bug 10 — Text colour can't be set to anything other than black

**(A) Three possible causes**

1. ✅ **CONFIRMED — RC-1 for the swatch.** `currentTextColor` reads
   `inspector.fillValue` → `session.scene`. On `.empty`/`.mixed` it returns the
   hardcoded near-black `(0.114, 0.098, 0.086, 1)`
   ([FontSettingsSheet.swift:274](Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:274)),
   and it never re-reads after a change. So the swatch reads black forever
   regardless of what was picked.
2. **Likely co-cause — the custom picker's HSB state.** `MKColorPickerSheet`
   derives `saturation` from the *initial* colour: for near-black,
   `saturation = delta/maxC ≈ 0`. Saturation is `@State` but **has no UI
   control** — only hue and brightness sliders exist. With saturation stuck at
   ~0, moving hue does nothing and moving brightness only produces **greys**.
   That is literally "can't set anything other than black" (→ grey).
   Confirmed by reading the picker; the `saturation: Double = 0.7` default is
   overwritten in `init`.
3. `.solid` fill may not reach `LiveTextDrawer` for text nodes — less likely,
   since `addLiveTextAtCenter` deliberately sets a default ink fill via the
   same `setFill` primitive and the code comments say that made text visible.

**(B) Three suggested remedies**

1. Fix RC-1 so the swatch reflects reality.
2. **Fix the picker.** Add a saturation slider (or a proper 2-D
   saturation/brightness square), and never initialise saturation to 0 —
   clamp to a sensible floor when the source colour is neutral, exactly as
   `previousHue` already does for hue.
3. Simplest option: replace `MKColorPickerSheet` with SwiftUI's system
   `ColorPicker` (already used in `InspectorPanelView.swift:40`), plus a row of
   preset ink swatches. Less bespoke code, full-gamut, accessible, and free
   RTL/VoiceOver support.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift` (`MKColorPickerSheet`)
- `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` (align the two colour paths)
- `MakhtootKit/Sources/MKColor/` (if a shared picker lands there)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| The bespoke picker exists for a reason (brand/RTL/theme fit) — swapping to system `ColorPicker` may be rejected | Offer remedy 2 (fix in place) as the default and remedy 3 as the alternative; `InspectorPanelView` already ships the system picker, so precedent exists either way |
| `static var previousHue` on `MKColorPickerSheet` is shared mutable state across every instance | Move it to `@AppStorage` or an instance/environment value — it is a latent cross-sheet bug |
| P3 vs sRGB round-tripping through `CIColor` | The existing `resolvedRGBA` uses `CIColor` for cross-space safety; keep it and add a round-trip test |

---

## Bug 11 — Highlight colour can't be set (shows yellow but it's none)

**(A) Three possible causes**

1. ✅ **CONFIRMED — nothing renders highlights.** `MKTextStyle.highlightColor`
   exists (`MKTextStyle.swift:81`) and `InspectorModel.setHighlightColor`
   persists it, but `grep -rn "highlightColor" MakhtootKit/Sources/MKRender`
   returns **zero hits**. No drawer paints it. So even a successful pick is
   invisible on canvas — and invisible in export.
2. ✅ **CONFIRMED — the Inspector panel has no setter at all.**
   `InspectorPanelView.swift:87-97` renders the highlight as a read-only
   `Circle` + label with no button and no picker. Only the أء sheet can set it.
3. **The "shows yellow" report.** The `none` case shows a dashed circle in the
   sheet and `Color.gray.opacity(0.2)` in the inspector — neither is yellow.
   Most likely the *picker* opens showing a misleading colour: it is seeded
   with `(0.5, 0.5, 0.5, 0.3)`, whose neutral hue falls back to the shared
   `static previousHue` (default 0.5) with saturation 0 — combined with the
   yellow band of the hue strip under the knob. **This specific claim needs a
   device screenshot to confirm** rather than being asserted from source.

**(B) Three suggested remedies**

1. Implement highlight painting in `LiveTextDrawer`/`PathTextDrawer`
   (line-fragment rects behind the glyph runs) plus `SVGSerializer` export
   parity. Without this the feature cannot work at all.
2. Add a real setter row to `InspectorPanelView` (mirroring the fill
   `ColorPicker`) and a "بلا تظليل" / clear action in both places —
   `setHighlightColor` currently cannot express *nil*.
3. Fix the picker seeding (see bug 10 remedy 2) so the initial swatch honestly
   shows "no highlight" rather than an arbitrary hue.

**(C) Files touched**
- `MakhtootKit/Sources/MKRender/Drawers/LiveTextDrawer.swift`, `PathTextDrawer.swift`
- `MakhtootKit/Sources/MKExport/SVGSerializer.swift`
- `MakhtootKit/Sources/MKCanvas/InspectorModel.swift` (`setHighlightColor(_ color: MKSolidColor?)`)
- `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift`, `FontSettingsSheet.swift`
- `MakhtootKit/Tests/MKRenderTests/`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Highlight rects behind RTL/bidi runs and on curved path text are non-trivial | Ship live-text highlight first; explicitly defer path-text highlight and say so in the UI rather than shipping it broken |
| Highlight must paint *under* glyphs but *over* the background, interacting with z-order and transparency layers | Extend `SceneRenderer`'s existing transparency-layer handling; add fixtures |
| Widening `setHighlightColor` to optional is a public API change in `MKCanvas` | It is a source-compatible overload if added alongside; update `InspectorModelTests` |

---

## Bug 12 — "Install font" doesn't work; should move to Settings

**(A) Three possible causes**

1. **Most likely — silent failure.** `installFontSystemWide` is called with
   `try?`, discarding every error, and the row only refreshes
   `isFontSystemInstalled` afterwards
   ([FontSettingsSheet.swift:398-402](Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:398)).
   System-wide font installation requires `CTFontManagerRegisterFontsWithAssetNames`
   + a persistent-scope registration and **user confirmation via a system
   sheet**; any failure (entitlement, unsupported scope, sandbox) is swallowed
   with no message.
2. **Wrong placement, which the user already diagnosed.** It is a
   device-scoped, one-time, per-font action sitting inside a per-selection text
   formatting sheet, and it only appears at all when `currentFontID != nil`
   (i.e. a text node is selected) — so it is often simply absent.
3. Missing capability/`Info.plist` configuration for font provisioning.
   Needs verification against the target's entitlements.

**(B) Three suggested remedies**

1. **Move it to Settings.** Add a "الخطوط" section under
   `SettingsPlaceholderView` listing installed/available fonts with per-font
   install/uninstall — the correct home for a device-wide action, and it pairs
   naturally with the font *import* feature from bug 18.
2. Stop swallowing errors: surface `MKFontError` in an alert, show a progress
   state during registration, and log the failure. Right now a failed install
   and a successful one look identical.
3. Verify the registration scope and entitlements end-to-end; add a
   `MKFontRegistryTests` case asserting the error surface (the module already
   has `MKFontErrorTests` and `MKFontRegistryTests` to extend).

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift` (remove the section)
- `Makhtoot/AppShell/Scenes/Settings/SettingsPlaceholderView.swift` (new section)
- `Makhtoot/AppShell/Scenes/Settings/` (new `FontsSettingsView.swift`)
- `MakhtootKit/Sources/MKFonts/MKFontRegistry.swift` (error surfacing)
- `Makhtoot/Config/Info.plist` / entitlements
- `MakhtootKit/Tests/MKFontsTests/MKFontRegistryTests.swift`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| System-wide font install may not be permitted for this app's entitlements at all | Determine this **first**; if unavailable, remove the affordance rather than leaving a button that cannot work |
| Font licences may forbid device-wide installation | The repo already has `FontLicenseAuditTests` and `MKLicensingDataSource` — gate the install action on the licence record |
| Moving the row is a discoverability regression for anyone who found it | Leave a "إدارة الخطوط…" link in the أء sheet that deep-links to the Settings section |

---

# + (add) menu

## Bug 13 — Can't add any shape

**(A) Three possible causes**

1. ✅ **CONFIRMED — the shape is created 1 pt × 1 pt.** `ShapeDrawer` paints
   **unit-square geometry** and relies on `core.transform.scale` to size it —
   its own comment says so:
   > `node.core.transform.scale` is EXACTLY the factor `SceneRenderer`
   > concatenated onto `ctx` to turn this drawer's unit-square geometry into
   > the shape's real on-canvas box size
   ([ShapeDrawer.swift:27-30](MakhtootKit/Sources/MKRender/Drawers/ShapeDrawer.swift:27))

   But `addRectangleAtCenter()` builds the node with
   `MKTransform2D(position: point)` and **never sets `scale`**
   ([EditorViewModel.swift:625](Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift:625)).
   `MKTransform2D`'s default is `CGSize(width: 1, height: 1)`
   ([MKTransform2D.swift:21](MakhtootKit/Sources/MKFoundation/Geometry/MKTransform2D.swift:21)).
   Result: a **one-point** dark-red rectangle at the canvas centre — added,
   selected, and effectively invisible at fit-zoom.
2. Menu offers exactly one shape ("شكل" → rectangle) despite the model
   supporting `ellipse`, `line`, `polygon`, `path`, and `asset`. Even once
   sizing is fixed, "can't add any shape" partly means "can't add *the* shape
   I want".
3. `.asset` geometry is unimplemented in the renderer (`ShapeDrawer.swift:17`
   records a substitution and draws nothing) — so any asset-backed shape from
   `MKAssets` silently no-ops today.

**(B) Three suggested remedies**

1. **Preferred, one line.** Set a real default size:
   `MKTransform2D(position: anchored, scale: CGSize(width: 120, height: 120))`,
   and anchor by half that. Verify against `MKArrangeTests`/`MKRenderTests`
   fixtures that assume unit geometry.
2. Replace the single "شكل" item with a shape submenu (rectangle, ellipse,
   line, triangle/polygon) matching `MKShapeGeometry`, each with a sensible
   default size — the model and hit-tester already support all of them.
3. Wire `.asset` geometry to the `MKAssets` vector program so the built-in
   ornament/frame library (which has an extensive test suite already) becomes
   reachable from the UI.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`addRectangleAtCenter` → `addShape(_:)`)
- `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift` (submenu)
- `MakhtootKit/Sources/MKCanvas/CanvasContentAPI.swift` (a `size:` parameter, so the default lives with the API not the caller)
- `MakhtootKit/Sources/MKRender/Drawers/ShapeDrawer.swift` (remedy 3)
- `MakhtootKit/Tests/MKCanvasTests/CanvasContentAPITests.swift`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Other call sites may already compensate for unit-sized shapes; changing the default could double-scale them | `addShape` currently has exactly one production caller — check `MKArrangeTests`/`MKRenderTests` fixtures before changing the default |
| A 120 pt default is wrong for very small or very large canvases | Scale the default off `min(canvas.width, canvas.height)`, as `addPathText` already does with `shortSide` |
| Stroke width compensation depends on `transform.scale` | `MKStylePainting.paint(strokeWidthCompensationScale:)` already handles this; verify with a non-1 scale fixture |

---

## Bug 14 — Can't add any tashkeel

**(A) Three possible causes**

1. ✅ **CONFIRMED — the menu item is a copy-paste stub.**
   ```
   ToolRailView.swift:58-60
       Button(addTextFieldLabel) { viewModel.addLiveTextAtCenter() }
       Button(addShapeLabel)     { viewModel.addRectangleAtCenter() }
       Button(addTashkeelLabel)  { viewModel.addLiveTextAtCenter() }   // ← identical to "حقل نص"
   ```
   "تشكيل" does exactly what "حقل نص" does: inserts an empty text field. There
   is no tashkeel picker, no diacritic palette, no insertion logic.
2. Tashkeel arguably belongs in the *text editing* flow (insert a diacritic at
   the caret in the active overlay), not as a standalone canvas object — so the
   menu placement itself may be the design error.
3. The Arrange-mode machinery *does* model marks properly
   (`MarkAttachmentController`, `pendingMarkReattachID`, R-7.5 "attach to
   letter"), so the engine capability exists — only the authoring UI is absent.

**(B) Three suggested remedies**

1. **Preferred.** Add a tashkeel palette (fatha, damma, kasra, sukun, shadda,
   tanween ×3, madda, hamza forms) as an input accessory in the text-edit
   overlay, inserting the character at the caret. This is what users actually
   mean by "add tashkeel".
2. Keep a canvas-level entry too: insert a standalone mark node and arm the
   existing R-7.5 "attach to a letter" flow (`pendingMarkReattachID`) so it can
   be attached to a glyph in Arrange Mode. The plumbing is already built and
   tested.
3. Short term, if neither ships this cycle: **remove the menu item.** A button
   that silently does the wrong thing is worse than no button.

**(C) Files touched**
- `MakhtootKit/Sources/MKCanvas/TextEditingOverlay.swift` (accessory palette)
- `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift`
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`insertTashkeel(_:)`)
- `MakhtootKit/Sources/MKTextEngine/` (mark shaping is already covered by `MarkAttachmentTests`)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Inserting a combining mark with no preceding base character produces a dotted-circle fallback | Disable palette entries when the caret has no valid base; `JoiningAnalyzer`/`MarkAttachmentTests` already model this |
| Marks must survive shaping, arrange derivation, and export | Extend `MKTextEngineTests/MarkAttachmentTests` and add an export fixture |
| Palette competes with the "تم" toolbar for accessory space | Two-row accessory, or a segmented accessory with a toggle |

---

## Bug 15 — Text on shape is very buggy

**(A) Three possible causes**

1. **Most likely — this is Path Text, and the presets place geometry in absolute
   canvas coordinates while the node's transform is left at `.zero`.**
   `addPathText` builds `BezierPathModel` presets from absolute canvas points
   and inserts at `at: .zero`
   ([EditorViewModel.swift:738-754](Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift:738)).
   The code comments argue this is correct because `PathTextDrawer` ignores
   `core.transform.position`. But that means **moving a path-text node via the
   inspector or a drag gesture cannot work** — the drawer never reads the
   position the gesture writes. That is a textbook "very buggy" symptom
   (selection chrome moves, glyphs don't).
2. **RC-1 again.** `PathOptionsPopoverView` and `PathEditToolbarView` gate on
   `pathTextInteraction.isActive` and other `session.scene`-derived state →
   stale/disabled controls, same as the Arrange toolbar.
3. Path-edit chrome is drawn in `MKCanvas` (`PathEditChromeLayer`) while the
   ghost guide is drawn in **SwiftUI** (`PathGhostGuideOverlay`), in two
   different coordinate systems with two different zoom responses — a likely
   source of visible drift between handles and glyphs.

**(B) Three suggested remedies**

1. **Diagnose precisely before fixing.** This report is the least specific of
   the eighteen. Capture concrete repro steps (which preset, which gesture,
   what was expected). `MKPathTextTests` and `MKCanvasTests/PathTextInteractionModelTests`
   are extensive — a failing case there is the fastest route to a real fix.
2. Make path text obey `core.transform` like every other node: store the path
   in **local** space and apply the node transform in `PathTextDrawer`, so
   move/rotate/scale work uniformly. This is the structural fix behind cause 1.
3. Unify the chrome: draw the ghost guide in the same `PathEditChromeLayer`
   coordinate space as the anchors (with an explicit never-in-export flag)
   instead of the parallel SwiftUI overlay.

**(C) Files touched**
- `MakhtootKit/Sources/MKRender/Drawers/PathTextDrawer.swift`
- `MakhtootKit/Sources/MKPathText/` (`BezierPathModel`, `PathLayoutEngine`)
- `MakhtootKit/Sources/MKCanvas/PathText/PathEditChromeLayer.swift`
- `Makhtoot/AppShell/Scenes/Editor/PathGhostGuideOverlay.swift`, `PathOptionsPopoverView.swift`, `PathEditToolbarView.swift`
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`addPathText`)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Moving path text to local space is a **document-format migration** — existing projects store absolute paths | Version the scene format and migrate on open; `MKPersistence` already has journal/recovery infrastructure |
| Path text has the largest test surface in the repo (`MKPathTextTests`, `WS16CursiveTests`) | Treat any red test as a blocker, not a fixture to update, until the change is understood |
| Without a concrete repro, effort may go to the wrong defect | **Do not start this one until step 1 (repro capture) is done** — it is the only item here I would not fix from source-reading alone |

---

## Bug 16 — The wand freezes the app and none of its buttons work

**(A) Three possible causes**

1. ✅ **CONFIRMED (freeze) — glyph derivation runs on the main thread.**
   `MKArrangeInteractionAdapter` is `@MainActor`
   ([MKArrangeInteractionAdapter.swift:20](Makhtoot/AppShell/Scenes/Editor/MKArrangeInteractionAdapter.swift:20)).
   Its `deriveArrangeCommand` awaits `shapingService.captureResult` (a true
   `actor`, so that hops off) and then calls
   `deriver.derive(...)` — but `ArrangeDeriver` is a plain
   `struct ArrangeDeriver: Sendable` with no actor isolation, so **it inherits
   the caller's `@MainActor` context** and runs full CoreText shaping plus
   per-glyph outline extraction **synchronously on the main thread**. For any
   non-trivial string that is a visible hang.
2. ✅ **CONFIRMED (dead buttons) — RC-1.** Every `ArrangeToolbarView` gate —
   `viewModel.canBreakOrRestoreJoinForSelection`, `canDecomposeSelection`,
   `interaction.granularity`, `activeOwnerNode` — resolves through
   `session.scene`, which is unobservable. The toolbar renders once with
   nothing selected, every button computes `disabled: true`, and it **never
   re-evaluates**. Buttons stay permanently greyed at `.opacity(0.4)`.
3. Entry preconditions fail silently. `enterArrangeMode` has four separate
   early `return`s (no node, no engine, derive returned nil, unsupported node
   kind) that set `lastErrorMessage` — and `lastErrorMessage` is **never
   displayed anywhere in the UI**. So "nothing happened" is indistinguishable
   from "it refused".

**(B) Three suggested remedies**

1. **Move derivation off the main actor.** Make `ArrangeDeriver` an `actor`, or
   run `derive` in a detached task and await the result — `MKShapingService` is
   already an actor, so the pattern exists in-repo. Add a progress/blocking
   indicator for large compositions, and a size guard that warns before
   arranging very long strings.
2. Fix RC-1 (bug 8, remedy 1) so the toolbar's `can…` gates re-evaluate.
   Nothing else will make those buttons usable.
3. Surface `lastErrorMessage` — the strings already exist
   (`arrangeEngineUnavailableMessage`, `deriveFailedMessage`) and are simply
   never rendered. A toast or inline banner turns three silent failure modes
   into diagnosable ones.

**(C) Files touched**
- `MakhtootKit/Sources/MKArrange/ArrangeDeriver.swift` (actor isolation)
- `Makhtoot/AppShell/Scenes/Editor/MKArrangeInteractionAdapter.swift`
- `MakhtootKit/Sources/MKCanvas/Arrange/MKArrangeInteractionModel.swift` (error surfacing)
- `Makhtoot/AppShell/Scenes/Editor/ArrangeToolbarView.swift`, `EditorScene.swift` (banner)
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`
- `MakhtootKit/Tests/MKArrangeTests/`, `MKCanvasTests/ArrangeInteractionModelTests.swift`

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| `MKPathTextInteractionAdapter` almost certainly has the identical main-actor problem | Audit and fix both in the same pass; the freeze will otherwise just move to the path-text button |
| Making the deriver an actor may expose data races currently masked by main-actor serialisation | Build with strict concurrency; `MKArrangeTests/DerivationFidelityTests` guards output equivalence |
| A long-running derive now needs cancellation (user taps the wand twice) | Store the `Task` on the interaction model and cancel the prior one on re-entry |
| Arrange Mode is the app's flagship feature — regressions here are expensive | Land behind the existing `-mkE2EArrangeDrive` launch-arg harness and re-run the full drive before/after |

---

# Settings

## Bug 17 — Can't change the app icon

**(A) Three possible causes**

1. ✅ **CONFIRMED — not implemented.** `grep -rn "setAlternateIconName\|CFBundleAlternateIcons"`
   over the entire repo returns **nothing**. There is no alternate-icon UI, no
   alternate icon assets, and no `Info.plist` declaration.
2. Assets exist but aren't declared in `CFBundleAlternateIcons` — ruled out;
   there are no alternate icon assets either.
3. Would be a premium gating question once built — not currently a cause.

**(B) Three suggested remedies**

1. **Preferred.** Ship 3–5 alternate icons (one per design-system theme —
   the repo already has a themes system and a `BrandMark` component from commit
   `5134d73`), declare them under `CFBundleAlternateIcons`, and add a picker
   row in `GeneralSettingsView` calling
   `UIApplication.shared.setAlternateIconName(_:)`.
2. Gate the extra icons as a premium perk, reusing the
   `entitlementProvider` + `presentPaywall` pattern already used for export
   formats.
3. If icons won't ship this cycle, ensure Settings does not advertise the
   option at all.

**(C) Files touched**
- `Makhtoot/Config/Info.plist` (`CFBundleIcons` / `CFBundleAlternateIcons`)
- `Makhtoot/Resources/Assets.xcassets` (icon sets — must be top-level `.png` files, **not** in an asset catalog `AppIcon` set, for alternate icons)
- `Makhtoot/AppShell/Scenes/Settings/GeneralSettingsView.swift`
- `Makhtoot/AppShell/AppContainer.swift` (if persisting the choice)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Alternate icons have strict, easy-to-get-wrong packaging rules (loose files at the bundle root, exact naming, every @2x/@3x size) | Verify on a real device, not just the simulator; a wrong name fails silently returning an error to the completion handler |
| `setAlternateIconName` shows a **system alert the app cannot suppress** | Expected iOS behaviour; explain it in the picker copy |
| Icon changes are lost/odd during App Store review or on restore | Persist the selection and reapply on launch if `alternateIconName` drifts |

---

## Bug 18 — No way for premium users to import fonts

**(A) Three possible causes**

1. ✅ **CONFIRMED — the engine exists, the UI does not.**
   `MKFontImporter` is a full `public actor` with
   `importFont(from:originalFilename:) async throws -> MKFontID`
   ([MKFontImporter.swift:36](MakhtootKit/Sources/MKFonts/MKFontImporter.swift:36)),
   backed by `MKFontImporterTests`, `MKFontValidatorTests`, and
   `MKFontStorageManagerTests`. The **only** reference to it from `Makhtoot/`
   is a passing mention inside a code comment in `RootShellView.swift:84`.
   There is no `.fileImporter` anywhere in the app.
2. Entitlement gating hiding an existing entry point — ruled out; there is no
   entry point to hide.
3. Font licence/validation blocking imports at runtime — not reachable, since
   nothing calls the importer.

**(B) Three suggested remedies**

1. **Preferred.** Add a "الخطوط" section to Settings (the same section bug 12
   wants) with an "استيراد خط" row opening a `.fileImporter` for
   `[.font, UTType("public.truetype-font"), UTType("public.opentype-font")]`,
   wired to `MKFontImporter.importFont`. Gate on
   `isEntitled(.premiumFonts)` with the standard paywall fallback.
2. Surface imported fonts in `FontBrowserSheet` under a "خطوطي" section,
   with delete/re-validate actions, and show `MKFontValidator` failures
   explicitly instead of `try?`-swallowing them.
3. Also accept fonts via the share sheet / "Open in Makhtoot" so a font
   emailed or AirDropped to the user imports in one step.

**(C) Files touched**
- `Makhtoot/AppShell/Scenes/Settings/` (new `FontsSettingsView.swift`)
- `Makhtoot/AppShell/Scenes/Settings/SettingsPlaceholderView.swift`
- `Makhtoot/AppShell/Scenes/Editor/FontBrowserSheet.swift`
- `Makhtoot/AppShell/AppContainer.swift` (expose `MKFontImporter`)
- `Makhtoot/Config/Info.plist` (`CFBundleDocumentTypes` for remedy 3)
- `MakhtootKit/Sources/MKFonts/MKFontRegistry.swift` (refresh after import)

**(D) Risks & mitigation**
| Risk | Mitigation |
|---|---|
| Users import licence-restricted fonts and then export commercially | `MKLicensingDataSource` + `FontLicenseAuditTests` already exist — record imported fonts as "user-supplied, licence unknown" and show that in `LicensingView` |
| Malformed/hostile font files | `MKFontValidator` is already written and tested — make it a hard gate, and surface its errors rather than `try?` |
| Security-scoped URLs from `.fileImporter` expire | Copy into the app's font store inside the `startAccessingSecurityScopedResource` bracket — check `MKFontStorageManager` already does this |
| Imported fonts must survive iCloud sync and appear on other devices | Decide explicitly (sync the file, or mark projects using it as needing the font) and reuse the existing `isOrphaned` pattern from the project browser |

---

# Recommended sequencing

| Phase | Work | Why first |
|---|---|---|
| **0** | Capture a real repro for bug 15 (text-on-shape) | The only item that can't be fixed from source-reading; do it before allocating effort |
| **1** | **RC-1** — make the scene observable | Unblocks bugs 8, 9, 10, 11, 16(buttons), and the inspector. Highest risk; land it alone with full suites green |
| **2** | Cheap, isolated correctness fixes: zoom-poll guard (3), pill centring (4), zoom-control surface (7), shape default size (13) | Four visible wins, tiny diffs, near-zero risk |
| **3** | Keyboard/overlay: tap-outside + scroll-to-visible (5, 6) | Self-contained in `MKCanvas`, high daily-use impact |
| **4** | Arrange derivation off the main actor + error surfacing (16) | Flagship feature; needs phase 1 landed first |
| **5** | Renderer gaps: highlight painting (11), traits (9) | Model → renderer → export, in that order, with parity tests |
| **6** | New features: thumbnails (1), background import (2), font import + install relocation (12, 18), tashkeel (14), app icon (17) | Additive; can proceed in parallel once phases 1–2 are stable |
| **7** | Path-text structural work (15) | Format migration — only after a confirmed repro and with the most test coverage in the repo behind it |

## What I did not verify

- The exact "shows **yellow**" appearance in bug 11 (source says grey/dashed —
  needs a device screenshot).
- Whether zoom taps are *lost* or *land-and-no-op* (bug 3, causes 1/2 vs 3) —
  one `#if DEBUG` log run settles it.
- Whether underline/strikethrough have drawing paths (bug 9, cause 3) — only
  `highlightColor` was confirmed to have none.
- No build or test run was performed as part of this triage.
