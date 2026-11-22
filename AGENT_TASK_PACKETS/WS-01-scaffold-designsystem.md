# WS-01 — Scaffold & Design System

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md; if this packet
and FOUNDATION.md disagree, FOUNDATION.md wins. Use Xcode 16.x, `xcodebuild`, `gh` only (D-101).

## 1. Mission

Create the entire buildable skeleton of Makhtoot: the `Makhtoot.xcodeproj` app target,
the local Swift package `MakhtootKit` with every module target from FOUNDATION §2 stubbed
and compiling under Swift 6 strict concurrency, Arabic-only (`ar`) localization with RTL
forced end-to-end, and the two foundational libraries every other workstream imports:
`MKFoundation` (geometry, transforms, RTL utilities, ids, logging, errors, feature flags)
and `MKDesignSystem` (the token-based `MKTheme` protocol, the default "حبر ورق" (Ink &
Paper) theme, semantic colors, the Arabic type ramp, spacing/radius/motion tokens, and the
RTL-first component kit). This packet is the root of the dependency graph: WS-02 through
WS-15 all branch from it, so API stability and naming discipline matter more here than
anywhere else.

The second half of the mission is de-risking parallelism. You must ship the cross-
workstream **protocol stub layer** (always-premium `MKEntitlementProviding` stub, no-op
persistence hooks, system-font `MKFontProviding` stub) inside `MKFoundation`/dedicated
stub files so that WS-03..WS-08 agents can build and test without waiting for WS-09/WS-10.
Everything you create must follow FOUNDATION §0 naming exactly (`MK` prefix, placeholder
bundle id `com.example.makhtoot` marked as FD-01, product name Makhtoot / مخطوط — never
Masoon) and must build clean with `xcodebuild` from the command line on the first try for
downstream agents.

## 2. Scope

**IN**
- `Makhtoot.xcodeproj`, app target `Makhtoot`, iOS 18.0 deployment, iPhone+iPad universal.
- Local SPM package `MakhtootKit` with all library targets of FOUNDATION §2 declared
  (empty-but-compiling stubs for modules owned by other workstreams).
- `MKFoundation` fully implemented.
- `MKDesignSystem` fully implemented (tokens, theme, RTL components).
- `ar`-only localization scaffolding (String Catalog, development region `ar`), forced RTL.
- Cross-workstream protocol stubs (entitlement, fonts, persistence touchpoints).
- Minimal app shell that boots to a placeholder RTL screen proving theme + RTL + Arabic.
- `.gitignore`, README stub, build documentation (`xcodebuild` invocations).

**OUT**
- Any real feature UI (project browser, editor, settings — WS-13).
- Scene model, persistence (WS-02); shaping (WS-03); canvas (WS-06); rendering (WS-07).
- StoreKit code beyond the entitlement protocol + stub (WS-10).
- App icons/final visual identity (separate design run; FD-02). Use placeholder assets
  clearly marked `PLACEHOLDER`.
- Accessibility work (explicitly not a v1 requirement per BRIEF).

## 3. Dependencies

**Upstream:** none. This is the root workstream.

**Stub strategy (you PROVIDE these; others consume):**
- `MKEntitlementProviding` protocol (in `MKFoundation/Entitlement/`): exposes
  `var state: MKEntitlementState` (`lifetime`, `subscribed`, `inGracePeriod`,
  `inBillingRetry`, `trial(daysLeft:)`, `free` — precedence order per D-113) and
  `func isEntitled(_ capability: MKPremiumCapability) -> Bool`. Ship
  `StubEntitlementResolver` returning always-`lifetime` (always premium). WS-10 later
  ships the real `MKEntitlementResolver` conforming to the same protocol.
- `MKFontProviding` protocol: resolve a font reference (postScript name + size) to a
  `CTFont`; stub maps everything to system SF Arabic. WS-09 replaces internals.
- `MKDocumentStoring` minimal protocol (open/save hooks) with in-memory stub so canvas
  and engine test apps run before WS-02 lands.

**Downstream consumers:** every other packet (WS-02..WS-15). WS-06/WS-13 consume the
component kit; WS-02..WS-08 consume `MKFoundation` types and the stubs above.

## 4. Locked decisions binding this packet (quoted from FOUNDATION.md)

- **D-100**: "Universal iPhone+iPad, iOS 18.0 minimum, Swift 6 language mode (strict
  concurrency), Xcode 16.x, SwiftUI app shell + UIKit canvas host. Arabic-only RTL UI
  (`ar` as the only localization; development region `ar`)."
- **D-101**: "One `Makhtoot.xcodeproj` app target + one local SPM package `MakhtootKit`
  containing all engine/feature modules as library targets… No third-party dependencies
  in v1. No XcodeGen/Tuist/Fastlane/CI services; build and distribute with `xcodebuild` +
  `gh`…"
- **D-102**: "`@MainActor` UI + document model; engines … are `Sendable` services running
  on structured-concurrency task groups; renderer works on immutable scene snapshots…"
- **D-113** (protocol shape only): "Entitlement precedence: lifetime > subscribed > grace
  > billingRetry > trial > free. … Single source: `MKEntitlementResolver`…"
- **D-126**: "Token-based `MKTheme` (semantic colors, Arabic type ramp — UI font: system
  SF Arabic; display/preview fonts from catalog — spacing 4-pt grid, radii, elevation,
  motion durations), RTL-first components, all UI strings in `ar` only. Baseline aesthetic
  (editable founder decision FD-02): 'حبر ورق' (Ink & Paper)…"
- §0 naming table: module prefix `MK`, package `MakhtootKit`, bundle id
  `com.example.makhtoot` ← PLACEHOLDER-FOUNDER-DECISION FD-01, feature flags
  `MKFeatureFlags` with `referralProgram` default **OFF**.

## 5. Task breakdown (ordered)

1. **Create `Makhtoot.xcodeproj`** with app target `Makhtoot`, bundle id
   `com.example.makhtoot` plus a `// PLACEHOLDER FD-01` comment in project docs;
   deployment target iOS 18.0; device family iPhone+iPad; Swift 6 language mode;
   development region `ar`. *Accept:* `xcodebuild -project Makhtoot.xcodeproj -scheme
   Makhtoot -destination 'generic/platform=iOS Simulator' build` succeeds.
2. **Create `MakhtootKit` local package** (path `MakhtootKit/`) referenced by the app
   target; declare library targets: `MKFoundation`, `MKModel`, `MKTextEngine`,
   `MKArrange`, `MKPathText`, `MKCanvas`, `MKRender`, `MKColor`, `MKExport`, `MKFonts`,
   `MKPersistence`, `MKSync`, `MKStore`, `MKAnalytics`, `MKDesignSystem`, `MKAssets`,
   with dependency edges exactly per FOUNDATION §2 table. *Accept:* `swift build` inside
   `MakhtootKit/` compiles all targets; no third-party deps in `Package.swift`.
3. **Stub non-WS-01 modules** with one `<Module>Placeholder.swift` each containing a
   `public enum <Module>Info { public static let owner = "WS-xx" }` marker and doc
   comment naming the owning packet. *Accept:* stubs compile under strict concurrency;
   each names its owning workstream.
4. **`MKFoundation/MKID.swift`**: `MKNodeID`, `MKProjectID`, `MKClusterID` as typed UUID
   wrappers (`Hashable`, `Codable`, `Sendable`). *Accept:* unit test round-trips Codable.
5. **`MKFoundation/Geometry/`**: `MKPoint`, `MKSize`, `MKRect` typealiases/bridges over
   CoreGraphics plus `MKTransform2D` — decomposed transform struct
   `{position: CGPoint, rotation: CGFloat (radians), scale: CGSize}` with
   `affineTransform` derivation, concatenation, inversion, and point mapping. This is the
   canonical node transform per D-111 ("decomposed, not raw matrix"). *Accept:* unit
   tests: compose→decompose round-trip within 1e-6; rotation of marked point matches
   `CGAffineTransform` reference.
6. **`MKFoundation/RTL/MKRTLUtilities.swift`**: helpers `isRTLCharacter(_:)` (Arabic
   ranges incl. U+0600–06FF, U+0750–077F, U+08A0–08FF, presentation ranges for
   *detection only*), `baseDirection(of:)` (first-strong heuristic wrapper), Arabic-Indic
   digit conversion `٠١٢٣٤٥٦٧٨٩` ↔ `0123456789`, and layout-direction helpers for UIKit
   host views. *Accept:* tests cover "١٢٣", "123", "مرحبا Hello", empty string.
7. **`MKFoundation/MKLog.swift`**: `os.Logger` wrappers per subsystem
   (`com.example.makhtoot.<module>` — placeholder-derived, marked) + `MKSignpost` enum of
   signpost names reserved for D-115 budgets (`manipulationFrame`, `typingEcho`,
   `documentOpen`, `autosave`, `export`). WS-07 consumes these names. *Accept:* names
   compile as static constants; documented in a doc comment table.
8. **`MKFoundation/MKError.swift`**: `MKError` protocol (`errorCode`,
   `arabicUserMessage: String?`, `underlying`), base enums for io/validation/entitlement
   errors. *Accept:* every user-facing message is Arabic with Latin gloss in doc comment.
9. **`MKFoundation/MKFeatureFlags.swift`**: compile-time + local runtime flags struct;
   `referralProgram = false` default, `multiPageSeam = false`, `metalRenderer = false`.
   No remote config (offline-first). *Accept:* flags readable from all modules; test
   asserts `referralProgram` defaults false.
10. **Entitlement stub layer**: `MKEntitlementState` enum with precedence comparator
    (D-113 order), `MKPremiumCapability` enum (`premiumFonts`, `fontImport`,
    `photoBackgrounds`, `premiumExportFormats`, `hiResExport`, `cloudSync`,
    `premiumAssets`), `MKEntitlementProviding` protocol, `StubEntitlementResolver`
    (always `lifetime`). *Accept:* test asserts precedence ordering
    lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free.
11. **Font + document stubs**: `MKFontProviding` + `SystemFontStubProvider` (SF Arabic
    via `CTFontCreateUIFontForLanguage`/`.systemFont` bridged to `CTFont`);
    `MKDocumentStoring` + `InMemoryDocumentStore`. *Accept:* stub resolves a `CTFont`
    for size 17 and 96; compiles into `MKFoundation` without importing StoreKit/SwiftData.
12. **`MKDesignSystem/MKTheme.swift`**: `MKTheme` protocol — semantic color tokens
    (`backgroundPrimary`, `backgroundElevated`, `inkPrimary`, `inkSecondary`, `accent`,
    `accentPressed`, `separator`, `canvasBackdrop`, `selectionStroke`, `warning`,
    `destructive`), type ramp tokens, spacing scale (4-pt grid: 4/8/12/16/24/32/48),
    radius scale (4/8/12/continuous), elevation styles, motion durations
    (fast 0.15s / standard 0.25s / modal 0.35s + easing). *Accept:* protocol is
    `Sendable`; theme injected via SwiftUI `Environment` key `\.mkTheme`.
13. **`MKDesignSystem/InkPaperTheme.swift`**: default theme per D-126 — warm paper
    neutrals (paper `#F7F2E9`-family light / ink-dark `#1C1A17`-family dark), ink-dark
    foregrounds, one deep madder-red-family accent (`#A63A2B`-family), light+dark
    variants. Values are FD-02-editable: every hex constant carries `// FD-02 editable`
    comment. *Accept:* renders in both color schemes in the placeholder shell.
14. **`MKDesignSystem/MKTypeRamp.swift`**: Arabic type ramp using system SF Arabic for
    UI (`largeTitle 34, title 28, title2 22, headline 17 semibold, body 17, callout 16,
    footnote 13, caption 11` — tuned for Arabic ascender/descender space with
    line-height multipliers ≥1.3); explicit note that display/preview fonts come from
    the catalog (WS-09), never the UI ramp. *Accept:* snapshot-free manual check: Arabic
    sample "مخطوط — حبر ورق" renders without clipped diacritics at every ramp step
    (tashkeel test string "خَطٌّ عَرَبِيٌّ" not clipped).
15. **RTL-first components** in `MKDesignSystem/Components/`: `MKPanel` (grouped
    container), `MKInspectorField` (label + numeric TextField, RTL label order, Latin
    digits for numeric entry with Arabic-Indic display option), `MKSlider` (RTL-mirrored
    track), `MKChip`, `MKToolbarButton`, `MKSectionHeader`, `MKBanner` (used later for
    memory-pressure warning "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا"). *Accept:* a
    DesignSystemGallery debug screen shows all components; in RTL the slider minimum is
    on the RIGHT; chevrons point left for "forward".
16. **Localization scaffolding**: String Catalog `Localizable.xcstrings` with `ar` as
    the only language; `CFBundleDevelopmentRegion = ar`; app-level forced RTL is NOT
    hacked via semanticContentAttribute overrides — it follows `ar` locale naturally;
    document the rule "all UI strings in ar only, Latin gloss in comments" (FOUNDATION
    §12) in `MakhtootKit/README.md`. *Accept:* running on an English-device simulator
    still shows Arabic RTL UI (only localization = ar).
17. **Placeholder app shell**: `MakhtootApp.swift` (SwiftUI `@main`), `RootView` showing
    theme-driven placeholder: app name "مخطوط", theme swatch row, type-ramp sample,
    components gallery link (DEBUG only). *Accept:* boots on iPhone 16 and iPad simulators;
    no constraint warnings; RTL layout confirmed.
18. **Info.plist / privacy**: `UISupportedInterfaceOrientations` all for iPad, portrait+
    landscape iPhone; no network-permission-requiring keys; empty
    `NSPrivacyCollectedDataTypes` seed of `PrivacyInfo.xcprivacy` (analytics is opt-in,
    WS-12 extends). *Accept:* app builds with privacy manifest present.
19. **Build docs**: `docs/BUILD.md` (create if absent) with exact `xcodebuild` commands
    for Debug/Release build, simulator run, and test invocation used by all downstream
    packets. *Accept:* commands copy-paste-run successfully.
20. **Unit test targets**: `MKFoundationTests`, `MKDesignSystemTests` wired into scheme
    `Makhtoot`. *Accept:* `xcodebuild test` runs the suites green.
21. **Cross-packet contract doc**: `MakhtootKit/CONTRACTS.md` listing every public stub
    protocol, its owner packet, and replacement plan (StubEntitlementResolver → WS-10,
    SystemFontStubProvider → WS-09, InMemoryDocumentStore → WS-02). *Accept:* file lists
    all three with exact type names.

## 6. Arabic-correctness notes

- The design system is the first place Arabic breaks silently. Verify with fixture
  strings: "مخطوط", "خَطٌّ عَرَبِيٌّ" (shadda+tanwin stacks must not clip at caption
  sizes), "لا إله إلا الله" (lam-alif must render as ligature in every component),
  mixed-digit "الإصدار 1.0 — ٢٠٢٦" (numerals must not reorder in RTL labels).
- Numeric inspector fields (component only in this WS): accept both `123` and `١٢٣`
  input; normalize to Latin internally via `MKRTLUtilities`.
- Slider/stepper mirroring: increase must be leftward motion in RTL.
- Never use Unicode presentation-form codepoints (U+FB50–FDFF, U+FE70–FEFF) in any
  string literal, sample, or test — D-103 forbids them app-wide; detection ranges in
  `MKRTLUtilities` are the only sanctioned mention.
- Placeholder shell must be checked with iOS Arabic keyboard input in a TextField to
  confirm no LTR flipping of the caret.

## 7. Packet acceptance criteria (gates)

- **Build gate**: clean `xcodebuild` build + test, zero warnings in `MKFoundation`/
  `MKDesignSystem`, Swift 6 strict concurrency with no `@unchecked Sendable` except
  documented CoreText bridges (none expected in this WS). TEST_MATRIX area `T-SCAF-*`.
- **Design-system gate**: gallery screen manual review against D-126 tokens; RTL
  mirroring checklist passes (`T-DS-*`).
- **Manual Arabic check**: §6 fixture strings render correctly at all ramp sizes on
  iPhone + iPad simulators (`T-ARABIC-M-01..04` scaffold rows).
- **Perf sanity** (D-115 pre-gate): cold app launch to placeholder < 1 s on simulator;
  no main-thread hangs reported by the Thread Performance Checker.
- **Stub gate**: a scratch target importing only `MKFoundation` can resolve
  always-premium entitlement + a CTFont — proving WS-03..WS-08 can start.

## 8. Deliverables (FILE_MAP.md granularity)

- `Makhtoot.xcodeproj/`
- `Makhtoot/App/MakhtootApp.swift`, `Makhtoot/App/RootView.swift`,
  `Makhtoot/App/DesignSystemGallery.swift` (DEBUG), `Makhtoot/Resources/Localizable.xcstrings`,
  `Makhtoot/Resources/PrivacyInfo.xcprivacy`, `Makhtoot/Resources/Assets.xcassets` (placeholder)
- `MakhtootKit/Package.swift`, `MakhtootKit/README.md`, `MakhtootKit/CONTRACTS.md`
- `MakhtootKit/Sources/MKFoundation/MKID.swift`, `Geometry/MKTransform2D.swift`,
  `Geometry/MKGeometry.swift`, `RTL/MKRTLUtilities.swift`, `MKLog.swift`, `MKError.swift`,
  `MKFeatureFlags.swift`, `Entitlement/MKEntitlementState.swift`,
  `Entitlement/MKEntitlementProviding.swift`, `Entitlement/StubEntitlementResolver.swift`,
  `Stubs/MKFontProviding.swift`, `Stubs/MKDocumentStoring.swift`
- `MakhtootKit/Sources/MKDesignSystem/MKTheme.swift`, `InkPaperTheme.swift`,
  `MKTypeRamp.swift`, `MKSpacing.swift`, `MKMotion.swift`, `Components/MKPanel.swift`,
  `Components/MKInspectorField.swift`, `Components/MKSlider.swift`,
  `Components/MKChip.swift`, `Components/MKToolbarButton.swift`,
  `Components/MKBanner.swift`, `Components/MKSectionHeader.swift`
- Placeholder files for all other module targets
- `MakhtootKit/Tests/MKFoundationTests/*`, `MakhtootKit/Tests/MKDesignSystemTests/*`
- `docs/BUILD.md`

## 9. References

- ARCHITECTURE.md: §1 System Overview, §2 Module Architecture, §22 Design System,
  §24 Extension Seams (v2).
- PRD.md: §1 Overview & Personas, §2 Information Architecture & Navigation,
  §22 Non-Functional Requirements.
- BRIEF.md: "Product identity", "Platform and scope", "Engineering" bullets.
- Market study: §12 Architecture implications[^61]; §4 SF Arabic Qur'anic-mark coverage
  context[^21][^22]; WWDC22 "Design for Arabic"[^24].

## 10. Codebase-memory MCP duties

- `manage_adr`: record ADR "WS01-A1: Project/package layout per D-100/D-101" and
  "WS01-A2: Cross-workstream stub contracts (entitlement/font/document)" with
  alternatives considered (single mega-target rejected; per-feature xcodeproj rejected).
- Implementation log entries at: project builds; MKFoundation done; MKDesignSystem done;
  stubs done — each with the exact `xcodebuild` command + result summary.
- Verification evidence: store build/test logs, screenshot descriptions of the gallery in
  light/dark RTL, and the T-ARABIC-M fixture-check outcomes.
- Index the repository (`index_repository`) once the scaffold compiles so later
  workstreams can `search_code` the contracts.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Product identity — name Makhtoot/مخطوط everywhere, never Masoon | T1, T3, §0 naming discipline |
| Product identity — bundle id `com.example.makhtoot` marked placeholder FD-01 | T1 |
| Product identity — themeable Arabic-first design-system layer, swappable tokens, baseline aesthetic (FD-02) | T12–T14 |
| Platform — universal iPhone+iPad, one codebase, iOS 18 min | T1 |
| Platform — Arabic-only RTL UI at launch | T16, T17 |
| Platform — accessibility NOT a v1 requirement | §2 OUT |
| Platform — fully useful offline, network use restricted | T9 (no remote config, offline-first flags) |
| Engineering — SwiftUI-first, UIKit/Core Text/etc. permitted where needed | T2, T17 |
| Engineering — Xcode/xcodebuild/gh only, no XcodeGen/Tuist/Fastlane/CI | T1–T2, T19 |
| Engineering — gates: build success + manual Arabic-script verification checklist | §7 (Build gate, Manual Arabic check) |
| Engineering — codebase-memory MCP conventions | §10 |
| Canvas & projects — numeric inspector component | T15 (`MKInspectorField`; full inspector wiring: WS-06/WS-13) |
| Monetization — referral flow isolated behind feature flag, default OFF (Q78) | T9 (`referralProgram = false`; activation logic: WS-10) |
| Accounts/data/privacy — privacy manifest groundwork for opt-in analytics | T18 (`PrivacyInfo.xcprivacy` seed; rest: WS-12) |
