# ANDROID_SPINE.md — Makhtoot Android Port: Shared Specification

This is the single authoritative source for every fact `ANDROID_PORT_PLAN.md` and
`ANDROID_TASK_PACKETS/BATCH-0.md`…`BATCH-9.md` cite by section number. If a plan document or a
packet states a fact that conflicts with this file, this file is correct and the other document
is wrong and must be corrected in its own pass — this file is not itself patched to match a
packet. Section numbers below (`§0`…`§17`) are frozen: they are cited verbatim across all ten
`BATCH-N.md` files and must not be renumbered without updating every citation.

This document supersedes an earlier state of the plan in which `ANDROID_SPINE.md` was cited 36
times across the plan and packets but did not exist on disk. Every number, decision, and rule
below has been re-derived from the shipped Swift source (`find`/`wc -l` against `main`,
2026-07-30) or corrected per a verified adversarial-review finding; overrides are folded into
the relevant section inline rather than kept as a separate errata list, so a writer who reads
only this file produces a consistent packet.

---

## 0. Overview and source of truth

Founder-authorised. This plan overrides `CLAUDE.md`'s "iPhone and iPad only. No Android port,
and none is planned for v1" and `FOUNDATION.md` D-100 ("Universal iPhone+iPad"). The override is
recorded as a formal decision at Batch 0 · Agent 0.5, which writes **D-300** into
`DECISIONS_LOG.md`, `FOUNDATION.md` and `CLAUDE.md` — the plan does not silently contradict those
documents, it is the mechanism by which they get amended.

**No-"coming soon" contract.** All 318 `R-<section>.<n>` requirements in `PRD.md` ship in Android
v1 (not 319 — see the corrected count and its derivation in the metrics table below). No
`قريبًا` ("coming soon") strings, no disabled buttons, no stubbed screens. The stub
burn-down counter (`§4` ground rule 4, gated at `§6` G8) is the measurable proof of this
contract, and it must read exactly **0** at Gate G8, with no exception and no escalation path
(`§6`, `§4`).

Source of truth for behaviour is the **shipped Swift code**, not the prose docs — this applies to
every "iOS implementing file(s)" / "iOS status" cross-reference any packet makes. Verified
2026-07-30 by direct `find`/`wc` against `main`:

| Metric | Value |
|---|---|
| MakhtootKit library targets | 16 |
| MakhtootKit source LOC | 38,080 |
| MakhtootKit source files | **269** (not 267 — the earlier count under-stated `MKRender` and `MKAssets`; `MKRender` is 23 files, `MKAssets` is 24; the corrected per-module table is `§3`) |
| `:app` scope (screen-level Kotlin/Swift entry points, `Makhtoot/AppShell/**`) | **60 files / 16,227 LOC** |
| `MakhtootUITests` | separate: **7 files / 678 LOC** (the combined `16,905` figure used earlier conflates the app target and its UI test target — 16,227 + 678 = 16,905; keep the two numbers apart everywhere else in the plan) |
| Test LOC (`MakhtootKit/Tests`) | 26,771 |
| Swift files across the repo | 567 |
| Passing tests, zero skips | 1,101 (per `AUDIT_2026-07-28.md`) |
| PRD requirement ids (`R-<section>.<n>`) | **318** (not 319 — `grep -oE 'R-[0-9]+\.[0-9]+' PRD.md \| sort -u \| wc -l` gives 319, but that naive pattern is wrong twice in opposite directions that happen to cancel: it strips the letter suffix off the real, independently-defined P0 id `R-21.35a`, collapsing it into `R-21.35` (undercounts by 1), and it counts `R-14.20`/`R-21.72` — two dangling typo'd cross-references inside prose with no bold definition anywhere in `PRD.md`, since corrected to `R-14.11`/`R-21.55` (overcounts by 2). The correct count, `grep -oE '\*\*R-[0-9]+\.[0-9]+[a-z]?' PRD.md \| sed 's/\*\*//' \| sort -u \| wc -l`, is 318) |
| Test ids (`T-<area>-<n>`) referenced in specs/tests | 212 |
| Bundled font families / font files | 45 / 87 |
| Design-system themes | 5 (Hibr حبر / Kufi كوفي / Naqsh نقش / Raml رمل / Tayf طيف) |

This is the master document; ten per-batch packet files (`ANDROID_TASK_PACKETS/BATCH-0.md` …
`BATCH-9.md`) hold the 66 per-agent packets (`§5`). `ANDROID_PORT_PLAN.md` is the narrative
front-door that points here and does not duplicate this file's content; this file, not the master
plan, is what a packet author or an agent should read when a number or rule is in question.

---

## 1. Founder decisions (FDA-01…FDA-08)

FDA-01, FDA-02, and the FDA-03 carve-out were decided by the founder on 2026-07-30. The
remaining FDAs carry defaults chosen so the run never has to stop mid-batch waiting on an
answer — each is revisable later without invalidating any completed batch.

| ID | Decision | Resolution |
|---|---|---|
| FDA-01 | Premium sync mechanism on Android | Google Drive `appDataFolder` (Drive v3 REST + Credential Manager + GIS `AuthorizationClient`, `§2` D-310). No backend of our own. Android↔Android only — an iOS device and an Android device never see each other's projects, documented in Settings → المزامنة (sync). |
| FDA-02 | Where Android code lives | `android/` inside this monorepo. Golden fixtures exported from the Swift engine sit next to the Kotlin tests that consume them (`§10`). |
| FDA-03 | CMYK ICC profile for Android | Default: lcms2 synthetic generic CMYK, documented as lower fidelity exactly as D-117 documents Apple Generic CMYK. Apple Generic CMYK is **not** redistributable in an Android APK. Upgrade seam: a redistributable profile whose licence is verified, never assumed (`VERIFY-AT-SUBMISSION`, `§9`). |
| FDA-04 | Analytics upload endpoint | Default: no-op uploader. Consent UI and on-device counters ship complete; the uploader posts to the same founder-controlled static host as FD-04 premium fonts once it exists, and is a no-op until then. Never a third-party analytics SDK. |
| FDA-05 | Play product ids | Play base-plan ids may contain only lowercase letters, digits and hyphens — no dots. Subscription product `net.binjamshid.makhtoot.premium` with base plans **`monthly`** and **`annual`** (mirrors iOS's monthly/annual terms, not iOS's dotted id spelling); one-time INAPP `net.binjamshid.makhtoot.premium.lifetime`. |
| FDA-06 | Play Console + merchant account | Founder-only. First needed at Batch 9 (blocks G9) — see `§7` Prerequisites for the full external-dependency ledger, which is longer than "first needed at Batch 9" alone implies. |
| FDA-07 | minSdk | **29** (Android 10), not 26. Consequence: the API 26–28 `Picture` + bitmap-cache render fallback is deleted from the plan entirely (`§2` D-305) — `RenderNode` (API 29+) is the only path, removing an untestable code path. Remaining documented limitation: `Modifier.blur` is a no-op below API 31, so `MkFloatingBar`'s translucent surface degrades to a flat alpha surface on API 29–30; this must be visually checked on an API 30 emulator at Batch 8.5 (`§5`, `§6` G8). |
| FDA-08 | iOS gains zipped-`.makhtoot` import/export | Yes — one iOS-side agent in Batch 9 (D-309, Agent 9.3). |

---

## 2. Android decision register (D-300…D-325)

`DECISIONS_LOG.md` currently runs to D-231 (verified against the file's own closing tally), so
the D-3xx block is collision-free. Batch 0 · Agent 0.5 writes these into `DECISIONS_LOG.md`,
`FOUNDATION.md` and `CLAUDE.md`. This is the heart of the plan — every later batch executes
against this register.

| ID | Decision | Rationale | iOS decision mirrored/amended |
|---|---|---|---|
| D-300 | Android platform: phone + tablet + foldable, **minSdk 29 (FDA-07)**, compileSdk/targetSdk 36, Kotlin 2.1, Jetpack Compose (BOM), AGP 8.7+, JDK 17, NDK r27, Arabic-only UI forced to `ar`, RTL-first | Establishes the toolchain baseline before anything else can be scaffolded | Amends D-100 for Android only; D-100 stays authoritative for iOS |
| D-301 | Project layout: `android/` Gradle build, 18 modules mirroring MakhtootKit 1:1 plus `:mk-native` and `:app`; version catalog + convention plugins | Keeps the module boundary identical to the audited Swift boundary so port mapping is 1:1 and reviewable | Mirrors D-101's one-package-many-targets shape |
| D-302 | Concurrency: Kotlin coroutines + `StateFlow`; UI on `Dispatchers.Main.immediate`; engines pure/dispatcher-agnostic; scene graph is immutable `data class` values | Same race-free guarantee iOS gets from `@MainActor` + value-type scene graph | Mirrors D-102 exactly |
| D-303 | Shaping: HarfBuzz (`hb_shape`) for GSUB/GPOS, FreeType for outlines, ICU BiDi for paragraph/run levels, all via one JNI facade; never write a shaper, never use presentation-form codepoints | Core Text has no Android equivalent; HarfBuzz is the industry-standard drop-in that preserves the "never write a shaper" invariant | Replaces D-103 as the shaping source of truth on Android; D-103 stays for iOS |
| D-304 | Third-party carve-out to D-101, Android only: harfbuzz (+ hb-subset), freetype, lcms2 vendored under `android/mk-native/third_party/`; ICU from platform; JVM side AndroidX/Play Billing/Drive/kotlinx-serialization/OkHttp; no analytics SDK ever | D-101's "zero third-party dependencies" is an iOS-only luxury enabled by Apple frameworks that don't exist on Android; the carve-out is scoped to exactly the libraries with no platform equivalent | Amends D-101 for Android only; D-101 stays unamended for iOS |
| D-305 | Rendering: Core Graphics → Skia via `android.graphics.Canvas`; one `RenderNode` per top-level node — **`RenderNode` (API 29+) is the only path; the API 26–28 `Picture` + bitmap-cache fallback is deleted from the plan entirely per FDA-07's minSdk 29**; Metal→Vulkan is a documented seam only. **Documented limitation:** `Modifier.blur` is a no-op below API 31, so `MkFloatingBar`'s translucent surface is a flat alpha surface on API 29–30 — visually verify on an API 30 emulator at Batch 8.5 | Preserves the CALayer-per-node cheap-transform model that D-115's frame budgets depend on, and minSdk 29 removes an untestable fallback code path entirely rather than leaving it unexercised | Mirrors D-114 |
| D-306 | Canvas host: custom `MkCanvasView : View` in Compose via `AndroidView`; pan/zoom is an owned transform matrix via `ScaleGestureDetector` + `GestureDetector` + raw pointer tracking, not a `ScrollView` | `ScrollView` cannot reproduce UIScrollView's bounce/zoom-bounds/content-inset semantics that the canvas depends on; those semantics must be reimplemented explicitly, so they must be tested explicitly | Replaces the UIScrollView half of MKCanvas's mechanism; behaviour target is unchanged |
| D-307 | Text-editing overlay: transparent `EditText` + custom `InputConnection` for IME/Arabic keyboard/selection handles/cursor; committed rendering always goes through `mk-textengine`→`mk-render` | Preserves pixel-identical canvas/export by keeping the overlay display-only, exactly as D-104 does | Mirrors D-104 |
| D-308 | Persistence: `.makhtoot` project as a directory in app-private storage, byte-identical internal layout to iOS (`manifest.json`, `scene.json`, `assets/`, `backups/`, `thumbnail.png`); Room replaces SwiftData for metadata only, never the scene graph; atomic write-temp+rename, debounced autosave ≤2 s, journal + crash recovery | Byte-identical layout is what makes D-309's zip interchange possible without a translation layer | Mirrors D-112, substituting Room for SwiftData |
| D-309 | Interchange: zipped `.makhtoot` (STORED/DEFLATE, no path-traversal on extract) as the cross-platform document format; Android reads/writes both directory and zip forms; iOS gains zip import/export in Batch 9 · Agent 9.3; `schemaVersion` + migrator chain shared and kept in lockstep | The only mechanism that lets a user move a project between an iPhone and an Android device without cloud sync (FDA-01 explicitly does not cover cross-platform sync) | New — no iOS-only precedent; extends D-112's file-package format |
| D-310 | Sync: Google Drive `appDataFolder`, Drive v3 REST. **Credential Manager handles identity only** (it returns a Google ID token and grants no OAuth scopes); authorizing `https://www.googleapis.com/auth/drive.appdata` is a separate step via **Google Identity Services (GIS) `AuthorizationClient`/`AuthorizationRequest`** — restated from an earlier "Credential Manager sign-in" formulation that could not actually obtain the Drive scope. One project = one folder of blobs; last-writer-wins + conflict-copy fallback named `(نسخة متعارضة)`, same policy/naming/engine as `MKSyncDecisionEngine`; premium-gated | CloudKit has no Android SDK; Drive's `appDataFolder` is the closest hidden-app-storage analogue, and reusing the decision engine unchanged keeps conflict semantics identical across platforms | Replaces the CloudKit clause of D-112 on Android |
| D-311 | Store: Google Play Billing 7+; entitlement precedence (D-113) mapped to Play's states (`lifetime`←acknowledged INAPP, `subscribed`←ACTIVE sub, `inGracePeriod`←Play grace, `inBillingRetry`←account hold/paused, `trial`←D-312, `free`); on-device RSA signature verification only, no backend; `acknowledgePurchase` within 72 h is a first-class tested work item; restore = `queryPurchasesAsync`, mandatory UI. **Play Billing exposes no client-side `paymentState`/`subscriptionState`** — `inGracePeriod` and `inBillingRetry` cannot be reliably distinguished on-device without the server-side Play Developer API. Both states retain premium and show a banner; the banner copy cannot be state-specific the way iOS's is (also listed in `§14` as a named out-of-scope limitation) | Play's state machine has no 1:1 StoreKit 2 equivalent, so it must be mapped explicitly rather than assumed compatible; the 72 h acknowledgement window is a real Play foot-gun (auto-refund) that iOS has no analogue for; the grace/hold ambiguity is a genuine Play Billing API limitation, not an implementation gap | Mirrors D-113's precedence and on-device-verification posture |
| D-312 | Trial: 7-day app-side trial for everyone from first launch. **The trial record is stored unencrypted but integrity-signed** — HMAC with a key embedded in the app binary, tamper-evident, an appropriate posture for a 7-day trial — mirrored to Android Auto Backup (backup rules restricted to exactly that blob, `§11`). An AndroidKeyStore-wrapped blob was the earlier formulation; it is **wrong**, because a Keystore key is destroyed on uninstall, so a Keystore-wrapped blob restored by Auto Backup would be permanently undecryptable — zero reinstall survival, not merely "weaker than Keychain." Clock-rollback guard via `SystemClock.elapsedRealtime()` anchor, never extends. **"Earliest timestamp wins across devices" is deleted as a claim**: Auto Backup is a single-slot restore performed once at device setup, not a live sync channel, so there is no cross-device propagation at all — say that plainly, not "weaker than iOS," in every place this decision is elaborated | Auto Backup can be disabled by the user, unlike Keychain's `kSecAttrAccessibleAfterFirstUnlock`; the honesty requirement (never overclaim) comes straight from `PROJECT_DESCRIPTION.md`'s product principles; the HMAC redesign is required because the Keystore approach gave no reinstall survival at all, which is a correctness bug, not a documented weakness | Mirrors D-123, with the reinstall-survival gap documented as R6 (`§13`) |
| D-313 | Raster export: tiled `Bitmap` strips → `Bitmap.compress` for PNG/JPEG; transparent PNG native; output size bounded by disk not RAM; same 2 MP free-tier clamp | Keeps the free/premium raster boundary numerically identical across platforms | Mirrors D-118's raster half |
| D-314 | PDF export: in-house PDF writer in `:mk-export` — vector paths, live-text runs, font subsetting via `hb-subset`, ICC OutputIntent, CMYK; Android's `PdfDocument` rejected (no CMYK, no output intents, no controlled font embedding) | `PdfDocument` cannot meet the print-PDF bar D-118/D-117 already committed to on iOS; there is no shortcut here | Mirrors D-118's PDF half, ports rather than reimplements the CG-based approach conceptually |
| D-315 | Colour: lcms2 via NDK replaces `CGColorSpace(iccData:)` for sRGB→CMYK with relative colorimetric intent; working space stays extended sRGB, document stores sRGB components; profile choice is FDA-03; no on-screen soft-proofing in v1, same as iOS | lcms2 is the de facto open-source CMS with the same relative-colorimetric conversion iOS uses via Core Graphics | Mirrors D-117 |
| D-316 | Fonts: bundled fonts in `android/app/src/main/assets/fonts/**`, opened by FreeType/HarfBuzz via `AssetManager` fd + `hb_blob` (no extraction to disk, no OS-level registration needed); user import via SAF `ACTION_OPEN_DOCUMENT`, content-addressed copy, same sfnt table validator ported byte-for-byte with the same Arabic error strings | `CTFontManagerRegisterFontURLs` has no Android analogue and needs none — HarfBuzz opens fonts directly from a blob | Mirrors D-122 |
| D-317 | Design system: `MkTheme` via Compose `CompositionLocal`s, not `MaterialTheme`; all 5 themes ported with identical tokens; all 9 UI-chrome fonts are already bundled custom fonts, so there is no SF-Arabic dependency to replace | `MaterialTheme` would fight, not host, a fully custom Arabic-first token system; the UI-chrome fonts being self-contained removes what would otherwise be the hardest parity risk | Mirrors D-126 |
| D-318 | Localisation: `resConfigs("ar")`, `android:supportsRtl="true"`, per-app locale pinned to `ar` via `locales_config.xml` + `AppCompatDelegate.setApplicationLocales` regardless of device locale; `Scripts/check-localization.sh` gets an Android sibling | Preserves the Arabic-only strategic bet (`CLAUDE.md`, `PROJECT_DESCRIPTION.md`) on a platform where the OS locale is not the app locale by default | Mirrors the `ar`-only intent underlying D-100 §Platform and scope |
| D-319 | Accessibility: TalkBack replaces VoiceOver; touch-target floor **48dp** (Android convention) replacing 44pt; `fontScale` honoured throughout; reduce-motion read from `Settings.Global.TRANSITION_ANIMATION_SCALE` | Direct platform-idiomatic substitution, same quality bar as iOS's 44pt/VoiceOver requirement in `CLAUDE.md` | New Android-specific elaboration of the accessibility clause in `CLAUDE.md`'s quality bar |
| D-320 | Analytics: consent (default OFF, versioned record), on-device font-usage bucket counters, kill switch port verbatim; upload target per FDA-04; never text, projects, identifiers or font files | Zero behavioural change from D-125 is achievable because analytics has no iOS-specific dependency | Mirrors D-125 exactly, upload transport only differs (FDA-04) |
| D-321 | Referral: same compile-time exclusion as D-225 — a `referral` source set present only in the debug variant plus `buildConfigField("boolean","REFERRAL_ENABLED",...)`; module and Arabic strings absent from the release AAB entirely; `Scripts/android/referral-release-grep.sh` mirrors the iOS ratchet | The App Review risk rationale behind D-225 applies identically to Play Store review | Mirrors D-225 |
| D-322 | Distribution: AAB + Play App Signing; Play Data Safety form replaces iOS privacy nutrition labels; track ladder internal → closed → production | Standard Play distribution shape, chosen to mirror the iOS TestFlight-then-App-Store ladder in spirit | New — no direct iOS decision; parallels the App Store submission process described in `PROJECT_DESCRIPTION.md`'s Launch direction |
| D-323 | No KMP, no Flutter, no React Native | All three require rewriting the shipped, tested Swift engine; the Swift source is used as an executable spec instead, which only a native Kotlin/NDK port allows | Directly enforces `PROJECT_DESCRIPTION.md`'s "correctness of the Arabic engine first" principle at the tooling-choice level |
| D-324 | Parity is enforced by fixtures, not by review: golden artefacts exported from the iOS engine in Batch 0 are the acceptance oracle for every engine module | Human review cannot reliably catch shaping regressions (`CLAUDE.md`: "shaping regressions are invisible in review") — this is the two-platform version of that same rule | Elaborates `CLAUDE.md`'s "test the text engine with golden fixtures" for a two-shaper world |
| D-325 | Shaping-delta register: any legitimate Core Text ↔ HarfBuzz difference recorded in `android/SHAPING_DELTAS.md` with font, input, delta, class (A/B/C — `§12`) and reason; an unregistered delta, or any Class-B delta, fails the gate | Two independent shaper implementations will diverge on edge cases; the register is what keeps "never silently mis-shape Arabic" true across two stacks instead of one, and the class system stops the agent that caused a delta from being the one who authorises it | New mechanism required specifically because Android introduces a second shaper; enforces `CLAUDE.md`'s "shaping correctness is non-negotiable" |

Entitlement access from any module (including `:mk-export`) is via the `MKEntitlementProviding`
protocol, which lives in `MKFoundation`/`:mk-foundation` — **not** a direct dependency on
`:mk-store`. See `§3` for why this matters to the dependency graph and to batch ordering.

### Platform substitution table

One row per iOS technology, its Android replacement, the fidelity risk of that replacement, and
which batch/agent owns making it real. Batch/agent numbers use the post-split ids from `§5`.

| iOS mechanism | Android mechanism | Fidelity risk | Where handled |
|---|---|---|---|
| Core Text shaping (`CTTypesetter`/`CTLine`/`CTRun`) | HarfBuzz `hb_shape` (D-303) | High — two independent OpenType shapers | 3.1a, 3.1b, 3.2, 3.3 |
| `CTFontCreatePathForGlyph` | FreeType outline extraction via `mk-native` | Medium — hinting/outline-fidelity differences at small sizes | 1.2, 3.1a |
| `CTRunGetStringIndices`/`kCTRunStatusRightToLeft` (cluster/bidi introspection) | `hb_glyph_info_t.cluster` (`HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS`) + ICU BiDi | High — cluster/ligature-candidate detection (D-105/D-108) depends on exact semantics matching | 3.2, 4.1, 4.2 |
| ZWJ form harvesting (D-107) | Same technique through `hb_shape` (D-303) | Medium — depends on font GSUB tables behaving identically under HarfBuzz | 3.3, 4.2 |
| Core Graphics (path fill/stroke, CGContext) | `android.graphics.Canvas` / Skia (D-305) | Low — both are mature 2D vector rasterizers | 4.5, 4.6, 5.1–5.4 |
| CALayer tree (layer-per-node, cheap transforms) | `RenderNode` (API 29+ only — no fallback, FDA-07/D-305) | Medium — no fallback path means the RenderNode path must simply work on every supported device | 4.5, 4.6, 5.1 |
| `UIScrollView` zoom/pan (bounce, zoom bounds, content inset) | Owned transform matrix + `ScaleGestureDetector`/`GestureDetector` (D-306) | High — semantics fully reimplemented, not inherited from a system component | 5.1, 5.2a |
| `UITextView`/TextKit 2 editing overlay | Transparent `EditText` + custom `InputConnection` (D-307) | Medium — IME/Arabic-keyboard/selection-handle behaviour varies by OEM keyboard | 5.4a |
| SwiftUI app shell | Jetpack Compose | Low — comparable declarative UI paradigms | 7.1–7.8 (incl. 7.3a/7.3b) |
| UIKit gestures (`UIGestureRecognizer` family) | Android `GestureDetector`/`ScaleGestureDetector`/raw `MotionEvent` tracking | Medium — gesture-conflict resolution differs by platform | 5.2a, 5.3 |
| `.makhtoot` file package | Directory + zip forms, byte-identical layout (D-308/D-309) | Low — plain filesystem layout, well specified | 3.4, 3.5, 3.6 |
| SwiftData (metadata index) | Room (D-308) | Low — both are typed local-database layers over a known schema | 3.6 |
| `UIDocument`/Files app integration | SAF (`ACTION_OPEN_DOCUMENT`)/content-addressed storage | Medium — SAF's content-URI model differs meaningfully from `NSFileCoordinator` semantics | 3.7, 6.5, 7.2 |
| `CGPDFContext` | In-house PDF writer in `:mk-export` (D-314) | High — ~5,000 LOC of new code with no CG equivalent to lean on | 5.7a, 5.7b |
| `CGColorSpace` ICC/CMYK conversion | lcms2 via NDK (D-315) | Medium — different CMS implementation, same relative-colorimetric intent | 2.3, 5.7b |
| `CTFontManagerRegisterFontURLs` | None needed — HarfBuzz opens fonts directly via `hb_blob` from `AssetManager` fd (D-316) | Low — the substitution removes a dependency rather than replacing it 1:1 | 3.7, 1.2 |
| StoreKit 2 | Google Play Billing 7+ (D-311) | High — grace/hold/pause state machine (undistinguishable client-side, `§14`) and 72 h acknowledgement window differ materially | 6.1 |
| Keychain + iCloud KVS (trial persistence) | Unencrypted, HMAC-signed DataStore blob + Android Auto Backup (D-312) | Medium — no reinstall survival if Auto Backup is disabled by the user; no cross-device propagation at all (not "weaker," genuinely absent) | 6.2 |
| CloudKit private DB (project sync) | Google Drive `appDataFolder` (D-310) | High — no CKSyncEngine equivalent; change-token/quota semantics differ; auth is Credential Manager + GIS AuthorizationClient, two mechanisms not one | 6.3a, 6.3b |
| CloudKit public DB (analytics upload) | Founder-controlled static host / no-op uploader (FDA-04) | Low — analytics payload shape is unchanged, only the transport moves | 6.4 |
| `os_proc_available_memory` + `DispatchSource` memory pressure | `ActivityManager.MemoryInfo` polling + `ComponentCallbacks2.onTrimMemory` | Medium — Android's trim-memory levels don't map 1:1 to iOS's three-stage ladder | 4.6, 8.4 |
| `OSSignposter` | Android `Trace`/Perfetto tracing | Low — both are OS-native tracing facilities for Instruments/Perfetto-class profiling | 4.6, 8.4 |
| VoiceOver | TalkBack (D-319) | Medium — screen-reader traversal order and gesture vocabulary differ by platform | 8.5 |
| Dynamic Type | `fontScale` (D-319) | Low — both are OS-level text-scaling factors | 7.x panels, 8.5 |
| `.xcstrings` localization | Android `strings.xml` under `resConfigs("ar")` (D-318) | Low — mechanical string-table translation, `ar`-only in both cases | 0.4, 1.1 (`§11`) |
| App Store Connect | Google Play Console (D-322) | Low — both are standard app-store back-office consoles | 9.1, 9.2, 9.4 |

---

## 3. Module map, dependency graph, and naming rule

18 Gradle modules under `android/` (D-301). Kotlin package root `net.binjamshid.makhtoot`.

### 3.1 Module table (source of the 269-file, 38,080-LOC total in `§0`)

| Gradle module | Kotlin package | Ports (Swift target) | Source files | Source LOC | Est. Kotlin LOC |
|---|---|---|---|---|---|
| `:mk-native` | `…makhtoot.mk.nativebridge` | *(new)* HarfBuzz/FreeType/lcms2/hb-subset JNI facade | — | — | ~2,500 (C++/Kotlin) |
| `:mk-foundation` | `…makhtoot.mk.foundation` | MKFoundation | 15 | 1,234 | ~1,400 |
| `:mk-model` | `…makhtoot.mk.model` | MKModel | 15 | 2,176 | ~2,400 |
| `:mk-textengine` | `…makhtoot.mk.textengine` | MKTextEngine | 17 | 2,195 | ~2,900 |
| `:mk-arrange` | `…makhtoot.mk.arrange` | MKArrange | 11 | 2,078 | ~2,300 |
| `:mk-pathtext` | `…makhtoot.mk.pathtext` | MKPathText | 9 | 1,945 | ~2,100 |
| `:mk-canvas` | `…makhtoot.mk.canvas` | MKCanvas | 29 | 6,580 | ~7,500 |
| `:mk-render` | `…makhtoot.mk.render` | MKRender | 23 | 3,603 | ~4,000 |
| `:mk-color` | `…makhtoot.mk.color` | MKColor | 4 | 467 | ~700 |
| `:mk-export` | `…makhtoot.mk.export` | MKExport | 22 | 3,342 | ~5,000 (PDF writer) |
| `:mk-fonts` | `…makhtoot.mk.fonts` | MKFonts | 21 | 2,480 | ~2,800 |
| `:mk-persistence` | `…makhtoot.mk.persistence` | MKPersistence | 19 | 3,283 | ~3,800 |
| `:mk-sync` | `…makhtoot.mk.sync` | MKSync → Drive | 10 | 1,945 | ~2,400 |
| `:mk-store` | `…makhtoot.mk.store` | MKStore → Play Billing | 18 | 1,668 | ~2,200 |
| `:mk-analytics` | `…makhtoot.mk.analytics` | MKAnalytics | 13 | 1,004 | ~1,100 |
| `:mk-designsystem` | `…makhtoot.mk.designsystem` | MKDesignSystem | 19 | 1,405 | ~2,200 |
| `:mk-assets` | `…makhtoot.mk.assets` | MKAssets | 24 | 2,675 | ~2,900 |
| `:app` | `net.binjamshid.makhtoot` | `Makhtoot` app target — **55 files / 15,280 LOC in port scope** (see exclusion note below); excludes `MakhtootUITests` | 55 | 15,280 | ~14,000 |
| | | **Total in port scope** | **324** | **~53,360** | **~62,000 + ~28,000 test** |

**Excluded from the port entirely** (`§14`, `§17`): the four iOS developer harnesses
(`App/DesignSystemGallery.swift` 161, `App/Debug/PathTextHarnessView.swift` 389,
`App/Debug/PerfHUDView.swift` 83, `App/Debug/ShapingHarnessView.swift` 232 — 865 LOC total)
and `EditorPlaceholderView.swift` (82 LOC, dead unrouted code on iOS). **947 LOC across
5 files.**

Arithmetic, stated explicitly and verified against the tree on 2026-07-30, because two
earlier drafts each got it wrong in a different way:

| Tree | Files | LOC |
|---|---|---|
| `MakhtootKit/Sources/**` (the 16 library rows above, which sum to 269) | 269 | 38,080 |
| `Makhtoot/**` on disk | 60 | 16,227 |
| — of which excluded from the port (the 5 files above) | −5 | −947 |
| `:app` **in port scope** | **55** | **15,280** |
| **Total in port scope** (269 + 55) | **324** | **53,360** |
| `MakhtootUITests/**` — separate, counted in neither figure | 7 | 678 |
| `MakhtootKit/Tests/**` — separate, ported per ground rule 6 | 218 | 26,771 |

**269 is the `MakhtootKit/Sources` count alone, not a Sources-plus-app total** — an earlier
draft conflated the two and reported 264. The all-in port-scope figure is **324 files /
53,360 LOC**. Any packet stating 264, 267, or 269 as the *overall* total is wrong; 269 is
correct only when scoped to `MakhtootKit/Sources`.

None of the five excluded files may appear in any agent's port map, inflate Agent 1.4's
stub count, or be referenced by `Scripts/android/stub-count.sh`.

### 3.2 Dependency edges (regenerated from `MakhtootKit/Package.swift`, verified 2026-07-30)

The edges below are extracted directly from `Package.swift`, not from `FOUNDATION.md` §2 — an
earlier version of this table was derived from a stale reading of that document and was wrong
for 7 of 17 modules (it invented a `:mk-export → :mk-store` edge and a `:mk-sync → :mk-store`
edge that do not exist; see the note below). Treat this table, not any other document, as
authoritative for what a module may depend on.

| Module | Depends on |
|---|---|
| `:mk-foundation` | — |
| `:mk-designsystem` | `:mk-foundation` |
| `:mk-model` | `:mk-foundation` |
| `:mk-color` | `:mk-foundation`, `:mk-native` |
| `:mk-store` | `:mk-foundation` |
| `:mk-persistence` | `:mk-model`, `:mk-foundation` |
| `:mk-fonts` | `:mk-foundation`, `:mk-persistence`, `:mk-native` |
| `:mk-textengine` | `:mk-foundation`, `:mk-fonts`, `:mk-model`, `:mk-native` |
| `:mk-arrange` | `:mk-foundation`, `:mk-model`, `:mk-textengine`, `:mk-persistence` |
| `:mk-pathtext` | `:mk-foundation`, `:mk-model`, `:mk-textengine`, `:mk-persistence`, `:mk-arrange` |
| `:mk-render` | `:mk-foundation`, `:mk-model`, `:mk-textengine`, `:mk-pathtext`, `:mk-native` |
| `:mk-canvas` | `:mk-foundation`, `:mk-model`, `:mk-render`, `:mk-designsystem` |
| `:mk-export` | `:mk-foundation`, `:mk-model`, `:mk-render`, `:mk-color`, `:mk-fonts`, `:mk-textengine`, `:mk-pathtext`, `:mk-native` |
| `:mk-sync` | `:mk-persistence`, `:mk-foundation` |
| `:mk-analytics` | `:mk-foundation`, `:mk-persistence` |
| `:mk-assets` | `:mk-foundation`, `:mk-model` |
| `:app` | everything above |

`:mk-native` is a dependency of `:mk-textengine`, `:mk-render`, `:mk-export`, `:mk-fonts`,
`:mk-color` — every module that shapes, outlines, or colour-transforms.

**There is no `:mk-export` → `:mk-store` edge and no `:mk-sync` → `:mk-store` edge.** The earlier
table invented both. Entitlement access from `:mk-export` (2 MP free-tier clamp, watermark) and
from `:mk-sync` (premium gating) is via the `MKEntitlementProviding` protocol, which lives in
`:mk-foundation`, a dependency every module already has. This removes the apparent Batch 5 /
Batch 6 ordering inversion the old table implied (export, in Batch 5, cannot depend on store,
which is built in Batch 6 — under the correct graph it never needed to).

**Rule.** If an agent finds it needs a module edge that is not in this table, that is a
`android/docs/CONTRACT_CHANGES.md` entry (`§11`), not a direct edit. **Agent 1.1 is the only
owner of `build.gradle.kts` files during Batches 2–8** (`§17` names the one explicit Batch 9
exception) — the gate applies an approved edge by editing the Gradle file, the requesting agent
never does.

### 3.3 Naming rule (frozen, corrected)

**Every** Kotlin file and top-level type gets an `Mk` prefix. There are no exceptions — an
earlier version of this rule said "files without the prefix keep their name," which is wrong and
was the direct cause of roughly 97 mismatched file paths across the existing packets (fixed in a
later pass, not by this file).

- `MKShapingEngine.swift` → `MkShapingEngine.kt`
- `ArrangeDeriver.swift` → `MkArrangeDeriver.kt` (previously left unprefixed — that was wrong)
- `SceneCodec.swift` → `MkSceneCodec.kt`
- `ClusterMap.swift` → `MkClusterMap.kt`
- `CMYKConverter.swift` → `MkCmykConverter.kt`
- Acronyms are title-cased after the prefix: `MKStoreIDs` → `MkStoreIds`, `MKRTLUtilities` →
  `MkRtlUtilities`, `ICCProfileStore` → `MkIccProfileStore`.
- Directory structure still mirrors the Swift sub-directories (`Sources/MKArrange/…` →
  `mk-arrange/src/main/kotlin/…/arrange/…`).
- Preserve the Swift doc comments' intent and every `D-###`/`INV-###`/`R-###` reference —
  traceability is the point.
- A file with no valid Kotlin filename under this rule as a mechanical transform (e.g. a `+`
  extension file) resolves by either merging into the base type's file or by a documented
  alternate spelling — the choice is recorded in the agent's impl log, never made silently.

**Batch 1's contract stubs and Batches 2–7's implementations MUST produce identical paths under
this rule.** Every implementation agent has explicit authority and instruction to delete or
overwrite the Batch 1 stub file it supersedes, naming the superseded path in its own Owns list
(`§8`). This is not a race condition: Batch 1 runs to completion and gates at G1 before any
Batch 2+ agent starts, so "supersede" means "replace the compiled stub with the real
implementation at the same path," never a concurrent write.

---

## 4. Ground rules (frozen)

Four mechanisms make one-shot parallel execution across 66 agents safe:

**(a) Exclusive file ownership.** One agent owns a file set; no two agents in a batch touch the
same path. Every batch packet file ends with a collision-proof ownership matrix, in the same
style as this repo's `EXECUTION_PLAN_2026-07-28.md` Appendix. `§17` names the ownership rule's
cross-batch extension and the four known conflicts it resolves.

**(b) Contract-first stubs.** Batch 1 lands every public API of all 16 ported modules plus the
app target as a compiling stub whose body is `throw MkNotYetPorted("<module>.<symbol>")`. Every
later batch's modules therefore compile independently against real signatures from day one — no
agent is ever blocked waiting for another module to exist.

**(c) `android/docs/CONTRACT_CHANGES.md`** (owned by Agent 1.1, `§11`) is the only channel for
cross-module API changes. No agent edits another module's public API directly; a needed change is
appended to this file and applied by the batch gate, not by the agent mid-batch. This is what
makes 66 agents editing in parallel safe without a live merge process.

**(d) The stub burn-down counter** is the measurable definition of "no coming soons."
`Scripts/android/stub-count.sh` prints the remaining `MkNotYetPorted` count; it is published at
every gate and must reach **exactly 0** at G8 — no exceptions, no escalation path.

### Ground rules (numbered, frozen)

1. **Exclusive file ownership.** One agent owns a file set; no two agents in a batch touch the
   same path. Every batch file ends with a collision-proof ownership matrix.
2. **Every agent ends green.** `./gradlew :<module>:testDebugUnitTest :<module>:lintDebug` must
   pass before the agent reports done. An agent that cannot go green reports the blocker in its
   impl-log and leaves the tree compiling.
3. **No "coming soon", ever.** `Scripts/android/check-no-stubs.sh` greps the tree for `TODO(`,
   `NotImplementedError`, `notYetPorted`, `قريبًا`, `coming soon`, `Placeholder`, checked against
   `Scripts/android/no-stubs-allowlist.txt` (`§11`) for the two named legitimate matches, and
   fails on any other hit. It is advisory from G1 and **blocking from G8**.
4. **Stub burn-down counter.** Batch 1 lands every public API as a contract stub whose body is
   `throw MkNotYetPorted("<module>.<symbol>")`. `Scripts/android/stub-count.sh` prints the
   remaining count. The count is published at every gate and **must reach exactly 0 at G8, with
   no exception and no escalation path** — there is no "stub count reaches 0 or every remainder
   is a named, escalated gap" clause; an earlier draft of Agent 8.1's acceptance criteria
   contained exactly that clause and it is deleted, not softened.
5. **Contract-first.** No agent edits another module's public API. A needed change is appended
   to `android/docs/CONTRACT_CHANGES.md` and applied by the batch gate, not by the agent. A gate
   run has an explicit "apply pending contract changes" step performed before the gate's checks
   re-run (`§11`).
6. **Port the tests too.** Every ported behaviour brings its Swift test across. Where the Swift
   test used a golden fixture, the Kotlin test consumes the same fixture from
   `android/fixtures/**` (`§10`).
7. **Shaping correctness is non-negotiable** (`CLAUDE.md`). A change that mis-shapes Arabic,
   drops tashkeel or breaks a ligature is never acceptable, on either platform. Mechanically
   enforced by the Class-B shaping-delta rule (`§12`): a Class-B delta cannot be registered, full
   stop — it is a hard gate failure.
8. **Impl log.** Every agent writes `android/docs/impl-log/BATCH-<N>.<k>.md`: what was ported,
   deviations, deltas registered, tests added, stub count delta.
9. **Never touch iOS.** Batches 0 and 9 have explicit, named iOS-side agents (Agent 0.5, Agent
   9.3 — `§17` names this as the only other exception). Every other agent is forbidden from
   editing anything outside `android/` and `Scripts/android/`.

---

## 5. Batch / agent register

10 batches, **66 agents** (not 59 — seven agents from the original 59-agent register were not one
unit of work and are split by letter suffix, `§5.2` below). Every agent in a batch is dispatched
in **one message** so the batch runs concurrently.

### 5.1 At-a-glance batch table

| Batch | Agents | Theme | Agent count | Cumulative stub-count target | Gate |
|---|---|---|---|---|---|
| 0 | 0.1–0.5 | Extraction from iOS: parity matrix, golden fixtures, API surface, strings/tokens/assets, decision-doc amendment | 5 | n/a — no stubs exist yet | G0 |
| 1 | 1.1–1.4 | Gradle scaffold · native toolchain · contract stubs A · contract stubs B | 4 | 100% of public API stubbed (peak count, published at G1) | G1 |
| 2 | 2.1–2.5 | foundation · model · color · designsystem tokens · designsystem components | 5 | 5 modules' stubs burned down | G2 |
| 3 | 3.1a, 3.1b, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7 | textengine (HarfBuzz bridge + line breaking split) ×2, textengine ×2 more · persistence ×3 · fonts core | 8 | +3 modules burned down | G3 |
| 4 | 4.1–4.6 | arrange ×2 · pathtext ×2 · render ×2 | 6 | +3 modules burned down | G4 |
| 5 | 5.1, 5.2a, 5.2b, 5.3, 5.4a, 5.4b, 5.5a, 5.5b, 5.6, 5.7a, 5.7b | canvas view/session ×1, gestures (split) ×2, selection/inspector ×1, IME+interaction (split) ×2, assets (split) ×2, export raster/SVG ×1, export PDF (split) ×2 | 11 | +3 modules burned down | G5 |
| 6 | 6.1, 6.2, 6.3a, 6.3b, 6.4, 6.5 | store billing · store trial+referral · sync Drive transport (split) ×2 · analytics · fonts catalog | 6 | +3 modules burned down (store, sync, analytics) | G6 |
| 7 | 7.1, 7.2, 7.3a, 7.3b, 7.4, 7.5, 7.6, 7.7, 7.8 | app shell: shell/nav · browser · editor core (split) ×2 · canvas host · arrange+path toolbars · inspector/layers · sheets · settings/paywall/onboarding | 9 | `:app` stubs burned down | G7 |
| 8 | 8.1–8.7 | wiring + stub burn-down · shaping parity · render/export parity · performance · accessibility · instrumented UI tests · edge-case compendium | 7 | **0** (mandatory, no exceptions) | G8 |
| 9 | 9.1–9.5 | Play listing/Data Safety · signing/AAB/R8/baseline profile · iOS zip interop · Android store checklist · final parity report | 5 | 0 (unchanged) | G9 |

**Total: 5 + 4 + 5 + 8 + 6 + 11 + 6 + 9 + 7 + 5 = 66 agents across 10 batches.** (Verified by
direct addition: 5+4=9, +5=14, +8=22, +6=28, +11=39, +6=45, +9=54, +7=61, +5=66.)

### 5.2 Agent re-splits (register grows from 59 to 66)

Seven agents from the original register were not one unit of work. Split using **letter
suffixes** so every existing cross-reference to the parent number stays meaningful — a citation
of "5.2" without a suffix should be read as "5.2a and 5.2b together" wherever it appears in older
material.

| Parent | Split into | Scope of each half |
|---|---|---|
| 3.1 | **3.1a** | HarfBuzz shaping bridge + shaped models |
| | **3.1b** | Line breaking and paragraph layout — the from-scratch piece with no Core Text source |
| 5.2 | **5.2a** | Gesture arbitration state machine (`GestureCoordinator`, `HandleGestures`, `MarqueeController`, `MoveGesture`) |
| | **5.2b** | Snapping, guides, grid, geometry helpers |
| 5.4 | **5.4a** | IME text-editing overlay |
| | **5.4b** | Arrange + path-text interaction models |
| 5.5 | **5.5a** | Generators, model, library, manifest |
| | **5.5b** | Instantiation, provenance, thumbnails, contact sheet |
| 5.7 | **5.7a** | PDF core writer (object model, content streams, vector operators, raster XObjects) |
| | **5.7b** | Font subsetting, Type0/CIDFontType2 embedding, CMYK, OutputIntent/ICC |
| 6.3 | **6.3a** | Drive transport (auth, REST client, resumable upload, `changes.list`, WorkManager) |
| | **6.3b** | Policy port (decision engine, conflict naming, pending queue, record coder, status, errors) |
| 7.3 | **7.3a** | `EditorViewModel` and the event-driven state replacing the four polling loops |
| | **7.3b** | `EditorScene`, status views, tool rail, zoom controls, token strip |

### 5.3 Coverage assignments made explicit here (elaborated further in `§16`)

- Agent 2.1 additionally owns `MakhtootKit/Sources/MKFoundation/Stubs/MKFontProviding.swift`
  (139 LOC) — `:mk-foundation` is **15** files, not 14; the earlier register omitted an
  implementing agent for this file even though Batch 1's stub already covers it mechanically.
- Agent 3.3 additionally owns `MakhtootKit/Tests/WS16CursiveTests/` (4 files, 450 LOC — the
  cursive-attachment fidelity evidence suite for the five held fonts, load-bearing for the
  Arrange invariant); its evidence assertions are re-run at Batch 8.2.
- Agent 2.4 additionally owns `TokenResolutionTests.swift` and `MKTypeRampDynamicTypeTests.swift`
  (from the orphaned `MakhtootKit/Tests/MKDesignSystemTests/`); Agent 2.5 additionally owns
  `MKMotionAccessibilityTests.swift` from the same directory. The names `MKThemeTests`,
  `MKTypeRampTests`, `MKSpacingTests` that appear in earlier packet drafts **do not exist in the
  repo** and must be struck wherever they are cited.
- Agent 0.1 assigns all 318 `R-` ids (not 319 — `§0`) to an owning batch.agent in
  `android/PARITY_MATRIX.md`; 102
  were previously cited by no packet at all — 0.1 closes that gap as part of producing the
  matrix, not as an afterthought.
- Agents 8.7 and 9.5 register every new `T-AND-*` id (Android-only tests with no Swift-side
  counterpart) back into `TEST_MATRIX.md`.

### 5.4 How to run a batch

For each batch N (0 through 9): the founder dispatches every agent in Batch N as one message of
concurrent `Agent` tool calls, each pointing at its packet section in
`ANDROID_TASK_PACKETS/BATCH-N.md`; once every agent reports done, the founder runs
`bash Scripts/android/gate.sh N`; if the gate passes, proceed to Batch N+1, otherwise fix within
that batch's scope before moving on — never carry a broken build forward. **The only true
stopping points are the gates** (`§6`). Nothing in a batch should require the founder mid-batch
except the external dependencies tabulated in `§7`.

---

## 6. Gates

Each gate is a script the founder runs between batches (`Scripts/android/gate.sh N`, owned by
Agent 1.1). Gates are the only stopping points. Every gate run applies any pending
`CONTRACT_CHANGES.md` entries first (`§4` ground rule 5, `§11`), then re-runs its checks.

| Gate | Command | Must be true |
|---|---|---|
| G0 | `bash Scripts/android/gate.sh 0` | `android/PARITY_MATRIX.md` covers all 318 R-ids (not 319 — `§0`); `android/fixtures/**` (categories per `§10`) regenerates byte-identically on a second run **for deterministic categories only** — the [exclusion manifest](android/fixtures/DETERMINISM_EXCLUSIONS.json) records JPEG because its encoder has no byte-stability guarantee. PDF samples are [generated locally](docs/BUILD.md#export-fixture-checks) outside the fixture tree; `android/API_SURFACE.md` lists every public symbol of all 16 targets; `android/strings/strings.xml` has every Arabic string from `Localizable.xcstrings`; D-300…D-325 present in `DECISIONS_LOG.md` |
| G1 | `bash Scripts/android/gate.sh 1` | `./gradlew assembleDebug` green on all 18 modules; `:mk-native` smoke test passes on arm64-v8a, armeabi-v7a, x86_64; stub count published; `CONTRACT_CHANGES.md` contains no `pending`-status entry |
| G2 | `…gate.sh 2` | `:mk-foundation :mk-model :mk-color :mk-designsystem` tests green; `mk-model` round-trips all 4 `Tests/Fixtures/*.makhtoot` scenes byte-identically |
| G3 | `…gate.sh 3` | Shaping parity restated with an explicit denominator (`§12`): parity is measured per **(font family × corpus string × glyph) triple**; gate passes iff **zero Class-B deltas**, **Class-A deltas ≤ 1% of triples**, and **every Class-C row is signed off** in `android/SHAPING_DELTAS.md` — the earlier "≥99% of golden fixtures" wording had no unit and was unenforceable; persistence journal + crash recovery tests green; font validator rejects the same corpus iOS rejects; `CONTRACT_CHANGES.md` has no `pending` entry |
| G4 | `…gate.sh 4` | Arrange derive→decompose→recompose→revert round-trips match golden fixtures; path-text placement within tolerance; render goldens within the tolerance defined in `android/docs/RENDER_TOLERANCE.md` (`§12`) — Skia and Core Graphics rasterise antialiased vector art differently, so a concrete per-pixel-channel tolerance and a maximum fraction of differing pixels are required and must be justified in that file, not merely asserted in a test; `CONTRACT_CHANGES.md` has no `pending` entry |
| G5 | `…gate.sh 5` | Canvas gesture tests green; export references (tracked PNG/JPEG/SVG and [locally generated PDF](docs/BUILD.md#export-fixture-checks)) match within tolerance; PDF structural validation (OutputIntent presence, object-stream well-formedness, font-subset integrity) passes as an agent-run automated check (Agent 5.7b). **Opening the PDF in Adobe Acrobat and macOS Preview is a founder gate task, not an agent task** — a headless agent cannot perform it, and an earlier draft that assigned it to Agent 5.7b would have logged a verification that never actually happened; the founder performs this check by hand between batches, same as any other gate step that needs a human | `§7` — this is one of the prerequisites that block G5 |
| G6 | `…gate.sh 6` | Play Billing tested against the six `MKSandboxScenarioStub` scenarios; Drive sync round-trips a project incl. conflict copy, exercising the Credential Manager + GIS `AuthorizationClient` two-step auth (D-310); trial clock-rollback guard holds |
| G7 | `…gate.sh 7` | App runs end-to-end on emulator + a physical device; every screen reachable; zero `Placeholder` composables |
| G8 | `…gate.sh 8` | **Stub count = 0, exactly, no exception, no escalation path** (`§4` ground rule 4); `check-no-stubs.sh` clean against `Scripts/android/no-stubs-allowlist.txt` (`§11`); all 318 R-ids (not 319 — `§0`) ✅ in the parity matrix; performance budgets met; TalkBack sweep clean; `MkFloatingBar`'s flat-alpha-surface degradation on API 29–30 visually checked on an API 30 emulator (FDA-07) |
| G9 | `…gate.sh 9` | Signed AAB uploads to the internal track; Data Safety complete; referral grep of the release AAB is clean |

---

## 7. Prerequisites

The plan previously claimed FDA-06 (Play Console + merchant account) was the only external
dependency, first needed at Batch 9. That is false — it is merely the last one to bind. The full
external-dependency ledger, in the order each item first blocks a gate:

| Dependency | Needed for | First blocks |
|---|---|---|
| Android SDK + NDK r27 + JDK 17 toolchain | Building `android/` at all | G1 |
| A Google Cloud project with an Android OAuth client, SHA-1 registration, and a **verified** OAuth consent screen for the `drive.appdata` scope | D-310 sync auth (`§2`); consent-screen verification lead time is measured in **weeks**, not days — start this well before Batch 6 | G6 |
| Two Google accounts + a two-emulator harness | Exercising Drive sync's conflict-copy path (two accounts writing the same project) | G6 |
| Two named physical devices | On-device gesture/IME/accessibility verification that cannot be faked on an emulator | G7 / G8 |
| Adobe Acrobat and macOS Preview access for a human | G5's external-viewer PDF check (`§6`) — explicitly a founder task, not an agent task | G5 |
| Play Console + merchant account (FDA-06) | Signed AAB upload, Data Safety form, release track ladder | G9 |

Batches 0–5 and 7–8 do not require founder-held credentials mid-batch; Batch 6 (G6) and Batch 9
(G9) are where the plan's only real external-dependency waits occur, and the OAuth
consent-screen verification lead time means that item should be started as early as practical,
not deferred until Batch 6 begins.

---

## 8. Packet template

Every `BATCH-N.md` agent section follows this shape. A packet author who deviates from it makes
the packets inconsistent with each other in exactly the way this file exists to prevent.

```
### Batch N · Agent N.k — <one-line title>

**Depends on:** <gate the batch depends on, e.g. G4> ·
**Parallel-safe with:** <other agents in the same batch, or "every other Batch N agent">

**Mission.** 2–5 sentences: what this agent ports, why it is scoped the way it is, and the one
or two hardest correctness risks in its scope, named explicitly if this is a high-risk agent.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| ... | ... |

**Owns (creates or edits — no other agent may touch these).**
- exhaustive file list, new or modified, including test files and the impl log path

**Never touch.** Explicit call-outs of adjacent files/modules this agent must not edit, even if
tempted, and where a needed cross-boundary change goes instead (`CONTRACT_CHANGES.md`, §4/§11).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| ... | ... | ... | ... |

**Tasks.** Numbered, ordered by dependency within the agent's own scope (what to port first and
why), not merely a restated file list.

**Acceptance.**
- `./gradlew :<module>:testDebugUnitTest` / `:lintDebug` green
- Requirements covered: `R-*` ids (traceable to `android/PARITY_MATRIX.md`)
- Tests ported: `T-*` ids
- Fixtures consumed: `android/fixtures/<category>/**` (`§10` spelling only)
- Any agent-specific correctness bar stated as an explicit, checkable acceptance item — never
  "compiles and looks right," always a named test or a named artifact

**Impl log.** `android/docs/impl-log/BATCH-N.k.md`
```

Every batch file additionally ends with a collision-proof ownership matrix (`§4` mechanism (a))
covering every agent in that batch.

---

## 9. Writing standards

- Match `EXECUTION_PLAN_2026-07-28.md`: dense tables, no padding, no marketing tone.
- Arabic strings appear in Arabic with a Latin gloss in parentheses on first use, per
  `FOUNDATION.md` §12.
- Never call the app Masoon, and never borrow its conventions.
- A licence characterization (MIT-ish, FTL, MIT, etc.) for any vendored third-party library is
  written as `VERIFY-AT-SUBMISSION` in both the impl log and a source comment until it is
  actually verified — do not assert a licence claim as settled fact this early, even when it is
  very likely correct.
- A deviation from a port map or a naming-rule mechanical transform is always recorded in the
  agent's impl log, never made silently — this applies equally to a naming collision (`§3.3`), a
  dropped iOS-only capability with no Android analogue (e.g. `MKFontRegistry`'s system-wide
  installation surface), and a tolerance number an agent had to pick rather than was given
  (`§12`).
- `R-<section>.<n>` is used exactly as defined in `PRD.md`; `D-3xx` continues the `D-1xx`/`D-2xx`
  sequence `FOUNDATION.md` §11 establishes; `T-<area>-<n>` for ported tests, `T-AND-<n>` for
  Android-only new tests (`§5.3`).
- Keep this document self-contained: a writer who reads only `ANDROID_SPINE.md` must be able to
  produce a consistent packet without cross-referencing `ANDROID_PORT_PLAN.md` or another batch
  file for a fact this file should already state.

---

## 10. Fixture directory convention

Batch 0 · Agent 0.2 produces exactly these category directories under `android/fixtures/`, and no
packet may reference any other spelling:

```
android/fixtures/
  shaping/
  joining/
  ligature/
  marks/
  arrange/
  pathtext/
  scenecodec/
  render/
  export/
  canvas/
  assets/
  resources/   (owned separately by Agent 0.4)
```

The `mk-arrange/`, `mk-pathtext/`, `mk-render/`, `mk-export/`, `mk-canvas/`, `mk-assets/`
spellings used in earlier drafts of Batches 4 and 5 are **wrong** and must be normalised to the
unprefixed spelling above wherever they appear. `canvas/` and `assets/` are **new categories**
added by this correction — eleven agents across the plan cite fixtures under these categories
that were absent from the earlier Batch 0 fixture specification.

---

## 11. Glue artifacts (named owners)

These artifacts were previously specified as read by multiple agents but never assigned a writer.
**Agent 1.1 owns and must create all of them**, alongside its Gradle-scaffold scope (`§4`
mechanism (a), `§3.2`):

- **`android/docs/CONTRACT_CHANGES.md`** — append-only entry format: `date | requesting agent |
  target module | requested change | rationale | status (pending/applied/rejected)`.
  `Scripts/android/gate.sh N` **fails** if the file contains any entry with status `pending`
  (`§6`). Each gate run has an explicit "apply pending contract changes" step performed
  immediately before the gate's own checks re-run.
- **`android/app/src/main/res/values/strings.xml`** — installed from Agent 0.4's staging output
  `android/strings/strings.xml`. Before this assignment, `res/values` appeared zero times in the
  whole plan, meaning no `R.string.*` symbol would ever have existed for Compose to reference.
- **`android/app/src/main/assets/fonts/**`** — copy of the 87 `.ttf` files across the 45 bundled
  families from `MakhtootKit/Sources/MKFonts/Resources/Fonts/`, honouring `_PROHIBITED.md` and
  `EXCLUDED_FONTS.md` exactly as the iOS bundling step does. Before this assignment, all six
  references to this path across the plan were reads with no corresponding writer.
- **`android/app/src/main/res/xml/dataExtractionRules.xml`** and **`backup_rules.xml`** — at
  targetSdk 36, `android:dataExtractionRules` governs backup on Android 12+ and
  `fullBackupContent` governs it only on Android 11 and below; both files are required, restricted
  to exactly the D-312 trial DataStore blob (`§2` — the unencrypted, HMAC-signed blob, not a
  Keystore-wrapped one). Specifying only `fullBackupContent`, as an earlier draft did, means
  D-312's "restricted to exactly that blob" intent was not achieved on any device running Android
  12 or later, and the whole project tree would have been backed up.
- **`Scripts/android/no-stubs-allowlist.txt`** — `check-no-stubs.sh` (`§4` ground rule 3) greps
  for `NotImplementedError` and `Placeholder`, which will always match `MkNotYetPorted.kt` (it
  extends `NotImplementedError` by construction, `§3.3`) and `MkSettingsPlaceholderView.kt`.
  Without this allowlist, G8's blocking check can never pass, since those two files are legitimate
  and permanent, not stub debt.

---

## 12. Shaping-delta classification and parity definitions

The shaping-delta register (D-325) was previously self-service — the agent that caused a mismatch
could also be the one who authorised recording it. That is corrected here with three classes,
none of which any agent may self-assign without following the rule for that class:

- **Class A — acceptable, an agent may register it directly.** Sub-pixel positional deltas within
  a stated tolerance (**starting number: position delta ≤ 0.5 px at the fixture's rendered scale,
  or ≤ 1/64 em, whichever is larger** — marked as the agent's to validate and tighten at G3, not a
  permanently fixed constant), line-break opportunity choice, advance rounding (**≤ 1 unit at
  1000 UPM**).
- **Class B — never acceptable, a hard gate failure, and cannot be registered at all.** Any
  dropped, added, or reordered mark; any changed glyph id; any broken or differently-composed
  ligature; any changed joining form; any tashkeel loss. This is the mechanical expression of
  `CLAUDE.md`'s non-negotiable invariant — there is no register entry that makes a Class-B delta
  acceptable, ever.
- **Class C — requires founder sign-off, per row.** Everything that is neither A nor B — a
  legitimate font-behavior difference under HarfBuzz that is neither a rounding artifact nor a
  correctness violation.

**G3's denominator, restated with a unit.** Parity is measured per **(font family × corpus string
× glyph) triple**. G3 passes iff: zero Class-B deltas; Class-A deltas ≤ 1% of triples; every
Class-C row is signed off. The earlier "≥99% of golden fixtures match" wording named no unit and
was unenforceable — a "fixture" is not the thing being counted, a triple is.

**G4's render tolerance.** Skia and Core Graphics rasterise antialiased vector art differently, so
a concrete tolerance is required, not "pixel tolerance" left unstated. Starting numbers, to be
justified (not merely asserted) in `android/docs/RENDER_TOLERANCE.md` and validated by the
Batch 4/5 agents that first exercise them:

- Per-channel (8-bit RGB) tolerance: **≤ 6** per channel.
- Maximum fraction of differing pixels per compared raster: **≤ 1.0%**.

Both numbers are explicitly the agent's to validate and tighten or loosen at G4, not a value this
document asserts as final — `RENDER_TOLERANCE.md` is where the justification for whatever value
ships actually lives.

---

## 13. Risk register

| # | Risk | Why it is real here | Mitigation | First detected at |
|---|---|---|---|---|
| R1 | HarfBuzz ↔ Core Text shaping divergence | Two independent OpenType implementations; Arrange Mode freezes shaped output into user-editable structure, so a divergence is visible and permanent | D-324 golden fixtures + D-325 delta register with the A/B/C classification (`§12`) + per-font fidelity gate mirroring D-222 | G3 |
| R2 | The 45-family bundled catalog behaves differently under FreeType | Variable fonts, Nastaliq (`NotoNastaliqUrdu`, `Gulzar`, `Alkalami`) and ink fonts stress GSUB hardest | Per-family fidelity sweep in Batch 3, blocking; a family that fails ships only after its delta is registered as Class C and signed off | G3 |
| R3 | PDF writer scope | ~5,000 LOC of the hardest new code, no CG equivalent to lean on; now explicitly two agents (5.7a core writer, 5.7b subsetting/CMYK/ICC) | Own agents (5.7a/5.7b), byte-golden tests, external-viewer verification in G5 performed by the founder, not an agent (`§6`) | G5 |
| R4 | Play Billing state machine ≠ StoreKit 2 | Grace/hold/pause semantics differ; unacknowledged purchases auto-refund at 72 h; `paymentState`/`subscriptionState` are not observable client-side at all (`§2` D-311) | Dedicated agent (6.1), scenario stubs ported from `MKSandboxScenarioStub`, acknowledgement is a tested invariant, banner copy is deliberately generic rather than state-specific | G6 |
| R5 | Drive sync is not CloudKit | No CKSyncEngine equivalent; change tokens and quotas differ; auth is a two-step Credential Manager + GIS `AuthorizationClient` flow, not one call | Reuse `MKSyncDecisionEngine`'s policy unchanged (6.3b); only the transport is new (6.3a) | G6 |
| R6 | Trial reinstall-survival is weaker, and has no cross-device propagation at all | Auto Backup can be disabled by the user; it is also a single-slot device-setup restore, not a live sync channel (`§2` D-312) | Documented in-app and in the plan; never presented as equivalent to Keychain, and never presented as cross-device sync | G6 |
| R7 | Two codebases drift | The iOS engine keeps changing | Monorepo (FDA-02) + fixtures regenerated in CI + parity matrix as a checked-in ratchet | G0, re-checked every gate |
| R8 | Canvas performance | Reimplemented pan/zoom, no CALayer, no API 26–28 fallback to fall back to if `RenderNode` underperforms (FDA-07 removed that path deliberately) | D-305 RenderNode-only path + Batch 8.4 budgets on real hardware, including an A12-class Android equivalent (a 2020 mid-range device) | G8 |
| R9 | `Modifier.blur` is a no-op below API 31 | `MkFloatingBar`'s translucent surface has no blur on API 29–30 devices, which are in-scope under minSdk 29 | Documented limitation (flat alpha surface fallback), explicit visual check on an API 30 emulator at Batch 8.5 | G8 |

---

## 14. Out of scope for Android v1

The no-"coming soon" contract in `§0`/`§4` is about **iOS parity** — every one of the 318 iOS
R-ids (not 319 — `§0`) ships. It is not a promise that Android v1 exceeds iOS v1. The following are honestly out
of scope, and none of them is a feature the iOS app has today:

- **iOS↔Android cross-device sync** (FDA-01). Sync is Android↔Android via Drive and iOS↔iOS via
  CloudKit; the two never see each other's projects. This is a documented limitation, not a
  missing feature — the iOS app has no cross-platform sync either.
- **Play grace-period / billing-retry state-specific banner copy** (`§2` D-311). Play Billing
  gives no client-side signal to distinguish the two states, so both retain premium and show one
  generic banner; iOS's state-specific banner copy has no Android equivalent and none is planned,
  since building one would require the server-side Play Developer API, which this plan
  deliberately does not introduce (D-311 stays no-backend).
- **On-screen CMYK soft-proofing.** Matches iOS: D-117/D-315 both explicitly ship without it in
  v1.
- **Apple Pencil equivalents beyond stylus pressure.** iOS v1 has no Pencil-specific features
  beyond standard touch/stylus input; Android inherits the same scope, nothing more.
- **The four iOS developer harnesses and `EditorPlaceholderView.swift`** (`§3.1`) — internal
  tooling and dead unrouted code, backing no PRD requirement; excluded from Agent 1.4's stub
  scope explicitly so they cannot inflate the stub-burn-down counter.
- **Anything `PRD.md` §23 already lists as a v2 seam** (e.g. animation/video/reels, templates,
  multi-page canvas, Metal/Vulkan adoption, App Store Server API integration, licensed CMYK
  profile) — these are out of scope for iOS v1 too, so they are out of scope for Android v1 by
  the same logic, not a new cut.
- **Commercial foundry font licensing** (FD-07, "post-v1" on iOS) stays post-v1 on Android.
- **Accessibility work beyond D-319's direct substitutions.** `PROJECT_DESCRIPTION.md` records "no
  material scope allocated" for accessibility as an explicit founder "no" for v1 on iOS; D-319
  ports what already exists (touch targets, VoiceOver→TalkBack, Dynamic Type→fontScale) without
  adding net-new accessibility scope beyond that iOS baseline.

---

## 15. Estimate

| Quantity | Estimate | What drives the range |
|---|---|---|
| Kotlin production LOC | ~62,000 | Direct 1:1 module port of 38,080 Swift LOC plus the app target's 16,227, inflated by Kotlin/JNI boilerplate (native bridge, Compose scaffolding) and the ~5,000 LOC in-house PDF writer that has no Swift-side equivalent to size from |
| Kotlin test LOC | ~28,000 | Mirrors the 26,771 Swift test LOC roughly 1:1, since D-324/ground-rule 6 require porting every test, plus new instrumented UI tests in Batch 8.6 and the `T-AND-*` Android-only tests (`§5.3`) |
| Agents | 66 across 10 batches | Fixed by the frozen register in `§5` — not an estimate |
| Wall-clock per batch | Low tens of minutes to a few hours, batch-dependent | Driven by the largest single agent in the batch (e.g. Batch 5's PDF writer agents 5.7a/5.7b, or Batch 7's 9-way UI split) rather than agent count, since all agents in a batch run concurrently |
| Token magnitude per batch | Roughly proportional to source+test LOC touched that batch | Batches 5 (`mk-canvas`, `mk-export`, `mk-assets`) and 7 (`app` UI) are the largest by LOC and should be expected to run longest; Batches 2 and 6 are comparatively light |

These are ranges, not commitments — the real gates (`§6`) are what determines whether a batch is
actually done, not a token or time budget.

---

## 16. Traceability and coverage register

- **`FOUNDATION.md` §11 conventions.** `R-<section>.<n>` exactly as defined in `PRD.md`; `D-3xx`
  for new decisions, continuing the `D-1xx`/`D-2xx` sequence; Arabic UI strings with a Latin gloss
  in parentheses on first use, per FOUNDATION.md §12 (`§9`).
- **`PRD.md` sections.** All 23 `PRD.md` sections map to Android v1 one-for-one except where `§14`
  explicitly excludes a §23 v2 seam from both platforms. `android/PARITY_MATRIX.md` (Batch 0 ·
  Agent 0.1) is the per-requirement ledger that proves every `R-<section>.<n>` from every PRD
  section ships, and is the place all 318 ids (not 319 — `§0`) get assigned an owning batch.agent, including the
  102 that were previously cited by no packet (`§5.3`).
- **`ARCHITECTURE.md` sections.** The platform substitution table (`§2`) covers the Android
  counterpart of every `ARCHITECTURE.md` mechanism section that has a platform-specific
  implementation (§4 Text Engine → D-303, §9 Path Text → D-303/D-305, §11 Rendering → D-305, §13
  Persistence → D-308/D-309, §15 Color → D-315, §16 Export → D-313/D-314, §18 StoreKit → D-311,
  §19 Trial/Referral → D-312/D-321, §20 CloudKit Sync → D-310, §21 Analytics → D-320, §22 Design
  System → D-317).
- **Orphaned test coverage closed** (`§5.3`): `MakhtootKit/Tests/WS16CursiveTests/` → Agent 3.3;
  `MakhtootKit/Tests/MKDesignSystemTests/`'s three real files → Agents 2.4/2.5; the three
  non-existent test-file names struck from any packet that still cites them.
  `Scripts/android/stub-source-audit.sh` (an existing house ratchet, `§9` house-style reference)
  is the mechanical check that a Kotlin file's Swift source actually exists — use it to catch
  future orphaning, not just this round's.
- **`T-AND-*` ids.** Any Android-only test with no Swift-side counterpart gets a new
  `T-AND-<n>` id, registered into `TEST_MATRIX.md` by whichever agent authored it; Agents 8.7 and
  9.5 are responsible for confirming the full set is registered by their respective gates.
- **`EXECUTION_PLAN_2026-07-28.md` house style.** This document borrows its ground-rules numbering
  style, its at-a-glance table convention, and its file-ownership-matrix appendix convention
  directly from that plan's structure (`§9`).

---

## 17. Ownership rule and cross-batch conflicts

**Ownership rule, restated.** Exclusive ownership (`§4` mechanism (a)) holds *within a batch*. A
later batch may take over a path from an earlier batch, but the takeover must be declared in
**both** packets — the earlier batch's "Owns" note that a later batch supersedes it, and the
later batch's "Owns" note that it is taking over a specific named path, not creating a new one.

Four known cross-batch conflicts, each resolved explicitly here so no packet has to guess:

| Path | Conflict | Resolution |
|---|---|---|
| `res/xml/locales_config.xml` | Cited as owned by both 1.1 and 7.1 | Agent 1.1 creates it in Batch 1 pinned to `ar` (D-318); Agent 7.1 may take it over in Batch 7 only if app-shell locale-picker wiring requires edits, and must declare the takeover in its own packet's Owns list, with 1.1's packet annotated "superseded by 7.1" |
| `android/app/build.gradle.kts` | Cited as owned by both 1.1 and 9.2 | Agent 1.1 creates and owns it exclusively during Batches 2–8 (`§3.2`'s stated exception window); Agent 9.2 takes it over in Batch 9 specifically for signing-config/AAB/R8 additions — this is not a violation of 1.1's exclusivity, because that exclusivity is explicitly scoped to Batches 2–8, not Batch 9 |
| `MkAppContainer.kt` | Cited at three different paths across 1.4, 7.1 and 8.1 | Frozen at a single path: `android/app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt`. Agent 1.4 creates the Batch 1 contract stub at exactly this path (`§3.3`'s stub/impl path-identity rule); Agent 7.1 supersedes it with the real composition-root implementation at the same path, declaring the takeover; Agent 8.1 reads and wires against it but does not own or edit the file |
| `MkAlwaysPremiumEntitlementStub.kt` | Cited at `src/debug/` per 1.4 and `src/main/` per 7.1 | **`src/debug/` is correct** — this is a debug-only entitlement stub (mirrors D-225/D-321's debug-only referral pattern) and must never ship in `src/main/`; Agent 7.1's packet is wrong wherever it says `src/main/` and must be corrected in that file's own later pass |

**The second named exception to ground rule 9** ("never touch iOS/anything outside `android/`"),
alongside Batch 0 · Agent 0.5, is Batch 9 · Agent 9.3 (FDA-08, D-309) — it is the only iOS
engineering agent outside Batch 0, and it updates `FOUNDATION.md`, `CLAUDE.md` and
`PROJECT_DESCRIPTION.md` as part of landing iOS-side zip import/export.
