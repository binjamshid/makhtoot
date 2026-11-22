# Makhtoot (مخطوط) — FILE_MAP.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
## Exact Xcode Project + Swift Package Tree (Run 1)

Conforms to `FOUNDATION.md` (module map §2 is the authoritative skeleton; workstream
owners WS-01..WS-15 from §11) and `_input/BRIEF.md`. If this file and FOUNDATION.md
disagree, FOUNDATION.md wins.

Bundle id everywhere below is `net.binjamshid.makhtoot` — **PLACEHOLDER-FOUNDER-DECISION
FD-01** (real bundle id, team, repo name supplied by founder before distribution).

### Legend & conventions

- **WS-xx** — owning workstream packet (AGENT_TASK_PACKETS/WS-xx-*.md). Owner = the
  packet that creates and maintains the file; other packets touch it only via its
  public API.
- **Key public types** — the primary `public` declarations the file contributes to its
  module's API surface (internal helpers not listed).
- File counts per directory are stated in each section header and reconciled in the
  Coverage Check at the end.
- **Tests are supporting, not gating** (BRIEF "Engineering", founder Q59): unit-test
  files exist for every MakhtootKit target and run in CI-less local `swift test` /
  `xcodebuild test`, but v1 quality gates are: build success, performance profiling vs
  D-115 budgets, StoreKit sandbox tests, and the manual Arabic-script verification
  checklist (TEST_MATRIX.md). No test file below blocks a phase exit on its own.
- Naming: module prefix `MK`; one primary type per file, file named after it, except
  small enum/value clusters which are grouped (noted per file).
- All Swift files compile in Swift 6 language mode, strict concurrency
  (`.enableUpcomingFeature` not needed — tools 6.0 default).

---

## 1. Top-level repository layout

```
makhtoot/                                  ← repo root (founder will `git init`; no invented org/repo names)
├── Makhtoot.xcodeproj/                    ← app project (single app target `Makhtoot`)
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/
│       ├── Makhtoot.xcscheme              ← app scheme; StoreKit config attached (Makhtoot.storekit)
│       └── MakhtootKit.xcscheme           ← package aggregate scheme (build+test all kit targets)
├── Makhtoot/                              ← app target sources (§2)
├── MakhtootKit/                           ← local Swift package, all engine/feature modules (§4–§20)
├── FOUNDATION.md  PLAN.md  PRD.md  ARCHITECTURE.md  FILE_MAP.md
├── DEPENDENCY_GRAPH.md  TEST_MATRIX.md  APP_STORE_CHECKLIST.md  DECISIONS_LOG.md
├── AGENT_TASK_PACKETS/                    ← WS-01..WS-15 packets
├── RUN1_SELF_REVIEW.md
├── _input/                                ← BRIEF.md + digests
└── docs/                                  ← founder Q&A.pdf, makhtoot-market-study.md
```

No XcodeGen/Tuist/Fastlane manifests exist anywhere in the tree (D-101). No
third-party package references in `project.pbxproj` or `Package.swift`.

---

## 2. App target `Makhtoot` — full tree (85 Swift files + resources + config)

```
Makhtoot/
├── App/                                   (7 files)
│   ├── MakhtootApp.swift
│   ├── AppDelegate.swift
│   ├── AppEnvironment.swift
│   ├── AppRouter.swift
│   ├── RootView.swift
│   ├── LaunchGate.swift
│   └── ScenePhaseCoordinator.swift
├── Scenes/
│   ├── ProjectBrowser/                    (12 files)
│   │   ├── ProjectBrowserScene.swift
│   │   ├── ProjectBrowserViewModel.swift
│   │   ├── ProjectGridView.swift
│   │   ├── ProjectCellView.swift
│   │   ├── FolderSidebarView.swift
│   │   ├── FolderEditorSheet.swift
│   │   ├── ProjectSearchField.swift
│   │   ├── SearchResultsView.swift
│   │   ├── NewProjectSheet.swift
│   │   ├── ProjectContextMenuBuilder.swift
│   │   ├── ExportHistoryListView.swift
│   │   └── SyncStatusBadge.swift
│   ├── Editor/                            (8 files at root)
│   │   ├── EditorScene.swift
│   │   ├── EditorViewModel.swift
│   │   ├── CanvasHostView.swift
│   │   ├── EditorToolbar.swift
│   │   ├── EditorSecondaryBar.swift
│   │   ├── UndoRedoControls.swift
│   │   ├── MemoryWarningBanner.swift
│   │   └── EditorCommandBindings.swift
│   │   ├── Panels/                        (17 files)
│   │   │   ├── LayersPanel.swift
│   │   │   ├── LayerRowView.swift
│   │   │   ├── LayerReorderController.swift
│   │   │   ├── InspectorPanel.swift
│   │   │   ├── InspectorNumericField.swift
│   │   │   ├── TransformSection.swift
│   │   │   ├── StyleSection.swift
│   │   │   ├── StrokeShadowSection.swift
│   │   │   ├── TextSection.swift
│   │   │   ├── ArrangeSection.swift
│   │   │   ├── PathSection.swift
│   │   │   ├── ColorPickerPanel.swift
│   │   │   ├── SwatchGridView.swift
│   │   │   ├── FontPickerPanel.swift
│   │   │   ├── FontPreviewRow.swift
│   │   │   ├── AssetLibraryPanel.swift
│   │   │   └── AssetGridView.swift
│   │   ├── ArrangeUI/                     (6 files)
│   │   │   ├── ArrangeModeBar.swift
│   │   │   ├── JoiningFormSelectorView.swift
│   │   │   ├── LigatureActionsMenu.swift
│   │   │   ├── MarkBadgeOverlay.swift
│   │   │   ├── RevertConfirmationDialog.swift
│   │   │   └── GlyphLevelToggle.swift
│   │   ├── ImportUI/                      (4 files)
│   │   │   ├── ImagePickerBridge.swift
│   │   │   ├── FileImporterBridge.swift
│   │   │   ├── ImportErrorPresenter.swift
│   │   │   └── PhotoBackgroundGateView.swift
│   │   └── ExportUI/                      (6 files)
│   │       ├── ExportSheet.swift
│   │       ├── ExportPresetGrid.swift
│   │       ├── CustomDimensionsFields.swift
│   │       ├── ExportProgressView.swift
│   │       ├── ExportGateUpsellView.swift
│   │       └── ExportCompletionView.swift
│   ├── Settings/                          (12 files)
│   │   ├── SettingsScene.swift
│   │   ├── SettingsViewModel.swift
│   │   ├── SettingsRootView.swift
│   │   ├── SupportSectionView.swift
│   │   ├── LicensingScreen.swift
│   │   ├── FontLicenseDetailView.swift
│   │   ├── SubscriptionStatusView.swift
│   │   ├── RestorePurchasesRow.swift
│   │   ├── AnalyticsConsentView.swift
│   │   ├── SyncSettingsView.swift
│   │   ├── AboutView.swift
│   │   └── ReferralSection.swift
│   ├── Paywall/                           (8 files)
│   │   ├── PaywallScene.swift
│   │   ├── PaywallViewModel.swift
│   │   ├── PlanCardView.swift
│   │   ├── TrialCountdownView.swift
│   │   ├── BenefitsListView.swift
│   │   ├── PurchaseButton.swift
│   │   ├── ExpiryLockExplainerView.swift
│   │   └── LegalFooterView.swift
│   └── Onboarding/                        (5 files)
│       ├── OnboardingScene.swift
│       ├── OnboardingViewModel.swift
│       ├── OnboardingPageView.swift
│       ├── TrialIntroView.swift
│       └── FirstProjectPrompt.swift
├── Resources/
│   ├── ar.lproj/
│   │   ├── Localizable.strings            ← ALL UI strings, Arabic only (D-100, D-126)
│   │   └── InfoPlist.strings              ← Arabic CFBundleDisplayName مخطوط + usage strings
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/            ← placeholder glyph until FD-02 design run
│   │   ├── AccentColor.colorset/          ← madder-red accent from InkPaperTheme (FD-02 editable)
│   │   └── EditorSymbols/                 ← custom SF-Symbol-style vector glyphs for RTL editor chrome
│   ├── Makhtoot.storekit                  ← local StoreKit testing configuration (§3.3)
│   └── PrivacyInfo.xcprivacy              ← privacy manifest: no tracking, no required-reason APIs beyond UserDefaults/file-timestamp declarations
└── Config/
    ├── Info.plist                         ← key table §3.1
    ├── Makhtoot.entitlements              ← key table §3.2
    └── BuildSettings.md                   ← notes: SWIFT_VERSION=6, IPHONEOS_DEPLOYMENT_TARGET=18.0, dev region ar
```

### 2.1 `App/` (7 files) — owner WS-13 unless noted

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MakhtootApp.swift` | `@main` SwiftUI entry point; installs the RTL-only `ar` locale environment, injects `AppEnvironment`, hosts `RootView` in a single `WindowGroup`. | `MakhtootApp` | WS-13 |
| `AppDelegate.swift` | `UIApplicationDelegateAdaptor` for launch-time work SwiftUI cannot own: process-scope font registration kick-off (MKFonts), memory-warning forwarding to `MemoryPressureMonitor`, background-task wrap of emergency autosave. | `AppDelegate` | WS-13 |
| `AppEnvironment.swift` | Composition root. Constructs and wires every service singleton: `MKEntitlementResolver`, `TrialManager`, `FontRegistry`, `MetadataContainer`, `MKSyncEngine`, `ConsentManager`, theme. The only place concrete cross-module bindings (e.g., `SyncEntitlementGate` ← `MKEntitlementResolver`) are made. | `AppEnvironment` | WS-13 |
| `AppRouter.swift` | Observable navigation state: browser ⇄ editor ⇄ settings ⇄ paywall sheets; adaptive split (iPad sidebar) vs stack (iPhone) routing. | `AppRouter`, `AppRoute` | WS-13 |
| `RootView.swift` | Top-level switch over onboarding-needed / browser; presents paywall and memory banners globally; applies `layoutDirection(.rightToLeft)` guard for non-Arabic system locales. | `RootView` | WS-13 |
| `LaunchGate.swift` | First-launch sequence: start app-side 7-day trial via `TrialManager` (D-123, first app launch — Q37), decide onboarding presentation, replay crash-recovery journal before UI shows. | `LaunchGate` | WS-10 |
| `ScenePhaseCoordinator.swift` | Observes `scenePhase`; background → immediate autosave flush + journal sync (D-112); foreground → entitlement refresh + iCloud KVS trial reconcile. | `ScenePhaseCoordinator` | WS-13 |

### 2.2 `Scenes/ProjectBrowser/` (12 files) — owner WS-13

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ProjectBrowserScene.swift` | Browser screen: adaptive grid + folder sidebar (iPad) / collapsible (iPhone); toolbar with new-project, search, settings entry. | `ProjectBrowserScene` | WS-13 |
| `ProjectBrowserViewModel.swift` | Queries `MetadataContainer` (SwiftData) for projects/folders/search; drives duplicate, rename, move-to-folder, delete(trash-with-confirm); surfaces sync badge state per project. | `ProjectBrowserViewModel` | WS-13 |
| `ProjectGridView.swift` | LazyVGrid of `ProjectCellView` with thumbnail loading from `ThumbnailStore`; RTL grid ordering. | `ProjectGridView` | WS-13 |
| `ProjectCellView.swift` | One project card: thumbnail, name, modified date (Arabic calendar formatting), premium-content lock badge, sync badge. | `ProjectCellView` | WS-13 |
| `FolderSidebarView.swift` | Folder list (all/recents/user folders), counts, drag-target for move-to-folder. | `FolderSidebarView` | WS-13 |
| `FolderEditorSheet.swift` | Create/rename/delete folders; validates duplicate names. | `FolderEditorSheet` | WS-13 |
| `ProjectSearchField.swift` | Arabic-normalized search field (diacritic/hamza-insensitive fold via `RTLUtilities`). | `ProjectSearchField` | WS-13 |
| `SearchResultsView.swift` | Search results list bound to `SearchIndexer` queries; highlights matches. | `SearchResultsView` | WS-13 |
| `NewProjectSheet.swift` | Canvas preset chooser (social/story/status/wallpaper/print ratios + premium custom size, gated); creates `.makhtoot` package via `MKProjectDocument`. | `NewProjectSheet` | WS-13 |
| `ProjectContextMenuBuilder.swift` | Long-press/secondary-click menu: open, duplicate, rename, move, export history, delete. | `ProjectContextMenuBuilder` | WS-13 |
| `ExportHistoryListView.swift` | Per-project export history (format, size, date, preset) from `ExportHistoryModel`; re-export shortcut. | `ExportHistoryListView` | WS-13 |
| `SyncStatusBadge.swift` | Small badge view for per-project `SyncStatus` (synced/pending/conflict/off). | `SyncStatusBadge` | WS-11 |

### 2.3 `Scenes/Editor/` root (8 files)

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `EditorScene.swift` | Editor screen composition: canvas host center, toolbar top, panels trailing (iPad) / sheets (iPhone), arrange bar conditional; owns panel visibility state. | `EditorScene` | WS-13 |
| `EditorViewModel.swift` | `@MainActor` document session: holds open `MKProjectDocument`, current `MKScene` value, selection set, tool mode; funnels all mutations through `CommandStack`; publishes scene snapshots to canvas/renderer (D-102). | `EditorViewModel`, `EditorToolMode` | WS-13 |
| `CanvasHostView.swift` | `UIViewControllerRepresentable` wrapping `MKCanvasViewController`; bridges SwiftUI selection/tool state ↔ UIKit canvas callbacks. | `CanvasHostView` | WS-06 |
| `EditorToolbar.swift` | Top bar: back/title/undo-redo/arrange-toggle/export button; adapts to compact width. | `EditorToolbar` | WS-13 |
| `EditorSecondaryBar.swift` | Insert bar: text, shape, image, asset library, path-text; premium badges on gated inserts (photo background). | `EditorSecondaryBar` | WS-13 |
| `UndoRedoControls.swift` | Undo/redo buttons bound to `CommandStack` canUndo/canRedo; hold-to-scrub disabled in v1 (seam noted). | `UndoRedoControls` | WS-13 |
| `MemoryWarningBanner.swift` | Displays D-116 stage-2 banner "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا" (memory nearly full — autosaved) from `MemoryPressureMonitor` events. | `MemoryWarningBanner` | WS-07 |
| `EditorCommandBindings.swift` | Hardware-keyboard & menu commands (iPad): ⌘Z/⇧⌘Z, ⌘D duplicate, delete, arrow-nudge; RTL-aware arrow mapping. | `EditorCommandBindings` | WS-13 |

### 2.4 `Scenes/Editor/Panels/` (17 files)

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `LayersPanel.swift` | Layers list of scene nodes (text, arranged glyphs, marks, images, shapes) with visibility/lock toggles and reorder; virtualized rows for 5 000-node projects (D-115/116 safeguard). | `LayersPanel` | WS-13 |
| `LayerRowView.swift` | One layer row: type icon, name (editable), eye/lock buttons, child disclosure for groups and Arranged Compositions (glyph/mark/ligature children). | `LayerRowView` | WS-13 |
| `LayerReorderController.swift` | Drag-reorder → z-order `SceneCommand` emission; constrains reorders inside groups. | `LayerReorderController` | WS-13 |
| `InspectorPanel.swift` | Numeric/style inspector container; section stack switches on selection kind (node vs glyph vs mark vs path). | `InspectorPanel` | WS-13 |
| `InspectorNumericField.swift` | Reusable numeric field (Arabic-Indic or Latin digits per user keyboard), stepper, drag-to-scrub; commits via command emission. Built on `MKInspectorField` token component. | `InspectorNumericField` | WS-01 |
| `TransformSection.swift` | Editable X/Y/W/H/rotation (+ scale for glyph nodes) fields bound to selection; multi-select shows mixed-state dashes. | `TransformSection` | WS-13 |
| `StyleSection.swift` | Fill color, opacity slider for current selection; solid colors only v1 (Q34). | `StyleSection` | WS-13 |
| `StrokeShadowSection.swift` | Outline/stroke width+color and shadow (offset/blur/color/opacity) controls per BRIEF per-object styling. | `StrokeShadowSection` | WS-13 |
| `TextSection.swift` | Live Text controls: font (opens picker), size, kerning, tracking, baseline shift, line height (parent group), numeral policy, discretionary-ligature toggle (pre-arrange, D-108). | `TextSection` | WS-13 |
| `ArrangeSection.swift` | Arranged-selection controls: per-glyph transform fields, mark attach/detach toggle, joining-form entry point, ligature decompose/recompose entry, level toggle mirror. | `ArrangeSection` | WS-04 |
| `PathSection.swift` | Path Text controls: preset picker, path offset, flip side, spacing along path; edit-points mode toggle. | `PathSection` | WS-05 |
| `ColorPickerPanel.swift` | sRGB working-space picker (wheel + sliders + hex), P3-aware preview (D-117), recent colors; writes `MKSolidColor`. | `ColorPickerPanel` | WS-13 |
| `SwatchGridView.swift` | Named swatch library grid from `SwatchLibrary`; save-current-color. | `SwatchGridView` | WS-13 |
| `FontPickerPanel.swift` | Font catalog browser: categories (Naskh, Ruq'ah, Thuluth, Diwani, Kufi, Maghrebi, modern display, Qur'anic-style, handwriting, bilingual), search, favorites, download state, premium/locked badges, expiry-locked treatment (D-119). | `FontPickerPanel` | WS-09 |
| `FontPreviewRow.swift` | One catalog row rendering the preview string in the font itself (registered on demand), tags, favorite star, download/locked affordance. | `FontPreviewRow` | WS-09 |
| `AssetLibraryPanel.swift` | Bundled asset browser: shapes/ornaments/frames/calligraphic/patterns categories from `MKAssetCatalog`; drag-or-tap to place. | `AssetLibraryPanel` | WS-14 |
| `AssetGridView.swift` | Thumbnail grid of vector assets rendered via `VectorAssetDecoder` previews. | `AssetGridView` | WS-14 |

### 2.5 `Scenes/Editor/ArrangeUI/` (6 files) — owner WS-04

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ArrangeModeBar.swift` | Contextual bar shown when selection is a Live/Path Text object or Arranged Composition: enter-arrange (with derivation call), revert-to-text, level toggle host. | `ArrangeModeBar` | WS-04 |
| `JoiningFormSelectorView.swift` | Visual selector of isolated/initial/medial/final forms after an explicit join break; renders the actual reshaped glyph candidates from `FormResolver` (D-107), not abstract labels. | `JoiningFormSelectorView` | WS-04 |
| `LigatureActionsMenu.swift` | Menu on a `LigatureGroup` selection: decompose (fidelity default), decompose-to-default-forms (explicit opt-out, Q71), recompose. | `LigatureActionsMenu` | WS-04 |
| `MarkBadgeOverlay.swift` | Canvas-overlay badges marking detached tashkeel/marks and attach targets during mark drag. | `MarkBadgeOverlay` | WS-04 |
| `RevertConfirmationDialog.swift` | Confirmation dialog for revert-to-text: warns manual arrangement will be discarded (BRIEF Arrange Mode bullet); irreversible-action styling. | `RevertConfirmationDialog` | WS-04 |
| `GlyphLevelToggle.swift` | Toggle between shaped-glyph level and Unicode-letter level editing of an Arranged Composition; both lossless (BRIEF dual-level bullet). | `GlyphLevelToggle` | WS-04 |

### 2.6 `Scenes/Editor/ImportUI/` (4 files)

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ImagePickerBridge.swift` | PHPicker wrapper for raster image import as placeable assets (no photo-library permission needed with PHPicker); routes picked data into `AssetStore`. | `ImagePickerBridge` | WS-13 |
| `FileImporterBridge.swift` | `fileImporter` wrapper for SVG/PDF placeable imports and (premium) font files; UTType filters; hands fonts to `UserFontImporter`. | `FileImporterBridge` | WS-13 |
| `ImportErrorPresenter.swift` | Maps `FontsError`/import failures to specific Arabic error alerts (unsupported format, corrupt file, woff rejected…) per D-122. | `ImportErrorPresenter` | WS-09 |
| `PhotoBackgroundGateView.swift` | Premium gate interstitial for photo-background import; free tier = solid colors only (Q34); offers paywall. | `PhotoBackgroundGateView` | WS-10 |

### 2.7 `Scenes/Editor/ExportUI/` (6 files) — owner WS-08

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ExportSheet.swift` | Export flow root: format list with free/premium availability from `FormatCapabilities`, preset grid, quality/size summary, share destination. | `ExportSheet` | WS-08 |
| `ExportPresetGrid.swift` | Social/story/static-reel/messaging-status/wallpaper/print aspect presets at 2 MP baseline; premium custom entry point. | `ExportPresetGrid` | WS-08 |
| `CustomDimensionsFields.swift` | Premium exact-dimension fields (px/mm at 300 DPI), memory-estimate warning near hardware limits (Q76). | `CustomDimensionsFields` | WS-08 |
| `ExportProgressView.swift` | Progress for tiled/large exports with cancel; keeps screen awake during export. | `ExportProgressView` | WS-08 |
| `ExportGateUpsellView.swift` | Shown when free tier requests premium format/resolution or project contains premium content: replace-or-subscribe flow (D-119). | `ExportGateUpsellView` | WS-10 |
| `ExportCompletionView.swift` | Result card: file size, dimensions, share sheet / save; records to export history. | `ExportCompletionView` | WS-08 |

### 2.8 `Scenes/Settings/` (12 files)

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `SettingsScene.swift` | Settings navigation root (form style), sections: subscription, sync, analytics, support, about. | `SettingsScene` | WS-12 |
| `SettingsViewModel.swift` | Aggregates entitlement state, sync toggle state, consent state for the form; issues restore/manage-subscription actions. | `SettingsViewModel` | WS-12 |
| `SettingsRootView.swift` | The form body; hides `ReferralSection` unless `MKFeatureFlags.referralProgram` (default OFF, D-124). | `SettingsRootView` | WS-12 |
| `SupportSectionView.swift` | Support group: **Licensing** row (→ `LicensingScreen`), contact, App Store review link, version/diagnostics info. | `SupportSectionView` | WS-12 |
| `LicensingScreen.swift` | **Settings → Support → Licensing** (Q66): full list of bundled + downloaded fonts and bundled assets with license, attribution, foundry, commercial status, character coverage, source links from `LicenseRecord`/`AssetLicenseIndex`; ICC profile credit (FD-03). | `LicensingScreen` | WS-09 |
| `FontLicenseDetailView.swift` | Per-font detail: full license text (OFL.txt rendered), verification record date, coverage table, links. | `FontLicenseDetailView` | WS-09 |
| `SubscriptionStatusView.swift` | Current entitlement state with precedence-aware copy (lifetime/subscribed/grace/billing-retry/trial days left/free), manage-subscription deep link, expiry-lock explanation (Q27). | `SubscriptionStatusView` | WS-10 |
| `RestorePurchasesRow.swift` | Mandatory restore-purchases UI (D-113) with progress + result alerts. | `RestorePurchasesRow` | WS-10 |
| `AnalyticsConsentView.swift` | Opt-IN switch (default OFF) for anonymous aggregated font-usage analytics; consent explanation of exactly what is/never uploaded (D-125); versioned consent recording. | `AnalyticsConsentView` | WS-12 |
| `SyncSettingsView.swift` | Premium iCloud sync toggle, account status, quota errors, last-sync time; explains CloudKit-on-own-iCloud (no account/SIWA, Q77). | `SyncSettingsView` | WS-11 |
| `AboutView.swift` | App version, credits, privacy summary (no ads, no tracking), open-source font acknowledgements link into Licensing. | `AboutView` | WS-12 |
| `ReferralSection.swift` | Flag-gated referral UI: my code, enter-a-code, extensions earned (max 4); compiled always, rendered never while flag OFF. | `ReferralSection` | WS-10 |

### 2.9 `Scenes/Paywall/` (8 files) — owner WS-10

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `PaywallScene.swift` | Paywall sheet: plan cards, benefits, trial state, purchase CTA, restore link, legal footer. Reached from gates and settings. | `PaywallScene` | WS-10 |
| `PaywallViewModel.swift` | Loads `Product`s via `StoreClient` (monthly $2.99 / annual $29.99 / lifetime $89.99 (D-216) — Apple storefront-localized display prices only, never hardcoded), drives purchase & restore, maps errors to Arabic messaging. | `PaywallViewModel` | WS-10 |
| `PlanCardView.swift` | One plan card with localized price from `Product.displayPrice`, period, best-value badge (annual), lifetime distinction. | `PlanCardView` | WS-10 |
| `TrialCountdownView.swift` | App-side trial state display: `active(daysLeft)` countdown or `expired`; explains trial covers monthly+annual behavior (Q37). | `TrialCountdownView` | WS-10 |
| `BenefitsListView.swift` | Premium benefits list: PNG/SVG/print-PDF+CMYK, hi-res, premium+imported fonts, photo backgrounds, iCloud sync. | `BenefitsListView` | WS-10 |
| `PurchaseButton.swift` | Purchase CTA with in-flight state; disabled during `purchase()` await; success dismiss + entitlement refresh. | `PurchaseButton` | WS-10 |
| `ExpiryLockExplainerView.swift` | Post-expiry explainer: projects stay editable, premium/imported fonts lock, export falls to free matrix until re-subscribe or content replaced (Q27/Q41). | `ExpiryLockExplainerView` | WS-10 |
| `LegalFooterView.swift` | Terms/privacy links, auto-renew disclosure text required by App Review. | `LegalFooterView` | WS-15 |

### 2.10 `Scenes/Onboarding/` (5 files) — owner WS-13

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `OnboardingScene.swift` | First-launch pager (3 pages max), skippable; ends into browser with trial already started by `LaunchGate`. | `OnboardingScene` | WS-13 |
| `OnboardingViewModel.swift` | Page state + completion persistence (UserDefaults key `onboardingCompleted`). | `OnboardingViewModel` | WS-13 |
| `OnboardingPageView.swift` | One page: calligraphy-forward illustration slot (FD-02 assets), headline, body. | `OnboardingPageView` | WS-13 |
| `TrialIntroView.swift` | Communicates the 7-day full-premium trial started now; no purchase required to continue (Q37/Q41 framing). | `TrialIntroView` | WS-10 |
| `FirstProjectPrompt.swift` | Post-onboarding empty-state prompt to create the first project (preset sheet shortcut). | `FirstProjectPrompt` | WS-13 |

---

## 3. App configuration files

### 3.1 `Config/Info.plist` — key table (owner WS-15, document-type keys WS-02)

| Key | Value | Why |
|---|---|---|
| `CFBundleDevelopmentRegion` | `ar` | Arabic-only launch; dev region ar (D-100). |
| `CFBundleDisplayName` | `مخطوط` (via `InfoPlist.strings` ar) | Product identity. |
| `CFBundleIdentifier` | `$(PRODUCT_BUNDLE_IDENTIFIER)` → `net.binjamshid.makhtoot` **FD-01 confirmed** | Real id supplied by founder. |
| `CFBundleLocalizations` | `[ar]` | Only `ar.lproj` ships. |
| `UIFileSharingEnabled` | `YES` | Projects visible in Files/Finder — Documents-visible projects decision; users own their `.makhtoot` packages. |
| `LSSupportsOpeningDocumentsInPlace` | `YES` | Open `.makhtoot` in place from Files without import-copy; pairs with the key above. |
| `CFBundleDocumentTypes` | role Editor for UTI `net.binjamshid.makhtoot.project` | App opens its document packages (placeholder-derived UTI, FD-01). |
| `UTExportedTypeDeclarations` | `net.binjamshid.makhtoot.project`, ext `makhtoot`, conforms to `com.apple.package` | Declares the file-package document type (D-112). |
| `UIApplicationSceneManifest` | scene manifest; `UIApplicationSupportsMultipleScenes = NO` | Single-window v1; multi-window is a v2 seam. |
| `UILaunchScreen` | dict with background color only | SwiftUI-era launch screen; no storyboard file. |
| `UISupportedInterfaceOrientations` (iPhone) | portrait + landscape L/R | Adaptive editor. |
| `UISupportedInterfaceOrientations~ipad` | all four | iPad multitasking-friendly. |
| `NSPhotoLibraryAddUsageDescription` | Arabic string: saving exported images to Photos | Only add-permission; import uses PHPicker (no permission prompt). |
| `ITSAppUsesNonExemptEncryption` | `NO` | Only exempt HTTPS; skips export-compliance questionnaire per release. |

Explicitly **absent**: `NSPhotoLibraryUsageDescription` (PHPicker needs none),
`NSCameraUsageDescription`, `NSUserTrackingUsageDescription` (no tracking, no ads),
`UIRequiresFullScreen` (stays `NO`/absent), background modes (none needed — CloudKit
sync runs foreground + system push-less CKSyncEngine scheduling).

### 3.2 `Config/Makhtoot.entitlements` — key table (owner WS-15; CloudKit rows WS-11, KVS row WS-10)

| Entitlement key | Value | Why |
|---|---|---|
| `com.apple.developer.icloud-container-identifiers` | `[iCloud.net.binjamshid.makhtoot]` **FD-01 confirmed** | CloudKit container for premium project sync (D-112) and the analytics public DB (D-125). One container, private DB for sync, public DB for anonymous analytics batches. |
| `com.apple.developer.icloud-services` | `[CloudKit]` | CKSyncEngine only; NOT `CloudDocuments` (iCloud Drive/UIDocument sync was rejected, D-112). |
| `com.apple.developer.ubiquity-kvstore-identifier` | `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` | iCloud key-value store mirror of the trial-start timestamp (D-123, earliest-timestamp-wins across devices). |
| `aps-environment` | **absent** | No push notifications in v1; CKSyncEngine is used without CK subscriptions/pushes (foreground scheduling), documented in ARCHITECTURE §20. |
| `com.apple.developer.user-fonts` | **absent — deliberately** | The fonts capability (`app-usage`/`system-installation`) is only required for installing fonts system-wide or registering with persistent scope. Makhtoot registers all bundled/downloaded/imported fonts **per-process** via `CTFontManagerRegisterFontURLs(_:.process,_)` (D-122, amended by D-219), which needs no entitlement. Stating this here prevents an agent from "helpfully" adding the capability and triggering extra review scrutiny. |

One entitlements file for all configurations; Xcode maps the CloudKit environment
(Development/Production) automatically per build type. No separate Debug entitlements
file needed.

### 3.3 `Resources/Makhtoot.storekit` (owner WS-10)

Local StoreKit configuration for simulator/device testing without App Store Connect:

- Products: `net.binjamshid.makhtoot.premium.monthly` ($2.99/mo), `.premium.annual`
  ($29.99/yr) in subscription group `Makhtoot Premium`; `.premium.lifetime` ($89.99
  non-consumable). All ids confirmed (FD-01 applied).
- No introductory offers configured (D-123: app-side trial only, avoids double-trial
  divergence).
- Scenarios exercised via Xcode transaction manager: purchase, refund, expiry, billing
  retry, grace period (grace duration is VERIFY-AT-SUBMISSION), family-sharing toggle
  parked pending FD-06.
- Attached to `Makhtoot.xcscheme` run + test actions; StoreKit sandbox tests in
  TEST_MATRIX use it (these ARE a v1 gate, unlike unit suites).

---

## 4. `MakhtootKit/` — local Swift package

### 4.1 Top-level package tree

```
MakhtootKit/
├── Package.swift
├── Sources/
│   ├── MKFoundation/        (18 files)   §5
│   ├── MKModel/             (26 files)   §6
│   ├── MKTextEngine/        (18 files)   §7
│   ├── MKArrange/           (14 files)   §8
│   ├── MKPathText/          (10 files)   §9
│   ├── MKCanvas/            (22 files)   §10
│   ├── MKRender/            (16 files)   §11
│   ├── MKColor/             (9 files + Resources/Profiles)          §12
│   ├── MKExport/            (18 files)   §13
│   ├── MKFonts/             (18 files + Resources/Fonts, PremiumCatalog) §14
│   ├── MKPersistence/       (21 files)   §15
│   ├── MKSync/              (12 files)   §16
│   ├── MKStore/             (15 files + Referral/ 6 files + 2 docs) §17
│   ├── MKAnalytics/         (10 files)   §18
│   ├── MKDesignSystem/      (17 files)   §19
│   └── MKAssets/            (10 files + Resources/{Shapes,Ornaments,Frames,Patterns,Calligraphic}) §20
└── Tests/
    ├── MKFoundationTests/ … MKAssetsTests/   (16 test targets, 40 files) §21
```

### 4.2 `Package.swift` sketch (owner WS-01)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MakhtootKit",
    defaultLocalization: "ar",
    platforms: [.iOS(.v18)],
    products: [
        // One library product per module so the app links exactly what it needs
        // and DEPENDENCY_GRAPH.md layering is enforced by the build.
        .library(name: "MKFoundation",   targets: ["MKFoundation"]),
        .library(name: "MKModel",        targets: ["MKModel"]),
        .library(name: "MKTextEngine",   targets: ["MKTextEngine"]),
        .library(name: "MKArrange",      targets: ["MKArrange"]),
        .library(name: "MKPathText",     targets: ["MKPathText"]),
        .library(name: "MKCanvas",       targets: ["MKCanvas"]),
        .library(name: "MKRender",       targets: ["MKRender"]),
        .library(name: "MKColor",        targets: ["MKColor"]),
        .library(name: "MKExport",       targets: ["MKExport"]),
        .library(name: "MKFonts",        targets: ["MKFonts"]),
        .library(name: "MKPersistence",  targets: ["MKPersistence"]),
        .library(name: "MKSync",         targets: ["MKSync"]),
        .library(name: "MKStore",        targets: ["MKStore"]),
        .library(name: "MKAnalytics",    targets: ["MKAnalytics"]),
        .library(name: "MKDesignSystem", targets: ["MKDesignSystem"]),
        .library(name: "MKAssets",       targets: ["MKAssets"]),
    ],
    dependencies: [],   // D-101: zero third-party dependencies in v1
    targets: [
        .target(name: "MKFoundation"),
        .target(name: "MKModel",       dependencies: ["MKFoundation"]),
        .target(name: "MKFonts",       dependencies: ["MKFoundation", "MKPersistence"]),
        .target(name: "MKTextEngine",  dependencies: ["MKFoundation", "MKFonts"]),
        .target(name: "MKArrange",     dependencies: ["MKModel", "MKTextEngine"]),
        .target(name: "MKPathText",    dependencies: ["MKModel", "MKTextEngine"]),
        .target(name: "MKRender",      dependencies: ["MKModel", "MKTextEngine"]),
        .target(name: "MKCanvas",      dependencies: ["MKModel", "MKRender"]),
        .target(name: "MKColor",       dependencies: ["MKFoundation"],
                resources: [.copy("Resources/Profiles")]),
        .target(name: "MKExport",
                dependencies: ["MKModel", "MKRender", "MKColor", "MKFonts", "MKStore"]),
        .target(name: "MKPersistence", dependencies: ["MKModel", "MKFoundation"]),
        .target(name: "MKSync",        dependencies: ["MKPersistence", "MKStore"]),
        .target(name: "MKStore",       dependencies: ["MKFoundation"]),
        .target(name: "MKAnalytics",   dependencies: ["MKFoundation", "MKPersistence"]),
        .target(name: "MKDesignSystem", dependencies: ["MKFoundation"]),
        .target(name: "MKAssets",      dependencies: ["MKModel"],
                resources: [.copy("Resources")]),
        // MKFonts resources: bundled families + premium catalog sample manifest
        // (declared on the MKFonts target above in the real file:)
        //   resources: [.copy("Resources/Fonts"), .copy("Resources/PremiumCatalog")]

        // Test targets — supporting evidence, NOT v1 gates (Q59).
        .testTarget(name: "MKFoundationTests",   dependencies: ["MKFoundation"]),
        .testTarget(name: "MKModelTests",        dependencies: ["MKModel"]),
        .testTarget(name: "MKTextEngineTests",   dependencies: ["MKTextEngine"]),
        .testTarget(name: "MKArrangeTests",      dependencies: ["MKArrange"]),
        .testTarget(name: "MKPathTextTests",     dependencies: ["MKPathText"]),
        .testTarget(name: "MKCanvasTests",       dependencies: ["MKCanvas"]),
        .testTarget(name: "MKRenderTests",       dependencies: ["MKRender"]),
        .testTarget(name: "MKColorTests",        dependencies: ["MKColor"]),
        .testTarget(name: "MKExportTests",       dependencies: ["MKExport"]),
        .testTarget(name: "MKFontsTests",        dependencies: ["MKFonts"]),
        .testTarget(name: "MKPersistenceTests",  dependencies: ["MKPersistence"]),
        .testTarget(name: "MKSyncTests",         dependencies: ["MKSync"]),
        .testTarget(name: "MKStoreTests",        dependencies: ["MKStore"]),
        .testTarget(name: "MKAnalyticsTests",    dependencies: ["MKAnalytics"]),
        .testTarget(name: "MKDesignSystemTests", dependencies: ["MKDesignSystem"]),
        .testTarget(name: "MKAssetsTests",       dependencies: ["MKAssets"]),
    ],
    swiftLanguageModes: [.v6]
)
```

### 4.3 Target-membership / linking rules (mirrors FOUNDATION §2 dependency column)

- **App target `Makhtoot`** links ALL sixteen library products. It is the only place
  where every module meets; concrete cross-module adapters live in
  `App/AppEnvironment.swift`, never inside the package.
- **Layering (must match DEPENDENCY_GRAPH.md):**
  - `MKFoundation` depends on nothing (Foundation/os only).
  - `MKModel` → MKFoundation only. Pure value types; imports no UIKit/CoreText.
  - `MKTextEngine` → MKFoundation + MKFonts (font handles). Note: via
    MKFonts→MKPersistence this transitively links persistence; MKTextEngine itself
    imports only the `FontHandle` API surface — enforced by review, documented in
    DEPENDENCY_GRAPH.md.
  - `MKArrange`, `MKPathText`, `MKRender` → MKModel + MKTextEngine.
  - `MKCanvas` → MKModel + MKRender (UIKit lives here and in MKRender's layer code only).
  - `MKColor` → MKFoundation.
  - `MKExport` → MKModel, MKRender, MKColor, MKFonts, MKStore — the MKStore edge is
    consumed **only** through the `ExportEntitlementProviding` protocol
    (entitlement queries; no purchase/UI symbols referenced), per FOUNDATION §2
    "MKStore (entitlement queries via protocol)".
  - `MKFonts` → MKFoundation + MKPersistence (catalog/favorites/download state store).
  - `MKPersistence` → MKModel + MKFoundation. SwiftData appears only here.
  - `MKSync` → MKPersistence + MKStore (protocol-consumed `SyncEntitlementProviding`).
  - `MKStore` → MKFoundation. StoreKit 2 appears only here.
  - `MKAnalytics` → MKFoundation + MKPersistence (counter storage). CloudKit types
    appear in MKSync and MKAnalytics only.
  - `MKDesignSystem` → MKFoundation. SwiftUI tokens/components; no model imports.
  - `MKAssets` → MKModel (asset → node placement types).
- **Resource-bundle rule:** font files, ICC profile, and vector assets are SPM
  `.copy` resources inside their owning module bundle (`Bundle.module`), NOT app-target
  resources — keeps license files adjacent to their payloads and modules self-contained.
- **No upward imports**: any import that would reverse an arrow above is a build error
  by construction (SPM target deps) — this is the enforcement mechanism D-101 relies on
  in place of external lint tooling.

---

## 5. `Sources/MKFoundation/` (18 files) — owner WS-01 unless noted

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `Transform2D.swift` | Decomposed 2-D transform value (position, rotation, scale, anchor) with compose/invert/lerp and CGAffineTransform bridging; the canonical node transform representation (D-111: decomposed, not raw matrix). | `Transform2D` | WS-01 |
| `GeometryMath.swift` | Angle normalization, vector ops, rect fitting/aspect math shared by canvas, path text, export presets. | `GeometryMath` (enum namespace) | WS-01 |
| `RectAlgebra.swift` | Union/inset/snapped-rect helpers, handle-point enumeration for selection bounds. | `RectAlgebra`, `HandlePoint` | WS-06 |
| `RTLUtilities.swift` | RTL helpers: Arabic text folding for search (diacritic/hamza-insensitive), Arabic-Indic ↔ Latin digit transforms, direction probing of strings. | `RTLUtilities`, `NumeralForm` | WS-01 |
| `Identifiers.swift` | Phantom-typed UUID wrappers so node/project/font/asset ids cannot be cross-assigned. | `MKID<Tag>`, `NodeID`, `ProjectID`, `FontID`, `AssetID`, `ClusterID` | WS-01 |
| `MKError.swift` | Root error protocol with Arabic user-message + technical code; error-code registry ranges per module. | `MKErrorProtocol`, `MKErrorCode` | WS-01 |
| `MKLog.swift` | `os.Logger` wrappers per subsystem/category; signpost helpers for the D-115 performance gates (profiling hooks are a v1 gate). | `MKLog` | WS-07 |
| `MKFeatureFlags.swift` | Compile-time + local runtime feature flags; `referralProgram` defaults **OFF** (D-124, Q78) and is server-independent; `metalRenderer`, `multiPage`, `templates` seams default OFF. | `MKFeatureFlags` | WS-01 |
| `MemoryPressureMonitor.swift` | DispatchSource memory-pressure events + periodic `os_proc_available_memory` sampling; publishes D-116 ladder stages (70 % / 85 % / critical) as an AsyncStream. | `MemoryPressureMonitor`, `MemoryStage` | WS-07 |
| `MemoryBudget.swift` | Budget arithmetic: peak-editor-memory threshold (<60 % of available before degradation), export-size estimator inputs. | `MemoryBudget` | WS-07 |
| `MonotonicClock.swift` | Monotonic time source (`clock_gettime` CLOCK_MONOTONIC_RAW wrapper) used by the trial clock-rollback guard (D-123) and gesture coalescing timing. | `MonotonicClock` | WS-10 |
| `Debouncer.swift` | Actor-based debounce/throttle utilities used by autosave (≤2 s, D-112) and search. | `Debouncer` | WS-02 |
| `FileLocations.swift` | Canonical container paths: Documents (user-visible projects), Application Support (metadata store, downloaded fonts), Caches (bitmap tiles), tmp (export staging). | `FileLocations` | WS-02 |
| `ContentHash.swift` | SHA-256 content addressing for imported assets and fonts (dedup store keys, D-112/D-122). | `ContentHash` | WS-02 |
| `SchemaVersion.swift` | `schemaVersion` integer type + comparison; starts at 1 (FOUNDATION §0). | `SchemaVersion` | WS-02 |
| `ArabicLocale.swift` | Fixed `ar` locale/calendar/number formatters for UI; single place that owns locale constants (dev region ar). | `ArabicLocale` | WS-01 |
| `SendableAtomics.swift` | Small `Sendable` atomic box + once-flag utilities for engine services under strict concurrency (D-102). | `AtomicBox`, `OnceFlag` | WS-01 |
| `SequenceExtensions.swift` | Chunking, stable-partition, keyed-dedup helpers used by run extraction and tiling. | extensions | WS-01 |

## 6. `Sources/MKModel/` (26 files) — owner WS-02 unless noted

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKScene.swift` | Root scene value: canvas spec, background ref, ordered top-level nodes, schemaVersion; immutable value tree with copy-on-write storage (D-111); single canvas per project (multi-page seam documented here). | `MKScene` | WS-02 |
| `MKNode.swift` | The node enum: `.group`, `.liveText`, `.pathText`, `.arranged`, `.shape`, `.image`, `.background` with shared header (id, transform, z, opacity, style, locked, hidden, name) and payload structs. | `MKNode`, `NodeHeader` | WS-02 |
| `NodeTransform.swift` | Node-level transform wrapper over `Transform2D` + flip flags; world/local conversion helpers for nested groups. | `NodeTransform` | WS-02 |
| `NodeStyle.swift` | Per-object style: fill (solid v1), stroke (width/color/join), shadow (offset/blur/color/opacity); applies to nodes AND individual glyph/mark nodes (BRIEF per-object styling). | `NodeStyle`, `StrokeStyle`, `ShadowStyle` | WS-02 |
| `SolidColor.swift` | sRGB component color value stored in documents (+ optional named-swatch ref) per D-117; conversion to display/CMYK lives in MKColor, not here. | `MKSolidColor` | WS-02 |
| `GroupNode.swift` | Group payload: children array, group line-height property for text groups (line height lives on parent group per BRIEF). | `GroupNode` | WS-02 |
| `LiveTextNode.swift` | Live Text payload: source string, `TextStyle`, paragraph direction, numeral policy, ligature feature toggles, layout box; reflowable by definition. | `LiveTextNode` | WS-02 |
| `PathTextNode.swift` | Path Text payload: source string + style + owning `MKBezierPathData` + path offset/side; live (reflowable) until arranged (D-110). | `PathTextNode` | WS-02 |
| `ArrangedTextNode.swift` | Arranged node payload: an `ArrangedComposition` + the retained `SourceTextBackup`; never auto-reflows (BRIEF). | `ArrangedTextNode` | WS-02 |
| `ArrangedComposition.swift` | The arranged structure: glyph nodes, mark nodes, ligature groups, bidi metadata (`bidiLevel` + visual index per node, D-109), original line metrics; provenance-complete so level switching loses nothing. | `ArrangedComposition` | WS-04 |
| `GlyphNode.swift` | One arranged glyph: glyph id, `FontReference`, outline-path ref, position/advance, `Transform2D`, `NodeStyle`, `JoiningForm`, source codepoints + cluster id, joining state. | `GlyphNode`, `JoiningState` | WS-04 |
| `MarkNode.swift` | One tashkeel/Qurʼanic mark: mark codepoint(s), attached-base `NodeID?`, relative offset (captured GPOS result, D-105), follow-base flag, own transform/style; detachable/movable (Q11 full marks). | `MarkNode` | WS-04 |
| `LigatureGroup.swift` | Ligature membership: combined glyph node id, constituent codepoints, decomposable flag, stored original-ligature glyph for recomposition (D-108). | `LigatureGroup` | WS-04 |
| `JoiningForm.swift` | `isolated/initial/medial/final` enum + resolved glyph id pairing (D-107). | `JoiningForm`, `ResolvedForm` | WS-04 |
| `SourceTextBackup.swift` | Reversible backup: original source string, full `TextStyle` state, path data if path-text, creation date; consumed by revert-with-confirmation. | `SourceTextBackup` | WS-04 |
| `ShapeNode.swift` | Vector shape payload: shape kind (rect/ellipse/line/polygon/asset-path), path data, style. | `ShapeNode`, `ShapeKind` | WS-02 |
| `ImageNode.swift` | Placed raster/SVG/PDF asset: `AssetReference`, natural size, crop rect, premium flag (photo background marking feeds D-119 gating). | `ImageNode` | WS-02 |
| `BackgroundNode.swift` | Canvas background: solid color (free) or image asset (premium, Q34); exactly one per scene. | `BackgroundNode` | WS-02 |
| `TextStyle.swift` | Text styling: `FontReference`, size, kerning, tracking, baseline shift, fill, per-run overrides map; feature settings mirror (`dlig`/`calt` toggles). | `TextStyle` | WS-02 |
| `FontReference.swift` | Stable font pointer: catalog `FontID` + PostScript name + variation coords; resolves via MKFonts at runtime; survives font-unavailable (lock/expiry) states with lastKnown metrics stub. | `FontReference` | WS-09 |
| `AssetReference.swift` | Content-addressed asset pointer (`ContentHash` + original filename + media type) into the document `assets/` store. | `AssetReference` | WS-02 |
| `Provenance.swift` | Provenance records tying arranged nodes to source: codepoint ranges, cluster map slice, shaping context hash — the "switching level loses nothing" contract (BRIEF). | `GlyphProvenance`, `ClusterRecord` | WS-04 |
| `CanvasSpec.swift` | Canvas size/preset descriptor + preset catalog data (social/story/status/wallpaper/print ratios; 2 MP baseline math). | `CanvasSpec`, `CanvasPreset` | WS-02 |
| `SceneCoding.swift` | Codable conformances with stable keys, forward-tolerant decoding (unknown node kinds → preserved opaque blobs), schemaVersion envelope. | `SceneCodingEnvelope` | WS-02 |
| `SceneMigration.swift` | Migration runner v(n)→v(n+1); v1 ships identity migration + harness so schema evolution is testable from day one. | `SceneMigrator`, `MigrationStep` | WS-02 |
| `NodeQueries.swift` | Pure queries over the tree: find-by-id, hit-order enumeration, premium-content-present scan (feeds D-119), text-content extraction for search indexing. | `NodeQueries` | WS-02 |

## 7. `Sources/MKTextEngine/` (18 files) — owner WS-03

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `AttributedTextBuilder.swift` | Builds `NSAttributedString` from `TextStyle`/`LiveTextNode`: font, kerning/tracking, baseline shift, paragraph style (base direction default RTL), numeral policy, feature settings (D-103 input side). | `AttributedTextBuilder` | WS-03 |
| `ShapingSession.swift` | The shaping capture facade: string+style in → `ShapedLine[]` out via CTTypesetter/CTLine/CTRun; `Sendable` service, cacheable, pure w.r.t. inputs (D-102/D-103). | `ShapingSession`, `MKShaper` | WS-03 |
| `LineLayoutEngine.swift` | Multi-line layout for Live Text boxes: line breaking via CTTypesetter suggest-break, line stacking with group line-height, alignment in RTL space. | `LineLayoutEngine` | WS-03 |
| `RunExtractor.swift` | Per-run extraction: `CTRunGetGlyphs/Positions/Advances/StringIndices`, attributes, `kCTRunStatusRightToLeft` → `ShapedRun` values (D-103). | `RunExtractor` | WS-03 |
| `ShapedTypes.swift` | Value types of the capture: `ShapedLine`, `ShapedRun`, `ShapedGlyph` (glyph id, position, advance, string indices, font). | `ShapedLine`, `ShapedRun`, `ShapedGlyph` | WS-03 |
| `ClusterMap.swift` | Bidirectional codepoint ↔ cluster ↔ glyph map built from string indices (D-105); ligature-candidate detection (>1 codepoint → 1 glyph). | `ClusterMap` | WS-03 |
| `BidiRunMap.swift` | Preserves visual run order + RTL status + bidi level per run; paragraph base direction handling (D-109). | `BidiRunMap` | WS-03 |
| `JoiningAnalyzer.swift` | Per-letter joining analysis from Unicode Joining_Type + neighbor context: computes each glyph's `JoiningState` for provenance. | `JoiningAnalyzer` | WS-03 |
| `FormResolver.swift` | The ZWJ technique (D-107): reshapes a single letter in synthetic ZWJ context (e.g., ZWJ+ح+ZWJ) through the same font and harvests the glyph for each of the four forms; never uses presentation-form codepoints. | `FormResolver` | WS-03 |
| `GlyphOutlineProvider.swift` | Glyph → `CGPath` via `CTFontCreatePathForGlyph`, with bounds, caching keyed by (font, glyph, size); feeds render + SVG/PDF outline output. | `GlyphOutlineProvider` | WS-03 |
| `MarkClassifier.swift` | Classifies combining marks (Mn/Me; U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED Qurʼanic annotations) and captures base-relative offsets from shaped positions (D-105). | `MarkClassifier` | WS-03 |
| `LigatureDetector.swift` | Identifies mandatory (lam-alif) and discretionary/contextual ligature clusters; produces pre-`LigatureGroup` records with constituent codepoints. | `LigatureDetector` | WS-03 |
| `FontFeatureControl.swift` | Core Text feature settings mapping (`kLigaturesType`, OpenType `dlig`/`calt`) for pre-arrangement ligature toggling (D-108). | `FontFeatureControl` | WS-03 |
| `NumeralPolicy.swift` | Arabic-Indic vs Latin numeral handling in mixed runs (BRIEF typing bullet); locale-independent explicit policy enum. | `NumeralPolicy` | WS-03 |
| `MetricsProvider.swift` | Font metrics (ascent/descent/leading/x-height) for overlay matching (D-104) and baseline math. | `MetricsProvider` | WS-03 |
| `ShapingCache.swift` | LRU cache of shaping results keyed by (string, style-hash, font, width); invalidated on font lock/unlock; sized by `MemoryBudget`. | `ShapingCache` | WS-03 |
| `TextEngineError.swift` | Engine errors: font unavailable, shaping failure, unsupported control characters — with Arabic user messages. | `TextEngineError` | WS-03 |
| `EngineInvariants.swift` | Debug-build invariant checks (INV-n from ARCHITECTURE): cluster map bijectivity, advance-sum ≈ line width, mark-base resolution totality. | `EngineInvariants` | WS-03 |

## 8. `Sources/MKArrange/` (14 files) — owner WS-04

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ArrangementDeriver.swift` | Live/Path Text → `ArrangedComposition` snapshot (D-106): walks shaped lines, emits GlyphNodes/MarkNodes/LigatureGroups with full provenance, stores `SourceTextBackup`; explicit user action only. | `ArrangementDeriver` | WS-04 |
| `MarkAttachment.swift` | Mark attach/detach/reattach mechanics: attached marks follow base transforms (follow-base default), detach makes free node, reattach recomputes relative offset. | `MarkAttachmentEngine` | WS-04 |
| `LigatureDecomposer.swift` | Decomposes a `LigatureGroup`: reshapes constituents in joining-preserving context, places them with computed offsets matching original ligature bounds (visual-fidelity default, D-108/Q71). | `LigatureDecomposer` | WS-04 |
| `LigatureRecomposer.swift` | Restores the stored original ligature glyph from decomposed constituents; validates constituents unmodified-enough or warns. | `LigatureRecomposer` | WS-04 |
| `JoinBreaker.swift` | Explicit join break between adjacent glyph nodes (joining preserved by default, BRIEF); records break so `FormApplication` can offer the four forms; join restore. | `JoinBreaker` | WS-04 |
| `FormApplication.swift` | Applies a user-chosen `JoiningForm` to a broken-out letter using `FormResolver` results; updates provenance and advances neighbors optionally. | `FormApplication` | WS-04 |
| `DualLevelEditor.swift` | The two-level contract (BRIEF): glyph-level ops and Unicode-letter-level ops over the same composition; guarantees codepoint sequence + resolved glyph refs stay consistent. | `DualLevelEditor`, `EditLevel` | WS-04 |
| `CodepointReDeriver.swift` | Letter-level edits (insert/delete/replace codepoints) → localized re-derivation of affected cluster span while preserving untouched manual adjustments. | `CodepointReDeriver` | WS-04 |
| `RevertService.swift` | Revert-to-text: validates backup, produces the restored `LiveTextNode`/`PathTextNode`, discards arrangement; caller must present confirmation (UI owns dialog). | `RevertService` | WS-04 |
| `ArrangeOperations.swift` | Transform/style operations on glyph/mark/ligature selections (position, rotation, scale, opacity, fill, outline, shadow) emitting inverse-op records. | `ArrangeOperations` | WS-04 |
| `ArrangeSelectionModel.swift` | Selection semantics inside a composition: glyph vs mark vs ligature-as-unit vs ligature-components (both selectable, BRIEF). | `ArrangeSelection` | WS-04 |
| `ArrangeUndoRecords.swift` | Inverse-operation records for all arrange mutations, consumed by MKPersistence `CommandStack` via protocol (no persistence import). | `ArrangeUndoRecord` | WS-04 |
| `ArrangeValidation.swift` | Structural validation after mutations: orphan marks, dangling ligature members, provenance completeness; debug asserts + release-safe repairs. | `ArrangeValidation` | WS-04 |
| `ArrangeError.swift` | Arrange errors (backup missing, form resolution failed, non-decomposable ligature) with Arabic messages. | `ArrangeError` | WS-04 |

## 9. `Sources/MKPathText/` (10 files) — owner WS-05

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKBezierPath.swift` | Codable cubic Bézier path value (anchors + control points, open/closed) — the document representation for Q72 paths. | `MKBezierPathData` | WS-05 |
| `ArcLengthLUT.swift` | Arc-length parameterization lookup table with adaptive subdivision; point/tangent at arc-length queries (D-110). | `ArcLengthLUT` | WS-05 |
| `PathLayoutEngine.swift` | Lays shaped glyphs along the path: pen advances along arc length in visual order, position = arc point, rotation = local tangent, plus user offset (D-110). | `PathLayoutEngine` | WS-05 |
| `RTLPathPen.swift` | RTL-aware logical-reading-order pen: consumes `BidiRunMap` so Arabic runs travel start→end of path while internal glyph order stays correct; mixed-direction sub-runs coherent. | `RTLPathPen` | WS-05 |
| `TangentSampler.swift` | Smoothed tangent/normal sampling (avoids jitter at high curvature), degenerate-segment handling. | `TangentSampler` | WS-05 |
| `LivePathText.swift` | Live (reflowable) path-text session: retype → relayout along current path; overflow policies (compress-tracking warn / overflow marker). | `LivePathTextSession` | WS-05 |
| `PathEditModel.swift` | Control-point editing model (add/remove/move anchors and handles) — legal in live mode only (D-110); emits path-changed relayouts. | `PathEditModel` | WS-05 |
| `ArrangeOnPathService.swift` | Freezes path text into an `ArrangedComposition` via `ArrangementDeriver` with path-derived base transforms; per-glyph adjustability retained afterward. | `ArrangeOnPathService` | WS-05 |
| `PathPresets.swift` | Starter paths: circle, arc, wave, spiral, line — generated as `MKBezierPathData`. | `PathPresets` | WS-05 |
| `PathTextError.swift` | Path errors (degenerate path, text exceeds closed path length) with Arabic messages. | `PathTextError` | WS-05 |

## 10. `Sources/MKCanvas/` (22 files) — owner WS-06

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKCanvasViewController.swift` | UIKit canvas host: composes scroll view, content view, overlays; receives scene snapshots + selection from the app; emits `CanvasCommand`s upward. The single UIKit entry point wrapped by `CanvasHostView`. | `MKCanvasViewController`, `CanvasDelegate` | WS-06 |
| `CanvasScrollView.swift` | UIScrollView subclass: zoom (0.1×–64×), pan, RTL-neutral coordinate space, double-tap zoom-to-fit, keyboard-safe insets. | `CanvasScrollView` | WS-06 |
| `CanvasContentView.swift` | Content view owning the `LayerTreeController`-managed CALayer tree; re-rasterization requests on zoom-scale change (D-114). | `CanvasContentView` | WS-06 |
| `GestureRouter.swift` | Central gesture arbitration: tap-select, drag-move, pinch-scale, rotate, two-finger pan vs marquee, long-press menu; mode-aware (normal / text-edit / arrange / path-edit). | `GestureRouter`, `CanvasMode` | WS-06 |
| `SelectionController.swift` | Selection set management incl. multi-select, group-aware selection promotion, arranged-child selection pass-through; publishes selection bounds. | `SelectionController` | WS-06 |
| `MarqueeView.swift` | Rubber-band marquee rendering + hit collection through `HitTestCoordinator`. | `MarqueeView` | WS-06 |
| `TransformHandles.swift` | Selection chrome: 8 resize handles + rotation handle + bounds outline; renders in screen space, RTL-mirrored handle semantics off (geometry is direction-neutral). | `TransformHandlesView` | WS-06 |
| `HandleInteraction.swift` | Handle drag math: aspect-locked resize, snap-to-15° rotation with modifier, anchor-based scaling; emits live transform previews then a single coalesced command. | `HandleInteraction` | WS-06 |
| `GroupTransformSolver.swift` | Multi-select/group transforms: common-bounds transform application to heterogeneous nodes incl. arranged children (BRIEF group transforms). | `GroupTransformSolver` | WS-06 |
| `SnappingEngine.swift` | Snap candidates: canvas edges/center, other-node edges/centers, spacing equality; tolerance in screen points/zoom-aware; toggleable. | `SnappingEngine`, `SnapResult` | WS-06 |
| `SmartGuides.swift` | Converts `SnapResult`s into alignment-guide geometry (lines + spacing chips). | `SmartGuideSolver` | WS-06 |
| `GuidesOverlayView.swift` | Draws alignment guides + snap flashes over the canvas. | `GuidesOverlayView` | WS-06 |
| `ZoomPanController.swift` | Programmatic zoom-to-fit/zoom-to-selection, zoom readout, 120 Hz pan performance guard (layer-property-only updates during gestures, D-114). | `ZoomPanController` | WS-06 |
| `TextEditingOverlay.swift` | The D-104 UITextView (TextKit 2) overlay for in-canvas typing: IME/keyboard/selection correctness; styled to match engine metrics; on commit removes itself and the engine-rendered object remains. | `TextEditingOverlay` | WS-06 |
| `OverlayMetricsMatcher.swift` | Matches overlay UITextView typography to `MetricsProvider` metrics (font, line height, kerning, baseline) so echo-while-typing ≈ committed render; documents accepted divergences. | `OverlayMetricsMatcher` | WS-06 |
| `PathEditOverlay.swift` | Path control-point handles rendering + drag routing into `PathEditModel`; live-mode only. | `PathEditOverlay` | WS-05 |
| `ArrangePickTool.swift` | Arrange-mode hit/selection tool honoring `ArrangeSelectionModel` (glyph vs mark vs ligature vs component picking; tashkeel pick priority). | `ArrangePickTool` | WS-04 |
| `HitTestCoordinator.swift` | Screen-point → node/child hit testing delegating precise geometry to `MKRender.HitGeometry`; z-order + locked/hidden aware. | `HitTestCoordinator` | WS-06 |
| `CanvasCommands.swift` | The command vocabulary the canvas emits (move/resize/rotate/select/edit-text/place-asset/…) — consumed by `EditorViewModel` → `CommandStack`; canvas never mutates the scene directly (D-102 snapshot flow). | `CanvasCommand` | WS-06 |
| `InteractionPolicy.swift` | Per-node interaction rules: locked (selectable-not-editable), hidden (skip), background (tap-through unless background tool). | `InteractionPolicy` | WS-06 |
| `ContextMenuProvider.swift` | Canvas long-press menus: duplicate, delete, lock/hide, order ops, group/ungroup, arrange entry, copy style. | `ContextMenuProvider` | WS-06 |
| `KeyboardFrameObserver.swift` | Keyboard frame tracking for overlay editing scroll-avoidance. | `KeyboardFrameObserver` | WS-06 |

## 11. `Sources/MKRender/` (16 files) — owner WS-07

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKSceneRenderer.swift` | The single render path (D-118: never screen capture): renders an immutable `MKScene` snapshot into any `CGContext` at a given scale/region; used identically by preview layers, thumbnails, and export. | `MKSceneRenderer` | WS-07 |
| `RenderContext.swift` | Render parameters: scale, region, color-pipeline handle, quality tier (full/degraded), tile bounds; `Sendable` so exports run off-main (D-102). | `RenderContext`, `QualityTier` | WS-07 |
| `LayerTreeController.swift` | CALayer-per-top-level-node management (D-114): layer creation/reuse keyed by NodeID, transform changes as layer-property updates (cheap 60/120 Hz), contents invalidation on style/content change. | `LayerTreeController` | WS-07 |
| `BitmapCacheStore.swift` | Zoom-scale-keyed bitmap cache of node contents; cost-based eviction wired to `MemoryPressureMonitor` stage 1 (drop offscreen caches, D-116). | `BitmapCacheStore` | WS-07 |
| `TileRenderer.swift` | Bounded-strip tiled rendering for huge outputs (export limited by disk not RAM, D-116) and large-canvas preview fills. | `TileRenderer` | WS-07 |
| `DegradationLadder.swift` | D-116 stage-2 controlled degradation: half-res layer bitmaps, simplified shadows, virtualization hints — engineering safeguards, never feature caps. | `DegradationLadder` | WS-07 |
| `LiveTextRenderer.swift` | Draws Live Text via ShapingSession results (glyph runs through Core Graphics/CTRunDraw-equivalent from captured runs) — pixel-identical to export (D-104). | `LiveTextRenderer` | WS-07 |
| `ArrangedRenderer.swift` | Draws Arranged Compositions: per-glyph outline paths with individual transforms/styles, marks after bases, ligature groups as stored glyphs. | `ArrangedRenderer` | WS-07 |
| `PathTextRenderer.swift` | Draws live path text from `PathLayoutEngine` output (positions+tangent rotations). | `PathTextRenderer` | WS-05 |
| `ShapeRenderer.swift` | Shape/vector-asset drawing: path fill/stroke with style; pattern-tiled fills via `PatternTiler` handle. | `ShapeRenderer` | WS-07 |
| `ImageRenderer.swift` | Raster/SVG/PDF placed-asset drawing with crop, interpolation quality by tier, premium-locked placeholder treatment (D-119 lock badge state supplied by caller). | `ImageRenderer` | WS-07 |
| `BackgroundRenderer.swift` | Background fill (solid / image) under all nodes; export alpha handling for transparent-PNG (skip background when requested). | `BackgroundRenderer` | WS-07 |
| `EffectsRenderer.swift` | Stroke/outline and shadow effects application order (shadow → fill → stroke) shared by all node renderers; degraded-shadow variant. | `EffectsRenderer` | WS-07 |
| `HitGeometry.swift` | Precise hit geometry: path containment, glyph-bounds with transform, stroke-width tolerance — consumed by MKCanvas hit testing. | `HitGeometry` | WS-07 |
| `ThumbnailRenderer.swift` | Project thumbnail generation (browser cells + `.makhtoot/thumbnail.png`) at fixed budget size, debounced after edits. | `ThumbnailRenderer` | WS-07 |
| `RenderScheduler.swift` | Coalesces invalidations into display-link-aligned batches; priority: visible region > offscreen; export jobs on background executors. | `RenderScheduler` | WS-07 |

## 12. `Sources/MKColor/` (9 files + resources) — owner WS-08

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKColorSpace.swift` | Working-space definitions (extended sRGB working, P3 display) and CGColorSpace factories (D-117). | `MKColorSpace` | WS-08 |
| `WorkingColor.swift` | Runtime color value in working space; conversions from/to document `MKSolidColor` and display colors. | `WorkingColor` | WS-08 |
| `ICCProfileStore.swift` | Loads the bundled CMYK ICC profile (`Resources/Profiles/`), exposes `CGColorSpace(iccData:)`; falls back to Apple Generic CMYK with an explicit `fidelity: .reduced` marker when FD-03 profile absent (documented lower fidelity). | `ICCProfileStore`, `CMYKProfileChoice` | WS-08 |
| `CMYKConversion.swift` | sRGB → CMYK conversion via CG with relative colorimetric intent; conversion verification hooks for TEST_MATRIX external-tool checks. | `CMYKConverter` | WS-08 |
| `ExportColorPipeline.swift` | Per-format color pipelines: sRGB raster (JPEG/PNG), sRGB vector (SVG), CMYK+OutputIntent (print PDF); the object handed to `RenderContext`. | `ExportColorPipeline` | WS-08 |
| `DisplayMapping.swift` | P3-aware display mapping for pickers/preview (UIColor/SwiftUI Color bridging); no soft-proofing in v1 (documented limitation). | `DisplayMapping` | WS-08 |
| `NamedSwatch.swift` | Named swatch value (name + `MKSolidColor`) stored in documents/UserDefaults library. | `NamedSwatch` | WS-08 |
| `SwatchLibrary.swift` | User swatch collection CRUD + default Ink&Paper starter swatches (FD-02 editable). | `SwatchLibrary` | WS-01 |
| `ColorError.swift` | Color/profile errors (profile unreadable, conversion failure) with Arabic messages. | `ColorError` | WS-08 |

```
MKColor/Resources/Profiles/
├── FD-03-PLACEHOLDER.icc            ← zero-byte placeholder; real CMYK profile pending
│                                       FD-03 (eciRGB/ISO-Coated-class candidates; redistribution
│                                       license MUST be verified — never assumed; fallback = Apple
│                                       Generic CMYK at runtime, no bundled file needed)
└── PROFILE-LICENSE-VERIFICATION.md  ← verification protocol + record template (empty until FD-03)
```

## 13. `Sources/MKExport/` (18 files) — owner WS-08

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ExportCoordinator.swift` | Orchestrates an export: entitlement check → gate resolution → renderer/tiling plan → format writer → history record; async job with progress + cancel; memory-warned near limits (Q76). | `ExportCoordinator` | WS-08 |
| `ExportRequest.swift` | Value describing one export: format, dimensions/preset, transparency, DPI, destination. | `ExportRequest`, `ExportFormat` | WS-08 |
| `ExportPreset.swift` | Preset catalog: social/story/static-reel/messaging-status/wallpaper/print ratios at 2 MP baseline; premium exact-dimension factory. | `ExportPreset` | WS-08 |
| `FormatCapabilities.swift` | The D-118 matrix as data: free = JPEG + rasterized PDF ≤2 MP; premium = +opaque PNG, transparent PNG, SVG, vector print PDF (300 DPI floor, CMYK); no artificial caps beyond memory protection. | `FormatCapabilities` | WS-08 |
| `MegapixelGate.swift` | 2 MP effective-cap math for free tier (downscale-to-fit, never crop) and baseline preset sizing. | `MegapixelGate` | WS-08 |
| `EntitlementGateway.swift` | Defines `ExportEntitlementProviding` protocol (the only MKStore surface MKExport touches) + premium-content-present project scan gate (D-119 replace-or-subscribe signal). | `ExportEntitlementProviding`, `ExportGateDecision` | WS-08 |
| `JPEGExporter.swift` | JPEG writer: quality tiers, sRGB tag, EXIF-free output. | `JPEGExporter` | WS-08 |
| `PNGExporter.swift` | Opaque + transparent PNG writer (premium); background-skip flag to renderer for alpha output. | `PNGExporter` | WS-08 |
| `RasterPDFExporter.swift` | Free-tier rasterized PDF: single raster page ≤2 MP wrapped in PDF. | `RasterPDFExporter` | WS-08 |
| `VectorPDFExporter.swift` | Premium vector PDF: CG PDF context, vector paths + live-text runs; live text in OFL fonts drawn as text with subset embedding, otherwise outlined per license switch (D-118). | `VectorPDFExporter` | WS-08 |
| `PDFCMYKPipeline.swift` | True-CMYK print PDF (Q75): color conversion through `ExportColorPipeline`, ICC profile embedded as OutputIntent, 300-DPI raster-asset floor. | `PDFCMYKPipeline` | WS-08 |
| `SVGSerializer.swift` | Custom SVG writer (no third-party lib): document structure, defs, viewBox; assembles emitter outputs; never silently flattens (Q73). | `SVGSerializer` | WS-08 |
| `SVGTextEmitter.swift` | Live Text → `<text>` elements; `@font-face` embedding only when license allows (per-license switch); otherwise documented per-feature outline fallback. | `SVGTextEmitter` | WS-08 |
| `SVGPathEmitter.swift` | Arranged/transformed glyphs → `<g><path>` with `data-mk-*` provenance attributes (source text, codepoints, font name) preserving editability intent (D-118). | `SVGPathEmitter` | WS-08 |
| `FontEmbedder.swift` | Font subsetting + embedding for PDF/SVG; license-permission lookup via `LicenseRecord`; outline-fallback decision records surfaced to UI. | `FontEmbedder`, `EmbedDecision` | WS-09 |
| `TiledRasterizer.swift` | Drives `TileRenderer` in bounded strips into CGBitmapContext/ImageIO incremental destinations for 4K+/print rasters (D-116). | `TiledRasterizer` | WS-08 |
| `ExportHistoryRecorder.swift` | Writes export records (format, dims, preset, date, file bookmark) through a persistence-facing protocol; feeds browser history UI. | `ExportHistoryRecording` | WS-08 |
| `ExportError.swift` | Export errors (memory abort with autosave note, profile missing, gate denied) with Arabic messages. | `ExportError` | WS-08 |

## 14. `Sources/MKFonts/` (18 files + resources) — owner WS-09

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `FontRegistry.swift` | Runtime registry of all usable fonts (bundled, downloaded, user-imported) with lifecycle state (registered/locked/missing); single lookup point for `FontReference` resolution. | `FontRegistry`, `FontRecord` | WS-09 |
| `FontHandle.swift` | CTFont wrapper handed to MKTextEngine (the "font handles" edge in FOUNDATION §2): size/variation instantiation, feature array access; `Sendable` by immutable CTFont. | `FontHandle` | WS-09 |
| `BundledFontIndex.swift` | Enumerates `Resources/Fonts/<Family>/` bundle contents + per-family metadata JSON; only families with a captured LICENSE + VERIFICATION record load (D-120). | `BundledFontIndex` | WS-09 |
| `ProcessRegistration.swift` | `CTFontManagerRegisterFontURLs(.process)` registration at launch/on-demand + deregistration on lock; no fonts entitlement required — process scope only (see §3.2). | `ProcessRegistration` | WS-09 |
| `FontValidator.swift` | sfnt validation for imports/downloads: accept ttf/otf/ttc/variable; reject woff/woff2/bitmap-only/corrupt with specific Arabic errors (D-122); table sanity (cmap/glyf|CFF/GSUB presence). | `FontValidator`, `FontValidationError` | WS-09 |
| `UserFontImporter.swift` | Premium-only import flow (Q64): validate → content-addressed copy into container → register → catalog entry flagged `userImported` (locks on expiry). | `UserFontImporter` | WS-09 |
| `CatalogManifest.swift` | Decodes the premium catalog JSON manifest (see resource sample): entries with id, family, styles, tags, category, license, coverage, download URL, size, hash. | `CatalogManifest`, `CatalogEntry` | WS-09 |
| `CatalogService.swift` | Catalog façade: merge bundled + premium manifest + imported; category browsing (the ten BRIEF categories), previews, favorites/tags, search. | `MKFontCatalog` | WS-09 |
| `CatalogDownloader.swift` | HTTPS download after entitlement confirmation (D-121): hash-verify, atomic install, resume support; offline-tolerant queue. | `CatalogDownloader` | WS-09 |
| `DownloadStateMachine.swift` | Per-entry download state (notDownloaded/downloading(progress)/installed/failed/locked) persisted via MKPersistence font-state models. | `DownloadState` | WS-09 |
| `CharacterCoverage.swift` | cmap-derived coverage analysis (Arabic block, Qurʼanic annotation range, Latin) → coverage summary shown in catalog + Licensing screen. | `CharacterCoverage` | WS-09 |
| `FontCategory.swift` | Category enum: Naskh, Ruqʼah, Thuluth, Diwani, Kufi, Maghrebi, modern display, Qurʼanic-style, handwriting, Arabic-Latin bilingual. | `FontCategory` | WS-09 |
| `FontMetadata.swift` | Per-font metadata: foundry, designer, license id, commercial status, source links, preview strings. | `FontMetadata` | WS-09 |
| `LicenseRecord.swift` | License records powering Settings→Support→Licensing (Q66) and `FontEmbedder` permission checks: license type (OFL 1.1 etc.), verification date/evidence, embedding-allowed flags. NEVER invents permissions — unverified = most-restrictive. | `LicenseRecord`, `EmbeddingPermission` | WS-09 |
| `FavoritesAndTags.swift` | Favorites + user tags CRUD persisted in metadata store. | `FontFavorites` | WS-09 |
| `FontSearch.swift` | Arabic-folded search over family/tags/category with ranking. | `FontSearch` | WS-09 |
| `ExpiryLockController.swift` | D-119 expiry locking: on entitlement drop, premium + imported fonts → locked (display via last cached shaping + lock badge; re-shape blocked); unlock on re-subscribe. | `ExpiryLockController` | WS-10 |
| `FontsError.swift` | Fonts errors (registration failed, download hash mismatch, locked) with Arabic messages. | `FontsError` | WS-09 |

```
MKFonts/Resources/
├── Fonts/                                ← ONE FOLDER PER VERIFIED FAMILY (D-120). A family folder
│   │                                        may exist ONLY with all three: font files + LICENSE + VERIFICATION.
│   ├── Amiri/                            ← verified OFL 1.1 (market study §5)
│   │   ├── Amiri-Regular.ttf  Amiri-Bold.ttf  Amiri-Italic.ttf  Amiri-BoldItalic.ttf
│   │   ├── LICENSE-OFL.txt
│   │   └── VERIFICATION.md               ← source URL, license hash, date, verifier
│   ├── AmiriQuran/                       ← candidate; pending WS-09 per-repo verification
│   ├── NotoNaskhArabic/                  ← verified OFL 1.1 (market study §5)
│   │   ├── NotoNaskhArabic-Regular.ttf  NotoNaskhArabic-Bold.ttf
│   │   ├── LICENSE-OFL.txt
│   │   └── VERIFICATION.md
│   ├── NotoKufiArabic/   NotoSansArabic/     ← Noto family, OFL 1.1 verified at family level;
│   │                                            per-file capture still required by protocol
│   ├── ScheherazadeNew/  Lateef/  Harmattan/  ReemKufi/  ArefRuqaa/  Mada/
│   ├── Tajawal/  Almarai/  ElMessiri/  MarkaziText/  Rakkas/  Katibeh/
│   ├── Jomhuria/  Mirza/  Qahiri/           ← ALL candidates pending WS-09 verification protocol;
│   │                                            folders are created only upon verification, each with
│   │                                            font files + LICENSE-OFL.txt + VERIFICATION.md
│   └── _PROHIBITED.md                    ← KFGQPC/Uthmanic HAFS et al.: non-commercial freeware,
│                                            bundling PROHIBITED (BRIEF); list + rationale so no
│                                            agent re-adds them
└── PremiumCatalog/
    └── manifest.sample.json              ← premium catalog manifest sample (schema fixture for
                                             CatalogManifest + MKFontsTests; real manifest hosted
                                             per FD-04, fallback = bundle-in-app behind entitlement)
```

`manifest.sample.json` shape (schema v1): `{ "schemaVersion": 1, "fonts": [ { "id",
"family", "familyAr", "styles": [...], "category", "tags": [...], "license":
{ "type": "OFL-1.1", "verifiedAt", "sourceURL" }, "coverage": {...}, "download":
{ "url", "bytes", "sha256" } } ] }` — v1 premium catalog ships OFL-verified fonts only
(BRIEF research gap: commercial foundry licenses unverified; FD-07).

## 15. `Sources/MKPersistence/` (21 files) — owner WS-02

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKProjectDocument.swift` | The `.makhtoot` file-package document object (D-112): open/close lifecycle, coordinated reads/writes, Documents-directory placement (user-visible), UTI `net.binjamshid.makhtoot.project` (FD-01 applied). | `MKProjectDocument` | WS-02 |
| `PackageLayout.swift` | Package internal layout contract: `manifest.json`, `scene.json`, `assets/`, `backups/`, `thumbnail.png`; path builders + integrity scan. | `PackageLayout` | WS-02 |
| `ManifestCodec.swift` | `manifest.json` codec: ids, schemaVersion, canvas size, thumbnail refs, premium-content-present flag cache. | `ProjectManifest` | WS-02 |
| `SceneCodec.swift` | `scene.json` codec over `SceneCodingEnvelope` + migration invocation on version mismatch. | `SceneCodec` | WS-02 |
| `AtomicFileWriter.swift` | Write-temp + rename atomic writes for every package member; fsync policy; power-loss safe (D-112). | `AtomicFileWriter` | WS-02 |
| `AutosaveController.swift` | Debounced autosave ≤2 s after mutation; immediate on background/memory-pressure (stages from `MemoryPressureMonitor`); incremental (<100 ms off main, D-115). | `AutosaveController` | WS-02 |
| `RecoveryJournal.swift` | Crash-recovery journal of the last un-flushed command batch; append-only, checksummed. | `RecoveryJournal` | WS-02 |
| `JournalReplayer.swift` | On relaunch after termination: detect journal, replay onto last-saved scene, exact-state recovery (D-116 stage 3 guarantee). | `JournalReplayer` | WS-02 |
| `BackupSnapshotter.swift` | `backups/` rescue snapshots (periodic + pre-migration + pre-revert); rotation policy. Source Text Backups live in scene nodes, NOT here (D-112). | `BackupSnapshotter` | WS-02 |
| `CommandStack.swift` | In-memory undo/redo stack of inverse operations on the value-type scene; unbounded within memory budget; coalesced gestures = single command (D-112). | `CommandStack` | WS-02 |
| `SceneCommand.swift` | Command protocol + concrete commands (transform, style, add/remove, reorder, group, arrange-op wrapper consuming `ArrangeUndoRecord`). | `SceneCommand` | WS-02 |
| `GestureCoalescing.swift` | Merges continuous-gesture mutation streams into single undoable commands with begin/update/commit API. | `GestureCoalescer` | WS-06 |
| `AssetStore.swift` | Content-addressed `assets/` store inside the package: ingest (dedup by `ContentHash`), fetch, garbage-collect unreferenced. | `AssetStore` | WS-02 |
| `ThumbnailStore.swift` | Thumbnail write into package + browser-side cache; invalidation hooks from `ThumbnailRenderer`. | `ThumbnailStore` | WS-02 |
| `MetadataContainer.swift` | SwiftData `ModelContainer` setup in Application Support: metadata ONLY, never scene graphs (D-112); migration plan; the single SwiftData entry point. | `MetadataContainer` | WS-02 |
| `ProjectMetadataModel.swift` | `@Model` project row: name, folder ref, dates, search text, thumbnail path, sync state, premium-content flag. | `ProjectMetadata` | WS-02 |
| `FolderModel.swift` | `@Model` folder row: name, order, children counts. | `FolderMetadata` | WS-02 |
| `ExportHistoryModel.swift` | `@Model` export-history row implementing `ExportHistoryRecording` storage. | `ExportHistoryEntry` | WS-08 |
| `FontStateModel.swift` | `@Model` rows for font catalog state: download state, favorites, tags, imported-font records, lock state. | `FontCatalogState` | WS-09 |
| `ConsentAndTrialModels.swift` | `@Model` rows for versioned analytics-consent records and trial bookkeeping mirror (authoritative trial timestamp stays in Keychain/KVS per D-123 — this is the queryable copy). | `ConsentRecord`, `TrialRecordMirror` | WS-12 |
| `PersistenceError.swift` | Persistence errors (corrupt package, journal mismatch, disk full) with Arabic messages + recovery suggestions. | `PersistenceError` | WS-02 |

## 16. `Sources/MKSync/` (12 files) — owner WS-11

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKSyncEngine.swift` | CKSyncEngine-based premium project sync façade (D-112): start/stop by entitlement + toggle, event loop, batch send/fetch; user's own iCloud, no account system (Q77). | `MKSyncEngine` | WS-11 |
| `SyncConfiguration.swift` | Container id `iCloud.net.binjamshid.makhtoot` (FD-01 applied), zone naming, record types, private-DB scope. | `SyncConfiguration` | WS-11 |
| `RecordMapper.swift` | Project ↔ CKRecord mapping: one record per project; manifest+scene as encrypted-asset payloads, imported assets as CKAssets (D-112). | `RecordMapper` | WS-11 |
| `AssetPackaging.swift` | Packs/unpacks package members into CKAsset temp files; hash-skip unchanged assets. | `AssetPackaging` | WS-11 |
| `ConflictResolver.swift` | Last-writer-wins per project with conflict-copy fallback named "(نسخة متعارضة)" (conflicted copy) (D-112); never merges scene JSON. | `ConflictResolver` | WS-11 |
| `AccountObserver.swift` | CKAccountStatus observation: signed-out/restricted → pause with Arabic status messaging in `SyncSettingsView`. | `AccountObserver` | WS-11 |
| `SyncScheduler.swift` | Foreground-only scheduling (no push entitlement in v1, §3.2): on-open, on-save-debounced, on-foreground triggers with backoff. | `SyncScheduler` | WS-11 |
| `SyncStateStore.swift` | Persists CKSyncEngine state serialization + per-project sync status into metadata store. | `SyncStateStore` | WS-11 |
| `QuotaAndErrors.swift` | Quota-exceeded, network, zone-busy error taxonomy → user-facing states + retry policy. | `SyncErrorPolicy` | WS-11 |
| `SyncEntitlementGate.swift` | `SyncEntitlementProviding` protocol (the only MKStore surface MKSync touches); sync hard-stops on non-premium (free/expired) per BRIEF. | `SyncEntitlementProviding` | WS-11 |
| `SyncStatus.swift` | Per-project + global status enum (off/idle/pending/syncing/conflict/error) published to UI. | `SyncStatus` | WS-11 |
| `SyncError.swift` | Sync errors with Arabic messages. | `SyncError` | WS-11 |

## 17. `Sources/MKStore/` (15 files + `Referral/` 6 + 2 docs) — owner WS-10

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ProductCatalog.swift` | Product id constants (`net.binjamshid.makhtoot.premium.monthly/.annual/.lifetime` — FD-01 applied), subscription group `Makhtoot Premium`, display metadata keys. | `ProductCatalog` | WS-10 |
| `StoreClient.swift` | StoreKit 2 product loading + purchase execution; storefront price localization pass-through (never formats prices itself). | `StoreClient` | WS-10 |
| `PurchaseFlow.swift` | Purchase orchestration: purchase → verify → finish → entitlement refresh; pending/ask-to-buy handling; error mapping. | `PurchaseFlow` | WS-10 |
| `RestoreService.swift` | `AppStore.sync()` restore + result summarization for mandatory restore UI (D-113). | `RestoreService` | WS-10 |
| `TransactionMonitor.swift` | `Transaction.updates` listener task started at launch: verifies, finishes, forwards to resolver; revocation handling. | `TransactionMonitor` | WS-10 |
| `MKEntitlementResolver.swift` | THE single entitlement source (D-113): observes `Transaction.currentEntitlements` + `Product.SubscriptionInfo.Status` + `TrialManager`; resolves precedence lifetime > subscribed > grace > billingRetry > trial > free; publishes `EntitlementState` stream consumed app-wide and via the MKExport/MKSync protocols. | `MKEntitlementResolver` | WS-10 |
| `EntitlementState.swift` | The six-state enum with associated data (expiry dates, daysLeft) + convenience `isPremium`; Sendable. | `EntitlementState` | WS-10 |
| `SubscriptionStatusMapper.swift` | Maps StoreKit renewal states → grace/billingRetry/expired with messaging keys; grace-period durations marked VERIFY-AT-SUBMISSION (BRIEF research gap). | `SubscriptionStatusMapper` | WS-10 |
| `VerificationPolicy.swift` | On-device JWS verification via `VerificationResult` (v1 position, D-113); App Store Server API documented as extension seam ONLY (no backend exists); rejects unverified transactions. | `VerificationPolicy` | WS-10 |
| `TrialManager.swift` | App-side 7-day trial state machine `active(daysLeft)` → `expired` (D-123): starts at first launch, earliest-timestamp-wins reconcile across Keychain/KVS, applies to monthly+annual framing (Q37); documents app-trial vs Apple intro-offer differences (none configured in v1). | `TrialManager`, `TrialState` | WS-10 |
| `KeychainTrialStore.swift` | Trial timestamp in Keychain `kSecAttrAccessibleAfterFirstUnlock` — survives reinstall so reinstall cannot trivially reset the trial. | `KeychainTrialStore` | WS-10 |
| `KVSTrialMirror.swift` | `NSUbiquitousKeyValueStore` mirror of trial start (entitlement §3.2); earliest timestamp wins across devices. | `KVSTrialMirror` | WS-10 |
| `ClockRollbackGuard.swift` | Monotonic-clock cross-check (via `MonotonicClock`) so device-clock rollback never extends trial (D-123). | `ClockRollbackGuard` | WS-10 |
| `PaywallState.swift` | Paywall-facing state assembly: products + entitlement + trial → view state; gate-reason plumbing (which feature triggered the paywall). | `PaywallState`, `GateReason` | WS-10 |
| `StoreError.swift` | Store errors incl. billing/expiration/cancellation messaging keys with Arabic messages. | `StoreError` | WS-10 |

```
MKStore/Referral/                          ← FLAG-ISOLATED (D-124): compiled always, inert unless
│                                             MKFeatureFlags.referralProgram == true (default OFF, Q78).
│                                             Removal = delete this folder + the flag. No file outside
│                                             this folder (except ReferralSection.swift UI shell and the
│                                             flag itself) references referral symbols.
├── ReferralFlagGate.swift                 ← runtime gate; every public entry point no-ops when OFF
├── ReferralCode.swift                     ← local code generation/format/checksum (no server in v1)
├── ReferralAttribution.swift              ← manual code-entry attribution; honor-based exchange —
│                                             documented weakness pending any future backend
├── ExtensionLedger.swift                  ← referrer-only reward: +7 days trial per qualifying event,
│                                             hard cap 4 extensions, persisted beside trial records
├── AbuseGuards.swift                      ← self-referral block, device-dedup via KVS, rate caps
├── ReferralUIModel.swift                  ← view-state for ReferralSection (code, entries, earned days)
├── REVIEW-RISK.md                         ← full App-Review risk memo: invitee incentives are
│                                             documented rejection territory (market study §8);
│                                             compliant variant = referrer-only; MUST recheck current
│                                             guidelines before activation (FD-05, VERIFY-AT-SUBMISSION)
└── REMOVAL.md                             ← exact removal instructions (folder + flag + UI shell row)
```

| Referral file | Key public types | WS |
|---|---|---|
| `ReferralFlagGate.swift` | `ReferralFlagGate` | WS-10 |
| `ReferralCode.swift` | `ReferralCode` | WS-10 |
| `ReferralAttribution.swift` | `ReferralAttribution` | WS-10 |
| `ExtensionLedger.swift` | `ExtensionLedger` | WS-10 |
| `AbuseGuards.swift` | `AbuseGuards` | WS-10 |
| `ReferralUIModel.swift` | `ReferralUIModel` | WS-10 |

## 18. `Sources/MKAnalytics/` (10 files) — owner WS-12

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `ConsentManager.swift` | Opt-IN consent state (default OFF, D-125/Q79): grant/revoke, versioned consent records via MKPersistence; nothing counts or uploads without current-version consent. | `ConsentManager` | WS-12 |
| `ConsentVersion.swift` | Consent text/version constants; version bump forces re-consent. | `ConsentVersion` | WS-12 |
| `FontUsageCounter.swift` | On-device counters: fontID → usage count buckets only (Q43); increments from catalog/editor events; no text, no project data ever enters this module's types (compile-time: APIs accept `FontID` only). | `FontUsageCounter` | WS-12 |
| `Aggregator.swift` | Bucketing/aggregation: counts → coarse buckets, week-granularity periods only (no finer timestamps, D-125). | `Aggregator` | WS-12 |
| `BatchBuilder.swift` | Builds anonymous upload batches: random ephemeral batch UUID, bucketed counts, schema version; provably contains no identifiers (unit-tested payload allowlist). | `BatchPayload` | WS-12 |
| `CloudKitUploader.swift` | Uploads batches to the CloudKit **public** database (no user record link); network use limited to this + font downloads + sync per BRIEF offline policy. | `CloudKitUploader` | WS-12 |
| `UploadScheduler.swift` | Batched, opportunistic upload scheduling (foreground, network-available, consent-checked each time). | `UploadScheduler` | WS-12 |
| `KillSwitch.swift` | Local kill switch: consent revoke → stop counting, purge pending batches and counters. | `AnalyticsKillSwitch` | WS-12 |
| `PrivacyInvariants.swift` | Debug asserts + release guards enforcing the never-upload list (text, projects, identifiers, font files, user content); the payload allowlist definition. | `PrivacyInvariants` | WS-12 |
| `AnalyticsError.swift` | Analytics errors (silent-degrade policy: analytics failures never surface to users beyond settings status). | `AnalyticsError` | WS-12 |

## 19. `Sources/MKDesignSystem/` (17 files) — owner WS-01

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKTheme.swift` | Theme protocol: semantic colors, type ramp, spacing, radii, elevation, motion — the swappable-token contract for the future visual identity (BRIEF: themeable Arabic-first layer). | `MKTheme` | WS-01 |
| `InkPaperTheme.swift` | Default theme "حبر ورق" (Ink & Paper, FD-02 editable): warm paper neutrals, ink-dark foregrounds, madder-red accent, generous whitespace values (D-126). | `InkPaperTheme` | WS-01 |
| `ThemeEnvironment.swift` | SwiftUI environment plumbing (`@Environment(\.mkTheme)`), theme injection at RootView. | `ThemeEnvironmentKey` | WS-01 |
| `SemanticColors.swift` | Semantic color roles (surface, surfaceRaised, ink, inkSecondary, accent, warning, premiumGold, canvasChrome…) resolved through the active theme. | `SemanticColor` | WS-01 |
| `TypeRamp.swift` | Arabic type ramp: UI font = system SF Arabic at defined roles (display/title/body/caption/numeric-inspector); display/preview fonts come from the catalog, never the ramp (D-126). | `TypeRole`, `TypeRamp` | WS-01 |
| `SpacingTokens.swift` | 4-pt grid spacing scale. | `Spacing` | WS-01 |
| `RadiusTokens.swift` | Corner radius scale (panels, cards, chips, sheets). | `Radius` | WS-01 |
| `ElevationTokens.swift` | Elevation/shadow tokens for panels and floating bars. | `Elevation` | WS-01 |
| `MotionTokens.swift` | Motion durations/curves (panel slide, selection pulse, snap flash). | `Motion` | WS-01 |
| `MKPanelChrome.swift` | RTL-first panel container: leading-edge-aware (trailing on RTL), drag-to-resize on iPad, sheet fallback on iPhone. | `MKPanel` | WS-01 |
| `MKInspectorField.swift` | Token-styled labeled field row used by inspector numeric fields; RTL label/value order. | `MKInspectorField` | WS-01 |
| `MKSlider.swift` | RTL-correct slider (fill from trailing) with haptic detents. | `MKSlider` | WS-01 |
| `MKChip.swift` | Category/tag chip (font categories, asset categories) with selected state. | `MKChip` | WS-01 |
| `MKButtonStyles.swift` | Primary/secondary/destructive/premium button styles from tokens. | `MKPrimaryButtonStyle` et al. | WS-01 |
| `MKBanner.swift` | Inline banner component (memory warning, grace-period notice, sync errors). | `MKBanner` | WS-01 |
| `MKSheetChrome.swift` | Sheet header chrome (title, close, trailing action) RTL-ordered. | `MKSheetChrome` | WS-01 |
| `RTLHelpers.swift` | View modifiers: forced RTL container, direction-safe chevrons/symbols, numeric-field direction islands (LTR digits inside RTL rows). | modifiers | WS-01 |

## 20. `Sources/MKAssets/` (10 files + resources) — owner WS-14

| File | Responsibility | Key public types | WS |
|---|---|---|---|
| `MKAssetCatalog.swift` | Bundled-asset catalog façade: enumerates resource categories, metadata, search; feeds `AssetLibraryPanel`. | `MKAssetCatalog` | WS-14 |
| `AssetItem.swift` | One bundled asset: id, category, Arabic name, vector data ref, default size, license ref. | `AssetItem` | WS-14 |
| `AssetCategory.swift` | Categories: shapes, ornaments, frames, patterns, calligraphic elements (all v1 per BRIEF; templates are NOT a category — seam only). | `AssetCategory` | WS-14 |
| `VectorAssetDecoder.swift` | Decodes the bundled vector assets (constrained SVG subset: paths/groups/fills) → `CGPath` trees; validated at build time by tests, not at runtime. | `VectorAssetDecoder` | WS-14 |
| `PatternTiler.swift` | Pattern-background tiling model (tile size, scale, tint) consumed by `ShapeRenderer`/`BackgroundRenderer`. | `PatternTiler` | WS-14 |
| `AssetBrowserModel.swift` | Browser view-state: category filter, search, recents. | `AssetBrowserModel` | WS-14 |
| `AssetPlacement.swift` | Placement factory: `AssetItem` → `ShapeNode`/`ImageNode`/`BackgroundNode` (pattern) with sensible default transform at viewport center. | `AssetPlacement` | WS-14 |
| `AssetLicenseIndex.swift` | Bundled-asset license index (all assets license-clear originals or verified-open; feeds Licensing screen). | `AssetLicenseIndex` | WS-14 |
| `TemplateSeam.swift` | The v2 templates extension seam ONLY (Q61–62: no templates in v1): protocol + empty provider so future template packs plug in without model changes. | `TemplateProviding` | WS-14 |
| `AssetsError.swift` | Asset decode/placement errors. | `AssetsError` | WS-14 |

```
MKAssets/Resources/
├── Shapes/          basic-rect.svg  basic-ellipse.svg  basic-line.svg  star-8.svg  … (12 files)
├── Ornaments/       ornament-rub-el-hizb.svg  ornament-arabesque-01..08.svg  … (16 files)
├── Frames/          frame-arch-01..06.svg  frame-border-geometric-01..06.svg  (12 files)
├── Patterns/        pattern-girih-01..06.svg  pattern-star-lattice-01..04.svg  (10 files)
├── Calligraphic/    flourish-01..10.svg  divider-01..06.svg  (16 files)
└── LICENSES.md      ← provenance: all assets are original commissioned/generated vectors,
                        license-clear (BRIEF: license-clear requirement); per-file table with
                        creation record; NO third-party assets without a verification record
```

All bundled assets are vector (BRIEF: vector assets); raster appears only in
user-imported content. Asset filenames are stable ids referenced by `AssetItem`.

## 21. `Tests/` — 16 test targets, 40 files — supporting evidence, NOT v1 gates (Q59)

Every MakhtootKit target has a mirror test target. These suites document intent and
catch regressions during agent work, but phase exits are gated ONLY by: build success,
D-115 profiling, StoreKit sandbox tests, and the manual Arabic-script checklist
(TEST_MATRIX.md). Owners follow the module's owner.

| Test target (files) | Files | Focus | WS |
|---|---|---|---|
| `MKFoundationTests/` (2) | `TransformMathTests.swift`, `FeatureFlagTests.swift` | Transform compose/invert round-trips; flag defaults (referral OFF). | WS-01 |
| `MKModelTests/` (3) | `SceneCodableRoundTripTests.swift`, `MigrationHarnessTests.swift`, `NodeQueryTests.swift` | Scene JSON round-trip incl. arranged provenance; identity migration; premium-content scan. | WS-02 |
| `MKTextEngineTests/` (4) | `ClusterMapTests.swift`, `JoiningAnalysisTests.swift`, `FormResolverTests.swift`, `BidiRunTests.swift` | Cluster bijectivity on ligature-rich strings; joining states; ZWJ form harvesting; mixed-direction run order. | WS-03 |
| `MKArrangeTests/` (3) | `DerivationTests.swift`, `LigatureDecompositionTests.swift`, `RevertTests.swift` | Snapshot completeness; fidelity-offset decomposition + recomposition; lossless revert. | WS-04 |
| `MKPathTextTests/` (2) | `ArcLengthTests.swift`, `RTLPenOrderTests.swift` | LUT accuracy; RTL visual-order placement on paths. | WS-05 |
| `MKCanvasTests/` (2) | `SnappingEngineTests.swift`, `SelectionControllerTests.swift` | Snap candidate math; group-aware selection. | WS-06 |
| `MKRenderTests/` (2) | `RendererSmokeTests.swift`, `DegradationLadderTests.swift` | Render-to-context smoke on fixture scenes; ladder stage transitions. | WS-07 |
| `MKColorTests/` (2) | `CMYKConversionTests.swift`, `PipelineSelectionTests.swift` | Known-value conversions vs tolerance; per-format pipeline choice incl. FD-03 fallback. | WS-08 |
| `MKExportTests/` (3) | `MegapixelGateTests.swift`, `SVGSerializerTests.swift`, `PDFStructureTests.swift` | 2 MP math; SVG `data-mk-*` provenance + no-silent-flatten; PDF page/OutputIntent structure. | WS-08 |
| `MKFontsTests/` (3) | `FontValidatorTests.swift`, `CoverageAnalysisTests.swift`, `CatalogManifestTests.swift` | sfnt accept/reject fixtures; coverage over Arabic ranges; `manifest.sample.json` decode. | WS-09 |
| `MKPersistenceTests/` (4) | `AtomicWriteTests.swift`, `JournalRecoveryTests.swift`, `CommandStackTests.swift`, `MetadataQueryTests.swift` | Crash-simulated atomicity; replay-to-exact-state; undo/redo inverse laws; search queries. | WS-02 |
| `MKSyncTests/` (2) | `RecordMapperTests.swift`, `ConflictResolverTests.swift` | Project↔record round-trip; LWW + conflict-copy naming. | WS-11 |
| `MKStoreTests/` (3) | `EntitlementPrecedenceTests.swift`, `TrialClockTests.swift`, `ReferralLedgerTests.swift` | Six-state precedence table; rollback guard + earliest-wins; +7d/cap-4 ledger with flag OFF inertness. | WS-10 |
| `MKAnalyticsTests/` (2) | `AggregationBucketTests.swift`, `PayloadPrivacyTests.swift` | Week-bucketing; payload allowlist (no identifiers/text possible). | WS-12 |
| `MKDesignSystemTests/` (1) | `TokenResolutionTests.swift` | Theme protocol conformance completeness for InkPaperTheme. | WS-01 |
| `MKAssetsTests/` (2) | `VectorDecoderTests.swift`, `LicenseIndexTests.swift` | Every bundled SVG decodes; every asset has a license index row. | WS-14 |

App-target UI/snapshot suites: none in v1 (BRIEF: no mandatory accessibility/UI/
snapshot suites); manual Arabic-script verification checklist covers UI correctness.

---

## 22. Traceability (BRIEF.md bullets → files)

| BRIEF requirement | Primary files / groups |
|---|---|
| Name Makhtoot everywhere; bundle id placeholder | §3.1 Info.plist row (FD-01), `ProductCatalog.swift`, `SyncConfiguration.swift`, `MKProjectDocument.swift` (UTI) |
| Universal iPhone+iPad, iOS 18, adaptive | `Package.swift` platforms, `AppRouter.swift`, `EditorScene.swift`, `MKPanelChrome.swift`, §3.1 orientation keys |
| Arabic-only RTL UI | `Resources/ar.lproj/*`, `ArabicLocale.swift`, `RTLHelpers.swift`, `RootView.swift` layoutDirection guard |
| Offline-first; network only fonts/sync/analytics | `CatalogDownloader.swift`, `MKSyncEngine.swift`, `CloudKitUploader.swift` — the only networking files in the tree |
| No accessibility scope v1 | absence of a11y file groups; note in §21 |
| No templates v1; seam only | `TemplateSeam.swift`; `AssetCategory.swift` excludes templates |
| Native typing (shaping, tashkeel, bidi, numerals) | §7 MKTextEngine all files; `TextEditingOverlay.swift`, `OverlayMetricsMatcher.swift` (D-104) |
| Arrange Mode derivation + Source Text Backup + revert | `ArrangementDeriver.swift`, `SourceTextBackup.swift`, `RevertService.swift`, `RevertConfirmationDialog.swift` |
| Never auto-reflow; every glyph/mark/ligature transformable | `ArrangedTextNode.swift`, `ArrangedComposition.swift`, `GlyphNode.swift`, `MarkNode.swift`, `LigatureGroup.swift`, `ArrangeOperations.swift` |
| Dual level (glyph + Unicode letter), lossless | `DualLevelEditor.swift`, `CodepointReDeriver.swift`, `Provenance.swift`, `GlyphLevelToggle.swift` |
| Joining preserved; explicit break + form selector | `JoinBreaker.swift`, `FormResolver.swift`, `FormApplication.swift`, `JoiningForm.swift`, `JoiningFormSelectorView.swift` |
| Full tashkeel/Qurʼanic marks attach/detach/move | `MarkClassifier.swift`, `MarkAttachment.swift`, `MarkNode.swift`, `MarkBadgeOverlay.swift` |
| Ligatures: combined + decomposable, fidelity default, opt-out | `LigatureDetector.swift`, `LigatureDecomposer.swift`, `LigatureRecomposer.swift`, `LigatureActionsMenu.swift`, `FontFeatureControl.swift` |
| Per-object kerning/tracking/baseline/line-height/effects | `TextStyle.swift`, `NodeStyle.swift`, `TextSection.swift`, `StrokeShadowSection.swift`, `GroupNode.swift` (line height) |
| Bézier path text, live-editable until arranged | §9 MKPathText all files; `PathSection.swift`, `PathEditOverlay.swift` |
| No preloaded Qurʼanic content | No Qurʼan data/resource file exists anywhere in this map; `_PROHIBITED.md` blocks KFGQPC fonts; all text user-entered |
| Canvas: drag/resize/rotate/multiselect/guides/snap/layers/group/lock/hide/undo/zoom | §10 MKCanvas all files; `LayersPanel.swift`, `CommandStack.swift` |
| Numeric inspector X/Y/W/H/rotation + style | `TransformSection.swift`, `InspectorNumericField.swift`, `InspectorPanel.swift` |
| Autosave, duplicate, folders, search, export history | `AutosaveController.swift`, `ProjectBrowserViewModel.swift`, `FolderModel.swift`, `SearchIndexer` (in `ProjectSearchField`/`MetadataContainer` group), `ExportHistoryModel.swift`, `ExportHistoryListView.swift` |
| Premium iCloud sync (CloudKit, own iCloud, no SIWA) | §16 MKSync all files; `SyncSettingsView.swift`; §3.2 entitlements |
| Imports: raster/SVG/PDF assets; premium font import | `ImagePickerBridge.swift`, `FileImporterBridge.swift`, `ImageNode.swift`, `AssetStore.swift`, `UserFontImporter.swift` |
| Four font mechanisms + formats + rejection errors | §14 MKFonts: `BundledFontIndex` (1), `CatalogService`+`CatalogDownloader` (2), `UserFontImporter` (3), `CatalogManifest` hooks + `FontMetadata.commercialStatus` (4); `FontValidator.swift` |
| Catalog previews/styles/tags/favorites/search/categories | `FontPickerPanel.swift`, `FontPreviewRow.swift`, `FavoritesAndTags.swift`, `FontSearch.swift`, `FontCategory.swift` |
| Settings→Support→Licensing with full license metadata | `SupportSectionView.swift`, `LicensingScreen.swift`, `FontLicenseDetailView.swift`, `LicenseRecord.swift`, `AssetLicenseIndex.swift` |
| Expiry: fonts lock, export falls back | `ExpiryLockController.swift`, `ExpiryLockExplainerView.swift`, `FormatCapabilities.swift`, `EntitlementGateway.swift` |
| Font acquisition/verification protocol; never invent licenses | `Fonts/<Family>/VERIFICATION.md` pattern, `_PROHIBITED.md`, `LicenseRecord.swift` most-restrictive default |
| Export free/premium matrix, 2 MP, presets, custom dims | `FormatCapabilities.swift`, `MegapixelGate.swift`, `ExportPreset.swift`, `CustomDimensionsFields.swift`, format writer files §13 |
| SVG editability-preserving, documented fallbacks | `SVGSerializer.swift`, `SVGTextEmitter.swift`, `SVGPathEmitter.swift` (`data-mk-*`), `FontEmbedder.swift` |
| True CMYK print PDF + ICC pipeline | `PDFCMYKPipeline.swift`, §12 MKColor all files, `Profiles/` resources (FD-03) |
| Hi-res no artificial caps; warn near memory; tiled | `TiledRasterizer.swift`, `TileRenderer.swift`, `MemoryBudget.swift`, `CustomDimensionsFields.swift` warning |
| Performance budgets + memory ladder + recovery | `MemoryPressureMonitor.swift`, `DegradationLadder.swift`, `RecoveryJournal.swift`, `JournalReplayer.swift`, `MKLog.swift` signposts |
| $3/$30/$90 products; storefront localization | `ProductCatalog.swift`, `Makhtoot.storekit`, `PlanCardView.swift` (displayPrice only; mapped per D-216) |
| 7-day first-launch trial, reinstall-resistant | `TrialManager.swift`, `KeychainTrialStore.swift`, `KVSTrialMirror.swift`, `ClockRollbackGuard.swift`, `LaunchGate.swift` |
| Post-trial free tier keeps editing + free export | `FormatCapabilities.swift` free rows, `EntitlementState.swift` `.free`, `ExpiryLockExplainerView.swift` |
| Referral architected, flag OFF, removable | `MKStore/Referral/` folder (§17), `MKFeatureFlags.referralProgram`, `ReferralSection.swift`, `REVIEW-RISK.md`, `REMOVAL.md` |
| Full StoreKit 2 incl. restore, grace, retry, verification position | `RestoreService.swift`, `SubscriptionStatusMapper.swift`, `VerificationPolicy.swift`, `TransactionMonitor.swift`, `Makhtoot.storekit` |
| No account; SIWA not used | No auth/SIWA files exist; `SyncSettingsView.swift` copy |
| Opt-in anonymous font-usage analytics only | §18 MKAnalytics all files; `AnalyticsConsentView.swift`; `PrivacyInfo.xcprivacy` |
| No ads | No ad SDK/files anywhere (D-101 zero third-party) |
| SwiftUI-first + UIKit/CoreText/CG where needed | UIKit confined to MKCanvas/MKRender/`AppDelegate`; Core Text confined to MKTextEngine/MKFonts |
| Xcode/xcodebuild/gh only | §1 note: no XcodeGen/Tuist/Fastlane/CI files |
| Persistence decision implemented | §15 MKPersistence per D-112 (file packages + JSON scene + SwiftData metadata) |
| Gates: build/perf/StoreKit-sandbox/manual Arabic checklist | §21 preamble; `Makhtoot.storekit`; signpost hooks; tests marked supporting |
| Distribution automation, pause points | §3 config tables (WS-15), `BuildSettings.md`, APP_STORE_CHECKLIST.md cross-ref |

## 23. Coverage check

**FOUNDATION §2 module coverage — all 17 rows present:**

| FOUNDATION §2 target | Section | Prod files |
|---|---|---|
| MKFoundation | §5 | 18 |
| MKModel | §6 | 26 |
| MKTextEngine | §7 | 18 |
| MKArrange | §8 | 14 |
| MKPathText | §9 | 10 |
| MKCanvas | §10 | 22 |
| MKRender | §11 | 16 |
| MKColor | §12 | 9 |
| MKExport | §13 | 18 |
| MKFonts | §14 | 18 |
| MKPersistence | §15 | 21 |
| MKSync | §16 | 12 |
| MKStore (+Referral/) | §17 | 15 + 6 |
| MKAnalytics | §18 | 10 |
| MKDesignSystem | §19 | 17 |
| MKAssets | §20 | 10 |
| App target `Makhtoot` | §2 | 85 |

Totals: **MakhtootKit 260 production Swift files**, **app target 85**, **tests 40** →
**345 production / 385 total Swift files** (within the 250–400 production envelope).
Resource files (fonts, SVG assets, ICC placeholder, storekit config, strings,
manifests, license/verification docs) are additional to these counts.

**Workstream coverage — every WS packet owns ≥1 file group:**

| WS | Owned groups (primary) |
|---|---|
| WS-01 scaffold-designsystem | `Package.swift`, §5 MKFoundation core, §19 MKDesignSystem, `InspectorNumericField.swift` |
| WS-02 model-persistence | §6 MKModel, §15 MKPersistence, `FileLocations`/`ContentHash`/`SchemaVersion` |
| WS-03 text-engine | §7 MKTextEngine (all 18) |
| WS-04 arrange-engine | §8 MKArrange, arranged model files (§6), `ArrangeUI/` (§2.5), `ArrangePickTool` |
| WS-05 path-text | §9 MKPathText, `PathTextRenderer`, `PathEditOverlay`, `PathSection` |
| WS-06 canvas-interaction | §10 MKCanvas, `CanvasHostView`, `GestureCoalescing`, `RectAlgebra` |
| WS-07 rendering-performance | §11 MKRender, `MemoryPressureMonitor`/`MemoryBudget`/`MKLog`, `MemoryWarningBanner` |
| WS-08 export-pipeline | §13 MKExport, §12 MKColor, `ExportUI/` (§2.7), `ExportHistoryModel` |
| WS-09 fonts-licensing | §14 MKFonts + font resources, `LicensingScreen`/`FontLicenseDetailView`, `FontReference`, `FontEmbedder`, `ImportErrorPresenter` |
| WS-10 storekit-entitlements | §17 MKStore + Referral/, Paywall (§2.9), trial files, `PhotoBackgroundGateView`, `ExportGateUpsellView`, `ExpiryLockController`, `MonotonicClock` |
| WS-11 cloudkit-sync | §16 MKSync, `SyncSettingsView`, `SyncStatusBadge`, entitlement iCloud rows |
| WS-12 analytics-settings | §18 MKAnalytics, Settings scene files (§2.8), `ConsentAndTrialModels` |
| WS-13 app-shell-browser | §2.1 App/, §2.2 ProjectBrowser, editor shell (§2.3), Onboarding (§2.10), ImportUI bridges |
| WS-14 assets-ornaments | §20 MKAssets + vector resources, `AssetLibraryPanel`/`AssetGridView` |
| WS-15 distribution | §3.1 Info.plist, §3.2 entitlements, `PrivacyInfo.xcprivacy`, `BuildSettings.md`, `LegalFooterView` |

**Canonical-type coverage:** `MKScene`, `MKNode`, `ArrangedComposition`, `GlyphNode`,
`MarkNode`, `LigatureGroup`, `JoiningForm`, `SourceTextBackup`, `MKEntitlementResolver`,
`MKFeatureFlags`, `MKTheme` — each declared in exactly one file above (§6, §6, §6, §6,
§6, §6, §6, §6, §17, §5, §19 respectively); glossary terms from FOUNDATION §0 used
verbatim throughout.

*End of FILE_MAP.md — Run 1. Conforms to FOUNDATION.md; deviations are defects.*
