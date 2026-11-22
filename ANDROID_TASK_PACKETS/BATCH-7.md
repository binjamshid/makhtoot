# BATCH-7 — App shell (Compose)

Batch 7 of 10 (spine §5). Dispatch the 9 assignments concurrently. Depends on **G6** and gates at **G7**
(`bash Scripts/android/gate.sh 7`).

Ports `Makhtoot/**` — the app target, 60 Swift files / 16,227 LOC on disk, read and measured
(`wc -l`) for this plan and matching spine §0/§3.1 exactly. Port scope (what this batch's nine
agents actually port) is **55 files / 15,280 LOC** — the on-disk total minus the 5 files
excluded per spine §3.1/§14 (see the Writer notes and Partition sums at the end of this file)
— from SwiftUI to Jetpack Compose. Forced RTL throughout (D-300/D-318). Substitution rules,
fixed for every agent in this batch:

- `NavigationStack` → Navigation-Compose or a typed custom navigator (Agent 7.1 picks and
  documents which; the recommendation is a typed custom navigator over `MkRoute`'s existing
  five-case sealed shape, since v1 has no deep links/back-stack complexity to justify full
  Navigation-Compose — see Agent 7.1's Tasks).
- `@Observable` view models → `ViewModel` + `StateFlow`.
- `.sheet`/`.popover` → `ModalBottomSheet`/`Dialog`/`DropdownMenu`/`Popup`.
- `UIViewControllerRepresentable`/`UIViewRepresentable` → `AndroidView` with a stable
  factory/update contract (construct once in `factory`, push state in `update` — never
  recreate the wrapped `View` on recomposition; this is the standard Compose-interop
  footgun and Agent 7.4 must get it right for the canvas host specifically).
- `PHPickerViewController` → Android Photo Picker (`ActivityResultContracts.PickVisualMedia`).
- Every UI string ships in Arabic only, RTL-first (`LayoutDirection.Rtl` forced per D-318,
  not inferred from device locale).

Two named audit findings from `AUDIT_2026-07-28.md` are load-bearing for this batch and are
called out in the specific agents where they land, not fixed generically:
- **FC-1** — bold/italic have no visual effect anywhere in the shipped iOS app (the real
  font provider was built in `AppContainer` and never passed to any consumer). Agent 7.1
  wires the composition root so this class of bug cannot recur by construction; Agent 7.7
  verifies the font-settings B/I toggle actually reaches rendering.
- **P-2** — the iOS editor runs four permanent polling loops (100 ms/150 ms/1 s/2 s, ~18
  main-thread wakeups/second) for the entire time a project is open, none gated on scene
  phase. Agent 7.3a must not reproduce this: Android ships event-driven from the start.

**Agent 7.3 is split into two agents (spine §5.2).** The parent scope owned ~4,500 Swift LOC
across the two largest files in the repo — `EditorViewModel.swift` (2,725 LOC) and
`EditorScene.swift` (1,067 LOC) — plus a from-scratch concurrency rewrite (P-2); not one unit
of work. **7.3a** owns `MkEditorViewModel` and the event-driven state that replaces the four
polling loops, with everything suspended on `onStop`. **7.3b** owns `MkEditorScene`, status
views, tool rail, zoom controls, and token strip. A citation of "7.3" without a suffix in
older material means "7.3a and 7.3b together."

Ground rules (spine §4) apply unchanged: exclusive file ownership, green
`testDebugUnitTest`+`lintDebug` before done, zero `check-no-stubs.sh` regressions, stub
count published and driven toward 0, contract-first, tests ported alongside behavior, impl
log per agent.

**Frozen convention (all nine agents):** `android/app/build.gradle.kts` and
`android/gradle/libs.versions.toml` are Batch 1.1-owned and stay frozen — Compose BOM,
Navigation-Compose, Coil (image loading), Photo Picker, and every other Compose-adjacent
dependency this batch needs were already declared there. No Batch 7 agent edits a build
file; escalate a genuinely missing dependency via `android/docs/CONTRACT_CHANGES.md`.

**`SettingsPlaceholderView`/`EditorPlaceholderView` — read this before touching either.**
Both names are misleading in the Swift source and must NOT be reproduced literally as
Kotlin filenames — `Scripts/android/check-no-stubs.sh` fails on any `Placeholder` hit from
G8 (advisory from G1). Concretely, from reading both files in full:
- `SettingsPlaceholderView.swift` (286 LOC) is **the real, fully-wired Settings root view**
  — its own header comment says so ("Replaces the stub that previously showed placeholder
  rows... The file retains the name... to avoid a pbxproj rename"). It contains live
  subscription/sync/privacy/general/fonts/support navigation, entitlement-state-driven UI,
  and a `#if DEBUG` developer-tools section. Agent 7.8 ports this as `MkSettingsRootView.kt`
  with all real content — not as a placeholder, because it never was one.
- `EditorPlaceholderView.swift` (82 LOC) is **genuinely dead code** — its own header
  comment says so ("SUPERSEDED... the real composition now lives in `EditorScene.swift`...
  it is dead code, unreferenced by any route... Safe to delete in a future cleanup pass").
  `grep -rn "EditorPlaceholderView"` across `Makhtoot/` confirms no live route constructs
  it. Neither Agent 7.3a nor Agent 7.3b ports this file to Kotlin at all — porting genuinely unreferenced
  dead code would violate ground rule 3's spirit for no reason. This is recorded here, not
  silently done, per the spine's own "no invented alternatives without noting them" spirit.

---

### Batch 7 · Agent 7.1 — Shell, DI, navigation

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the app entry point, composition root, and navigation layer. Wire every
dependency to its REAL Batch 2–6 implementation directly — unlike iOS's `AppContainer`,
which carries an incremental stub-to-real swap history across many work sessions, this is a
fresh port landing after every engine module already shipped real, so there is no swap log
to write and no stub-vs-real ambiguity to leave behind (FC-1's root cause).

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/App/MakhtootApp.swift` (83 LOC), `RootView.swift` (110), `UIChromeFontBootstrap.swift` (47) | App entry, root composable host, UI-chrome font registration |
| `Makhtoot/AppShell/AppContainer.swift` (298 LOC) | The composition root — read in full; its own header table is the authoritative list of every dependency this agent must wire for real |
| `Makhtoot/AppShell/Navigation/AppNavigationModel.swift` (159), `MKRoute.swift` (77), `RootShellView.swift` (420) | Navigation state, route enum, top-level routing view |
| `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift` (435) | `ProjectLibraryProviding` conformer bridging UI to the real persistence layer + constructing the sync engine controller |
| `Makhtoot/Stubs/{AlwaysPremiumEntitlementStub,NoOpAnalyticsRecorder,ProjectLibraryProviding,SyncStatusProviding}.swift` (25/13/312/45 LOC) | Protocol seams + the debug-only/no-op conformers that stay stubs by design (not stub-in-the-sense-of-unported) |
| `Makhtoot/AppShell/Support/MKAppSignpost.swift` (47), `MKArabicRelativeDate.swift` (43) | Perf-signpost naming registry, Arabic relative-date formatting |
| `MakhtootUITests/CompositionRootWiringTests.swift` (123 LOC) | The exact wiring-correctness test this agent's Kotlin test must mirror (FC-1 safety net) |
| `PRD.md` §2.1–2.3 (R-2.1…R-2.6, R-2.10…R-2.12), §3.1 (R-3.1…R-3.4) | Navigation and project-package/autosave requirements this layer must satisfy |
| `AUDIT_2026-07-28.md` FC-1 (lines ~41, ~857) | Full root-cause writeup of the bug this agent must not reintroduce |
| `ANDROID_SPINE.md` §2 D-300, D-301, D-302, D-308, D-318 | Platform/module/concurrency/persistence/locale decisions this file wires against |
| `android/mk-persistence/**`, `android/mk-model/**` (Batch 3), `android/mk-store/**`, `android/mk-sync/**`, `android/mk-analytics/**`, `android/mk-fonts/**` (Batch 6), `android/mk-assets/**` (Batch 5.5), `android/mk-foundation/**` (Batch 2.1, `MkFeatureFlags`/entitlement-provider protocol) | Real conformers this composition root wires — read their public APIs, do not edit |

**Owns (creates or edits — no other agent may touch these).**
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/app/MkMakhtootApplication.kt` (new — see Port map for the 1-Swift-file→2-Kotlin-files split)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/app/MkMainActivity.kt` (new, same split)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/app/MkRootView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/app/MkUiChromeFontBootstrap.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt` (spine §17 frozen path —
  package root, not `appshell/`; this is the single frozen location Agents 1.4/7.1/8.1 must all
  agree on, superseding the Batch 1.4 contract stub at this same path, named in this agent's
  supersedes-note below)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/navigation/MkAppNavigationModel.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/navigation/MkRoute.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/navigation/MkRootShellView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/persistence/MkPersistenceProjectLibrary.kt`
- `android/app/src/debug/kotlin/net/binjamshid/makhtoot/stubs/MkAlwaysPremiumEntitlementStub.kt`
  (`src/debug/` only — spine §17's cross-batch conflict table; 7.1's path must not read
  `src/main/`, since a debug-only entitlement stub in `main` would ship to Release)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkNoOpAnalyticsRecorder.kt` (main source set — honest pre-consent default, not a stand-in for unported code)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkProjectLibraryProviding.kt` (interface in `main`; any preview/test-only in-memory conformer it contains moves to `debug`/`test` — judge per the Swift file's own gating, document per-symbol in the impl log)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkSyncStatusProviding.kt` (same split rule)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/support/MkAppSignpost.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/support/MkArabicRelativeDate.kt`
- `android/app/src/androidTest/kotlin/net/binjamshid/makhtoot/MkCompositionRootWiringTest.kt`
- `android/app/src/main/res/xml/locales_config.xml` (D-318, owned here since it's this agent's locale-pinning task, not a Batch 1 scaffold concern)
- `android/docs/impl-log/BATCH-7.1.md`

**Never touch.** Every other Batch 7 agent's `appshell/scenes/**` path (7.2–7.8);
`android/mk-*/**` (Batch 2–6, read-only dependencies); `build.gradle.kts`/
`libs.versions.toml` (frozen, see header).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `App/MakhtootApp.swift` | 83 | `app/MkMakhtootApplication.kt` + `app/MkMainActivity.kt` | SwiftUI's single `@main App` struct has no one-class Android equivalent — `Application` (process-level init: locale pinning, `MkAppContainer` construction) and `ComponentActivity` (single-activity host for the Compose tree) are genuinely two different Android lifecycle objects. This is the one deliberate exception to the naming rule's "one Kotlin file per Swift file," recorded here rather than silently split. |
| `App/RootView.swift` | 110 | `app/MkRootView.kt` | Top composable: reads `MkAppContainer` (via `CompositionLocal`), renders `MkRootShellView`. |
| `App/UIChromeFontBootstrap.swift` | 47 | `app/MkUiChromeFontBootstrap.kt` | Registers the 9 bundled UI-chrome fonts (already true bundled TTFs, FOUNDATION §9/D-317 — no SF-Arabic dependency to replace) as Compose `FontFamily`s loaded from `assets/fonts/**` via the standard `Font(assetPath, ...)` API. Important distinction to document: UI-chrome text (labels, buttons) does NOT need the D-303 HarfBuzz/FreeType/`:mk-native` path — that path is exclusively for DOCUMENT/canvas text (`:mk-textengine`→`:mk-render`). Compose's own text layout is sufficient and correct for Arabic UI chrome. |
| `AppShell/AppContainer.swift` | 298 | `MkAppContainer.kt` (package root — spine §17 frozen path, NOT `appshell/`) | Composition root. Construct in the SAME dependency order the Swift file's comments establish and for the same reasons (shared-instance correctness, not just shared-protocol correctness): entitlement resolver (Batch 6.1) before purchase controller and before font-lock controller and before asset-browser model — each of those must observe the SAME resolver instance, never independently-constructed default instances (this is precisely the class of bug that produced two-different-resolver-instances risk on iOS, called out explicitly in the Swift header as "would have been a real bug, not just an accepted rough edge"). Exposed to the Compose tree via a `CompositionLocal` (`LocalMkAppContainer`), the direct analogue of `@Environment(AppContainer.self)` (Swift-side API name, cited verbatim — not renamed). No stub-matrix table is needed in the Kotlin header — every row is real from day one. |
| `AppShell/Navigation/AppNavigationModel.swift` | 159 | `appshell/navigation/MkAppNavigationModel.kt` | `@Observable` → `ViewModel` holding `StateFlow<MkRoute?>`/paywall-presentation state; `presentPaywall(...)` ports unchanged in shape. |
| `AppShell/Navigation/MKRoute.swift` | 77 | `appshell/navigation/MkRoute.kt` | Pure data — sealed class `MkRoute` (`Browser`, `Editor(projectId)`, `Settings`, `Paywall(context)`, `Onboarding`), `PaywallContext`, `PremiumFeature` with its `storeFeatureIdentifier` mapping to `MkStore`'s `MkPaywallContext` (Batch 6.1) — ports 1:1, no logic to adapt. |
| `AppShell/Navigation/RootShellView.swift` | 420 | `appshell/navigation/MkRootShellView.kt` | Top-level route dispatcher. **Decision this agent must make and document**: implement as a typed custom navigator (a `when (route)` dispatch over `MkRoute`'s five cases, each case rendering its scene composable directly or via `ModalBottomSheet`/`Dialog` per the `.sheet`/`.fullScreenCover` mapping) rather than full Navigation-Compose — `MkRoute`'s fixed five-case shape plus R-2.6's "no deep links/no widgets/no App Intents in v1" removes Navigation-Compose's main advantages (string-route deep linking, back-stack serialization) while its type-unsafe string-route API would be a strict downgrade from `MkRoute`'s existing type safety. Document the choice (and the Navigation-Compose alternative, for the founder to revisit if deep links are added post-v1) in the impl log. |
| `AppShell/Persistence/MKPersistenceProjectLibrary.swift` | 435 | `appshell/persistence/MkPersistenceProjectLibrary.kt` | `MkProjectLibraryProviding` conformer wired to the real `:mk-persistence` document package + metadata index (Batch 3.4–3.6); also constructs the sync engine controller (`makeSyncEngineController`, Batch 6.3) the same way `AppContainer` does today (Swift-side description), gated on `entitlementResolver.isEntitled(cloudSync)`. |
| `Stubs/AlwaysPremiumEntitlementStub.swift` | 25 | `stubs/MkAlwaysPremiumEntitlementStub.kt` (`src/debug/`) | `#if DEBUG`-gated on iOS → Android `debug` source set — **`src/debug/`, never `src/main/`** (spine §17). Preview/manual-QA only, never referenced from `MkAppContainer`'s production wiring path. |
| `Stubs/NoOpAnalyticsRecorder.swift` | 13 | `stubs/MkNoOpAnalyticsRecorder.kt` (main) | Ships in `main` — this is the honest pre-consent no-op conformer (D-320), not unported code; it stays exactly this simple on Android too. |
| `Stubs/ProjectLibraryProviding.swift` | 312 | `stubs/MkProjectLibraryProviding.kt` | Interface + (per the Swift file's size relative to its 45–65-LOC siblings) an in-memory test/preview conformer bundled in the same file — split the interface into `main` and the in-memory conformer into `debug`/`test` per Kotlin convention rather than reproducing one oversized file; document the split in the impl log since the Swift source doesn't cleanly `#if DEBUG`-gate the split itself. |
| `Stubs/SyncStatusProviding.swift` | 45 | `stubs/MkSyncStatusProviding.kt` | Interface + `StaticSyncStatusPublisher` default (always `.none` until Batch 6.3's real publisher is wired) — same main/debug split judgment as above, smaller file. |
| `AppShell/Support/MKAppSignpost.swift` | 47 | `appshell/support/MkAppSignpost.kt` | `os_signpost` → `androidx.tracing.Trace`; preserve the exact signpost NAMES from `TEST_MATRIX.md` §1.5's canonical registry so Batch 8.4's performance gate can locate equivalent trace sections cross-platform. |
| `AppShell/Support/MKArabicRelativeDate.swift` | 43 | `appshell/support/MkArabicRelativeDate.kt` | Arabic relative-date strings ("قبل يومين") — use platform ICU (`android.icu.text.RelativeDateTimeFormatter`, API 24+, D-304) with the `ar` locale rather than reimplementing formatting logic. |

**Tasks.**
1. Port `MkRoute.kt` first (pure data, zero dependencies).
2. Build `MkAppContainer.kt`, wiring every Batch 2–6 real conformer in the dependency order
   documented in the port map row above; expose it via `CompositionLocal`.
3. Implement D-318 locale pinning in `MkMakhtootApplication.kt`: `locales_config.xml` +
   `AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags("ar"))`,
   applied unconditionally regardless of device locale, plus `resConfigs("ar")` at the
   manifest/build level (already Batch 1.1's job if it touches `build.gradle.kts` — this
   agent only writes `locales_config.xml` and the runtime pinning call).
4. Implement `MkRootShellView.kt` as the typed navigator described in the port map, covering
   R-2.4's scene/state restoration (last open project restored, editor viewport zoom/pan/
   selection cleared but mode preserved) by reading the crash-recovery journal state Batch
   3.4 already exposes — this agent wires the restoration call, it does not reimplement the
   journal.
5. Port `MkPersistenceProjectLibrary.kt`, including the sync-engine-controller construction
   glue.
6. **FC-1 safety net.** Write `MkCompositionRootWiringTest.kt` mirroring
   `CompositionRootWiringTests.swift`: assert `MkAppContainer.fontProvider` is the real
   `MkFontRegistry`-backed provider (never `MkAlwaysPremiumEntitlementStub`'s font-adjacent
   equivalent or any stub type) in the `release`-equivalent construction path, and assert
   it is the SAME instance passed to every constructor inside `MkAppContainer.kt` that takes a
   font provider (`fontImporter`, and — by cross-reference, since this agent cannot edit
   Agent 7.3a/7.7's files — assert the TYPE of the parameter Batch 7.3a's `MkEditorViewModel`
   and Batch 7.7's font-settings surface declare matches `MkAppContainer`'s exposed property
   type, so a future accidental re-introduction of a locally-constructed stub fails this
   test at the composition-root boundary even before Batch 7.3a/7.7 exist to fail their own
   acceptance checks).
7. Port the four `Stubs/**` files with the main/debug split documented above.
8. Port `MkAppSignpost.kt`/`MkArabicRelativeDate.kt`.
9. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stub at
   `android/app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt` and every other
   Batch 1.4 stub path this agent's Owns list above lands a real implementation at — this
   agent's file set supersedes those stub bodies (`MkNotYetPorted("app.<symbol>")`) with the
   real composition root; name every superseded stub path explicitly in
   `android/docs/impl-log/BATCH-7.1.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green (unit-testable pieces: `MkAppNavigationModel`,
  `MkRoute`, `MkArabicRelativeDate`)
- `./gradlew :app:connectedDebugAndroidTest` green for `MkCompositionRootWiringTest.kt`
  (composition-root wiring needs an instrumented context, mirroring why the Swift original
  is a `MakhtootUITests` target test, not a unit test)
- `./gradlew :app:lintDebug` green
- Requirements covered: R-2.1, R-2.2, R-2.3, R-2.4, R-2.6, R-2.10, R-2.11, R-2.12, R-3.1,
  R-3.2, R-3.3, R-3.4
- Tests ported: `CompositionRootWiringTests.swift` → `MkCompositionRootWiringTest.kt`
  (FC-1 regression guard)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-7.1.md`

---

### Batch 7 · Agent 7.2 — Project browser

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the project browser: thumbnail grid, folders, search, new-project sheet,
export history sheet — the root scene of the app (R-2.1 item 1).

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift` (1,029 LOC) | The largest file in this agent's set — grid, folders, adaptive iPhone/iPad layout, search |
| `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserViewModel.swift` (155 LOC) | State holder talking to `MkProjectLibraryProviding` (Agent 7.1's interface, read-only here) |
| `Makhtoot/AppShell/Scenes/Browser/NewProjectSheet.swift` (335 LOC) | Canvas preset chooser feeding both new-project creation and (shared list) export presets |
| `Makhtoot/AppShell/Scenes/Browser/ExportHistorySheet.swift` (101 LOC) | Per-project export history list |
| `Makhtoot/AppShell/Scenes/Browser/MKSearchBarFontUpdater.swift` (56 LOC) | UIKit `UISearchBar`-appearance-proxy workaround — read for context, see Port map for why it is not ported |
| `PRD.md` §3 (R-3.5…R-3.12), FL-2 | Browser feature and new-project-flow requirements |
| `TEST_MATRIX.md` §4 T-MDL-9, T-MDL-10 | Tests this agent's Kotlin suite must have equivalents for |
| `android/app/.../appshell/navigation/MkRoute.kt`, `android/app/.../MkAppContainer.kt` (Agent 7.1 output, package root) | Route/DI surface this scene reads |
| `android/mk-persistence/**` (Batch 3) | `MetadataStore` search/folder/duplicate/export-history APIs this scene calls |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 7).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/browser/MkProjectBrowserView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/browser/MkProjectBrowserViewModel.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/browser/MkNewProjectSheet.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/browser/MkExportHistorySheet.kt`
- `android/app/src/test/kotlin/net/binjamshid/makhtoot/appshell/scenes/browser/MkProjectBrowserViewModelTest.kt`
- `android/docs/impl-log/BATCH-7.2.md`

**Never touch.** `MkAppContainer.kt` (package root), `appshell/navigation/**` (Agent 7.1);
`appshell/scenes/editor/**` (Agents 7.3a/7.3b–7.7); `appshell/scenes/settings/**`,
`appshell/scenes/paywall/**`, `appshell/scenes/onboarding/**` (Agent 7.8); any
`build.gradle.kts`/`libs.versions.toml` (frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ProjectBrowserView.swift` | 1,029 | `browser/MkProjectBrowserView.kt` | `LazyVerticalGrid` for the thumbnail grid (R-3.5, most-recently-edited first, list-view toggle on tablet); adaptive layout via `WindowSizeClass` (phone: stack + bottom toolbar; tablet/foldable: split/sidebar per D-300) replacing SwiftUI's iPhone/iPad size-class branching; folders (R-3.6, one level deep) as a filterable section; search (R-3.7) as a live-filter `TextField` reading the indexed searchable text from `:mk-persistence`'s metadata store, diacritic-insensitive by default. |
| `ProjectBrowserViewModel.swift` | 155 | `browser/MkProjectBrowserViewModel.kt` | `@Observable` → `ViewModel` + `StateFlow<List<ProjectSummary>>`; duplicate/delete/rename call straight through to the injected `MkProjectLibraryProviding` conformer (Agent 7.1's `MkPersistenceProjectLibrary`). |
| `NewProjectSheet.swift` | 335 | `browser/MkNewProjectSheet.kt` | `ModalBottomSheet`; preset grid (مربّع/قصة/منشور/غلاف/طباعة…) driving canvas size, same list R-13.12 uses for export presets — read that shared list from `:mk-model`/`:mk-export`, do not fork a second copy; custom W×H fields; background-color swatch (solid only, R-3.11/R-4.20). |
| `ExportHistorySheet.swift` | 101 | `browser/MkExportHistorySheet.kt` | `ModalBottomSheet` listing export-history rows (date, format, dimensions, preset, entitlement tier at export time) from the metadata index (R-3.10); tap re-opens the export sheet pre-configured (call site into Agent 7.6's export-adjacent surface — coordinate via `MkAppNavigationModel`, do not reach into Agent 7.6's owned files directly). |
| `MKSearchBarFontUpdater.swift` | 56 | *(intentionally not ported — see note)* | This file exists solely to work around SwiftUI's `.searchable(...)` having no font modifier for its native `UISearchBar`/`UISearchTextField` backing (an `appearance(whenContainedInInstancesOf:)` proxy plus a live view-hierarchy walk with retries). Compose's search `TextField`/`SearchBar` takes a `TextStyle`/`FontFamily` as a direct composable parameter — the underlying problem this file solves does not exist on Compose. Style the search field's `TextStyle` from `MkTheme`'s typography tokens directly inside `MkProjectBrowserView.kt`; this is a normal theming line, not a ported file. Recorded here so the omission is a documented decision, not a silently dropped file. |

**Tasks.**
1. Port `MkProjectBrowserViewModel.kt` first against Agent 7.1's `MkProjectLibraryProviding`
   interface (available from G6/Agent 7.1's contract, unblocking this agent to build against
   the interface even if 7.1's concrete wiring lands in the same batch dispatch).
2. Port `MkProjectBrowserView.kt`: grid, folders, list-view toggle, adaptive layout,
   diacritic-insensitive search.
3. Port `MkNewProjectSheet.kt`, sharing the canvas-preset list with the export-preset list
   (R-3.11/R-13.12) rather than duplicating it.
4. Port `MkExportHistorySheet.kt`.
5. Apply the search-field theming directly in `MkProjectBrowserView.kt` as the Compose
   replacement for `MKSearchBarFontUpdater`'s workaround (no separate file).
6. Port the browser-relevant assertions from `MKPersistenceTests`/`MkProjectBrowserView`
   coverage into `MkProjectBrowserViewModelTest.kt` (duplicate is a deep copy sharing nothing;
   Arabic search matches with/without tashkeel; export-history rows record format/dims/date).
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.2.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green
- `./gradlew :app:lintDebug` green
- Requirements covered: R-2.2 (adaptive layout), R-3.5, R-3.6, R-3.7, R-3.8, R-3.9, R-3.10,
  R-3.11, R-3.12
- Tests ported: T-MDL-9, T-MDL-10; FL-2 acceptance (steps 1–6 offline, package exists on
  disk, kill-app-after-step-5 relaunches into R-2.4 restoration — verified in concert with
  Agent 7.1's restoration wiring)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-7.2.md`

---

### Batch 7 · Agent 7.3a — `MkEditorViewModel`: event-driven state, P-2 rewrite, undo/redo, export orchestration

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent
(including 7.3b — disjoint file sets; 7.3b's `MkEditorScene.kt` calls this agent's view model
by its public API, this agent never touches 7.3b's composables)

**Mission.** Port `EditorViewModel.swift` (2,725 LOC — the largest single file in the whole
`Makhtoot/**` app target) as `MkEditorViewModel.kt`: mode/selection state, undo/redo, export
orchestration, autosave triggers. Ship it **event-driven from the start**: audit finding P-2
(four permanent polling loops, ~18 main-thread wakeups/second, none gated on scene phase) is
an iOS-only defect this port must not reproduce, not a behavior to preserve. This is the
single highest-LOC, highest-risk agent in Batch 7 — it is split out from the editor chrome
(7.3b) specifically so the P-2 rewrite and the 2,725-LOC view model get a full agent's
attention rather than competing for it with five straight-port composable files.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (2,725 LOC) | The largest file in the app target — mode/selection state, undo/redo, export orchestration, autosave triggers, the four P-2 polling loops (lines ~304-329, ~378-408, ~423-448) |
| `AUDIT_2026-07-28.md` P-2 (lines ~98-123) | Full polling-loop writeup: cadences, exact line numbers, the suggested `withObservationTracking`/delegate-callback fix (whose Compose equivalent is `Flow` collection, not a port of the polling itself) |
| `PRD.md` §2.3 (R-2.10…R-2.12), §4 (R-4.1, R-4.2, R-4.16…R-4.19) | Editor mode model, undo/redo requirements this view model implements (the underlying engine logic is Batch 4/5's, already ported) |
| `FOUNDATION.md` §5, D-115 | Performance budgets this agent's event-driven rewrite is directly in service of |
| `TEST_MATRIX.md` §6 T-CVS-8; §4 T-MDL-7 | Tests this agent's Kotlin suite must have equivalents for |
| `EXECUTION_PLAN_2026-07-28.md` Wave 1 Agent 1.1 (FC-2/P-4) | The already-fixed-on-iOS export-orchestration shape this agent must port (explicit `fontProvider`/`assetProvider`/`renderer` arguments), not an earlier pre-fix mental model |
| `android/mk-canvas/**`, `android/mk-render/**` (Batch 5, 4.6) | `StateFlow`-backed session/selection/zoom/memory-pressure sources this view model collects from — read their public APIs, do not edit |
| `android/mk-persistence/**` (Batch 3.5 output) | The command stack undo/redo wiring reads from |
| `android/app/.../appshell/scenes/editor/MkEditorScene.kt` (Agent 7.3b output) | The composable this view model is consumed by — read its call signature expectations, do not edit |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 6).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorViewModel.kt`
  (may split into `MkEditorViewModel.kt` + `MkEditorViewModelExportSupport.kt` if 2,725 ported
  LOC becomes unwieldy as one file — permitted, not mandated; document the split if taken)
- `android/app/src/test/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorViewModelTest.kt`
- `android/app/src/test/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorViewModelPollingRegressionTest.kt` (new — no Swift analogue, P-2 guard)
- `android/docs/impl-log/BATCH-7.3a.md`

**Never touch.** `appshell/scenes/editor/{MkEditorScene,MkEditorStatusViews,MkToolRailView,
MkZoomControlsView,MkTokenStripView}.kt` (Agent 7.3b); `EditorPlaceholderView.swift` is
explicitly NOT ported by this or any agent — see the batch-level note at the top of this
file; do not create an Android equivalent. `appshell/scenes/editor/{MkCanvasHostView,
MkCanvasRenderAdapter,MkArrangeInteractionAdapter,MkPathTextInteractionAdapter}.kt`
(Agent 7.4); `appshell/scenes/editor/{MkArrangeToolbarView,MkFormSelectorPopoverView,
MkPathEditToolbarView,MkPathOptionsPopoverView,MkPathGhostGuideOverlay}.kt` (Agent 7.5);
`appshell/scenes/editor/{MkInspectorPanelView,MkLayersPanelView,MkTextInsertSheet,
MkMergeDesignSheet,MkBackgroundImageSheet,MkBackgroundImageSupport}.kt` (Agent 7.6);
`appshell/scenes/editor/{MkFontBrowserSheet,MkFontSettingsSheet,MkAssetBrowserSheet}.kt`
(Agent 7.7); `appshell/scenes/editor/{MkEditorTourModel,MkEditorTourOverlay}.kt` (Agent 7.8);
`android/mk-canvas/**`, `android/mk-render/**` (Batch 4–5, frozen); any
`build.gradle.kts`/`libs.versions.toml` (frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `EditorViewModel.swift` | 2,725 | `editor/MkEditorViewModel.kt` | `@Observable` → `ViewModel` + multiple `StateFlow`s. **The P-2 rewrite is this file's central task** — see Tasks §2. Export orchestration (`exportForSharing`/`exportPNGForSharing`/etc., already fixed on iOS per `EXECUTION_PLAN_2026-07-28.md` Wave 1 Agent 1.1's FC-2/P-4 work — port the FIXED, gate-routed, font/asset-provider-explicit version, not an earlier shape) calls into `:mk-export` (Batch 5.6/5.7). |

**Tasks.**
1. **P-2 event-driven rewrite (the core task — do this before anything else in this agent's
   scope).** Do NOT port the four polling loops as timers. Replace each with the direct
   Compose/coroutines equivalent:
   - 100 ms mode+selection poll → collect `session.mode`/`session.selection.ids` as
     `StateFlow`s (both are already reactive sources in the ported `:mk-canvas` session
     type per Batch 5.1/5.3) via `collectAsState()` in the composable or
     `viewModelScope.launch { flow.collect { ... } }` in the view model — Compose
     recomposition IS the replacement for polling, not a faster poll.
   - 150 ms zoom-scale poll → a zoom-change callback/`StateFlow` exposed by Agent 7.4's
     canvas adapter (the direct analogue of the audit's suggested
     `scrollViewDidZoom`/`scrollViewDidScroll` delegate-callback fix — Android's
     `ScaleGestureDetector`/custom canvas view already fires a callback on scale change,
     per D-306; this agent consumes that callback, it does not implement gesture detection
     itself, that is Agent 7.4/Batch 5.2's territory).
   - 1 s memory-banner poll → collect `:mk-render`'s memory-pressure `Flow` (Batch 4.6)
     with `collectLatest`, not a timer.
   - Suspend ALL collectors on `onStop`: wrap every collector in
     `repeatOnLifecycle(Lifecycle.State.STARTED)` inside the composable's
     `LaunchedEffect`/the view model's lifecycle-aware scope — this is the direct,
     first-class Android mechanism for exactly what the audit recommended iOS gate on
     `scenePhase` and never did.
2. Write `MkEditorViewModelPollingRegressionTest.kt` asserting zero `delay(...)`-in-a-loop
   or `Timer`/`Handler.postDelayed`-recurring patterns exist in `MkEditorViewModel.kt`
   (a static/reflection-based grep-style test is acceptable — the point is a compiling,
   CI-enforced guard, not just a code-review promise, mirroring how Agent 7.1's
   `MkCompositionRootWiringTest` mechanically guards FC-1).
3. Port undo/redo UI-facing state (R-4.16…R-4.19: two toolbar chips' backing state,
   long-press operation-name lookup, mode-crossing undo is P0) against `:mk-persistence`'s
   already-ported command stack (Batch 3.5) — this agent owns the state and command-stack
   wiring; 7.3b's `MkEditorScene.kt` owns the toolbar chip composables that display it.
4. Port the export-orchestration methods in their POST-FC-2/P-4-fix shape (explicit
   `fontProvider`/`assetProvider`/`renderer` arguments at every `MkExportCoordinator`/
   `MkSnapshotRenderer` construction site — no bare default-constructed renderer that
   silently drops background images or fonts). Follow the corrected iOS behavior
   from Wave 1 work item 1.1.
5. Port the remaining `EditorViewModel.swift` state surface (mode/selection state, autosave
   triggers) not already covered by Tasks 1–4, mirroring the Swift file's public API shape so
   7.3b's `MkEditorScene.kt` can bind to it without any further changes to this agent's file.
6. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.3a.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green, including `MkEditorViewModelPollingRegressionTest`
- `./gradlew :app:lintDebug` green
- Requirements covered: R-2.10, R-2.11, R-2.12, R-4.1, R-4.2, R-4.16, R-4.17, R-4.18, R-4.19
- Tests ported: T-CVS-8 (undo across canvas gestures), T-MDL-7 (undo/redo command-stack
  integrity, integration level against the already-ported `:mk-persistence` stack)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0
- Zero polling timers of any kind in `MkEditorViewModel.kt`, verified by
  `MkEditorViewModelPollingRegressionTest.kt`, not merely asserted in prose

**Impl log.** `android/docs/impl-log/BATCH-7.3a.md`

---

### Batch 7 · Agent 7.3b — `MkEditorScene`, status views, tool rail, zoom controls, token strip

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent
(including 7.3a — disjoint file sets; this agent calls 7.3a's `MkEditorViewModel` by its
public API, never edits it)

**Mission.** Port the editor scene's composition and chrome: the scene shell that hosts the
canvas/toolbar/panels, plus four small straight-port status/control composables. This agent
has no P-2 polling to fix — that risk lives entirely in 7.3a's view model — so its scope is
mechanical composable translation over an already-event-driven state surface.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` (1,067 LOC) | Canvas host + toolbar + panels composition, replaces the dead `EditorPlaceholderView` as the real `.editor(projectID)` route target |
| `Makhtoot/AppShell/Scenes/Editor/EditorStatusViews.swift` (67 LOC), `ToolRailView.swift` (458), `ZoomControlsView.swift` (113), `TokenStripView.swift` (68) | Editor chrome composables |
| `PRD.md` §2.3 (R-2.10), §4 (R-4.4) | Mode-toolbar and zoom-indicator requirements these composables render |
| `TEST_MATRIX.md` §6 T-CVS-9 | Tests this agent's Kotlin suite must have equivalents for |
| `android/app/.../appshell/scenes/editor/MkEditorViewModel.kt` (Agent 7.3a output) | The `StateFlow`-backed state surface this scene binds to — read its public API, do not edit |
| `android/mk-canvas/**`, `android/mk-render/**` (Batch 5, 4.6) | `StateFlow`-backed session/selection/zoom/memory-pressure sources ultimately behind 7.3a's view model — read-only context, this agent binds through 7.3a, not directly |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 5).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorScene.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorStatusViews.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkToolRailView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkZoomControlsView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkTokenStripView.kt`
- `android/docs/impl-log/BATCH-7.3b.md`

**Never touch.** `appshell/scenes/editor/{MkEditorViewModel,MkEditorViewModelExportSupport}.kt`
(Agent 7.3a); `EditorPlaceholderView.swift` is explicitly NOT ported by this or any agent —
see the batch-level note at the top of this file; do not create an Android equivalent.
`appshell/scenes/editor/{MkCanvasHostView,MkCanvasRenderAdapter,MkArrangeInteractionAdapter,
MkPathTextInteractionAdapter}.kt` (Agent 7.4); `appshell/scenes/editor/{MkArrangeToolbarView,
MkFormSelectorPopoverView,MkPathEditToolbarView,MkPathOptionsPopoverView,
MkPathGhostGuideOverlay}.kt` (Agent 7.5); `appshell/scenes/editor/{MkInspectorPanelView,
MkLayersPanelView,MkTextInsertSheet,MkMergeDesignSheet,MkBackgroundImageSheet,
MkBackgroundImageSupport}.kt` (Agent 7.6); `appshell/scenes/editor/{MkFontBrowserSheet,
MkFontSettingsSheet,MkAssetBrowserSheet}.kt` (Agent 7.7); `appshell/scenes/editor/
{MkEditorTourModel,MkEditorTourOverlay}.kt` (Agent 7.8); `android/mk-canvas/**`,
`android/mk-render/**` (Batch 4–5, frozen); any `build.gradle.kts`/`libs.versions.toml`
(frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `EditorScene.swift` | 1,067 | `editor/MkEditorScene.kt` | Composes the canvas host (Agent 7.4's file, called not owned here), toolbar, layers/inspector panels, autosave indicator, memory-pressure banner, binding to Agent 7.3a's `MkEditorViewModel` by its public `StateFlow` surface. This is the real `.editor(projectID)` route target Agent 7.1's `MkRootShellView.kt` dispatches to. Also hosts the two undo/redo toolbar chips (R-4.16…R-4.19) whose backing state and command-stack wiring is 7.3a's; this file renders them and forwards taps. |
| `EditorStatusViews.swift` | 67 | `editor/MkEditorStatusViews.kt` | Small status composables (autosave indicator, memory banner content) — straight port, reading state from 7.3a's view model. |
| `ToolRailView.swift` | 458 | `editor/MkToolRailView.kt` | Mode toolbar (تحرير النص / تحريك / وضع التنسيق, R-2.10) — straight port, RTL layout. |
| `ZoomControlsView.swift` | 113 | `editor/MkZoomControlsView.kt` | Zoom indicator chip + tap-to-reset (R-4.4) — reads zoom state via `Flow` from Agent 7.4's canvas adapter (surfaced through 7.3a's view model), not the removed polling loop. |
| `TokenStripView.swift` | 68 | `editor/MkTokenStripView.kt` | Straight port. |

**Tasks.**
1. Port the four small chrome files first (`MkEditorStatusViews`, `MkToolRailView`,
   `MkZoomControlsView`, `MkTokenStripView`) — they're straight ports with no polling to fix,
   and establish the composable vocabulary `MkEditorScene.kt` assembles in Task 2.
2. Port `MkEditorScene.kt`, composing panels/toolbar/canvas-host call sites (calling into
   Agents 7.4–7.7's owned composables by their public signatures, not editing them) and
   binding all editor state through Agent 7.3a's `MkEditorViewModel` — never a locally
   re-derived copy of that state.
3. Wire the undo/redo toolbar chips (R-4.16…R-4.19: two chips, long-press shows operation
   name) as pure display/dispatch composables over 7.3a's already-ported command-stack state
   — this agent renders and forwards taps, it does not touch `:mk-persistence` directly.
4. Confirm `EditorPlaceholderView.swift` is NOT ported (no Kotlin file created for it,
   consistent with the batch-level note) and that `MkEditorScene.kt` is the sole real
   `.editor(projectID)` route target.
5. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.3b.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green
- `./gradlew :app:lintDebug` green
- Requirements covered: R-2.10, R-4.4
- Tests ported: T-CVS-9 (adaptive layout smoke, phone/tablet/foldable per D-300)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0
- `EditorPlaceholderView.swift` is confirmed NOT ported (no Kotlin file created for it) —
  recorded explicitly in the impl log, not silently omitted

**Impl log.** `android/docs/impl-log/BATCH-7.3b.md`

---

### Batch 7 · Agent 7.4 — Canvas host, render adapter, arrange adapter, path-text adapter

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the Compose↔engine bridge: the `AndroidView`-wrapped canvas host and the
three adapters that translate engine state (render/arrange/path-text) into interaction the
editor scene consumes.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Editor/CanvasHostView.swift` (44 LOC) | `UIViewControllerRepresentable` wrapper this agent replaces with `AndroidView` |
| `Makhtoot/AppShell/Scenes/Editor/MKCanvasRenderAdapter.swift` (188 LOC) | Bridges `:mk-canvas`/`:mk-render` state into the hosted view |
| `Makhtoot/AppShell/Scenes/Editor/MKArrangeInteractionAdapter.swift` (235 LOC) | Bridges Arrange Mode interaction (§6) into the canvas host |
| `Makhtoot/AppShell/Scenes/Editor/MKPathTextInteractionAdapter.swift` (347 LOC) | Bridges path-text interaction (§9) into the canvas host |
| `PRD.md` §4.1 (R-4.3), §6.1–6.2 (R-6.1, R-6.2, R-6.10), §9.1–9.2 (R-9.1…R-9.3, R-9.7) | Rendering-path, arrange-entry, and path-text requirements this bridge must satisfy |
| `TEST_MATRIX.md` §6 T-CVS-1, T-CVS-6, T-CVS-10; §5 T-TXT-8 | Tests this agent's Kotlin suite must have equivalents for |
| `ANDROID_SPINE.md` §2 D-305, D-306, D-307 | `RenderNode`/`Picture` rendering, custom `MkCanvasView`, transparent-`EditText`-overlay decisions this adapter layer wires against |
| `android/mk-canvas/**`, `android/mk-render/**`, `android/mk-arrange/**`, `android/mk-pathtext/**` (Batch 4–5) | The engine surfaces these three adapters bridge — read their public APIs, do not edit |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 6).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkCanvasHostView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkCanvasRenderAdapter.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkArrangeInteractionAdapter.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkPathTextInteractionAdapter.kt`
- `android/app/src/test/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkCanvasRenderAdapterTest.kt`
- `android/docs/impl-log/BATCH-7.4.md`

**Never touch.** `appshell/scenes/editor/{MkEditorViewModel,MkEditorViewModelExportSupport}.kt`
(Agent 7.3a); `appshell/scenes/editor/{MkEditorScene,MkEditorStatusViews,MkToolRailView,
MkZoomControlsView,MkTokenStripView}.kt` (Agent 7.3b); every other editor-scene agent's files
(7.5–7.7); `android/mk-canvas/**`, `android/mk-render/**`, `android/mk-arrange/**`,
`android/mk-pathtext/**` (Batch 4–5, frozen); any `build.gradle.kts`/`libs.versions.toml`
(frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `CanvasHostView.swift` | 44 | `editor/MkCanvasHostView.kt` | `UIViewControllerRepresentable` → `AndroidView(factory = { MkCanvasView(context) }, update = { view -> /* push state, never recreate */ })` — the stable factory/update contract this batch's header calls out. Getting `update` wrong (recreating the view on every recomposition) is the most common Compose-interop bug class; write it once, correctly, here. |
| `MKCanvasRenderAdapter.swift` | 188 | `editor/MkCanvasRenderAdapter.kt` | Bridges the immutable scene-snapshot render path (R-4.3, D-104/D-114-equivalent: committed text always renders through `:mk-textengine`→`:mk-render` so canvas and export are pixel-identical) into `MkCanvasView`'s `RenderNode`/`Picture` draw calls (D-305). |
| `MKArrangeInteractionAdapter.swift` | 235 | `editor/MkArrangeInteractionAdapter.kt` | Bridges Arrange Mode entry (R-6.1: explicit user action only, synchronous derivation) and per-node selection/manipulation (R-6.2, R-6.10) into the canvas host's gesture handling (Batch 5.2's gesture layer, called not owned here). |
| `MKPathTextInteractionAdapter.swift` | 347 | `editor/MkPathTextInteractionAdapter.kt` | Bridges live path-text editing (R-9.1…R-9.3: arc/circle/wave/freeform creation, live relayout on retype/font/path-edit) and arranged-path-text (R-9.7) into the canvas host. |

**Tasks.**
1. Port `MkCanvasHostView.kt` with the stable `AndroidView` factory/update contract as the
   first task — every other file in this agent's set and in Agent 7.3b's `MkEditorScene.kt`
   depends on this being correct.
2. Port `MkCanvasRenderAdapter.kt`, preserving the single-render-path invariant: this
   adapter must never diverge from the export render path (R-4.3) — the same invariant
   `:mk-export`'s Batch 5.6/5.7 tests already enforce at the engine level, this file is
   where that invariant is honored at the UI-bridge level.
3. Port `MkArrangeInteractionAdapter.kt`, wiring Arrange Mode entry/exit/selection through
   to `:mk-arrange` (Batch 4.1/4.2) without re-implementing any derivation/decomposition
   logic here — this file is a bridge, not a second copy of the engine.
4. Port `MkPathTextInteractionAdapter.kt`, wiring live and arranged path-text through to
   `:mk-pathtext` (Batch 4.3/4.4) the same way.
5. Write `MkCanvasRenderAdapterTest.kt` covering the `AndroidView` update-contract
   regression risk directly: assert that calling `update` twice with different scene
   snapshots does NOT reconstruct the underlying `MkCanvasView` (identity check on the
   wrapped view across two `update` calls).
6. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.4.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green
- `./gradlew :app:lintDebug` green
- Requirements covered: R-4.3, R-6.1, R-6.2, R-6.10, R-9.1, R-9.2, R-9.3, R-9.7
- Tests ported: T-CVS-1 (drag/resize/rotate with handles), T-CVS-6 (zoom/pan fidelity),
  T-CVS-10 (in-canvas text editing lifecycle), T-TXT-8 (typing overlay ↔ engine parity)
- Fixtures consumed: none — these are interaction/bridge tests, not golden-render tests
  (those are Batch 8.3's territory)
- Stub count for this agent's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-7.4.md`

---

### Batch 7 · Agent 7.5 — Arrange toolbar, form selector popover, path edit toolbar, path options, ghost guide overlay

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the Arrange Mode and path-text contextual toolbars — the UI surface for
the app's core differentiator (join-breaking, form selection, ligature decompose/recompose,
path controls).

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Editor/ArrangeToolbarView.swift` (189 LOC) | Level toggle, break-join, decompose/recompose, mark attach/detach, form selector, revert entry points (R-6.7) |
| `Makhtoot/AppShell/Scenes/Editor/FormSelectorPopoverView.swift` (191 LOC) | The four-contextual-forms selector (R-8.3) |
| `Makhtoot/AppShell/Scenes/Editor/PathEditToolbarView.swift` (111 LOC), `PathOptionsPopoverView.swift` (147) | Live path-text controls (R-9.4) |
| `Makhtoot/AppShell/Scenes/Editor/PathGhostGuideOverlay.swift` (78 LOC) | Frozen-path ghost guide for arranged path text (R-9.9) |
| `PRD.md` §6.2 (R-6.4, R-6.7), §8 (R-8.2, R-8.3, R-8.5, R-8.9…R-8.12), §9.1 (R-9.4, R-9.9) | Arrange/ligature/path-control requirements |
| `FOUNDATION.md` §7 (D-120's arrange-fidelity gate cross-reference) | The per-font fidelity block this toolbar's decompose action must respect |
| `TEST_MATRIX.md` §7.9/§7.13 (T-AR-31…33, T-AR-36…38 — arrange-fidelity block), §5 T-TXT-6 | Tests/manual-checklist items this agent's port must not regress |
| `android/mk-arrange/**`, `android/mk-pathtext/**` (Batch 4) | Engine surfaces these toolbars call into — read their public APIs, do not edit |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 6).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkArrangeToolbarView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkFormSelectorPopoverView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkPathEditToolbarView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkPathOptionsPopoverView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkPathGhostGuideOverlay.kt`
- `android/docs/impl-log/BATCH-7.5.md`

**Never touch.** Every other editor-scene agent's files (7.3a, 7.3b, 7.4, 7.6, 7.7);
`android/mk-arrange/**`, `android/mk-pathtext/**` (Batch 4, frozen — read-only
dependencies); any `build.gradle.kts`/`libs.versions.toml` (frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ArrangeToolbarView.swift` | 189 | `editor/MkArrangeToolbarView.kt` | Level toggle (حروف/أشكال, R-6.4), فك الارتباط/فك الوصلة/إعادة الوصلة/mark attach-detach/form selector/العودة إلى النص entry points (R-6.7) — straight composable port, calling `:mk-arrange` operations Batch 4.1/4.2 already implements. |
| `FormSelectorPopoverView.swift` | 191 | `editor/MkFormSelectorPopoverView.kt` | `.popover` → `Popup`/`DropdownMenu` per the batch header mapping; renders the letter's live-previewed forms (isolated/initial/medial/final, or fewer for non-connecting letters per R-8.5/T-TXT-6) in the composition's actual font — the live-preview requirement means this file loads the real font face, not a placeholder glyph. |
| `PathEditToolbarView.swift` | 111 | `editor/MkPathEditToolbarView.kt` | Start offset, side (above/below), spacing-on-path, reverse-direction controls (R-9.4) — straight port. |
| `PathOptionsPopoverView.swift` | 147 | `editor/MkPathOptionsPopoverView.kt` | `.popover` → `Popup`/`DropdownMenu`, same mapping as the form selector. |
| `PathGhostGuideOverlay.swift` | 78 | `editor/MkPathGhostGuideOverlay.kt` | Optional ghost-guide render for an arranged path composition (R-9.9) — canvas-space overlay, never rendered in export (this file draws on the Compose/canvas-adapter layer only, never touches `:mk-export`). |

**Tasks.**
1. Port `MkArrangeToolbarView.kt`, wiring every action to the already-ported `:mk-arrange`
   operations (Batch 4.1/4.2) — this file dispatches, it does not reimplement
   join-breaking/decompose/recompose logic.
2. Port `MkFormSelectorPopoverView.kt` with real live-font previews per letter, honoring
   R-8.5's "fewer than four forms" rule for non-connecting letters and the D-120/D-222
   arrange-fidelity gate's expectation that the UI never lies about what a font can
   actually render.
3. Port `MkPathEditToolbarView.kt`/`MkPathOptionsPopoverView.kt`.
4. Port `MkPathGhostGuideOverlay.kt`, explicitly excluding it from any export code path
   (verify by construction: this composable has no dependency on `:mk-export`'s render
   entry points at all, not merely "doesn't call export" by convention).
5. Manual-visual cross-check against the arrange-fidelity block (T-AR-31/32/33 +
   decompose/recompose round-trip T-AR-36…38, per D-222) at G7/G8 — this agent's port must
   not introduce a UI-level regression in a block that is otherwise an engine-level gate;
   record the cross-check in the impl log even though the block's automation lives in
   Batch 8.2.
6. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.5.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:lintDebug` green (this agent's files are composables over an
  already-tested engine surface; no new engine-level unit tests are owned here — UI-level
  interaction tests are Batch 8.6's territory)
- Requirements covered: R-6.4, R-6.7, R-8.2, R-8.3, R-8.5, R-8.9, R-8.10, R-8.11, R-8.12,
  R-9.4, R-9.9
- Tests ported: T-TXT-6 (non-joining letters yield only two forms — verified through this
  agent's form-selector UI, engine logic already tested in Batch 3.3); manual cross-check
  against T-AR-31/32/33, T-AR-36…38
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-7.5.md`

---

### Batch 7 · Agent 7.6 — Inspector panel, layers panel, text insert, merge design, background image

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the numeric inspector, layers panel, text-insert sheet, merge-design
sheet, and background-image sheet + its photo-picker support.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` (461 LOC) | Numeric X/Y/W/H/rotation + style fields, Arabic-Indic digit entry (R-10.6…R-10.10) |
| `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` (122 LOC) | Layer list, visibility/lock toggles, drag-reorder (R-10.1…R-10.5) |
| `Makhtoot/AppShell/Scenes/Editor/TextInsertSheet.swift` (425 LOC) | New Live/Path Text object creation surface |
| `Makhtoot/AppShell/Scenes/Editor/MergeDesignSheet.swift` (98 LOC) | Cross-project design merge |
| `Makhtoot/AppShell/Scenes/Editor/BackgroundImageSheet.swift` (263 LOC), `BackgroundImageSupport.swift` (145) | Photo/raster background import (premium-gated, R-4.20/R-11.6…R-11.7) |
| `PRD.md` §10 (R-10.1…R-10.10), §11.2 (R-11.6…R-11.12), §4.5 (R-4.20, R-4.21) | Layers/inspector and import requirements |
| `TEST_MATRIX.md` §6 T-CVS-3, T-CVS-4, T-CVS-5 | Tests this agent's Kotlin suite must have equivalents for |
| `android/mk-canvas/**` (Batch 5.3, selection/layers/inspector policy), `android/mk-assets/**` (Batch 5.5, imported-asset content-addressing) | Engine surfaces these panels bridge to |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 6).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkInspectorPanelView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkLayersPanelView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkTextInsertSheet.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkMergeDesignSheet.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkBackgroundImageSheet.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkBackgroundImageSupport.kt`
- `android/app/src/test/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkInspectorPanelFieldParsingTest.kt`
- `android/docs/impl-log/BATCH-7.6.md`

**Never touch.** Every other editor-scene agent's files (7.3a, 7.3b, 7.4, 7.5, 7.7);
`android/mk-canvas/**`, `android/mk-assets/**` (frozen, read-only dependencies); any
`build.gradle.kts`/`libs.versions.toml` (frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `InspectorPanelView.swift` | 461 | `editor/MkInspectorPanelView.kt` | Numeric fields (X/Y/W/H/rotation + style/transform fields per node type, R-10.6) accepting BOTH Arabic-Indic and European digit input (R-10.7) — a custom `VisualTransformation`/input-parsing layer, not Compose's default `TextField` numeric handling, since Compose has no built-in Arabic-Indic digit normalization; mixed-selection "—" display and steppers (±1/±10) per R-10.8. |
| `LayersPanelView.swift` | 122 | `editor/MkLayersPanelView.kt` | `LazyColumn` with drag-reorder (R-10.2), visibility/lock toggles (R-10.1), expandable Arranged Composition children (glyph/mark/ligature rows, R-10.3) — reorder writes straight through to the scene's z-order via `:mk-canvas`'s already-ported selection/layers policy (Batch 5.3), no reordering logic duplicated here. |
| `TextInsertSheet.swift` | 425 | `editor/MkTextInsertSheet.kt` | New Live/Path Text creation entry point — straight port. |
| `MergeDesignSheet.swift` | 98 | `editor/MkMergeDesignSheet.kt` | Straight port. |
| `BackgroundImageSheet.swift` | 263 | `editor/MkBackgroundImageSheet.kt` | Solid-color (all tiers) vs. photo/raster (premium-only, R-4.20/R-11.7) background picker; premium gate reads Agent 7.1's `MkAppContainer.entitlementProvider`. |
| `BackgroundImageSupport.swift` | 145 | `editor/MkBackgroundImageSupport.kt` | `PHPickerViewController` → Android Photo Picker (`ActivityResultContracts.PickVisualMedia`), the exact substitution named in this batch's header; content-addressed copy into the project package on selection (R-11.10), 50 MP downsample-on-import notice (R-11.11) delegated to `:mk-assets`' already-ported import pipeline (Batch 5.5), not reimplemented here. |

**Tasks.**
1. Port `MkInspectorPanelView.kt` with the Arabic-Indic/European dual-digit-entry
   `VisualTransformation`/parser as its own well-tested unit
   (`MkInspectorPanelFieldParsingTest.kt`), since this is the one piece of genuinely new
   input-handling logic in this agent's set (everything else is straight composable
   translation over an already-ported engine).
2. Port `MkLayersPanelView.kt`, wiring drag-reorder to `:mk-canvas`'s z-order API and
   expandable Arranged Composition child rows.
3. Port `MkTextInsertSheet.kt`, `MkMergeDesignSheet.kt`.
4. Port `MkBackgroundImageSupport.kt` onto the Android Photo Picker, then
   `MkBackgroundImageSheet.kt` on top of it, gating photo/raster selection on entitlement
   (R-11.7) with the same solid-colors-only free-tier fallback UI.
5. Write `MkInspectorPanelFieldParsingTest.kt`: both `٩٠` and `90` parse to the same numeric
   value; illegal input (negative width, letters) is rejected with a field-level error, not
   a crash (T-CVS-5).
6. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.6.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green
- `./gradlew :app:lintDebug` green
- Requirements covered: R-4.20, R-4.21, R-10.1, R-10.2, R-10.3, R-10.4, R-10.5, R-10.6,
  R-10.7, R-10.8, R-10.9, R-10.10, R-11.6, R-11.7, R-11.8, R-11.9, R-11.10, R-11.11, R-11.12
- Tests ported: T-CVS-3 (alignment guides/snapping — inspector-adjacent visual check),
  T-CVS-4 (layers panel reflects scene), T-CVS-5 (numeric inspector round trip)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-7.6.md`

---

### Batch 7 · Agent 7.7 — Font browser, font settings, asset browser sheets

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the font catalog browser, font settings sheet (incl. the bold/italic
toggle — audit finding FC-1's user-facing surface), and the asset browser sheet.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Editor/FontBrowserSheet.swift` (157 LOC) | Catalog browse/search/favorites (R-12.5…R-12.11) |
| `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift` (1,168 LOC) | Largest file in this agent's set — per-object font/size/style controls, including the B/I toggle that was inert app-wide on iOS until fixed (FC-1) |
| `Makhtoot/AppShell/Scenes/Editor/MKAssetBrowserSheet.swift` (288 LOC) | Bundled asset library browser (R-11.3) |
| `AUDIT_2026-07-28.md` FC-1 full writeup (lines ~857-…) | The bold/italic root cause — read in full before touching `MkFontSettingsSheet` |
| `PRD.md` §12.2 (R-12.5…R-12.11), §11.1 (R-11.3) | Font-catalog-UX and asset-browser requirements |
| `TEST_MATRIX.md` §10 T-FNT-1, T-FNT-2, T-FNT-7, T-FNT-8 | Tests this agent's Kotlin suite must have equivalents for |
| `android/mk-fonts/**` (Batch 3.7 registry/validator, Batch 6.5 catalog/lock), `android/mk-assets/**` (Batch 5.5) | Real font/asset providers this sheet must call — variant (bold/italic) resolution lives in `:mk-fonts`, already correct per Batch 3.7; this agent's job is to CALL it, not re-derive it |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 5).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkFontBrowserSheet.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkFontSettingsSheet.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkAssetBrowserSheet.kt`
- `android/app/src/androidTest/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkFontSettingsBoldItalicTest.kt` (new — FC-1 regression guard)
- `android/docs/impl-log/BATCH-7.7.md`

**Never touch.** Every other editor-scene agent's files (7.3a, 7.3b, 7.4, 7.5, 7.6);
`android/mk-fonts/**`, `android/mk-assets/**` (Batch 3.7/5.5/6.5, frozen — read-only
dependencies); any `build.gradle.kts`/`libs.versions.toml` (frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `FontBrowserSheet.swift` | 157 | `editor/MkFontBrowserSheet.kt` | Live previews, category chips (Naskh/Ruq'ah/Thuluth/Diwani/Kufi/Maghrebi/…, R-12.5), coverage badges (R-12.6), license-info deep-link to Agent 7.8's Licensing screen (R-12.7), premium download UX (size/progress/cancel/resumable, R-12.8) calling `:mk-fonts`' Batch 6.5 downloader. |
| `FontSettingsSheet.swift` | 1,168 | `editor/MkFontSettingsSheet.kt` | **FC-1 surface.** The bold/italic toggle must call through to the REAL font-variant resolver (`:mk-fonts`' `MkFontRegistry`/`MkFontProviding`, ported and correct since Batch 3.7) via the SAME font-provider instance `MkAppContainer.kt` exposes (Agent 7.1) — never a locally-constructed or system-font-fallback path. This is the file where FC-1's user-visible symptom ("bold/italic have no visual effect anywhere") would reappear if the wiring regresses; verified by `MkFontSettingsBoldItalicTest.kt` below, not just code review. |
| `MKAssetBrowserSheet.swift` | 288 | `editor/MkAssetBrowserSheet.kt` | Categorized RTL grid (أشكال/زخارف/إطارات/عناصر/خلفيات, R-11.3), search-by-Arabic-tag, favorites — calls `:mk-assets`' Batch 5.5 `MkAssetBrowserModel`/thumbnail renderer, premium-gated exactly as that model already resolves. |

**Tasks.**
1. Port `MkFontBrowserSheet.kt` against `:mk-fonts`' real registry/catalog/downloader.
2. Port `MkFontSettingsSheet.kt`, and as its FIRST wiring step (before anything else in this
   file), confirm the bold/italic control path: selecting Bold/Italic must resolve a
   variant via the font provider `MkAppContainer.kt` exposes, by PostScript name, with
   round-trip verification (mirroring `MKFontProviding.swift`'s own documented
   round-trip-verified resolution pattern on iOS) — not a `FontWeight.Bold`/`FontStyle.Italic`
   Compose synthetic-bold/italic fallback, which would silently reproduce FC-1's symptom in
   a new form (Compose CAN fake bold/italic by skewing/thickening glyphs when no real
   variant font is available, and that fake path must never be reached for a font that has a
   real bold/italic face in the catalog).
3. Write `MkFontSettingsBoldItalicTest.kt`: select text in a bundled font with real bold and
   italic faces (per the WS-09 catalog), tap B, assert the resolved glyph outlines differ
   from the non-bold render (pixel/outline diff, not just "no crash") — the direct Android
   analogue of the manual iOS verification step in Wave 1 work item 1.1, made into an automated,
   `connectedDebugAndroidTest`-run regression guard instead of a manual step this time.
4. Port `MkAssetBrowserSheet.kt` against `:mk-assets`' real browser model.
5. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.7.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:connectedDebugAndroidTest` green for `MkFontSettingsBoldItalicTest.kt`
- `./gradlew :app:lintDebug` green
- Requirements covered: R-11.3, R-12.5, R-12.6, R-12.7, R-12.8, R-12.9, R-12.10, R-12.11
- Tests ported: T-FNT-1 (bundled font registration at launch, verified through this sheet's
  catalog read), T-FNT-2 (catalog browsing/search/favorites), T-FNT-7 (license metadata
  deep-link target correctness), T-FNT-8 (character coverage badge correctness)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0
- FC-1 confirmed fixed: bold/italic visibly changes rendered glyphs in the font settings
  sheet's live preview AND in a subsequent canvas render of the same node (cross-checked
  against Agent 7.3a's `MkEditorViewModel` export path, not just this sheet's own preview)

**Impl log.** `android/docs/impl-log/BATCH-7.7.md`

---

### Batch 7 · Agent 7.8 — Settings, paywall, onboarding, editor tour

**Depends on:** G6 · **Parallel-safe with:** every other Batch 7 agent

**Mission.** Port the full Settings tree, the paywall, onboarding, and the editor tour.
`SettingsPlaceholderView.swift` is the real, fully-wired Settings root — port it as
`MkSettingsRootView.kt` with all real content (see the batch-level note at the top of this
file), never as a placeholder.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/AppShell/Scenes/Settings/SettingsPlaceholderView.swift` (286 LOC) | The real Settings root — subscription/sync/privacy/general/fonts/support navigation, `#if DEBUG` dev-tools section |
| `Makhtoot/AppShell/Scenes/Settings/GeneralSettingsView.swift` (296), `FontManagementView.swift` (265), `LicensingView.swift` (121), `LicenseFontDetailView.swift` (173), `PrivacyConsentView.swift` (168), `SupportSettingsView.swift` (86), `SyncSettingsView.swift` (147) | The seven settings sub-screens |
| `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` (444 LOC) | The one paywall implementation reused for every `PaywallContext` |
| `Makhtoot/AppShell/Scenes/Onboarding/OnboardingView.swift` (182 LOC) | First-launch 3-card + trial-explanation flow (R-2.9, FL-1) |
| `Makhtoot/AppShell/Scenes/Editor/EditorTourModel.swift` (58), `EditorTourOverlay.swift` (109) | Editor tour |
| `PRD.md` §14.2 (R-14.10…R-14.17), §15.2–15.3 (R-15.9, R-15.10), §17 (R-17.4…R-17.6), §18 (R-18.1…R-18.7), §20 (R-20.1…R-20.6), §2.2 (R-2.9) | Paywall/trial-copy/sync-disclosure/privacy/settings/onboarding requirements |
| `ANDROID_SPINE.md` §2 D-310 (Android↔Android-only sync disclosure), FDA-04 (uploader no-op disclosure) | The two spine-mandated disclosures this agent's `MkSyncSettingsView.kt`/`MkPrivacyConsentView.kt` must carry |
| `TEST_MATRIX.md` §12 T-SK-1, T-SK-7, T-SK-13, T-SK-18; §13 T-SYN-4, T-SYN-8; §14 T-ANL-1, T-ANL-2, T-ANL-4, T-ANL-5; §10 T-FNT-7 | Tests this agent's Kotlin suite must have equivalents for |
| `android/mk-store/**`, `android/mk-sync/**`, `android/mk-analytics/**`, `android/mk-fonts/**` (Batch 6) | Real conformers every screen in this agent's set reads state from |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 8).
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkSettingsRootView.kt` (renamed from `SettingsPlaceholderView` — see batch-level note; the old name is never used for the Kotlin file)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkGeneralSettingsView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkFontManagementView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkLicensingView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkLicenseFontDetailView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkPrivacyConsentView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkSupportSettingsView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkSyncSettingsView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/paywall/MkPaywallView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/onboarding/MkOnboardingView.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorTourModel.kt`
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/scenes/editor/MkEditorTourOverlay.kt`
- `android/app/src/test/kotlin/net/binjamshid/makhtoot/appshell/scenes/settings/MkSettingsRootViewTest.kt`
- `android/docs/impl-log/BATCH-7.8.md`

**Never touch.** Every other editor-scene agent's files (7.3a, 7.3b, 7.4–7.7, note
`MkEditorTourModel`/`MkEditorTourOverlay` live under the `editor/` path but are exclusively
this agent's — no collision since 7.3a/7.3b–7.7's editor-path file lists above never include
these two names); `appshell/scenes/browser/**` (Agent 7.2); `MkAppContainer.kt` (package root),
`appshell/navigation/**` (Agent 7.1); any `build.gradle.kts`/`libs.versions.toml` (frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `SettingsPlaceholderView.swift` | 286 | `settings/MkSettingsRootView.kt` | **Not a placeholder — see batch-level note.** Real Settings root: subscription section (entitlement-state-driven status label, upgrade/manage/restore actions per R-15.10's state-copy table), sync nav link, privacy nav link, general nav link, fonts nav link, support nav link; `#if DEBUG` dev-tools section (design-system gallery, shaping/path-text harnesses, fixture-project seeding) → Android `debug`-source-set-only composables, same gating intent as the Swift `#if DEBUG` block — these debug tools are internal and out of the same scope-of-porting judgment as the `App/Debug/**` files noted in this file's closing Writer note, so port them minimally (or omit if they'd require re-deriving iOS-only harnesses) and record the choice in the impl log. |
| `GeneralSettingsView.swift` | 296 | `settings/MkGeneralSettingsView.kt` | Canvas defaults, autosave prefs, snapping/haptics toggles (R-20.1) — straight port. |
| `FontManagementView.swift` | 265 | `settings/MkFontManagementView.kt` | Installed/downloaded/imported font management — straight port against `:mk-fonts`. |
| `LicensingView.swift` | 121 | `settings/MkLicensingView.kt` | Settings → الدعم → التراخيص list (R-20.2, Q66 canonical placement) — reads `:mk-fonts`' Batch 6.5 `MkLicensingDataSource`. |
| `LicenseFontDetailView.swift` | 173 | `settings/MkLicenseFontDetailView.kt` | Per-font license/attribution/foundry/coverage/source-link detail (R-20.2/R-20.3) — full OFL 1.1 text bundled, byte-identical to the captured license files in the repo. |
| `PrivacyConsentView.swift` | 168 | `settings/MkPrivacyConsentView.kt` | Analytics opt-in toggle (default OFF, R-18.1) — **carries the FDA-04 uploader-is-a-no-op-until-the-host-exists disclosure** (Agent 6.4's `MkStaticHostUploader`), stated plainly, not buried. |
| `SupportSettingsView.swift` | 86 | `settings/MkSupportSettingsView.kt` | Contact mailto link, Privacy Policy/Terms links (R-18.6), about/diagnostics export (R-20.5) — straight port. |
| `SyncSettingsView.swift` | 147 | `settings/MkSyncSettingsView.kt` | iCloud-sync-toggle equivalent for Drive sync (R-17.4…R-17.6) — **carries the D-310 Android↔Android-only disclosure**: this screen must state plainly that an iOS device and an Android device never see each other's synced projects, not merely omit the caveat. |
| `PaywallView.swift` | 444 | `paywall/MkPaywallView.kt` | One implementation reused for every `PaywallContext` (R-14.14/R-14.15); localized prices from `ProductDetails` (never hardcoded, R-14.10); mandatory close button, mandatory "استعادة المشتريات" footer link (R-14.13); Guideline-3.1.2-equivalent Play policy hygiene — title/duration/price adjacent to CTA (R-14.11, cross-ref Batch 9's `ANDROID_APP_STORE_CHECKLIST.md`, VERIFY-AT-SUBMISSION for the Play-specific policy text). |
| `OnboardingView.swift` | 182 | `onboarding/MkOnboardingView.kt` | 3 cards (اكتب/نسّق/صدّر) + trial-explanation card (R-2.9, FL-1), skippable at every card, shown-once flag in the metadata store. |
| `EditorTourModel.swift` | 58 | `editor/MkEditorTourModel.kt` | Tour step state machine — straight port. |
| `EditorTourOverlay.swift` | 109 | `editor/MkEditorTourOverlay.kt` | Tour overlay composable — straight port. |

**Tasks.**
1. Port `MkSettingsRootView.kt` first, establishing the navigation surface every other file
   in this agent's set is reached from; wire it against Agent 7.1's `MkAppContainer`
   `CompositionLocal` for entitlement state exactly as the Swift file's `.task` block does.
2. Port `MkPrivacyConsentView.kt` with the FDA-04 disclosure and `MkSyncSettingsView.kt` with
   the D-310 disclosure — both are spine-mandated, non-optional strings, not implementation
   details left to agent judgment.
3. Port `MkLicensingView.kt`/`MkLicenseFontDetailView.kt` against real captured license text
   (T-FNT-7: no invented license text, cross-checked against the repo's license files).
4. Port `MkGeneralSettingsView.kt`, `MkFontManagementView.kt`, `MkSupportSettingsView.kt`.
5. Port `MkPaywallView.kt` as the one reused implementation across all `PaywallContext`
   values, with real `ProductDetails`-sourced localized pricing (Agent 6.1's
   `MkProductCatalog`).
6. Port `MkOnboardingView.kt`, `MkEditorTourModel.kt`, `MkEditorTourOverlay.kt`.
7. Write `MkSettingsRootViewTest.kt` covering the entitlement-state-to-status-label mapping
   (R-15.10's full copy table — lifetime/subscribed/inGracePeriod/inBillingRetry/trial/free,
   all eight rows including revoked/refunded's silent-downgrade-no-accusatory-copy rule).
8. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-7.8.md` per spine §3.3.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest` green
- `./gradlew :app:lintDebug` green
- Requirements covered: R-2.9, R-14.10, R-14.11, R-14.12, R-14.13, R-14.14, R-14.15,
  R-14.16, R-14.17, R-15.9, R-15.10, R-17.4, R-17.5, R-17.6, R-18.1, R-18.2, R-18.3, R-18.4,
  R-18.5, R-18.6, R-18.7, R-20.1, R-20.2, R-20.3, R-20.4, R-20.5, R-20.6
- Tests ported: T-SK-1 (localized price display), T-SK-7 (restore reachable from
  Settings), T-SK-13 (revoked/refunded silent downgrade copy), T-SK-18 (status label
  correctness across the full precedence matrix), T-SYN-4/T-SYN-8 (sync settings
  disclosure + free-user-never-touches-sync), T-ANL-1/T-ANL-2/T-ANL-4/T-ANL-5 (consent
  default-off, nothing-uploads-without-consent, withdrawal, kill switch — all
  UI-surfaced through `MkPrivacyConsentView.kt`), T-FNT-7 (licensing screen content)
- Fixtures consumed: none
- Stub count for this agent's owned files reaches 0
- `SettingsPlaceholderView`'s literal name never appears in any Kotlin file path or class
  name in the output (verified by `check-no-stubs.sh`'s `Placeholder` grep passing
  clean for this agent's owned paths from this agent's own completion, not deferred to G8)

**Impl log.** `android/docs/impl-log/BATCH-7.8.md`

---

## Appendix — file-ownership matrix (collision proof)

| Owned path prefix | 7.1 | 7.2 | 7.3a | 7.3b | 7.4 | 7.5 | 7.6 | 7.7 | 7.8 |
|---|---|---|---|---|---|---|---|---|---|
| `android/app/.../app/{MkMakhtootApplication,MkMainActivity,MkRootView,MkUiChromeFontBootstrap}.kt` | ✔ | | | | | | | | |
| `android/app/.../MkAppContainer.kt` (package root, not `appshell/`) | ✔ | | | | | | | | |
| `android/app/.../appshell/navigation/**` | ✔ | | | | | | | | |
| `android/app/.../appshell/persistence/**` | ✔ | | | | | | | | |
| `android/app/.../stubs/**` | ✔ | | | | | | | | |
| `android/app/.../appshell/support/**` | ✔ | | | | | | | | |
| `android/app/.../appshell/scenes/browser/**` | | ✔ | | | | | | | |
| `android/app/.../appshell/scenes/editor/{MkEditorViewModel,MkEditorViewModelExportSupport}.kt` | | | ✔ | | | | | | |
| `android/app/.../appshell/scenes/editor/{MkEditorScene,MkEditorStatusViews,MkToolRailView,MkZoomControlsView,MkTokenStripView}.kt` | | | | ✔ | | | | | |
| `android/app/.../appshell/scenes/editor/{MkCanvasHostView,MkCanvasRenderAdapter,MkArrangeInteractionAdapter,MkPathTextInteractionAdapter}.kt` | | | | | ✔ | | | | |
| `android/app/.../appshell/scenes/editor/{MkArrangeToolbarView,MkFormSelectorPopoverView,MkPathEditToolbarView,MkPathOptionsPopoverView,MkPathGhostGuideOverlay}.kt` | | | | | | ✔ | | | |
| `android/app/.../appshell/scenes/editor/{MkInspectorPanelView,MkLayersPanelView,MkTextInsertSheet,MkMergeDesignSheet,MkBackgroundImageSheet,MkBackgroundImageSupport}.kt` | | | | | | | ✔ | | |
| `android/app/.../appshell/scenes/editor/{MkFontBrowserSheet,MkFontSettingsSheet,MkAssetBrowserSheet}.kt` | | | | | | | | ✔ | |
| `android/app/.../appshell/scenes/editor/{MkEditorTourModel,MkEditorTourOverlay}.kt` | | | | | | | | | ✔ |
| `android/app/.../appshell/scenes/settings/**` | | | | | | | | | ✔ |
| `android/app/.../appshell/scenes/paywall/**` | | | | | | | | | ✔ |
| `android/app/.../appshell/scenes/onboarding/**` | | | | | | | | | ✔ |
| `android/app/src/androidTest/.../MkCompositionRootWiringTest.kt` | ✔ | | | | | | | | |
| `android/app/src/androidTest/.../MkFontSettingsBoldItalicTest.kt` | | | | | | | | ✔ | |
| `android/app/src/test/.../appshell/scenes/browser/**` | | ✔ | | | | | | | |
| `android/app/src/test/.../appshell/scenes/editor/{MkEditorViewModelTest,MkEditorViewModelPollingRegressionTest}.kt` | | | ✔ | | | | | | |
| `android/app/src/test/.../appshell/scenes/editor/MkCanvasRenderAdapterTest.kt` | | | | | ✔ | | | | |
| `android/app/src/test/.../appshell/scenes/editor/MkInspectorPanelFieldParsingTest.kt` | | | | | | | ✔ | | |
| `android/app/src/test/.../appshell/scenes/settings/MkSettingsRootViewTest.kt` | | | | | | | | | ✔ |
| `android/app/src/main/res/xml/locales_config.xml` | ✔ | | | | | | | | |
| `android/docs/impl-log/BATCH-7.<k>.md` | 7.1 | 7.2 | 7.3a | 7.3b | 7.4 | 7.5 | 7.6 | 7.7 | 7.8 |

All `appshell/scenes/editor/` rows are disjoint by explicit file-name enumeration since six
different agents (7.3a/7.3b split plus 7.4–7.6 for editor files, 7.7 for the font/asset
sheets, and 7.8 for the two tour files) own files under that same directory — no agent's set
overlaps another's file names within it.

**Partition sums.** Port scope is **55 files / 15,280 LOC** (verified 2026-07-30 by direct
`find Makhtoot -name "*.swift" | wc -l` = 60 files / 16,227 LOC total, minus the 5 excluded
files below = 947 LOC, per spine §3.1). Per-agent LOC, summed from this file's own port-map
tables and cross-checked with `wc -l` against the real files: 7.1 = 2,114 (14 files); 7.2 =
1,676 (5 files — `MKSearchBarFontUpdater.swift`'s 56 LOC is folded into 7.2's theming line
rather than a separate Kotlin file, per that row's own note, but still counted in 7.2's
port-scope LOC since the file is real and not one of the 5 excluded); 7.3a = 2,725 (1 file);
7.3b = 1,773 (5 files); 7.4 = 814 (4 files); 7.5 = 716 (5 files); 7.6 = 1,514 (6 files); 7.7 =
1,613 (3 files); 7.8 = 2,335 (12 files). Total:
2,114+1,676+2,725+1,773+814+716+1,514+1,613+2,335 = **15,280**, matching the port-scope
figure exactly, with zero file counted twice and zero file omitted — every one of the 55
in-scope files above is claimed by exactly one agent, machine-verified (not just asserted)
against the repo's actual `Makhtoot/**/*.swift` listing.

> **Writer note 1 (file-count reconciliation — corrected).** Spine §3.1/§0 states the
> verified, `find`+`wc -l`-checked figures: `Makhtoot/**` on disk is **60 files / 16,227
> LOC**; port scope (what Batch 7 agents actually port) is **55 files / 15,280 LOC**, the
> difference being the 5 excluded files below (947 LOC). An earlier draft of this note
> attributed a discrepancy to "pre-existing repo drift" against a stale `16,905 LOC / 61
> files` figure — that was the wrong diagnosis. The real explanation is a different
> **denominator**: 16,227 is the on-disk total (includes the 5 excluded files), 15,280 is
> the port-scope total (excludes them). This file's own per-agent LOC sums, re-verified
> directly against the repo (see Partition sums above), total exactly 15,280 — the port-scope
> figure, not the on-disk one — with zero omission and zero double-count.
>
> **Writer note 2 (the five files with no home in any agent bullet).** `App/DesignSystemGallery.swift`
> (161 LOC), `App/Debug/PathTextHarnessView.swift` (389), `App/Debug/PerfHUDView.swift` (83),
> `App/Debug/ShapingHarnessView.swift` (232), and `AppShell/Scenes/Editor/EditorPlaceholderView.swift`
> (82) — **947 LOC across 5 files** — are excluded from this Android port entirely (spine
> §3.1/§14). The first four are `#if DEBUG`-only internal developer harnesses reachable only
> from `SettingsPlaceholderView`'s own `#if DEBUG` block; the fifth is genuinely dead code on
> iOS (its own header comment says so — see the batch-level note near the top of this file),
> superseded by `EditorScene.swift`. None of the five appear in any of the nine agent bullets
> this file specifies, and none backs any `R-<section>.<n>` requirement in `PRD.md` (they are
> developer tooling or dead code, not product surface). Rather than silently drop them or
> force them into an agent whose title doesn't match, they are recorded here as explicitly
> OUT OF SCOPE for this Android port — Android's own developer tooling, if wanted, is a
> future decision for the founder to make, not an implicit consequence of this plan. The
> master plan is being corrected to list all five in its own out-of-scope section so the cut
> is visible there too, not buried in this appendix alone. Agent 7.8's port map notes the one
> related judgment call (whether to port `MkSettingsRootView.kt`'s own small `#if DEBUG`
> section, distinct from these five larger excluded files, which stays that
> agent's call to record in its impl log).
