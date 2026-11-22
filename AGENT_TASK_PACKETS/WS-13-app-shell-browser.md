# WS-13 — App Shell & Project Browser (Makhtoot app target)

Run-1 agent task packet · Makhtoot (مخطوط) · Target: `Makhtoot` app target — navigation architecture, project browser, onboarding + trial-start, adaptive iPhone/iPad layouts, RTL-only UI, editor scene composition. Consumes FOUNDATION.md D-100, D-101, D-102, D-104, D-112, D-123, D-126, module map §2.

---

## 1. Mission

Build the application shell that turns MakhtootKit's modules into a product: the SwiftUI scene structure and navigation architecture; the project browser (المشاريع) with folders, search, duplicate, and thumbnails backed by MKPersistence's SwiftData metadata index; onboarding with the D-123 trial-start moment (trial begins at FIRST APP LAUNCH — the onboarding must present it honestly, not gate on it); and the editor scene that composes the canvas (WS-06), layers panel, inspector, font picker (WS-09), asset browser (WS-14), export sheet (WS-08), and paywall (WS-10 state machine) into one working, genuinely adaptive iPhone/iPad experience. The entire UI is Arabic-only RTL (D-100): `ar` is the sole localization, the development region is `ar`, and every screen must be designed RTL-first, not mirrored-as-an-afterthought.

"Genuinely adaptive" (BRIEF) means real layout strategies per size class, not a scaled-up phone UI: on iPad the editor uses persistent side panels (layers/inspector as columns, floating pickers), keyboard shortcuts and pointer hover states where cheap; on iPhone panels become bottom sheets and toolbars compress. The browser is a document-centric home: fast cold launch to your work (<1 s to interactive list per D-115 spirit), live thumbnails, folder tree, instant search. The shell also owns app bootstrap ordering — font registration (WS-09 T5), entitlement resolution (WS-10), trial record write (D-123), sync engine start (WS-11), analytics no-op init (WS-12) — with explicit dependency ordering and no blocking of first paint beyond what correctness requires.

## 2. Scope

**IN:**
- App bootstrap + dependency container (composition root wiring all MakhtootKit services; owns the stub-vs-real swaps as packets land).
- Navigation architecture: `NavigationStack`/`NavigationSplitView` strategy, route model, deep-link seam (none in v1 beyond internal routes).
- Project browser: grid/list of projects with thumbnails, folders (create/rename/delete/move), search (name + search-text metadata), duplicate, delete (with confirm), sort (modified/name), sync badges (WS-11 contract), export-history access point.
- New-project flow: canvas preset chooser (social/story/messaging-status/wallpaper/print ratios at 2 MP baseline per BRIEF; premium custom exact dimensions gated).
- Onboarding (first launch): 3–4 screens introducing the differentiator (Arrange Mode), then trial-start moment; paywall compliance choreography (content before paywall).
- Editor scene composition: canvas host (UIViewRepresentable from WS-06), top toolbar, layers panel, numeric inspector, font picker panel, asset browser panel, export sheet, memory-pressure banner (WS-07 contract), autosave indicator; panel adaptivity iPhone/iPad.
- Pre-export outline-disclosure review step (R-13.7): consumes WS-08's `FallbackNote` list and renders it BEFORE export commit (D-227(7)).
- Paywall presentation surface rendering WS-10's `MKPaywallStateMachine` + PW-01…PW-10 compliance requirements.
- RTL enforcement + Arabic strings catalog for the shell; app icon/asset-catalog placeholders (visual identity comes from a separate design run — FD-02).
- Scene-phase handling: background autosave triggers, entitlement re-resolve on foreground.

**OUT:**
- Canvas internals/gestures (WS-06), rendering (WS-07), export logic (WS-08), font logic (WS-09), store logic (WS-10), sync engine (WS-11), Settings screens (WS-12 — this packet only routes to them), assets content (WS-14), distribution (WS-15), accessibility work (not a v1 requirement — BRIEF Q53), templates (prohibited v1 — only the extension seam note), multi-window iPad scenes (v2 seam, single window per FOUNDATION single-canvas scope).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream (this packet is the integration point for nearly everything):**
- `MKPersistence` (WS-02): project/folder/search metadata, document open/save, thumbnails. **Stub:** in-memory project store fixture until WS-02 lands.
- `MKCanvas`/`MKRender` (WS-06/07): canvas host view + memory banner contract. **Stub:** placeholder gray canvas view with pinch/pan disabled, protocol `MKCanvasHosting`.
- `MKFonts` (WS-09): picker data + registration at bootstrap. **Stub:** fixture catalog of 3 fonts.
- `MKStore` (WS-10): entitlements, paywall state machine, trial manager. **Stub:** `AlwaysPremiumEntitlementStub` then WS-10's `SandboxScenarioStub` presets; trial-start call is a protocol `MKTrialStarting` no-op until real.
- `MKSync` (WS-11): status publisher for badges. **Stub:** static publisher.
- `MKAnalytics` (WS-12): `MKFontUsageRecording` hook. **Stub:** no-op.
- `MKAssets` (WS-14): asset browser model. **Stub:** empty catalog provider.
- `MKDesignSystem` (WS-01): all tokens/components — hard dependency, no stub; shell must not ship ad-hoc styles.
- `MKExport` (WS-08): export sheet flow. **Stub:** sheet with disabled formats.

All stubs live behind protocols already defined in the owning packets; the composition root (`AppContainer`) is the ONLY place stubs are referenced, so swapping is a one-file change per module. Document the current stub matrix in `AppContainer.swift` header comments.

**Downstream consumers:** WS-15 (the shell is what gets archived; launch screens/screenshots), all manual TEST_MATRIX flows execute through this shell.

## 4. Locked decisions binding this packet

- **D-100**: "Universal iPhone+iPad, iOS 18.0 minimum, Swift 6 language mode (strict concurrency), Xcode 16.x, SwiftUI app shell + UIKit canvas host. Arabic-only RTL UI (`ar` as the only localization; development region `ar`)."
- **D-101**: one `Makhtoot.xcodeproj` app target + local SPM `MakhtootKit`; no third-party deps.
- **D-102**: `@MainActor` UI + document model; engines off-main.
- **D-104**: in-canvas text editing via UITextView overlay — the shell hosts but does not implement it (WS-06).
- **D-112**: browser reads ONLY the SwiftData metadata index (never parses scene.json for lists); autosave debounce ≤2 s + immediate on background.
- **D-123**: trial starts at FIRST APP LAUNCH — bootstrap writes the trial record regardless of onboarding completion; onboarding presents it, never creates it.
- **D-126**: theme "حبر ورق" (Ink & Paper) tokens; RTL-first components; all strings `ar`.
- BRIEF: genuinely adaptive layouts; no accessibility scope (Q53); no templates (Q61–62) — minimal seam only; paywall-after-content choreography (market study §8[^50][^51]).
- FOUNDATION §0: bundle id `com.example.makhtoot` MARKED PLACEHOLDER (FD-01).

## 5. Task breakdown (ordered)

**T1 — Project scaffold conformance.** Verify/extend the WS-01 scaffold: app target `Makhtoot`, `MakhtootKit` local package linked, `ar` sole localization, `CFBundleDevelopmentRegion = ar`, deployment target iOS 18.0, Swift 6 mode, placeholder bundle id with `// PLACEHOLDER-FD-01` marker, required capabilities listed but commented for founder team (CloudKit, iCloud KVS, Keychain sharing n/a). **AC:** clean build both destinations (iPhone 16 sim, iPad Pro 13" sim); `xcodebuild -showBuildSettings` evidence of region/target.

**T2 — App bootstrap & dependency container.** `MakhtootApp` (SwiftUI `App`) + `AppContainer` (composition root): construction order — (1) MKFoundation logging/flags, (2) MKPersistence store open, (3) font registration kickoff (async, T5 of WS-09 — browser may render before completion; editor font picker awaits), (4) trial record ensure (D-123 — synchronous Keychain check/write, <10 ms), (5) entitlement resolver start + cached state, (6) sync controller (conditional), (7) analytics init (inert unless consent). First frame must not await (3), (6), (7). Pseudocode ordering with `TaskGroup` for parallelizable steps. **AC:** cold-launch to browser interactive <1 s on A15 device with 50-project fixture; trial record exists after first launch even if app killed during onboarding (test: kill at onboarding screen 1, relaunch, verify Keychain record + correct daysLeft).

**T3 — Route model & navigation architecture.** `MKRoute` enum (`browser, editor(projectID), settings, paywall(context), onboarding`) + `AppNavigationModel` (@Observable). iPhone: `NavigationStack` root = browser; editor pushes full-screen; settings/paywall = sheets. iPad: `NavigationSplitView` (sidebar = folders, content = project grid) for browser; editor = full-screen cover with its own internal panel layout; settings = sheet (routes into WS-12 scenes); paywall = formSheet. RTL: verify NavigationStack back-chevron + swipe-back operate RTL-correctly (system handles with `ar` locale; add manual check). **AC:** route round-trip unit tests; all five routes reachable; state restoration of last-open project via `SceneStorage` (reopen editor on relaunch if it was open and the document still exists).

**T4 — Project browser: data + grid.** `ProjectBrowserViewModel` reading MKPersistence metadata index (never scene files — D-112): sections by folder or flat all-projects; `LazyVGrid` thumbnails (thumbnail.png from package, async-loaded, memory-capped cache), name, modified date (Arabic relative: "قبل ٣ أيام"), sync badge slot (WS-11 per-project states), premium-content badge (projects flagged premium-content per D-119 show a subtle badge when entitlement is free). Sort: آخر تعديل (default) / الاسم. Empty state: "ابدأ أول تصميم لك" + prominent new-project button. **AC:** 500-project fixture scrolls at 60 fps (Instruments capture); thumbnails never block scroll (async decode); empty/error states render.

**T5 — Folders.** Folder tree (one level deep in v1 UI, model supports nesting via `folderPath` — document seam): create ("مجلد جديد"), rename, delete (confirm; projects move to root, never deleted with folder), move project to folder (context menu + drag on iPad). Sidebar on iPad; horizontal chips or menu on iPhone. **AC:** all operations persist via MKPersistence; deleting a folder with 3 projects leaves 3 projects at root; RTL drag-and-drop on iPad works.

**T6 — Search.** Search field (browser toolbar): matches project name + stored search-text metadata (WS-02 extracts text content at save — consume, don't build). Arabic normalization identical to WS-09 T8 rules (share the normalizer via MKFoundation — if WS-09 put it in MKFonts, lift it to MKFoundation and coordinate). Debounced 200 ms, results replace grid. **AC:** query "عيد" finds a project containing عيدكم مبارك in its text metadata; normalization test (أ/ا); clear restores full grid.

**T7 — Project operations.** Context menu + swipe actions: فتح, تكرار (duplicate — MKPersistence deep-copy incl. assets, name "نسخة من X"), إعادة تسمية, نقل إلى مجلد, حذف (two-step confirm "سيُحذف المشروع نهائيًا من هذا الجهاز"), مشاركة آخر تصدير (if export history non-empty — routes to WS-08 history). **AC:** duplicate of a 20-node project is independent (edit copy, original untouched); delete removes package + metadata + queues sync tombstone (verify via WS-11 stub spy).

**T8 — New-project flow.** Preset sheet: canvas size presets — مربع ١:١ (1080×1080), ستوري ٩:١٦ (1080×1920), منشور ٤:٥ (1080×1350), حالة رسائل, خلفية هاتف, بطاقة طباعة A5-ratio — all ≈2 MP baseline (BRIEF export presets); "أبعاد مخصصة" premium-gated (exact WxH numeric fields; free tap → paywall context `.premiumFeatureTap(.customCanvas)`). Creates document via MKPersistence, routes to editor. **AC:** each preset creates correct pixel dimensions in manifest; custom gated for free stub; created project appears in browser instantly.

**T9 — Onboarding + trial-start moment.** First-launch flow (flag in UserDefaults; trial record ALREADY written by T2): Screen 1 — the differentiator (Arrange Mode promise: "حرّك كل حرف كما تشاء"), Screen 2 — typing/tashkeel/ligatures teaser, Screen 3 — trial presentation: "تجربتك المجانية لأسبوع بدأت — بلا التزام" with explicit expiry date (from trial manager), what premium includes, and a clearly visible skip/continue ("ابدأ التصميم") that goes to the browser WITHOUT purchase; optional "عرض الباقات" opens paywall (context `.onboardingTrialIntro`, dismissible per PW rules). No consent prompts here (WS-12 rule); no account creation (none exists). Content-before-paywall choreography per market study §8[^50][^51]. **AC:** onboarding shows once; trial date shown == Keychain record; skip lands in browser; paywall from onboarding is dismissible (manual check); relaunch mid-onboarding resumes or skips gracefully.

**T10 — Paywall surface.** SwiftUI paywall rendering WS-10's state machine + PW-01…PW-10: all three products with localized prices, per-plan detail ("٣ دولارات شهريًا" style comes from StoreKit localized strings — never hardcode currency), auto-renew disclosure adjacent to CTA, Privacy/Terms links (`MKLegalLinks` from WS-12 T14), restore button, visible close (X) always, `catalogUnavailable` graceful state, success/pending/failed states with Arabic messages. One implementation reused for all contexts. **AC:** PW checklist walkthrough recorded (each PW-id → screenshot); StoreKit-testing purchase from paywall flips UI to premium live; no urgency/countdown UI anywhere.

**T11 — Editor scene composition.** `EditorScene`: hosts `MKCanvasHosting` UIKit view (WS-06) full-bleed; top toolbar (undo/redo from document command stack, title, export button, done/back); bottom/leading tool rail (add text, add shape/asset, arrange-mode toggle — actions dispatch to canvas contract); panels: طبقات (layers), الخصائص (numeric inspector), الخطوط (font picker), العناصر (assets). Panel contracts are protocol-typed views provided by owning packets where they exist (layers/inspector may be part of WS-06 contract — integrate, don't duplicate; if WS-06 ships them as models only, build the SwiftUI panels here per its view-model contract). Autosave indicator (subtle, from MKPersistence status), memory banner region (WS-07 D-116 banner "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا"). **AC:** editor opens a fixture project; all panels open/close; toolbar actions reach canvas stub spies; banner region renders when WS-07 stub emits stage 2.

**T12 — Adaptive layout (the "genuinely adaptive" gate).** Size-class-driven strategies: **iPad regular**: layers + inspector as persistent trailing columns (user-collapsible), font/asset pickers as floating panels or popovers anchored to rail, canvas keeps ≥60% width; pointer hover highlights on tools; keyboard shortcuts: ⌘Z/⇧⌘Z undo/redo, ⌘D duplicate, delete key, ⌘E export, space-drag pan (forward to canvas contract). **iPhone / iPad compact**: panels as detented bottom sheets (medium/large), toolbar compresses to icons, inspector fields in scrollable sheet. Rotation preserves editor state. RTL: panel sides honor RTL (trailing = left in RTL — verify visually, this is the classic mistake). **AC:** manual matrix T-shell-04 across iPhone 16, iPhone SE-class width, iPad 11" portrait/landscape, iPad 13" with Stage Manager narrow width — no clipped/overlapping panels, canvas never fully obscured, all functions reachable in every size; keyboard shortcuts fire on iPad with hardware keyboard.

**T13 — RTL & strings audit.** Central `Localizable.xcstrings` (ar-only) for shell strings; forbid string literals in views (lint grep in CI-less script `Scripts/strings-audit.sh`); numerals policy: UI counts/dates use Arabic-Indic via `ar` locale formatting defaults, numeric inspector fields accept both Arabic-Indic and Latin digit input (document; actual field impl in WS-06/12). Layout-direction audit: no `.leading`/`.trailing` misuse producing LTR-anchored elements; screenshots reviewed. **AC:** audit script passes; manual RTL sweep T-shell-05 finds zero mirrored-wrong elements.

**T14 — Scene-phase & lifecycle glue.** `scenePhase` handling: background → MKPersistence immediate autosave + journal flush (D-112/D-116), entitlement re-resolve + sync opportunistic kick on foreground; memory-warning forward to WS-07 controller. Document-open failure UX (corrupt/missing package): Arabic error with "استعادة من النسخة الاحتياطية" if rescue snapshot exists (WS-02 `backups/`). **AC:** backgrounding mid-edit then force-kill loses nothing (relaunch restores exact state — integration with WS-02); corrupt-package fixture shows recovery flow.

**T15 — Template extension seam (explicitly minimal).** Single seam: browser new-project sheet has a hidden section driven by `MKFeatureFlags.templatesEnabled` (default false, no UI when false) + `MKTemplateProviding` empty protocol in MKFoundation. NOTHING else — no template models, no gallery. Comment references BRIEF Q61–62 prohibition. **AC:** flag off = zero UI difference; grep confirms no other template references.

**T16 — Export & history entry points.** Export button → WS-08 export sheet (contract; commit step gains the T19 disclosure review); browser project context-menu "سجل التصدير" → export-history list (MKPersistence metadata) with re-share via `UIActivityViewController`/ShareLink. **AC:** history renders fixture records with format/date; free-tier export restrictions visible in sheet via stub.

**T17 — Launch performance & polish pass.** Instruments run: cold launch, browser scroll, editor open (typical ≤100-node fixture <1 s — D-115); fix regressions; ensure first paint isn't blocked by font registration (T2 ordering). **AC:** signposts added (`os_signpost` categories `launch`, `browser`, `editorOpen`); measured numbers recorded as evidence vs D-115 budgets.

**T18 — Shell error/empty/edge states compendium.** Implement + verify: empty browser, empty search, empty folder, document-open failure, disk-full save failure (Arabic message + retry), paywall catalog-unavailable, sync badge error states. Cross-reference PRD §21. **AC:** each state has a fixture trigger + screenshot evidence.

**T19 — Pre-export outline-disclosure UI (new task, PRD R-13.7 / D-227(7)).** Before an export actually commits (file written/shared) — not after — the export sheet (T16) surfaces WS-08's `FallbackNote` list for the current export request as a plain-language Arabic disclosure: which elements will be outlined/rasterized/substituted and why (font-license outline, path-text-as-paths, low-res asset, locked-font block, emoji-as-image-element, etc. — the exact strings from WS-08's `ExportFallbacks.md`, its task 16). This is a review step the user sees and proceeds from or cancels; it is positioned strictly BEFORE the commit action, extending "never silently flatten" to "never disclose only after the fact." If the request's `FallbackNote` list is empty, skip the step silently — no empty disclosure screen for a fallback-free export. **AC:** exporting a scene with ≥1 WS-08 fallback (e.g. a non-embeddable-license font) shows the disclosure listing that exact Arabic note string before the commit control is reachable; exporting a fallback-free scene skips straight to export with no extra screen; disclosure content is read directly from that request's `ExportResult.fallbacksApplied` (WS-08), never independently recomputed by the shell.

## 6. Compliance & licensing notes

- Paywall choreography: content before paywall, visible dismiss, disclosure adjacent to CTA — market study §8 [^50][^51][^45]; enforced via WS-10 PW-01…PW-10 checklist at T10/T9.
- Trial presentation must not misrepresent the app as permanently free nor claim an Apple introductory offer (WS-10 T7 doc) — copy reviewed at T9. **VERIFY-AT-SUBMISSION** against current 3.1.2 wording.
- No account/no SIWA surface anywhere in the shell (Guideline 4.8 stays untriggered [^56][^57]).
- No accessibility scope per BRIEF Q53 — do not add VoiceOver work; do not *break* system defaults gratuitously either (zero-effort defaults stay).
- Bundle id/team/capabilities are FD-01 placeholders — the shell must compile for simulator without a team; device signing handled in WS-15.
- App icon/visual identity: placeholder assets marked FD-02; do not invent brand artwork beyond neutral placeholders.

## 7. Packet acceptance criteria (gates)

1. **Build gate:** `xcodebuild build` green for iPhone + iPad simulators, Swift 6 strict, ar-only localization verified.
2. **Integration gate:** app runs end-to-end with current stub matrix: launch → onboarding → browser → new project → editor (stub canvas) → export sheet (stub) → settings → paywall (StoreKit-testing) without crashes.
3. **Manual Arabic checks (TEST_MATRIX `T-shell-*`):** T-shell-01 browser CRUD + folders + search; T-shell-02 onboarding + trial moment (incl. kill-mid-onboarding trial persistence); T-shell-03 paywall PW walkthrough; T-shell-04 adaptive matrix (5 form factors incl. Stage Manager narrow); T-shell-05 RTL sweep; T-shell-06 lifecycle/no-data-loss; T-shell-07 edge-state compendium; T-shell-08 pre-export outline-disclosure UI (T19) shows before commit and matches WS-08's fallback list exactly.
4. **Performance gate:** D-115-derived: cold launch <1 s to interactive browser (A15), editor open <1 s typical fixture, browser scroll 60 fps @ 500 projects — Instruments evidence.
5. **StoreKit sandbox gate:** paywall purchase/restore round-trip in sandbox once WS-10 integrated (T-store cross-refs).

## 8. Deliverables

- `Makhtoot/` app target sources: `MakhtootApp.swift`, `AppContainer.swift` (stub matrix documented), `Navigation/`, `Scenes/Browser/`, `Scenes/Onboarding/`, `Scenes/Editor/`, `Scenes/Paywall/`, shared shell components.
- `Localizable.xcstrings` (ar), `Scripts/strings-audit.sh`, asset-catalog placeholders (FD-02 marked).
- Unit tests (routes, view models) + fixtures (50/500-project stores, corrupt package).
- Instruments evidence files/notes for gate 4; screenshot set for edge states + PW walkthrough.
- Stub protocol conformances used pending other packets, isolated under `Makhtoot/Stubs/` (test/dev only).

## 9. References

- FOUNDATION.md §1 (D-100/101/102), §3 D-104, §4 D-112, §8 D-113/D-123, §9 D-126, §0 naming, §10 FD-01/FD-02.
- ARCHITECTURE.md: §1 System Overview; §2 Module Architecture; §10 Canvas & Interaction (host contract); §12 Performance & Memory (banner); §13 Persistence & Documents; §18 StoreKit & Entitlements; §22 Design System; §24 Extension Seams (templates/multi-page).
- PRD.md: §2 Information Architecture & Navigation; §3 Project Browser & Documents; §4 Canvas Editor (composition); §10 Layers & Inspector; §14 Free/Premium Gating & Paywall; §15 Trial/Subscription/Lifetime States; §21 Edge-Case Compendium; §22 Non-Functional Requirements.
- APP_STORE_CHECKLIST.md: paywall compliance; screenshots source flows (WS-15 uses these screens).
- Market study §8 (paywall/trial UX), §12 (SwiftUI shell + UIKit canvas hybrid); footnotes [^45][^50][^51][^56][^57].
- TEST_MATRIX.md `T-shell-*` (+ cross-refs T-store-*, T-sync-*).

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS-13-A1: navigation architecture (Stack vs SplitView per size class) + route model"; "WS-13-A2: bootstrap ordering and what may block first paint"; "WS-13-A3: panel adaptivity strategy iPhone/iPad"; "WS-13-A4: stub matrix + swap log (which packet replaced which stub, when)".
- Implementation logs per task T1–T19 with file paths.
- Verification evidence: Instruments captures (launch/scroll/editor-open), adaptive-matrix screenshots per form factor, RTL sweep notes, trial-persistence kill-test transcript, PW walkthrough screenshot set.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Universal iPhone+iPad, one codebase, genuinely adaptive layouts, iOS 18 minimum | T1, T12 |
| Arabic-only RTL UI | T13 (D-100 verified) |
| Canvas & projects: local autosave, duplicate, project folders, search, export history | T4–T7, T16 |
| Layers panel, numeric inspector, canvas composition | T11 (engine side: WS-06/07) |
| Premium/lifetime iCloud project sync (per-project badge rendering) | T4 (consumes WS-11 status contract) |
| No templates in v1 (Q61–62); only a minimal extension seam | T15 |
| 7-day trial starts at FIRST APP LAUNCH (Q37) | T2 (trial record write), T9 (onboarding presentation) |
| Post-trial free tier retains full editing (Q41) | T9, T10 |
| Export presets: social/story/messaging-status/wallpaper/print at 2 MP baseline; premium custom exact dimensions | T8 |
| Free-tier gating: resolution/formats/premium layers/locked fonts/photo backgrounds (paywall surfacing) | T10 (engine side: WS-08/WS-10) |
| Full StoreKit 2 paywall: status/restore/precedence/messaging (rendering side) | T10 (engine side: WS-10) |
| No mandatory account; no SIWA surface | §6 compliance notes |
| Accessibility NOT a v1 requirement (Q53) | §6 compliance notes |
| Gates (Q59): manual Arabic-script verification checklist | Gate 3, T-shell-* |
| Codebase-memory MCP conventions: durable ADRs, implementation logs, verification evidence per phase (Q58) | §10 |
| Never silently flatten on export — pre-commit disclosure of fallbacks (PRD R-13.7, D-227(7)) | T19 (data source: WS-08) |
