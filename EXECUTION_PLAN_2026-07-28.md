# Makhtoot — Execution Plan (2026-07-28)

Source: `AUDIT_2026-07-28.md` + verified finding data, repo `main` @ `ac17a23`.
This document defines the execution sequence. Each numbered Wave is one
Workflow invocation spawning one batch of parallel agents. Agents within a wave run
concurrently and **must never write the same file**. Waves run in order; each ends with a
gate (verify commands + one commit) before the next wave starts.

All 44 audit findings are scheduled exactly once: 34 execute across Waves 0–4, 10
(`Approval: Yes`) are decision packets in Wave 5 and do not execute in this plan.

## Ground rules

1. **Ownership exclusivity.** Every agent's "Owns" list is the *exhaustive* set of files it may
   write. Touching anything else — including a sibling agent's owned file — is a plan violation.
   "Reads" files are for context only.
2. **No cross-wave dependencies inside a wave.** If finding B needs finding A's result, A's wave
   must complete (and gate) before B's wave starts. `P-9` waits on `P-2` (Wave 2 → Wave 3);
   `FC-1`/`FC-7` wait on `FC-6` (Wave 0 → Wave 1/5).
3. **Test command — non-negotiable.** `swift test` (bare, parallel) deadlocks on concurrent
   CoreText font-fallback resolution and hangs 10–23 minutes at 0% CPU. Always:
   ```bash
   cd MakhtootKit && swift test --no-parallel
   ```
   Run `ps aux | grep swift-test` before starting any verification run — orphaned hung
   processes from a prior mistake must be killed first. Never run `swift test` concurrently
   with `xcodebuild`.
4. **App-target changes have no unit-test target** until Wave 0 lands FC-6's `MakhtootUITests`.
   Before that exists, app-layer changes (`Makhtoot/AppShell/**`) are verified by `xcodebuild
   build` (compiles) plus the manual check stated per-agent. After Wave 0, prefer the new
   UI-test target where a case exists.
5. **One commit per wave**, after its gate passes. Never leave `main` red — if a wave's gate
   fails, fix within that wave's scope before committing; do not carry a broken build into the
   next wave.
6. **Approval wave is a gate, not a task.** Wave 5 items do not touch files in this plan. Do not
   let any earlier wave depend on a Wave 5 outcome.

## At-a-glance wave table

| Wave | Theme | Agents | Findings |
|---|---|---|---|
| 0 | Premise re-verification + FC-6 safety net | 2 | FC-6, FC-9 (+ re-check P-7, UX-5, UX-8, FC-4 premises) |
| 1 | Critical revenue + persistence-safety fixes | 5 | FC-1, FC-2, P-4, S-5, UX-4, P-1, P-6, P-7, S-2, S-6, S-7, S-1, S-3, S-4 |
| 2 | Canvas/memory perf, font pipeline, error surfacing | 4 | P-2, P-3, P-5, UX-3, P-8, FC-3, S-8, S-9, EU-9, UX-5 |
| 3 | Deferred perf, accessibility/design sweep, nav state | 3 | P-9, UX-2, UX-6, UX-7, UX-8, EU-3, EU-7 |
| 4 | Export UX overhaul | 1 | EU-4 |
| 5 | Approval gate — founder decisions | — | UX-1, EU-1, EU-2, EU-5, EU-6, EU-8, FC-4, FC-5, FC-7, FC-8 |

---

## Wave 0 — Premise verification + safety net

Read-only / test-infrastructure only. No source-code behavior changes.

### Wave 0 · Agent 0.1 — Premise re-verification (read-only)
- **Findings:** FC-9 (verification only, no fix due), plus four findings this plan independently
  re-verified against current source, correcting the audit's scope: P-7, UX-5, UX-8, FC-4.
- **Owns (exclusive write set):** none — this agent is read-only.
- **Reads:** `MakhtootKit/Sources/MKPersistence/AssetStore.swift`, `MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift`, `MakhtootKit/Sources/MKPersistence/AutosaveController.swift`, `Makhtoot/AppShell/Scenes/Settings/SyncSettingsView.swift`, `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift`, `MakhtootKit/Sources/MKSync/Engine/MKSyncEngineController.swift`, `Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift`, `MakhtootKit/Sources/MKExport/SVGTextWriter.swift`, `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`, `Scripts/check-localization.sh`, `.github/workflows/ci.yml`
- **Do:**
  1. **P-7** (independently re-verified — real defect is worse than the audit's fix scope): confirm
     `MakhtootDocument.swift` lines ~114/169/180 still hardcode `referencedAssets: []` /
     `referencedAssetsProvider: { [] }`, so `AssetStore.sweepOrphans` never fires in production.
     Note this as the actual scope for Wave 1's persistence agent (wire real refs, not just
     fix the sweep body).
  2. **UX-5** (independently re-verified — sync errors are *already* partly surfaced, narrowing
     the audit's fix scope): confirm
     `SyncSettingsView.swift:~70` renders `globalState.localizedMessage` live, and
     `ProjectBrowserView.swift:~517-530` renders a per-project sync badge via
     `MKSyncStatusAdapter.badge(for:)`. Confirm only `MKSyncError.zoneNotFound` reaches the
     *global* state (`MKSyncEngineController.swift:~242`) — other error kinds only reach
     `publishProjectStatus`. Feed this corrected scope to Wave 2's UX-5 agent.
  3. **UX-8** (independently re-verified — a percentage `Text` badge already exists, narrowing
     the audit's fix scope):
     confirm `ZoomControlsView.swift:23` renders `Text(percentageText)` with no
     `.accessibilityElement(children: .combine)` suppressing it, so VoiceOver already reaches the
     value; the real gap is no `.accessibilityValue` on the +/− buttons themselves. Feed to
     Wave 3's design-sweep agent.
  4. **FC-4** (independently re-verified — SVG bold/italic embedding is currently unreachable):
     confirm every production `MKExportCoordinator(assets: assetProvider)` construction in
     `EditorViewModel.swift` (currently lines ~520,541,561) omits `fontData:`, so
     `MKNoFontDataProviding` is always used and `SVGTextWriter.swift:201`'s FIXME is dead code
     today. Also confirm `SVGSerializer.swift`'s emoji/placeholder-geometry branch already emits
     a `FallbackNote(reason: .colorGlyphRasterized)` — the audit's "silent" framing is wrong; the
     real defect is the note's Arabic wording claims rasterization ("تم تصدير الرمز التعبيري كصورة
     نقطية") for a branch that emits vector placeholder geometry. This is evidence to record, not
     a fix to apply here — feed it, along with the embedding-wiring scope, to Wave 5's FC-4
     decision packet, where the wording correction is pre-staged as piece (1) of that packet
     (it changes founder-authored user-facing Arabic, so it needs sign-off like the rest of this
     finding).
  5. **FC-9** (independently re-verified — largely already shipped): confirm
     `Scripts/check-localization.sh` exists and is wired at `.github/workflows/ci.yml:37-38`.
     Run it (see Verify). No fix is due; this closes the finding.
- **Verify:**
  - `grep -n 'referencedAssets' MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift`
  - `grep -n 'globalState.localizedMessage' Makhtoot/AppShell/Scenes/Settings/SyncSettingsView.swift`
  - `bash Scripts/check-localization.sh` → expect exit 0, "1 (baseline 1)" or current baseline
  - `grep -n 'fontData:' Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` → expect zero
    non-default hits
- **Done when:** all four checks above produce the stated evidence and the corrected scopes are
  understood by whoever executes Waves 1/2/3/5 (this document already encodes them).
- **Do not:** write any files at all — this agent produces confirmations only, no fixes. The
  `FallbackNote`/`SVGSerializer.swift` wording correction is a founder call (it changes
  user-facing Arabic), pre-staged in Wave 5's FC-4 decision packet, not something this agent
  touches.

### Wave 0 · Agent 0.2 — FC-6: UI test target + composition-root safety net
- **Findings:** FC-6
- **Owns (exclusive write set):**
  - `Makhtoot.xcodeproj/project.pbxproj`
  - `Makhtoot.xcodeproj/xcshareddata/xcschemes/Makhtoot.xcscheme`
  - `MakhtootUITests/OnboardingFirstProjectUITests.swift` (new)
  - `MakhtootUITests/InsertTextCommitUITests.swift` (new)
  - `MakhtootUITests/ArrangeModeEnterExitUITests.swift` (new)
  - `MakhtootUITests/PremiumExportPaywallGateUITests.swift` (new)
  - `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift` (new)
  - `MakhtootUITests/CompositionRootWiringTests.swift` (new)
- **Reads:** `Makhtoot/AppShell/Composition/AppContainer.swift` (or equivalent composition root), `docs/BUILD.md`
- **Do:**
  1. Add a new `PBXNativeTarget` to `project.pbxproj`, product-type
     `com.apple.product-type.bundle.ui-testing`, named `MakhtootUITests`, hosted by the
     `Makhtoot` app target. Do this with a short Ruby script against the installed `xcodeproj`
     gem (`gem list xcodeproj` confirms 1.28.1 is present) — open the project, add a
     `.ui_testing` native target hosted by `Makhtoot`, wire its build phases and register each
     new file's reference, then save. Do not hand-edit `project.pbxproj` text directly; the
     isa-graph (PBXNativeTarget/PBXBuildFile/PBXFileReference/XCConfigurationList) is too easy to
     leave internally inconsistent by manual text edit. If the resulting project fails to open
     (`xcodebuild -list` errors) or fails to build for pbxproj-structural reasons (not code
     reasons) even after using the gem, stop and report — do not attempt further manual patches.
  2. Wire the new target into the `Makhtoot` scheme's `TestAction` (edit
     `Makhtoot.xcodeproj/xcshareddata/xcschemes/Makhtoot.xcscheme` directly — it's a plain XML
     plist, safe to hand-edit; add a `TestableReference` entry for `MakhtootUITests`).
  3. Write `CompositionRootWiringTests.swift` first — this is the regression net Wave 1's FC-1
     fix must satisfy: assert `AppContainer.fontProvider` is not the default stub and (once FC-1
     lands) that it actually reaches `EditorViewModel`. If `AppContainer.fontProvider` isn't
     reachable from a UI test process, assert indirectly: launch the app, insert bold text, and
     compare rendered glyph pixels against the non-bold twin (XCUIScreenshot diff or
     accessibility-frame width comparison).
  4. Write the remaining four flow tests per the audit's stated scope: onboarding → first
     project creation; insert-text-then-commit; enter/exit Arrange Mode; premium-export paywall
     gate.
- **Verify:**
  - `xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:MakhtootUITests/OnboardingFirstProjectUITests -only-testing:MakhtootUITests/InsertTextCommitUITests -only-testing:MakhtootUITests/ArrangeModeEnterExitUITests -only-testing:MakhtootUITests/PremiumExportPaywallGateUITests -only-testing:MakhtootUITests/MakhtootFileOpenInPlaceUITests`
  - Confirm the target builds and these 5 flow tests execute and pass.
  - Separately, run `xcodebuild ... test -only-testing:MakhtootUITests/CompositionRootWiringTests`
    informationally — it is expected RED until Wave 1's FC-1 fix lands; note this explicitly in a
    comment atop that file and do not treat its failure as blocking this wave's gate.
- **Done when:** `MakhtootUITests` target exists, builds, and runs under `xcodebuild test`; the
  6 files above exist with the stated assertions.
- **Do not:** touch `Makhtoot/AppShell/**` source files. Do not attempt to make
  `CompositionRootWiringTests` pass in this wave — that requires Wave 1's fix.

### Wave 0 gate
```bash
cd MakhtootKit && swift test --no-parallel
cd .. && xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'generic/platform=iOS Simulator' build
# Pass/fail gate: the 5 flow tests only. CompositionRootWiringTests is excluded here — it is
# expected RED until Wave 1's FC-1 fix lands (see Agent 0.2's Verify step for its informational run).
xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:MakhtootUITests/OnboardingFirstProjectUITests -only-testing:MakhtootUITests/InsertTextCommitUITests -only-testing:MakhtootUITests/ArrangeModeEnterExitUITests -only-testing:MakhtootUITests/PremiumExportPaywallGateUITests -only-testing:MakhtootUITests/MakhtootFileOpenInPlaceUITests
git add Makhtoot.xcodeproj/project.pbxproj Makhtoot.xcodeproj/xcshareddata/xcschemes/Makhtoot.xcscheme MakhtootUITests/
git commit -m "Wave 0: land MakhtootUITests target + composition-root safety net (FC-6); re-verify P-7/UX-5/UX-8/FC-4/FC-9 premises"
```

---

## Wave 1 — Critical revenue + persistence-safety fixes

### Wave 1 · Agent 1.1 — Export & font correctness core
- **Findings:** FC-1, FC-2, P-4, S-5, UX-4
- **Owns (exclusive write set):**
  - `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`
  - `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift`
  - `MakhtootKit/Sources/MKCanvas/Gestures/GestureCoordinator.swift`
  - `MakhtootKit/Sources/MKCanvas/GuideRenderer.swift`
  - `MakhtootKit/Sources/MKPersistence/ExportTempDirectory.swift` (new)
  - `MakhtootKit/Tests/MKPersistenceTests/ExportTempDirectoryTests.swift` (new)
  - `MakhtootKit/Tests/MKExportTests/ExportCoordinatorTests.swift`
  - `MakhtootKit/Tests/MKCanvasTests/MKCanvasHapticsTests.swift` (new)
- **Reads:** `MakhtootKit/Sources/MKExport/ExportCoordinator.swift`, `MakhtootKit/Sources/MKExport/ExportGate.swift`, `MakhtootKit/Sources/MKExport/ExportRequest.swift`, `MakhtootKit/Sources/MKFonts/MKFontProviding.swift`, `Makhtoot/AppShell/Composition/AppContainer.swift`, `MakhtootKit/Sources/MKRender/SnapshotRenderer.swift`
- **Do:**
  1. **FC-1 — font provider wiring.** Add `fontProvider: any MKFontProviding` to
     `EditorViewModel.init` (currently `~line 170`); store it. Replace all seven
     `SystemFontStubProvider()` literals inside `EditorViewModel.swift` (currently lines 183,
     189, 235, 480, 497, 657, 1685) with the stored property. Update the sole call site,
     `EditorScene.swift:~49`, to pass `fontProvider: container.fontProvider`.
  2. **FC-2 + P-4 — route JPEG/PNG sharing through the gate.** Rewrite `exportForSharing()`
     (`~479-490`) and `exportPNGForSharing()` (`~496-508`) to build an `MKExportRequest` and call
     `MKExportCoordinator(assets: assetProvider, fonts: fontProvider).export(...)`, mirroring
     `exportPDFRasterForSharing`'s already-shipped free-tier pattern for JPEG and
     `exportSVGForSharing`'s premium pre-check + paywall pattern for PNG (`MKExportFormat
     .isFreeTierFormat` marks `.jpeg` free, `.pngOpaque`/`.pngAlpha` premium — do not treat them
     identically). **Do not** route these through a raw `.custom(pixelSize: canvasSize)` target —
     `MKExportGate.evaluate`'s `.custom` case unconditionally blocks free users
     (`ExportGateTests.swift:~102-104`). Instead give JPEG sharing a free-tier-eligible
     `.preset` target (mirror `exportPDFRasterForSharing`'s `"social.square"` preset pattern) so
     free users keep working JPEG export without touching `ExportGate.swift`. Both methods gain
     an `entitlement: any MKEntitlementProviding` parameter; update their two call sites in
     `EditorScene.swift` (`~574`, `~579`) to pass `entitlement: container.entitlementProvider`,
     and add the same pre-check + `nav.presentPaywall(.premiumFeatureTap(.exportFormat))` pattern
     the PNG-adjacent premium buttons already use for PNG specifically.
  3. **FC-1 continued.** At the three existing `MKExportCoordinator(assets: assetProvider)`
     construction sites for SVG/PDF-vector/PDF-raster (`~520,541,561`), add an explicit
     `fonts: fontProvider` argument. For every raster-format export path (pdfRaster today;
     jpeg/pngOpaque/pngAlpha after step 2), also pass
     `renderer: MKSnapshotRenderer(fonts: fontProvider, assets: assetProvider)` explicitly — the
     coordinator's own default `renderer: MKSnapshotRenderer()` independently defaults to
     `SystemFontStubProvider()` **and** `MKEmptyAssetProvider()`, so without this,
     `exportPDFRasterForSharing()` silently drops background images today, a bug this wiring
     also fixes.
  4. **S-5 — export temp files never cleaned up.** Create
     `MakhtootKit/Sources/MKPersistence/ExportTempDirectory.swift`: a small type exposing
     `urlForExport(ext:) -> URL` (writes into a dedicated `tmp/MKExports/` subdirectory, not bare
     `temporaryDirectory`) and `purge()`. Route `exportForSharing()`/`exportPNGForSharing()`'s
     (and the other three export methods') temp-file writes through it. Call `purge()` at editor
     close (`EditorViewModel.close()`) and once at app launch (call site inside
     `EditorViewModel` init or a hook it exposes — do not touch launch code outside this file's
     scope).
  5. **UX-4 — haptics.** Add `UISelectionFeedbackGenerator` firing from
     `GestureCoordinator`'s `onSelectionChromeNeedsUpdate` call sites (selection change). Add
     `UIImpactFeedbackGenerator(.rigid)` firing from `GuideRenderer.update(guides:zoomScale:)`
     when a guide transitions not-engaged → engaged (add the engaged/disengaged edge signal;
     `update` currently just redraws). Add `UINotificationFeedbackGenerator(.success)` at the end
     of `exportForSharing()`/`exportPNGForSharing()` on successful write (same functions step 2
     already rewrote — add this before finalizing that rewrite, not as a second pass).
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel`
  - New `ExportCoordinatorTests.swift` case: `MKExportCoordinator(assets:fonts:renderer:)`
    constructed with all three explicit and a fake variant-aware font provider — bold node's
    exported pixels differ from its non-bold twin.
  - New `ExportTempDirectoryTests.swift`: write two files via `urlForExport(ext:)`, call
    `purge()`, assert both gone.
  - New `MKCanvasHapticsTests.swift`: spy feedback-generator fires exactly once per selection
    change / snap-engage transition.
  - `grep -n 'MKSnapshotRenderer(' Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` inside
    `exportForSharing`/`exportPNGForSharing` → zero raw constructions remain.
  - Manual (simulator, per repo convention — no unit-test coverage for `EditorViewModel`
    itself pre-FC-6-integration): select text, tap **B**, confirm glyphs thicken on canvas and
    in a JPEG/PNG/PDF-raster/SVG export of the same node. Export from a free-tier account,
    confirm JPEG still succeeds (now via preset target) and PNG is paywalled.
- **Done when:** all Verify items pass; `Wave 0`'s `CompositionRootWiringTests.swift` (Agent 0.2)
  now passes when re-run.
- **Do not:** modify `ExportGate.swift` (use the preset-target workaround, not a gate-rule
  change — that rule is reused by `FC-7`, approval-gated, later). Do not modify
  `MKFontProviding.swift` or `MKFontRegistrar.swift` — both are already correct per commit
  `ec9887c`.

### Wave 1 · Agent 1.2 — Content-hash / sync perf (P-1)
- **Findings:** P-1
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKRender/ContentHash.swift`
  - `MakhtootKit/Sources/MKRender/LayerTreeBuilder.swift`
  - `MakhtootKit/Sources/MKCanvas/Arrange/MKArrangeInteractionModel.swift`
  - `MakhtootKit/Tests/MKRenderTests/PerfHarnessTests.swift`
- **Reads:** `MakhtootKit/Tests/MKRenderTests/ContentHashTests.swift`
- **Do:**
  1. In `ContentHash.swift`, replace the per-call `let encoder = JSONEncoder()` inside
     `encodedOrEmpty<T: Encodable>(_:)` (`~85-92`) with a single `private static let encoder`.
  2. Add a monotonic revision counter to composition mutations. `MKArrangeInteractionModel` owns
     all composition mutation (`~line 256`, `var composition = node.composition`) — bump a
     counter there on every mutating method.
  3. In `LayerTreeBuilder.swift`, cache each node's content hash in `MKLayerTreeController` keyed
     on that revision. `syncNode` (`~220-240`) and `syncBackground` (`~200-218`) must skip
     re-encode+re-hash when the revision is unchanged since the last sync, falling back to full
     re-encode+hash only on an actual composition edit or a `scaleBucket` change.
  4. Add a new large-arranged-composition test to `PerfHarnessTests.swift` alongside
     `incrementalSyncDoesNotRasterizeUnchangedNodes()` (`~83-93`): resync an unchanged large
     scene and assert it completes within a budget much tighter than today's O(composition-size)
     cost.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter PerfHarnessTests` — new test passes
    within budget; `syncTo5KNodeSceneMeetsSimulatorBudget` and
    `incrementalSyncDoesNotRasterizeUnchangedNodes` still pass.
  - `swift test --no-parallel --filter ContentHashTests` — hash semantics (transform/opacity
    exclusion, fill-color/text-string sensitivity) unchanged.
- **Done when:** both filtered test runs pass.
- **Do not:** touch `EditorViewModel.swift` or `MKCanvasViewController.swift` (owned by other
  agents this wave / later waves).

### Wave 1 · Agent 1.3 — Persistence hardening (asset refs, path traversal, file protection, tmp location)
- **Findings:** P-6, P-7, S-2, S-6, S-7
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKPersistence/Internal/PersistenceSupport.swift`
  - `MakhtootKit/Sources/MKPersistence/AssetStore.swift`
  - `MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift`
  - `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift`
  - `MakhtootKit/Sources/MKModel/MKNode.swift`
  - `MakhtootKit/Sources/MKPersistence/Metadata/LaunchReconciler.swift`
  - `MakhtootKit/Tests/MKPersistenceTests/AssetStoreTests.swift`
  - `MakhtootKit/Tests/MKPersistenceTests/MakhtootDocumentTests.swift`
  - `MakhtootKit/Tests/MKPersistenceTests/AutosaveControllerTests.swift`
  - `MakhtootKit/Tests/MKPersistenceTests/LaunchReconcilerTests.swift`
  - `MakhtootKit/Tests/MKModelTests/MKAssetRefValidationTests.swift` (new)
  - `MakhtootKit/Tests/MKPersistenceTests/FileProtectionTests.swift` (new)
- **Reads:** `MakhtootKit/Sources/MKPersistence/AutosaveController.swift`, `MakhtootKit/Sources/MKPersistence/Instantiation/BackgroundImageSupport.swift` (for `MKDocumentAssetProvider.rasterRefs(in:)`), `MakhtootKit/Sources/MKPersistence/CrashRecovery.swift`
- **Do:**
  1. **P-6 — CRC/hash O(n) per-byte loop.** In `PersistenceSupport.swift`, rewrite
     `MKSceneRevision.fnv1aHex(_:)` (`~51-59`) and `MKCRC32.checksum(_:)` (`~78-85`) to iterate
     via `data.withUnsafeBytes` over word-sized (e.g. `UInt64`) chunks instead of per-`UInt8`,
     preserving the exact algorithm/output format (persisted hashes must remain valid — see
     `CrashRecovery.swift:60,68` expectedBaseRev comparisons). Add a monotonic mutation counter
     to `MakhtootDocument` so `apply(_:)` (`~125-133`) and `saveNow(reason:)` (`~158-169`) can
     skip recomputing the full-scene hash within the same debounce window when nothing changed.
  2. **P-7 — Wave 0 work item 0.1 confirmed the orphan sweep is dead code.** The real bug: every
     production caller passes a hardcoded empty `referencedAssets`/`referencedAssetsProvider`
     (`MakhtootDocument.swift:~114,169,180`). Wire a real referenced-asset computation — call the
     existing `MKDocumentAssetProvider.rasterRefs(in:)` logic (`BackgroundImageSupport.swift:
     ~95-110`) from `MakhtootDocument`'s `scheduleAutosave()` `referencedAssetsProvider` closure
     and `saveNow()`'s `referencedAssets` argument. Reuse only — do not move, delete, or otherwise
     edit that logic inside `BackgroundImageSupport.swift`, which this agent does not own. Then
     fix `AssetStore.sweepOrphans` (`~61-76`):
     populate and check `MKManifest.assetIndexDigest` (`DocumentPackage.swift:27`, declared but
     never written) to skip the sweep when the referenced set truly hasn't changed, and delete
     only the previous cycle's orphan files instead of `removeItem`+recreate the whole
     `backups/orphans/` directory.
  3. **S-2 — path traversal via unvalidated `MKAssetRef`.** Add a hand-written
     `init(from decoder: Decoder) throws` to `MKAssetRef` (`MKNode.swift:247-255`) rejecting
     decode unless `digest` matches `^[a-f0-9]{64}$` and `ext` matches a lowercase alphanumeric
     allowlist (no `.`, `/`, `..`). Defense in depth: in `AssetStore.swift`'s `assetURL(for:)`
     (`~21-23`), after building the URL, assert
     `url.standardizedFileURL.path.hasPrefix(package.assetsDirURL.standardizedFileURL.path)` and
     throw on violation.
  4. **S-6 + S-7 — same function, land together to avoid clobbering.** In
     `MKAtomicIO.write(_:to:)` (`PersistenceSupport.swift:~21-29`): (a) add
     `.completeFileProtectionUnlessOpen` to the write options (S-6); (b) move the temp file off
     the destination's own directory (currently `directory.appendingPathComponent(".tmp-\(UUID)")`
     where `directory` is the package root) onto a sibling scratch directory outside the package
     (mirror `MKFileLocations.applicationSupportDirectory()`, `~162-168`), then
     `replaceItemAt` across directories (S-7). Also add `.completeFileProtectionUnlessOpen` to
     `AssetStore.storeAsset`'s `data.write` (`~30-39`, write at `~36`). Set the same protection
     attribute on the projects directory at creation in
     `MKFileLocations.documentsProjectsDirectory()` (`~153-160`).
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MakhtootDocumentTests,AutosaveControllerTests,CommandJournalCrashRecoveryTests` — baseRev/CRC values and crash-recovery chain unchanged.
  - `swift test --no-parallel --filter AssetStoreTests` — new cases: sweep skipped when
    referenced set unchanged; sweep deletes only prior-cycle orphans; a real image/background
    reference reaches `flushNow`'s `referencedAssets` non-empty (regression guard for the dead
    sweep).
  - `swift test --no-parallel --filter MKModelTests` — new `MKAssetRefValidationTests.swift`:
    malformed digest/ext both throw on decode.
  - `swift test --no-parallel --filter MKPersistenceTests` — new `FileProtectionTests.swift`:
    protection attribute set (note in test doc-comment this doesn't prove enforcement, Simulator
    has no passcode).
  - `swift test --no-parallel --filter LaunchReconcilerTests` — no stray `.tmp-*` left inside a
    package directory after `MKAtomicIO.write`.
- **Done when:** all filtered test runs pass; `grep -n assetIndexDigest
  MakhtootKit/Sources/MKPersistence/AssetStore.swift` shows it is now written, not just declared.
- **Do not:** touch `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift` (owned by
  Agent 1.5 this wave).

### Wave 1 · Agent 1.4 — Entitlement cache correctness (S-1)
- **Findings:** S-1
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKStore/MKEntitlementResolver.swift`
  - `MakhtootKit/Tests/MKStoreTests/MKEntitlementResolverTests.swift`
- **Reads:** `MakhtootKit/Sources/MKFonts/MKFontDownloader.swift` (line-19 pattern to mirror), `MakhtootKit/Sources/MKFonts/MKCatalogManifestFetchService.swift` (line-25 pattern to mirror)
- **Do:**
  1. In `init(catalog:trialManager:cacheURL:cacheStalenessTolerance:)` (`~63-89`), after decoding
     the cached `MKEntitlementCacheRecord` (`~85-88`), only apply `_snapshotState =
     record.decode()` when the decoded state is `.lifetime` (exempt per doc comment `~49-54`) OR
     `Date().timeIntervalSince(record.resolvedAt) < cacheStalenessTolerance`; otherwise leave
     `_snapshotState` at its `.free` default.
  2. Move the cache off `.cachesDirectory` (`~line 75`). **Do not** reach for
     `MKFileLocations.applicationSupportDirectory()` — it is `internal` to `MKPersistence` and
     `MKStore` must not gain a dependency on `MKPersistence` (D-230 boundary; `Package.swift:
     316-317`). Follow the pattern `MKFontDownloader.swift:19` and
     `MKCatalogManifestFetchService.swift:25` already use directly:
     `FileManager.default.urls(for: .applicationSupportDirectory, in:
     .userDomainMask)[0].appendingPathComponent("MKStore/entitlement-cache.json")`.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKEntitlementResolverTests`
  - New test: pre-write a cache record with `stateTag "subscribed"`, `resolvedAt` 4 days past, to
    a temp `cacheURL` → resolver's `state == .free`.
  - New test: same but `stateTag "lifetime"` → state remains `.lifetime` despite staleness.
  - New test: default (no override) cache path does not resolve under `.cachesDirectory` —
    assert path string contains "Application Support", not "/Library/Caches/".
- **Done when:** all three new tests pass alongside the existing suite.
- **Do not:** touch `MKFontDownloader.swift` or `MKCatalogManifestFetchService.swift` — read
  their patterns only, they are owned by Wave 2's Agent 2.4.

### Wave 1 · Agent 1.5 — Sync temp leak + external package import validation
- **Findings:** S-3, S-4
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKSync/Engine/MKSyncEngineController.swift`
  - `MakhtootKit/Tests/MKSyncTests/MKSyncBatchTempCleanupTests.swift` (new)
  - `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift`
  - `MakhtootKit/Sources/MKPersistence/PackageImportValidator.swift` (new)
  - `MakhtootKit/Tests/MKPersistenceTests/PackageImportValidatorTests.swift` (new)
- **Reads:** `MakhtootKit/Tests/MKSyncTests/MKSyncDurableDirtyMarkingTests.swift` (construction pattern)
- **Do:**
  1. **S-3.** In `nextBatch(context:)` (`~256-299`), track each `batchTempDir` (keyed by batch id
     / record-ID set) in actor state. In `processSentChanges(_:)` (`~486-509`, dispatched from
     the `.sentRecordZoneChanges` case at `~211`), after processing results, look up and
     `FileManager.default.removeItem(at:)` the tracked dir, then remove it from tracking. Add a
     launch-time sweep (`startEngineIfNeeded()` `~98` or `init` `~94`) enumerating
     `FileManager.default.temporaryDirectory` for `MKSyncBatch-*` entries left from a prior
     crash. Factor the tracking-add/tracking-remove-and-delete logic into small internal methods
     (`trackBatchTempDir(_:for:)`, `cleanupBatchTempDir(for:)`) so tests can call them directly —
     `CKSyncEngine.SendChangesContext`/`Event.SentRecordZoneChanges` are opaque CloudKit types
     with no public initializer anywhere in this codebase.
  2. **S-4.** Create `MakhtootKit/Sources/MKPersistence/PackageImportValidator.swift`:
     `DocumentPackage.validateForImport(at:limits:) throws`, enumerating a source URL with
     `FileManager.enumerator` and enforcing a total-bytes cap, total-file-count cap, and an
     allowlist of expected top-level members (`manifest.json`, `scene.json`, `thumbnail.png`,
     `journal.mkj`, `assets/`, `backups/`). Throw distinct error cases (byte-cap /
     file-count-cap / unexpected-member). Call it from
     `importExternalPackage(at:)` (`MKPersistenceProjectLibrary.swift:347-380`) before the
     `fm.copyItem(at:to:)` call at `~371`.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKSyncTests` — new
    `MKSyncBatchTempCleanupTests.swift`: (1) register+cleanup helper removes a real temp dir;
    (2) a stale `MKSyncBatch-<uuid>` dir predating "now" is swept at launch.
  - `swift test --no-parallel --filter MKPersistenceTests` — new
    `PackageImportValidatorTests.swift`: (a) under-cap allowlisted package passes; (b) 500MB
    extra file throws byte-cap error; (c) 10,000 tiny files throws file-count-cap error; (d)
    unexpected top-level entry throws unexpected-member error.
  - Manual (no app-target test coverage): AirDrop/open an oversized or malformed `.makhtoot` and
    confirm rejection, not partial copy.
- **Done when:** both filtered test runs pass.
- **Do not:** touch `Makhtoot/AppShell/Navigation/RootShellView.swift` (S-4's audit note calls
  this "secondary/optional, not required" — leave it for Wave 2's UX-5 agent).

### Wave 1 gate
```bash
cd MakhtootKit && swift test --no-parallel
cd .. && xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:MakhtootUITests/CompositionRootWiringTests
git add MakhtootKit/Sources MakhtootKit/Tests Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift Makhtoot/AppShell/Scenes/Editor/EditorScene.swift Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift
git commit -m "Wave 1: fix bold/italic wiring + export gate bypass (FC-1/FC-2/P-4), persistence hardening (P-6/P-7/S-2/S-6/S-7), entitlement cache TTL (S-1), sync/import leaks (S-3/S-4), haptics + export temp cleanup (UX-4/S-5)"
```

---

## Wave 2 — Canvas/memory perf, font pipeline, error surfacing

### Wave 2 · Agent 2.1 — Canvas viewport, motion accessibility, undo memory accounting
- **Findings:** P-2, P-3, P-5, UX-3
- **Owns (exclusive write set):**
  - `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`
  - `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift`
  - `MakhtootKit/Sources/MKDesignSystem/MKMotion.swift`
  - `MakhtootKit/Sources/MKCanvas/SelectionChromeLayer.swift`
  - `MakhtootKit/Sources/MKPersistence/Undo/UndoStack.swift`
  - `MakhtootKit/Tests/MKCanvasTests/MKCanvasViewControllerViewportCallbackTests.swift` (new)
  - `MakhtootKit/Tests/MKRenderTests/EvictOffscreenCoordinateSpaceTests.swift` (new)
  - `MakhtootKit/Tests/MKDesignSystemTests/MKMotionAccessibilityTests.swift` (new)
  - `MakhtootKit/Tests/MKPersistenceTests/UndoStackTests.swift`
- **Reads:** `MakhtootKit/Sources/MKRender/MemoryPressureMonitor.swift`, `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift` (scenePhase pattern), `MakhtootKit/Sources/MKRender/LayerTreeBuilder.swift`
- **Do:**
  1. **P-2 — replace poll loops.** Replace `startModePolling()`'s 100ms loop
     (`EditorViewModel.swift:378-408`) with `withObservationTracking` on
     `session.mode`/`session.selection.ids`. Add `public var onViewportChanged: ((CGRect,
     CGFloat) -> Void)?` to `MKCanvasViewController` and implement `scrollViewDidScroll(_:)`
     (not currently implemented) alongside the existing `scrollViewDidZoom(_:)` (`~270-273`),
     both firing the callback. Wire `EditorViewModel.attach(canvasViewController:)` to that
     closure, replacing the 150ms zoom poll's body (`~423-448`) — this also carries P-3's fix
     (below). Add `@Environment(\.scenePhase)` handling (mirror `ProjectBrowserView.swift:
     20,182`'s pattern) to suspend the memory-banner poll (`startMemoryLadder`, `~304-329`) and
     call `memoryMonitor?.stop()` on `.background`, resume on `.active`.
  2. **P-3 — fix the coordinate-space bug in the same call site.** Change the viewport rect
     handed to `renderAdapter.setVisibleRect` from `vc.scrollView.bounds` (unconverted) to
     `vc.scrollView.convert(vc.scrollView.bounds, to: vc.contentHostView)` — this is now inside
     the `onViewportChanged` closure body from step 1, not the old poll.
  3. **UX-3 — Reduce Motion / Differentiate Without Color.** Thread `@Environment
     (\.accessibilityReduceMotion)` into `MKMotionTokens.animation(duration:)`
     (`MKMotion.swift:42-47`) — short-circuit to `.linear(duration: 0)` when set. Add a
     Differentiate-Without-Color branch to `SelectionChromeLayer`'s stroke rendering (dash
     pattern or stroke-width delta) driven by the same flag threaded from
     `MKCanvasViewController`'s theme/environment context (selectionChrome color set at
     `~135-136`).
  4. **P-5 — undo stack memory accounting.** Conform `MKUndoStack` to `MKMemoryAccountable`
     (`UndoStack.swift`): `accountedBytes()` sampling a subset of entries via
     `MKCommandCoder`'s existing encode path; `evictOffscreen()` as
     `setMaxEntries(maxEntries / 2)`; `evictAll()` as a more aggressive cap or full clear.
     Register with the governor in `EditorViewModel.swift` alongside the existing
     `governor.register(layerTree,...)`/`governor.register(assetProvider,...)` calls
     (`~251-256`), using the existing `.standard` priority case (`MKMemoryEvictionPriority` has
     only `.offscreenFirst`/`.standard` — no `.low` exists; do not add one without a separate
     decision).
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKCanvasViewControllerViewportCallbackTests` — `onViewportChanged` fires from both `scrollViewDidZoom` and the new `scrollViewDidScroll`.
  - `swift test --no-parallel --filter EvictOffscreenCoordinateSpaceTests` — a centered node
    survives `evictOffscreen()` at zoom 0.5 and 4.0 given a correctly-converted rect.
  - `swift test --no-parallel --filter MKMotionAccessibilityTests` — zero-duration animation
    when reduceMotion simulated true; `MKCanvasTests` case confirms non-default dash pattern
    when differentiateWithoutColor set.
  - `swift test --no-parallel --filter UndoStackTests` — pushing >maxEntries then
    `evictOffscreen()` drops count by ~half.
  - Manual: build, run on Simulator, background the app, confirm (via a temporary log or
    Instruments) no 100ms/150ms/1s ticks continue while backgrounded.
- **Done when:** all filtered test runs pass; manual background check confirms polling stops.
- **Do not:** touch `DegradationController.swift` (owned by Agent 2.2 this wave).

### Wave 2 · Agent 2.2 — Degradation ladder bounds + undo-cap reclaim
- **Findings:** P-8, FC-3
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKRender/DegradationController.swift`
  - `MakhtootKit/Tests/MKRenderTests/DegradationLadderTests.swift`
  - `MakhtootKit/Tests/MKPersistenceTests/UndoStackDegradationTests.swift` (new)
- **Reads:** `MakhtootKit/Sources/MKPersistence/Undo/UndoStack.swift` (already correct — `setMaxEntries` exists, no change needed to that file), `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (context on where `document.undoStack` is reachable — no write)
- **Do:**
  1. **P-8 — unbounded history.** Change `history.append(...)` (`~line 164`, inside
     `transition(to:now:)` `~129-165`) to a bounded append: `history.append(event); if
     history.count > 64 { history.removeFirst(history.count - 64) }`. Preserve ordering
     (most-recent last).
  2. **FC-3 — wire the undo stack into the ladder.** `MKUndoStack.setMaxEntries(_:)` has zero
     call sites in the repo (Wave 1's Agent 2.1 conformed it to `MKMemoryAccountable` for the
     governor path — this is a *separate* reclaim mechanism, the D-116 degradation ladder). In
     `transition(to:)`'s stage1/stage2 branches (`~151-161`, alongside the existing
     `autosave.flushForMemoryPressure` calls), call `document.undoStack.setMaxEntries(_:)` with
     a smaller cap — this keeps the call inside `DegradationController.swift` and avoids a third
     `EditorViewModel.swift` writer this wave.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter DegradationLadderTests` — new test
    drives >64 stage transitions (alternating stages, injected `now:` timestamps to defeat the
    ≥10s hysteresis, matching this file's existing pattern), asserts `history.count` never
    exceeds 64.
  - `swift test --no-parallel --filter UndoStackDegradationTests` — simulating a stage1/stage2
    transition invokes `setMaxEntries` below the 500 default; `undo.count` never exceeds the new
    cap after.
- **Done when:** both filtered test runs pass.
- **Do not:** modify `UndoStack.swift` (already correct per Wave 1 Agent 2.1's conformance —
  this agent only adds a *caller*).

### Wave 2 · Agent 2.3 — Font pipeline safety (dormant, defense in depth)
- **Findings:** S-8, S-9, EU-9
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKFonts/MKCatalogManifestFetchService.swift`
  - `MakhtootKit/Sources/MKFonts/MKFontDownloader.swift`
  - `MakhtootKit/Tests/MKFontsTests/MKCatalogManifestFetchServiceTests.swift`
  - `MakhtootKit/Tests/MKFontsTests/MKFontDownloaderTests.swift`
- **Reads:** `MakhtootKit/Sources/MKFonts/MKPremiumDelivery.swift` (confirms `.bundledFallback` — both files are dormant in production; fix anyway, this is the FC-5 pre-work), `MakhtootKit/Tests/MKFontsTests/StubURLProtocol.swift`
- **Do:**
  1. **S-8 — response-size cap.** In `fetch(manifestURL:)` (`~40-65`), replace `session.data(from:
     manifestURL)` (`~50`) with `session.bytes(from: manifestURL)`; check
     `response.expectedContentLength` against an explicit ceiling and reject early if it's absent
     or implausible; accumulate bytes from the `AsyncBytes` stream up to the same ceiling,
     aborting before decode if exceeded.
  2. **S-9 — scheme check + defer ordering.** In `download(_:)` (`~37-80`), before
     `session.download(from: entry.fileURL)` (`~42`), add `guard entry.fileURL.scheme == "https"
     else { throw MKFontError.offline }` (or a dedicated error case). Move the
     `defer { try? FileManager.default.removeItem(at: tmpURL) }` (`~53`) so it only fires on
     failure paths — wrap the digest-verify-through-`moveItem` block (`~55-66`) in `do`/`catch`
     that removes `tmpURL` on catch and rethrows.
  3. **EU-9 — dead progress stream.** Replace `session.download(from:)` (same call site as S-9's
     fix, `~42`) with `URLSession.bytes(from:)` streaming so bytes accumulate incrementally,
     yielding fractional progress (`bytesReceived / expectedContentLength`) to
     `progressContinuations[entry.fontID]` (currently created in `progress(for:)` `~28-32` and
     never yielded to) as data arrives. Add
     `defer { progressContinuations[entry.fontID]?.finish();
     progressContinuations.removeValue(forKey: entry.fontID) }` so the continuation always
     finishes and is removed whether download succeeds or throws.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKFontsTests`
  - New `MKCatalogManifestFetchServiceTests.swift` case: stub an oversized response via
    `StubURLProtocol`, assert `fetch` falls back to `.empty`/`.stale` rather than decoding.
  - New `MKFontDownloaderTests.swift` cases: (a) `file://` `entry.fileURL` throws before any
    I/O; (b) success path still leaves destination file present, tmp file gone (defer reorder
    doesn't regress cleanup-on-success); (c) `progress(for:)` yields ≥1 value in [0,1], stream
    terminates after download completes, and `progressContinuations` no longer holds an entry
    for that `fontID` afterward.
- **Done when:** all new cases pass alongside the existing suite. (This code remains dormant
  behind `MKPremiumDelivery.current == .bundledFallback` — no production behavior change until
  Wave 5's FC-5 decision flips delivery mode.)
- **Do not:** touch `MKPremiumDelivery.swift` — that flag flip is FC-5, Wave 5.

### Wave 2 · Agent 2.4 — Error surfacing: import failures + sync error propagation
- **Findings:** UX-5
- **Owns (exclusive write set):**
  - `Makhtoot/Stubs/ProjectLibraryProviding.swift`
  - `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift`
  - `Makhtoot/AppShell/Navigation/RootShellView.swift`
  - `MakhtootKit/Sources/MKSync/Engine/MKSyncEngineController.swift`
  - `Makhtoot/AppShell/Scenes/Settings/SyncSettingsView.swift`
  - `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift`
  - `MakhtootKit/Tests/MKSyncTests/MKSyncErrorSurfacingTests.swift` (new)
- **Reads:** `MakhtootKit/Sources/MKSync/Engine/MKSyncError.swift`, `Makhtoot/Stubs/SyncStatusProviding.swift`
- **Do:**
  1. **Import-failure collapse (confirmed defect).** Expand `ProjectImportError`
     (`ProjectLibraryProviding.swift:62-63`, currently one case `.invalidPackage`) into distinct
     cases — `.missingPackage`, `.malformedManifest`, `.copyFailed(underlying: Error)`. Update
     the four throw sites in `importExternalPackage(at:)`
     (`MKPersistenceProjectLibrary.swift:348,351,352,373-374`) to throw the matching case.
     Update `RootShellView.swift`'s catch block / `openURLErrorBody` (`~96-105`) to map each
     case to a distinct Arabic message.
  2. **Sync errors — extend, don't rebuild (per Wave 0 Agent 0.1's corrected scope).** Sync
     errors are already partly surfaced (`SyncSettingsView.swift:~70`,
     `ProjectBrowserView.swift:~517-530`'s badge). Extend `MKSyncEngineController` to route more
     error kinds into the global state beyond `zoneNotFound` (only call site today:
     `~line 242`) — add a persisted `lastError: MKSyncError?` field to
     `MKSyncStatusPublisher` that survives a transition back to `.idle`. Make
     `ProjectBrowserView.swift`'s per-project badge (`~516-530`) tappable, surfacing
     `MKSyncError.localizedMessage` and an `accessibilityValue` rather than being a silent icon.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKSyncTests` — new
    `MKSyncErrorSurfacingTests.swift`: `MKSyncStatusPublisher` retains a non-nil `lastError`
    after a simulated `CKError` maps through `MKSyncErrorMapper` and the engine transitions back
    to `.idle`.
  - Manual (no app-target test target): trigger each of the four import failure modes (missing
    package dir, malformed `manifest.json`, unreadable disk, copy failure) via a crafted
    `.makhtoot` opened through `.onOpenURL`, confirm distinct Arabic alert text per case. Tap
    the per-project sync badge with a forced sync error, confirm the specific message appears.
- **Done when:** new sync test passes; manual import/sync checks confirm distinct messaging.
- **Do not:** touch `MKPersistenceProjectLibrary.swift`'s `importExternalPackage` byte/count-cap
  logic (that's S-4, already landed Wave 1) — only its throw sites' error *types* change here.

### Wave 2 gate
```bash
cd MakhtootKit && swift test --no-parallel
cd .. && xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'generic/platform=iOS Simulator' build
git add MakhtootKit/Sources MakhtootKit/Tests Makhtoot/AppShell
git commit -m "Wave 2: canvas poll removal + viewport coordinate fix (P-2/P-3), Reduce Motion (UX-3), undo memory reclaim (P-5/FC-3/P-8), font pipeline hardening (S-8/S-9/EU-9), import/sync error surfacing (UX-5)"
```

---

## Wave 3 — Deferred perf, accessibility/design sweep, navigation state

### Wave 3 · Agent 3.1 — Offscreen-eviction flag (P-9, depends on Wave 2's P-2)
- **Findings:** P-9
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKRender/LayerTreeBuilder.swift`
  - `MakhtootKit/Tests/MKRenderTests/PerfHarnessTests.swift`
- **Reads:** `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (confirms P-2's `onViewportChanged` now drives `setVisibleRect` at scroll-frame cadence, not 150ms — this is why the scan cost now matters)
- **Do:**
  1. Add a stored `private var hasEvictedContentFlag = false` to `MKLayerTreeController`. Set it
     true at the end of `evictOffscreen()` (`~341-347`) whenever at least one `layer.contents`
     was nil'd, and unconditionally in `evictAll()` (`~352-356`). Clear it to false at the end of
     `sync(to:)` (`~88-106`), after the per-node loop.
  2. Replace `hasEvictedContent`'s computed-property body (`~189-191`,
     `layers.values.contains { $0.contents == nil }`) with a direct read of the stored flag.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter PerfHarnessTests` — new case: after
    `sync(to:)` + `evictOffscreen()` with ≥1 layer going offscreen, flag reads true; after a
    subsequent `sync(to:)`, reads false again.
- **Done when:** the new case passes.
- **Do not:** touch `EditorViewModel.swift` or `MKCanvasViewController.swift`.

### Wave 3 · Agent 3.2 — Design-system & accessibility sweep (Dynamic Type, localized a11y labels, tour frames, zoom value)
- **Findings:** UX-2, UX-6, UX-7, UX-8
- **Owns (exclusive write set):**
  - `MakhtootKit/Sources/MKDesignSystem/MKTypeRamp.swift`
  - `Makhtoot/AppShell/Scenes/Browser/NewProjectSheet.swift`
  - `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift`
  - `Makhtoot/AppShell/Scenes/Browser/ExportHistorySheet.swift`
  - `Makhtoot/AppShell/Scenes/Editor/MKAssetBrowserSheet.swift`
  - `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift`
  - `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift`
  - `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift`
  - `Makhtoot/AppShell/Scenes/Editor/EditorPlaceholderView.swift`
  - `Makhtoot/AppShell/Scenes/Editor/TextInsertSheet.swift`
  - `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift`
  - `Makhtoot/AppShell/Scenes/Editor/BackgroundImageSheet.swift`
  - `Makhtoot/AppShell/Scenes/Onboarding/OnboardingView.swift`
  - `Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift`
  - `MakhtootKit/Sources/MKDesignSystem/Components/MKToolbarButton.swift`
  - `Makhtoot/AppShell/Scenes/Editor/EditorTourModel.swift`
  - `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift`
  - `Makhtoot/AppShell/Scenes/Editor/FormSelectorPopoverView.swift`
  - `MakhtootKit/Sources/MKCanvas/TextEditingOverlay.swift`
  - `MakhtootKit/Tests/MKDesignSystemTests/MKTypeRampDynamicTypeTests.swift` (new)
- **Reads:** none beyond the owned set.
- **Do:**
  1. **UX-2 — Dynamic Type.** In `MKTypeRamp.swift`'s `style(for:)` (`~69-92`), change every
     `MKTypeRole` case's font construction from `.custom(fonts.x, size: N)` to `.custom(fonts.x,
     size: N, relativeTo: <TextStyle>)` (display/largeTitle→`.largeTitle`,
     title/title2→`.title`/`.title2`, headline→`.headline`, body→`.body`, callout→`.callout`,
     footnote→`.footnote`, caption→`.caption`, mono→`.caption2`). Sweep the ~27 fixed
     `.system(size:)`/`Font.custom(size:)` call sites across the 13 files listed above (each
     finding's own file-list gives the exact lines) — route through `theme.typeRamp.style(for:)`
     or add `relativeTo:` directly. Add `.dynamicTypeSize(...DynamicTypeSize.accessibility3)`
     clamps on `ToolRailView` and inspector panels so they don't break at the largest
     accessibility sizes.
  2. **UX-7 — accessibility labels bypass the string catalog.** Change every `private var
     xLabel: String { "..." }` property (and `MKToolbarButton`'s `accessibilityLabel: String`
     init parameter, `~12`) that feeds `.accessibilityLabel(_:)` to type `LocalizedStringResource`
     instead of `String`, across `EditorScene.swift`, `ToolRailView.swift`,
     `ZoomControlsView.swift`, `FontSettingsSheet.swift`, `InspectorPanelView.swift`,
     `FormSelectorPopoverView.swift`, `MKAssetBrowserSheet.swift`, `TextInsertSheet.swift`,
     `MKToolbarButton.swift`, and `TextEditingOverlay.swift`'s `public let accessibilityLabel:
     String` property (~161) and its init parameter (~163). Purely mechanical — do not touch
     `Localizable.xcstrings` itself.
  3. **UX-8 — zoom value.** Attach `.accessibilityValue(percentageText)` (existing computed
     property at `ZoomControlsView.swift:86-89`, already Arabic-Indic formatted) to the zoom-in
     and zoom-out `MKToolbarButton` calls (`~20`, `~43`). Leave the existing `Text` badge
     (`~23`) in place.
  4. **UX-6 — stale tour frames.** Replace the three `Color.clear.onAppear { tourModel.xFrame =
     geo.frame(in: .global) }` blocks in `ToolRailView.swift` (`~136-137`, `~180-181`,
     `~190-191`) with a `PreferenceKey`-based approach: define an `MKTourFramePreferenceKey`
     collecting `[String: CGRect]`, report via `.preference(key:value:)` inside each
     `GeometryReader`, read with `.onPreferenceChange` at the ancestor view owning `tourModel`
     (`EditorTourModel.swift`'s frame properties at `~11-13` are unaffected in shape, just
     updated more often).
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKDesignSystemTests` — new
    `MKTypeRampDynamicTypeTests.swift`: each `MKTypeRole`'s resolved font scales between
    `.large` and `.accessibility3` content size categories.
  - `grep -rn 'accessibilityLabel: String' --include='*.swift' Makhtoot/ MakhtootKit/Sources/`
    → zero hits (was: `MKToolbarButton.swift:12` plus the ~15 `private var …Label: String`
    instances).
  - Manual (no app-target test target for these views): Settings → Accessibility → Larger Text
    at an accessibility size, confirm layout holds. VoiceOver: focus zoom buttons, confirm
    percentage is announced. Start the tour, rotate/resize mid-tour, confirm highlight follows
    the button.
- **Done when:** the grep returns zero and the new Dynamic Type test passes.
- **Do not:** touch `EditorViewModel.swift`, `ExportCoordinator.swift`, or any export-flow file
  — this agent is presentation-layer only. Must not alter the tour's step-3 copy string
  (`EditorTourModel.swift`) — that wording is approval-gated under EU-1 in Wave 5.

### Wave 3 · Agent 3.3 — Navigation state: onboarding replay + scene restoration
- **Findings:** EU-3, EU-7
- **Owns (exclusive write set):**
  - `Makhtoot/AppShell/Navigation/AppNavigationModel.swift`
  - `Makhtoot/AppShell/Navigation/RootShellView.swift`
  - `Makhtoot/AppShell/Scenes/Settings/GeneralSettingsView.swift`
  - `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`
- **Reads:** `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift` (line-320 restart-button pattern to mirror)
- **Do:**
  1. **EU-7 — onboarding cannot be replayed.** Add `resetOnboarding()` to
     `AppNavigationModel` (alongside `completeOnboarding()` `~103`) setting
     `hasCompletedOnboarding = false`. Add a row to `GeneralSettingsView.swift` — mirror
     `ToolRailView.swift:320`'s `Button { tourModel.restart() }` pattern — calling the new
     method.
  2. **EU-3 — no state restoration.** Add `@SceneStorage` properties to `RootShellView`
     (open project id, zoom scale, content offset), restored after `LaunchReconciler` completes
     its crash-recovery pass. Add a persisted "last open project id" to `AppNavigationModel`
     following the same UserDefaults pattern as `hasCompletedOnboarding` (`~67-81`).
     `EditorViewModel` needs a restoration payload (zoom/offset/selection) accepted via `init`
     or a `restore(_:)` method called after the project loads. Treat NSUserActivity/Handoff as
     explicitly out of scope.
- **Verify:**
  - No `swift test` coverage for this layer (Navigation/*.swift have no SwiftPM test target).
  - Add a lightweight unit test if any restoration logic can be factored into MakhtootKit
    (optional); otherwise verify manually: open a project, set known zoom/offset, background +
    force-terminate, relaunch, confirm the same project/zoom/offset/selection restore. Skip
    onboarding, go to Settings, tap the new reset row, confirm onboarding reappears.
- **Done when:** manual restoration + reset checks pass.
- **Do not:** touch `EditorScene.swift` (owned by Agent 3.2 this wave) or export-related
  `EditorViewModel.swift` regions already landed in Wave 1/2 — only add restoration-specific
  code.

### Wave 3 gate
```bash
cd MakhtootKit && swift test --no-parallel
cd .. && xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'generic/platform=iOS Simulator' build
git add MakhtootKit/Sources MakhtootKit/Tests Makhtoot/AppShell
git commit -m "Wave 3: offscreen-eviction O(1) flag (P-9), Dynamic Type + localized a11y labels + tour frames + zoom value (UX-2/UX-6/UX-7/UX-8), onboarding replay + scene restoration (EU-3/EU-7)"
```

---

## Wave 4 — Export UX overhaul

### Wave 4 · Agent 4.1 — Export progress, cancellation, format guidance, error surfacing
- **Findings:** EU-4
- **Owns (exclusive write set):**
  - `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift`
  - `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`
  - `MakhtootKit/Sources/MKExport/ExportCoordinator.swift`
  - `MakhtootKit/Tests/MKExportTests/ExportCoordinatorProgressTests.swift` (new)
- **Reads:** `MakhtootKit/Sources/MKExport/TiledRasterExporter.swift`, `MakhtootKit/Tests/MKExportTests/ExportCoordinatorTests.swift`
- **Do:**
  1. Replace the flat export-button list in `EditorScene.swift` (`~570-605`) with a sheet
     listing one row per format, each with a one-line Arabic purpose string
     (للطباعة/للنشر/للتحرير), a lock badge for premium-gated formats (SVG, PDF vector) shown
     before tapping, and resolved output pixel dimensions.
  2. In `EditorViewModel.swift`, change each of the five export methods' `catch { return nil }`
     blocks (post-Wave-1 rewrite, still present in the PDF-vector/PDF-raster paths at
     `~527-529`/`~548-550`/`~568-570` and now the JPEG/PNG paths from Wave 1's rewrite) to
     capture and propagate the thrown error instead, so the caller can show an alert.
  3. In `ExportCoordinator.swift`, add a `Progress`-based (or `AsyncStream<Double>`-based) signal
     for the tiled-raster/CMYK-PDF export path, with a cancellation token surfaced to the UI as
     a cancel button during long exports.
- **Verify:**
  - `cd MakhtootKit && swift test --no-parallel --filter MKExportTests` — new
    `ExportCoordinatorProgressTests.swift`: progress callbacks fire monotonically 0→1 during a
    `TiledRasterExporter` run; cancellation stops the export and throws `CancellationError`.
  - Manual / `MakhtootUITests` (target exists as of Wave 0): trigger a large export, confirm
    progress indicator + cancel button appear; force a failure (e.g. simulated disk-full),
    confirm a visible alert instead of silent no-op.
- **Done when:** the new export-progress test passes and the manual/UI-test check confirms
  visible progress + error alerting.
- **Do not:** touch `GestureCoordinator.swift`, `GuideRenderer.swift`, or any file owned by
  earlier waves' agents — this wave only re-touches `EditorScene.swift`/`EditorViewModel.swift`
  for export-UX concerns, building on Wave 1's coordinator rewrite.

### Wave 4 gate
```bash
cd MakhtootKit && swift test --no-parallel
cd .. && xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'generic/platform=iOS Simulator' build
git add MakhtootKit/Sources/MKExport MakhtootKit/Tests/MKExportTests/ExportCoordinatorProgressTests.swift Makhtoot/AppShell/Scenes/Editor/EditorScene.swift Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift
git commit -m "Wave 4: export progress/cancellation/format guidance, propagate export failures instead of silent nil (EU-4)"
```

---

## Wave 5 — Approval gate (founder decisions)

Nothing in Waves 0–4 depends on any answer here. Each item below is a decision, not a task —
present the question, the options, a recommendation, and the pre-scoped work packet that a future
wave executes once answered. Do not execute any of these until the founder responds in chat.

### Decision — UX-1: VoiceOver on the canvas
**Question:** Should the canvas gain full VoiceOver support (one accessibility element per node,
custom move/resize/delete actions), or ship without it for v1?
**Cost if yes:** Effort L. Implement `accessibilityElements` on `MKCanvasViewController`'s
`contentHostView` (currently a bare `UIView`, `MKCanvasViewController.swift:28`): one element per
top-level node from `LayersModel`, label from node kind + text, frame from
`LayerTreeBuilder`/`MKNodeLocalBounds`, custom actions for move/resize/delete, recomputed on
scene mutation / selection change. New test:
`MakhtootKit/Tests/MKCanvasTests/MKCanvasAccessibilityTests.swift`.
**Cost if no:** the canvas remains entirely invisible to VoiceOver — a hard accessibility gap on
the app's core surface.
**Recommendation:** Yes, but scope to top-level nodes only for v1; defer arrange-mode glyph
children to a follow-on.
**Work packet (runs once approved):** owns `MKCanvasViewController.swift`; reads `LayersModel.swift`,
`LayerTreeBuilder.swift`; verify with `swift test --no-parallel --filter
MKCanvasAccessibilityTests` (element count matches node count, frames match world bounds).

### Decision — EU-1: Tour copy vs. real gesture for Arrange Mode
**Question:** The tour's step-3 copy in `EditorTourModel.swift`'s `currentBody` default case
(`~line 44`) currently reads "اضغط مطوّلاً على حرف لتفعيل وضع الترتيب وتحريكه بحرية" (long-press
on a letter to activate Arrange Mode and move it freely) — but long-press does nothing today;
only tapping the Arrange button works. Two mutually exclusive ways to close the gap:
- **(a) CHEAP — rewrite the copy** to match the gesture that actually exists: replace the string
  with "اضغط زر الترتيب بعد تحديد نص" (tap the Arrange button after selecting text).
- **(b) BETTER — build the gesture** the original copy describes: ship EU-2's long-press context
  menu (with an Arrange action) so long-press genuinely activates Arrange Mode, and keep the
  original copy exactly as written.
**Cost of (a):** Effort XS — a one-string edit. Founder sign-off is needed only because it's
user-facing Arabic copy, not for engineering risk. Long-press stays a dead/duplicate gesture
(the same gap EU-2 describes) unless/until EU-2 ships later.
**Cost of (b):** see EU-2's own cost (Effort M) — a real feature build, not a copy fix. Until it
ships, the tour keeps teaching a gesture that does nothing, which actively misleads new users in
the meantime.
**Recommendation:** (a) now — it is nearly free and removes an actively misleading tour step
today. If EU-2 ships later (a separate, larger decision), revert this string back to the
long-press wording in that later wave. (a) and (b) are mutually exclusive — do not schedule both.
**Work packet for (a) (pre-staged, one-edit job once approved):** owns
`Makhtoot/AppShell/Scenes/Editor/EditorTourModel.swift`; in the `currentBody` default case
(`~line 44`), replace the exact current string
`"اضغط مطوّلاً على حرف لتفعيل وضع الترتيب وتحريكه بحرية"` with the exact replacement string
`"اضغط زر الترتيب بعد تحديد نص"`; no automated test (string literal) — manually verify tour step
3 (index 2) shows the new copy and still highlights `arrangeButtonFrame`.
**Work packet for (b):** see EU-2's own work packet above.

### Decision — EU-2: Build the long-press context menu (ARCHITECTURE §10.2)
**Question:** ARCHITECTURE.md §10.2 specifies a long-press context menu (duplicate, lock, hide,
arrange, order) that was never built — long-press on a node currently just duplicates tap
(selects it). Build it now?
**Cost if yes:** Effort M. Add `UIContextMenuInteraction` to `CanvasHostView`'s content host,
triggered by the node id `GestureCoordinator.handleLongPress` (`~362-390`) already resolves.
Five actions call existing `EditorViewModel` methods (`duplicateSelection` `~1171`,
`toggleLockForSelection` `~1176`, `toggleHideForSelection` `~1183`, `toggleArrangeMode` `~1266`,
`bringSelectionToFront`/`sendSelectionToBack` `~1190`/`~1195` — no new methods needed).
**Cost if no:** long-press stays a dead/duplicate gesture; ship EU-1's copy-only fix instead.
**Recommendation:** Yes if there's a design cycle available — it closes a documented spec gap
with entirely reused view-model methods. If deferred, approve EU-1's cheap copy fix (option (a))
separately instead.
**Work packet:** owns `MakhtootKit/Sources/MKCanvas/Gestures/GestureCoordinator.swift`,
`Makhtoot/AppShell/Scenes/Editor/CanvasHostView.swift`; verify manually (long-press a node,
confirm 5-item menu, tap "arrange", confirm `viewModel.arrangeInteraction.isActive`) until a UI
test is added to `MakhtootUITests`.

### Decision — EU-5: Apple Pencil support
**Question:** Add minimum-viable Pencil support (double-tap → toggle Arrange Mode, palm
rejection while Pencil is in use) to an iPad-first design tool that currently has zero Pencil
handling?
**Cost if yes:** Effort L. Add `UIPencilInteraction` to `MKCanvasViewController`; double-tap
toggles `EditorViewModel.toggleArrangeMode()` (same call `ToolRailView.swift:186` uses). Branch
`GestureCoordinator`'s pan/drag handling on touch type for palm rejection.
**Cost if no:** the app ships with no Pencil affordance at all on the platform it's designed for.
**Recommendation:** Yes for the minimum-viable scope (double-tap + palm rejection); full
pressure/tilt input stays out of scope regardless.
**Work packet:** owns `MakhtootKit/Sources/MKCanvas/Gestures/GestureCoordinator.swift`,
`MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift`; new
`MakhtootKit/Tests/MKCanvasTests/PencilInteractionTests.swift` (mocked `UITouch.type == .pencil`).
Physical-hardware verification required — Simulator does not fully simulate Pencil proximity.

### Decision — EU-6: Drag and drop for images and project export
**Question:** Add `.dropDestination` on the canvas (image import) and `.draggable` on project
cards (export a `.makhtoot` package by dragging out)?
**Cost if yes:** Effort M. `CanvasHostView` gains `.dropDestination(for: Data.self)` routed to
existing `EditorViewModel.placeAsset(_:using:)` (`~1055`) / `setBackgroundImage(data:entitlement:)`
(`~1111`) — no signature changes. `ProjectBrowserView.swift` gains `.draggable` on project cards
using the existing package-export path.
**Cost if no:** no drag-and-drop anywhere in the app; import/export stays button-only.
**Recommendation:** Yes — both call sites already exist and need no new engine code, this is
pure UI wiring.
**Work packet:** owns `Makhtoot/AppShell/Scenes/Editor/CanvasHostView.swift`,
`Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift`; verify via new `MakhtootUITests`
cases (drag an image onto canvas → node placed; drag a project card out → `.makhtoot` offered).

### Decision — EU-8: Interactive/animated Arrange Mode onboarding page
**Question:** The Arrange Mode onboarding page is a static SF Symbol (`"wand.and.stars"`,
`OnboardingView.swift` pages array `~38-46`) — replace with a short animation or interactive
glyph-drag demo?
**Cost if yes:** Effort M. Either a looping animation of Arabic text decomposing into
independently-moving glyphs (built on the real `MKTextEngine`/`MKArrange` rendering, not a
canned video) or an interactive drag-one-glyph variant. Requires extending `Page`/`pageView(_:)`
(`~89-122`) to support custom content for this one page.
**Cost if no:** onboarding continues to *tell* rather than *show* the app's signature feature.
**Recommendation:** Yes if design bandwidth exists — this is the single highest-leverage
first-impression fix in onboarding; otherwise defer without blocking anything else.
**Work packet:** owns `Makhtoot/AppShell/Scenes/Onboarding/OnboardingView.swift`; smoke-test via
`MakhtootUITests` (presence of a custom accessibility identifier on the new view).

### Decision — FC-4: SVG font embedding (bold/italic) + fallback-note wording accuracy
**Question:** Three sub-pieces. (1) The `FallbackNote` Arabic wording for SVG's
emoji/placeholder-geometry branch (`SVGSerializer.swift`'s emitted
`FallbackNote(reason: .colorGlyphRasterized)`, wired through `FallbackNote.swift`) currently
claims rasterization — "تم تصدير الرمز التعبيري كصورة نقطية" — for a branch that actually emits
vector placeholder geometry, not a rasterized image. Correct the wording to describe it as a
vector placeholder instead? (2) Should SVG **font embedding** be wired to production at all
before launch? Today `MKExportFontDataProviding` has no real conformer anywhere —
`MKNoFontDataProviding` (always returns `nil`) is the only one that exists, so
`SVGTextWriter.swift:201`'s bold/italic-embedding FIXME is currently dead code, not a live
user-facing bug. (3) Subsetting stays deferred per prior decision — no action.
**Cost of (1):** Effort XS — a one-string accuracy fix in `FallbackNote.swift`/the construction
site in `SVGSerializer.swift`. No engineering risk; needs sign-off only because it changes
founder-authored, user-facing Arabic copy.
**Cost if (1) deferred:** the note keeps describing an emoji/placeholder-geometry export as
rasterized when it is actually vector geometry — a minor but confirmed accuracy defect in
shipped user-facing text.
**Cost if (2) embedding proceeds:** Effort L. Widen `MKExportFontDataProviding.fontFileData` to
accept variant info (or mint per-variant `MKFontRef`s at resolution time), build a real
conformer backed by `MKFontRegistry`, wire it into `EditorViewModel`'s three
`MKExportCoordinator` constructions via `fontData:`.
**Cost if (2) deferred:** SVG exports carry no embedded fonts at all (current, shipped behavior)
— visually correct on the export author's device, broken on any other device/browser without the
fonts installed.
**Recommendation:** (1) yes — approve the wording fix; it is low-risk and purely corrects a
factual inaccuracy in shipped copy. Defer (2)/(3) unless SVG is a marketed export format for v1;
embedding without subsetting risks multi-MB files per the audit's original (now-corrected)
concern.
**Work packet for (1) (pre-staged, one-string job once approved):** owns
`MakhtootKit/Sources/MKExport/SVGSerializer.swift`,
`MakhtootKit/Sources/MKExport/FallbackNote.swift`, and a new
`MakhtootKit/Tests/MKExportTests/SVGSerializerTests.swift`; correct the Arabic string so it no
longer claims rasterization ("تم تصدير الرمز التعبيري كصورة نقطية") for the vector-placeholder
branch — describe it as a vector placeholder instead; verify with
`swift test --no-parallel --filter MKExportTests` (new case: the arranged-emoji `FallbackNote`
text no longer claims rasterization).
**Work packet for (2), if approved:** owns
`MakhtootKit/Sources/MKExport/SVGTextWriter.swift`,
`MakhtootKit/Sources/MKExport/MKExportFontDataProviding.swift`,
`Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`; extend
`MakhtootKit/Tests/MKExportTests/SVGBoldItalicAndPathHighlightParityTests.swift`.

### Decision — FC-5: Hosted premium-font delivery (FD-04)
**Question:** Ship premium fonts bundled in the app (current) or move to hosted delivery
(`MKPremiumDelivery.current` flips from `.bundledFallback` to `.hosted(manifestURL:)`,
`MKPremiumDelivery.swift:26`)?
**Cost if hosted:** requires a real HTTPS manifest endpoint (today's `placeholderManifestURL` is
an RFC 2606 `.invalid` TLD) and wiring `MKFontDownloader`/`MKCatalogManifestFetchService`
(hardened in Wave 2) into `AppContainer`. Effort: unknown pending infra decision.
**Cost if bundled (status quo):** every new premium font requires an App Store update.
**Recommendation:** No action until hosting infrastructure exists; the Wave 2 hardening
(S-8/S-9/EU-9) means this path is ready to flip the moment infra lands.
**Work packet (runs once approved and infra exists):** owns `MKPremiumDelivery.swift`, wires
`MKFontDownloader`/`MKCatalogManifestFetchService` into `AppContainer.swift`.

### Decision — FC-7: Export gate can't see premium assets (only fonts/backgrounds)
**Question:** `MKExportGate.premiumContentPresent` takes a `premiumAssetNodeIDs: Set<MKNodeID>`
that no caller ever populates — a free user's exported scene isn't checked for premium
*asset* content (only premium fonts/photo backgrounds are checked elsewhere). Fix via (a) a
`MKNodeCore.sourceAssetID: String?` schema bump so the gate can walk the scene structurally, or
(b) have `EditorViewModel` derive the set from the existing (but currently disconnected)
`MKPremiumContentLedger` and pass it explicitly at each export call site?
**Cost of (a):** Codable/legacy-decode schema change across all persisted documents.
**Cost of (b):** cheaper, no schema change, but ties export-time correctness to
`EditorViewModel` remembering to pass the set at every future export call site.
**Recommendation:** (b) — lower risk, no persisted-format migration, and the ledger already
exists and already tracks this state; it's just never read at export time.
**Work packet:** owns `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`,
`MakhtootKit/Sources/MKExport/ExportGate.swift` (or `MKModel/MKNode.swift` if (a) is chosen
instead); depends on Wave 0's FC-6 test target — verify via a new `ExportGateTests.swift` case.

### Decision — FC-8: Real referral qualifying action
**Question:** `MKReferralRedemption`'s qualifying action is `codeEntered` — a v1 placeholder that
is self-referral-friendly (enter your own code, redeem instantly). This is dormant today
(`MKFeatureFlags.referralProgram = false`, D-124/Q78) — fix before or only if FD-05 enables the
program?
**Cost if fixed now:** Effort S. Define a real qualifying action (first successful export, or
first project saved on the referred device — product call) in place of `codeEntered`.
**Cost if deferred:** no risk today (flag is off); risk only materializes if FD-05 flips on
without this fix landing first.
**Recommendation:** Defer implementation until FD-05 is actually being scheduled, but do not
enable the referral program before this fix lands.
**Work packet (runs once approved / before FD-05 enable):** owns
`MakhtootKit/Sources/MKStore/Referral/MKReferralRedemption.swift`,
`MakhtootKit/Sources/MKStore/Referral/MKReferralLedger.swift`; verify with
`swift test --no-parallel` extending `MKStoreTests` (redemption does not complete on code entry
alone; does complete on the new real action).

### Wave 5 gate
No commit — this wave produces decisions, not diffs. Once the founder answers each item above,
schedule the corresponding work packet(s) as a new Wave 6+ following the same ownership rules
(check the file-ownership matrix below before assigning — several packets reuse files already
touched in Waves 1–4, which is safe since those waves are already committed and this would be a
new, later wave).

---

## Coverage checklist — every finding, one wave

| ID | Wave | Agent | ID | Wave | Agent | ID | Wave | Agent | ID | Wave | Agent |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P-1 | 1 | 1.2 | S-1 | 1 | 1.4 | UX-1 | 5 | decision | EU-1 | 5 | decision |
| P-2 | 2 | 2.1 | S-2 | 1 | 1.3 | UX-2 | 3 | 3.2 | EU-2 | 5 | decision |
| P-3 | 2 | 2.1 | S-3 | 1 | 1.5 | UX-3 | 2 | 2.1 | EU-3 | 3 | 3.3 |
| P-4 | 1 | 1.1 | S-4 | 1 | 1.5 | UX-4 | 1 | 1.1 | EU-4 | 4 | 4.1 |
| P-5 | 2 | 2.1 | S-5 | 1 | 1.1 | UX-5 | 2 | 2.4 | EU-5 | 5 | decision |
| P-6 | 1 | 1.3 | S-6 | 1 | 1.3 | UX-6 | 3 | 3.2 | EU-6 | 5 | decision |
| P-7 | 1 | 1.3 | S-7 | 1 | 1.3 | UX-7 | 3 | 3.2 | EU-7 | 3 | 3.3 |
| P-8 | 2 | 2.2 | S-8 | 2 | 2.3 | UX-8 | 3 | 3.2 | EU-8 | 5 | decision |
| P-9 | 3 | 3.1 | S-9 | 2 | 2.3 |  |  |  | EU-9 | 2 | 2.3 |

| ID | Wave | Agent | ID | Wave | Agent |
|---|---|---|---|---|---|
| FC-1 | 1 | 1.1 | FC-6 | 0 | 0.2 |
| FC-2 | 1 | 1.1 | FC-7 | 5 | decision |
| FC-3 | 2 | 2.2 | FC-8 | 5 | decision |
| FC-4 | 5 | decision | FC-9 | 0 | 0.1 |
| FC-5 | 5 | decision |  |  |  |

44/44 findings accounted for. 34 execute across Waves 0–4, 10 are Wave 5 decisions with no early
sub-fixes.

---

## Appendix — file-ownership matrix (collision proof)

Every hot file (touched by ≥2 findings), which findings touch it, and which wave/agent owns the
write in each wave it appears. Waves not listed for a file mean no execution-wave agent writes it
that wave (approval-gated touches don't count — they don't execute in this plan).

| File | Findings (all) | Wave → Agent (execution only) |
|---|---|---|
| `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` | P-2,P-3,P-4,P-5,S-5,UX-4,EU-2\*,EU-3,EU-4,EU-6\*,FC-1,FC-2,FC-3\*\*,FC-7\* | W1→1.1 (FC-1,FC-2,P-4,S-5,UX-4) · W2→2.1 (P-2,P-3,P-5) · W3→3.3 (EU-3) · W4→4.1 (EU-4) |
| `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` | UX-2,UX-7,EU-4,FC-1,FC-2 | W1→1.1 (FC-1,FC-2) · W3→3.2 (UX-2,UX-7) · W4→4.1 (EU-4) |
| `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift` | P-2,UX-1\*,UX-3,EU-5\* | W2→2.1 (P-2,UX-3) |
| `MakhtootKit/Sources/MKCanvas/Gestures/GestureCoordinator.swift` | UX-4,EU-1\*,EU-2\*,EU-5\* | W1→1.1 (UX-4) |
| `MakhtootKit/Sources/MKRender/LayerTreeBuilder.swift` | P-1,P-9,UX-1\* | W1→1.2 (P-1) · W3→3.1 (P-9) |
| `MakhtootKit/Sources/MKPersistence/Internal/PersistenceSupport.swift` | P-6,S-6,S-7 | W1→1.3 (all three) |
| `MakhtootKit/Sources/MKPersistence/AssetStore.swift` | P-7,S-2,S-6 | W1→1.3 (all three) |
| `Makhtoot/AppShell/Navigation/RootShellView.swift` | S-4(optional,skipped),UX-5,EU-3 | W2→2.4 (UX-5) · W3→3.3 (EU-3) |
| `MakhtootKit/Sources/MKFonts/MKFontDownloader.swift` | S-9,EU-9,FC-5\* | W2→2.3 (S-9,EU-9) |
| `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift` | UX-2,UX-5,EU-6\* | W2→2.4 (UX-5) · W3→3.2 (UX-2) |
| `Makhtoot/AppShell/Scenes/Editor/ToolRailView.swift` | UX-2,UX-6,UX-7 | W3→3.2 (all three) |
| `MakhtootKit/Tests/MKRenderTests/PerfHarnessTests.swift` | P-1,P-9 | W1→1.2 (P-1) · W3→3.1 (P-9) |
| `MakhtootKit/Sources/MKPersistence/Undo/UndoStack.swift` | P-5,FC-3(read only) | W2→2.1 (P-5) |
| `MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift` | P-6,P-7 | W1→1.3 (both) |
| `MakhtootKit/Tests/MKPersistenceTests/AssetStoreTests.swift` | P-7,S-2 | W1→1.3 (both) |
| `MakhtootKit/Sources/MKRender/DegradationController.swift` | P-8,FC-3 | W2→2.2 (both) |
| `MakhtootKit/Sources/MKModel/MKNode.swift` | S-2,FC-7\* | W1→1.3 (S-2) |
| `MakhtootKit/Sources/MKSync/Engine/MKSyncEngineController.swift` | S-3,UX-5 | W1→1.5 (S-3) · W2→2.4 (UX-5) |
| `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift` | S-4,UX-5 | W1→1.5 (S-4) · W2→2.4 (UX-5, throw-site types only) |
| `MakhtootKit/Sources/MKFonts/MKCatalogManifestFetchService.swift` | S-8,FC-5\* | W2→2.3 (S-8) |
| `Makhtoot/AppShell/Scenes/Editor/MKAssetBrowserSheet.swift` | UX-2,UX-7 | W3→3.2 (both) |
| `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift` | UX-2,UX-7 | W3→3.2 (both) |
| `Makhtoot/AppShell/Scenes/Editor/TextInsertSheet.swift` | UX-2,UX-7 | W3→3.2 (both) |
| `Makhtoot/AppShell/Scenes/Onboarding/OnboardingView.swift` | UX-2,EU-8\* | W3→3.2 (UX-2) |
| `Makhtoot/AppShell/Scenes/Editor/EditorTourModel.swift` | UX-6,EU-1\* | W3→3.2 (UX-6 only) |
| `Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift` | UX-7,UX-8 | W3→3.2 (both) |
| `MakhtootKit/Sources/MKDesignSystem/Components/MKToolbarButton.swift` | UX-7,UX-8 | W3→3.2 (both) |
| `Makhtoot/AppShell/Scenes/Editor/CanvasHostView.swift` | EU-2\*,EU-6\* | — (both approval-gated, no execution-wave writer) |
| `Makhtoot/AppShell/Navigation/AppNavigationModel.swift` | EU-3,EU-7 | W3→3.3 (both) |
| `MakhtootKit/Sources/MKExport/ExportGate.swift` | FC-2(not touched — preset workaround used instead),FC-7\* | — (no execution-wave writer; FC-2 avoided touching it by design) |
| `Makhtoot.xcodeproj/project.pbxproj` | FC-6,FC-9(no change) | W0→0.2 (FC-6) |

\* approval-gated (Wave 5 decision) — does not execute in this plan, so it never collides with an
execution-wave writer of the same file.
\*\* FC-3 resolved to write only `DegradationController.swift`, not `EditorViewModel.swift` — by
design, to avoid a fourth `EditorViewModel.swift` writer in Wave 2.

No file has two writers in the same wave. Every non-approval finding's write set is owned by
exactly one agent in exactly one wave.
