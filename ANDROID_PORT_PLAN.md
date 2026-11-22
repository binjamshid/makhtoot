# Makhtoot Android Port — Master Plan (2026-07-30)

**Revision.** This version incorporates an adversarial review dated 2026-07-30 that found 27
defects (6 fatal) in the prior draft. Numbers, decisions and the module/dependency tables below
are corrected against `ANDROID_SPINE.md` (the now-authoritative shared spec) and re-verified
directly against the repo with `find`/`wc`/`grep`. The earlier version of this document was not
executable — it cited a `59`-agent register with a wrong dependency graph, a wrong minSdk, and
several decisions (D-310, D-311, D-312) that described mechanisms Android does not actually
expose.

Founder-authorised. This document overrides `CLAUDE.md`'s "iPhone and iPad only. No Android
port, and none is planned for v1" and `FOUNDATION.md` D-100 ("Universal iPhone+iPad"). The
override is recorded as a formal decision at Batch 0 · Agent 0.5, which writes **D-300** into
`DECISIONS_LOG.md`, `FOUNDATION.md` and `CLAUDE.md` — this plan does not silently contradict
those documents, it is the mechanism by which they get amended.

**No-"coming soon" contract.** All 319 `R-<section>.<n>` requirements in `PRD.md` ship in
Android v1. No `قريبًا` ("coming soon") strings, no disabled buttons, no stubbed screens. The
stub burn-down counter (§7) is the measurable proof of this contract, and it must read zero at
Gate G8.

This is the master document. Ten per-batch packet files
(`ANDROID_TASK_PACKETS/BATCH-0.md` … `BATCH-9.md`) hold the
66 per-agent packets (`§7`). This document references them; it does not duplicate their
per-agent detail. `ANDROID_SPINE.md` is the single authoritative source for every fact cited
here by section number — where this document and the spine disagree, the spine is correct.

---

## 1. What is being ported

Source of truth for behaviour is the **shipped Swift code**, not the prose docs. Verified
2026-07-30 by direct `find`/`wc` against `main`:

| Metric | Value |
|---|---|
| MakhtootKit library targets | 16 |
| `MakhtootKit/Sources/**` files / LOC | **269 / 38,080** — the 16-library-target count *alone*, before `:app` is added; `MKRender` is 23 files, `MKAssets` is 24 (see `§5` for the corrected per-module table). Never state 269 as an all-in total — it excludes `:app` entirely |
| `:app` scope (`Makhtoot/AppShell/**` entry points) | **55 files / 15,280 LOC** in port scope; **60 files / 16,227 LOC** on disk before excluding the four iOS developer harnesses and `EditorPlaceholderView.swift` (947 LOC across 5 files, `§12`) |
| **Total in port scope** (`MakhtootKit/Sources` 269 + `:app` 55) | **324 files / 53,360 LOC** (329 files / 54,307 LOC on disk before the five exclusions) |
| `MakhtootUITests` (separate — not part of the port-scope total above) | **7 files / 678 LOC** |
| `MakhtootKit/Tests/**` (separate — not part of the port-scope total above) | **218 files / 26,771 LOC** |
| Swift files across the repo | 567 |
| Passing tests, zero skips | 1,101 (per `AUDIT_2026-07-28.md`) |
| PRD requirement ids (`R-<section>.<n>`) | 319 |
| Test ids (`T-<area>-<n>`) referenced in specs/tests | 212 |
| Bundled font families / font files | 45 / 87 |
| Design-system themes | 5 (Hibr حبر / Kufi كوفي / Naqsh نقش / Raml رمل / Tayf طيف) |

### MakhtootKit targets — LOC and responsibility

| Target | Source LOC | Responsibility |
|---|---|---|
| `MKFoundation` | 1,234 | geometry, transforms, RTL utilities, ids, logging, errors, feature flags |
| `MKModel` | 2,176 | scene-graph value types, styles, provenance, Codable schema, migration |
| `MKTextEngine` | 2,195 | Core Text shaping capture: attributed-string build, run/cluster/bidi introspection, glyph geometry, joining analysis, form resolution |
| `MKArrange` | 2,078 | Live Text → Arranged Composition derivation, mark attachment, ligature grouping/decomposition/recomposition, join break/restore, revert-to-text |
| `MKPathText` | 1,945 | arc-length parameterized Bézier layout for RTL/bidi text, live path editing, arrange-on-path |
| `MKCanvas` | 6,580 | canvas view, gestures, selection, marquee, handles, guides, snapping, group transforms, zoom/pan, text-editing overlay |
| `MKRender` | 3,603 | scene renderer, layer-backed preview, tile/bitmap caches, degradation ladder, hit testing |
| `MKColor` | 467 | color model, ICC profile handling, RGB→CMYK conversion |
| `MKExport` | 3,342 | JPEG/PNG/SVG/PDF writer, presets, 2 MP gating, tiled huge-raster rendering, export history |
| `MKFonts` | 2,480 | bundled-font registry, premium catalog + downloads, user import, coverage, license metadata |
| `MKPersistence` | 3,283 | `.makhtoot` file-package documents, atomic autosave, journaling, crash recovery, undo/redo, SwiftData metadata index |
| `MKSync` | 1,945 | CKSyncEngine premium project sync, conflict policy, account state |
| `MKStore` | 1,668 | StoreKit 2 products/purchase/restore, entitlement resolution, trial, referral (flag-isolated) |
| `MKAnalytics` | 1,004 | opt-in consent, on-device font-usage aggregation, anonymous batched upload, kill switch |
| `MKDesignSystem` | 1,405 | theme protocol, 5 themes, semantic colors, Arabic type ramp, RTL-first components |
| `MKAssets` | 2,675 | bundled shapes, ornaments, frames, calligraphic elements, pattern backgrounds |

---

## 2. Founder decisions (FDA-01…FDA-08)

FDA-01, FDA-02, and the FDA-03 carve-out were decided by the founder on 2026-07-30. The
remaining FDAs carry defaults chosen so the run never has to stop mid-batch waiting on an
answer — each is revisable later without invalidating any completed batch.

| ID | Decision | Resolution |
|---|---|---|
| FDA-01 | Premium sync mechanism on Android | Google Drive `appDataFolder` (Drive v3 REST + Credential Manager + GIS `AuthorizationClient`, `§3` D-310). No backend of our own. Android↔Android only — an iOS device and an Android device never see each other's projects, documented in Settings → المزامنة (sync). |
| FDA-02 | Where Android code lives | `android/` inside this monorepo. Golden fixtures exported from the Swift engine sit next to the Kotlin tests that consume them. |
| FDA-03 | CMYK ICC profile for Android | Default: lcms2 synthetic generic CMYK, documented as lower fidelity exactly as D-117 documents Apple Generic CMYK. Apple Generic CMYK is **not** redistributable in an Android APK. Upgrade seam: a redistributable profile whose licence is verified, never assumed (`VERIFY-AT-SUBMISSION`). |
| FDA-04 | Analytics upload endpoint | Default: no-op uploader. Consent UI and on-device counters ship complete; the uploader posts to the same founder-controlled static host as FD-04 premium fonts once it exists, and is a no-op until then. Never a third-party analytics SDK. |
| FDA-05 | Play product ids | Mirror iOS: subscription `net.binjamshid.makhtoot.premium` (base plans `monthly` / `annual`); one-time INAPP `net.binjamshid.makhtoot.premium.lifetime`. |
| FDA-06 | Play Console + merchant account | Founder-only, first needed at Batch 9. Batches 0–8 run without it. |
| FDA-07 | minSdk | **29** (Android 10), not 26. Consequence: the API 26–28 `Picture` + bitmap-cache render fallback is deleted from the plan entirely (`§3` D-305) — `RenderNode` (API 29+) is the only path, removing an untestable code path. Remaining documented limitation: `Modifier.blur` is a no-op below API 31, so `MkFloatingBar`'s translucent surface degrades to a flat alpha surface on API 29–30; checked visually on an API 30 emulator at Batch 8.5 (`§7`, `§8` G8). |
| FDA-08 | iOS gains zipped-`.makhtoot` import/export | Yes — one iOS-side agent in Batch 9 (D-309). |

---

## 3. Android decision register (D-300…D-325)

`DECISIONS_LOG.md` currently runs to D-231 (verified), so the D-3xx block is collision-free.
Batch 0 · Agent 0.5 writes these into `DECISIONS_LOG.md`, `FOUNDATION.md` and `CLAUDE.md`. This
is the heart of the plan — every later batch executes against this register.

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
| D-311 | Store: Google Play Billing 7+; entitlement precedence (D-113) mapped to Play's states (`lifetime`←acknowledged INAPP, `subscribed`←ACTIVE sub, `inGracePeriod`←Play grace, `inBillingRetry`←account hold/paused, `trial`←D-312, `free`); on-device RSA signature verification only, no backend; `acknowledgePurchase` within 72 h is a first-class tested work item; restore = `queryPurchasesAsync`, mandatory UI. **Play Billing exposes no client-side `paymentState`/`subscriptionState`** — `inGracePeriod` and `inBillingRetry` cannot be reliably distinguished on-device without the server-side Play Developer API. Both states retain premium and show a banner; the banner copy cannot be state-specific the way iOS's is (also listed in `§12` as a named out-of-scope limitation) | Play's state machine has no 1:1 StoreKit 2 equivalent, so it must be mapped explicitly rather than assumed compatible; the 72 h acknowledgement window is a real Play foot-gun (auto-refund) that iOS has no analogue for; the grace/hold ambiguity is a genuine Play Billing API limitation, not an implementation gap | Mirrors D-113's precedence and on-device-verification posture |
| D-312 | Trial: 7-day app-side trial for everyone from first launch. **The trial record is stored unencrypted but integrity-signed** — HMAC with a key embedded in the app binary, tamper-evident, an appropriate posture for a 7-day trial — mirrored to Android Auto Backup (backup rules restricted to exactly that blob). An AndroidKeyStore-wrapped blob was the earlier formulation; it is **wrong**, because a Keystore key is destroyed on uninstall, so a Keystore-wrapped blob restored by Auto Backup would be permanently undecryptable — zero reinstall survival, not merely "weaker than Keychain." Clock-rollback guard via `SystemClock.elapsedRealtime()` anchor, never extends. **"Earliest timestamp wins across devices" is deleted as a claim**: Auto Backup is a single-slot restore performed once at device setup, not a live sync channel, so there is no cross-device propagation at all — say that plainly, not "weaker than iOS," in every place this decision is elaborated | Auto Backup can be disabled by the user, unlike Keychain's `kSecAttrAccessibleAfterFirstUnlock`; the honesty requirement (never overclaim) comes straight from `PROJECT_DESCRIPTION.md`'s product principles; the HMAC redesign is required because the Keystore approach gave no reinstall survival at all, which is a correctness bug, not a documented weakness | Mirrors D-123, with the reinstall-survival gap documented as R6 (`§11`) |
| D-313 | Raster export: tiled `Bitmap` strips → `Bitmap.compress` for PNG/JPEG; transparent PNG native; output size bounded by disk not RAM; same 2 MP free-tier clamp | Keeps the free/premium raster boundary numerically identical across platforms | Mirrors D-118's raster half |
| D-314 | PDF export: in-house PDF writer in `:mk-export` — vector paths, live-text runs, font subsetting via `hb-subset`, ICC OutputIntent, CMYK; Android's `PdfDocument` rejected (no CMYK, no output intents, no controlled font embedding) | `PdfDocument` cannot meet the print-PDF bar D-118/D-117 already committed to on iOS; there is no shortcut here | Mirrors D-118's PDF half, ports rather than reimplements the CG-based approach conceptually |
| D-315 | Colour: lcms2 via NDK replaces `CGColorSpace(iccData:)` for sRGB→CMYK with relative colorimetric intent; working space stays extended sRGB, document stores sRGB components; profile choice is FDA-03; no on-screen soft-proofing in v1, same as iOS | lcms2 is the de facto open-source CMS with the same relative-colorimetric conversion iOS uses via Core Graphics | Mirrors D-117 |
| D-316 | Fonts: bundled fonts in `android/app/src/main/assets/fonts/**`, opened by FreeType/HarfBuzz via `AssetManager` fd + `hb_blob` (no extraction to disk, no OS-level registration needed); user import via SAF `ACTION_OPEN_DOCUMENT`, content-addressed copy, same sfnt table validator ported byte-for-byte with the same Arabic error strings | `CTFontManagerRegisterFontURLs` has no Android analogue and needs none — HarfBuzz opens fonts directly from a blob | Mirrors D-122 |
| D-317 | Design system: `MkTheme` via Compose `CompositionLocal`s, not `MaterialTheme`; all 5 themes ported with identical tokens; all 9 UI-chrome fonts are already bundled custom fonts, so there is no SF-Arabic dependency to replace | `MaterialTheme` would fight, not host, a fully custom Arabic-first token system; the UI-chrome fonts being self-contained removes what would otherwise be the hardest parity risk | Mirrors D-126 |
| D-318 | Localisation: `resConfigs("ar")`, `android:supportsRtl="true"`, per-app locale pinned to `ar` via `locales_config.xml` + `AppCompatDelegate.setApplicationLocales` regardless of device locale; `Scripts/check-localization.sh` gets an Android sibling | Preserves the Arabic-only strategic bet (`CLAUDE.md`, `PROJECT_DESCRIPTION.md`) on a platform where the OS locale is not the app locale by default | Mirrors the `ar`-only intent underlying D-100 §Platform and scope |
| D-319 | Accessibility: TalkBack replaces VoiceOver; touch-target floor 48dp (Android convention) replacing 44pt; `fontScale` honoured throughout; reduce-motion read from `Settings.Global.TRANSITION_ANIMATION_SCALE` | Direct platform-idiomatic substitution, same quality bar as iOS's 44pt/VoiceOver requirement in `CLAUDE.md` | New Android-specific elaboration of the accessibility clause in `CLAUDE.md`'s quality bar |
| D-320 | Analytics: consent (default OFF, versioned record), on-device font-usage bucket counters, kill switch port verbatim; upload target per FDA-04; never text, projects, identifiers or font files | Zero behavioural change from D-125 is achievable because analytics has no iOS-specific dependency | Mirrors D-125 exactly, upload transport only differs (FDA-04) |
| D-321 | Referral: same compile-time exclusion as D-225 — a `referral` source set present only in the debug variant plus `buildConfigField("boolean","REFERRAL_ENABLED",...)`; module and Arabic strings absent from the release AAB entirely; `Scripts/referral-release-grep.sh` gets an Android sibling | The App Review risk rationale behind D-225 applies identically to Play Store review | Mirrors D-225 |
| D-322 | Distribution: AAB + Play App Signing; Play Data Safety form replaces iOS privacy nutrition labels; track ladder internal → closed → production | Standard Play distribution shape, chosen to mirror the iOS TestFlight-then-App-Store ladder in spirit | New — no direct iOS decision; parallels the App Store submission process described in `PROJECT_DESCRIPTION.md`'s Launch direction |
| D-323 | No KMP, no Flutter, no React Native | All three require rewriting the shipped, tested Swift engine; the Swift source is used as an executable spec instead, which only a native Kotlin/NDK port allows | Directly enforces `PROJECT_DESCRIPTION.md`'s "correctness of the Arabic engine first" principle at the tooling-choice level |
| D-324 | Parity is enforced by fixtures, not by review: golden artefacts exported from the iOS engine in Batch 0 are the acceptance oracle for every engine module | Human review cannot reliably catch shaping regressions (`CLAUDE.md`: "shaping regressions are invisible in review") — this is the two-platform version of that same rule | Elaborates `CLAUDE.md`'s "test the text engine with golden fixtures" for a two-shaper world |
| D-325 | Shaping-delta register: any legitimate Core Text ↔ HarfBuzz difference recorded in `android/SHAPING_DELTAS.md` with font, input, delta, **class (A/B/C)** and reason; an unregistered delta, or **any Class-B delta**, fails the gate. **Class A** (acceptable, agent-registerable): sub-pixel positional deltas within tolerance, line-break choice, advance rounding. **Class B** (never acceptable, cannot be registered at all): any dropped/added/reordered mark, changed glyph id, broken or differently-composed ligature, changed joining form, or tashkeel loss. **Class C** (requires founder sign-off per row): any other legitimate font-behavior difference | Two independent shaper implementations will diverge on edge cases; the register is what keeps "never silently mis-shape Arabic" true across two stacks instead of one, and the class system stops the agent that caused a delta from being the one who authorises it | New mechanism required specifically because Android introduces a second shaper; enforces `CLAUDE.md`'s "shaping correctness is non-negotiable" |

---

## 4. Platform substitution table

The single most useful table in this document — one row per iOS technology, its Android
replacement, the fidelity risk of that replacement, and which batch/agent owns making it real.

| iOS mechanism | Android mechanism | Fidelity risk | Where handled |
|---|---|---|---|
| Core Text shaping (`CTTypesetter`/`CTLine`/`CTRun`) | HarfBuzz `hb_shape` (D-303) | High — two independent OpenType shapers | 3.1, 3.2, 3.3 |
| `CTFontCreatePathForGlyph` | FreeType outline extraction via `mk-native` | Medium — hinting/outline-fidelity differences at small sizes | 1.2, 3.1 |
| `CTRunGetStringIndices`/`kCTRunStatusRightToLeft` (cluster/bidi introspection) | `hb_glyph_info_t.cluster` (`HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS`) + ICU BiDi | High — cluster/ligature-candidate detection (D-105/D-108) depends on exact semantics matching | 3.2, 4.1, 4.2 |
| ZWJ form harvesting (D-107) | Same technique through `hb_shape` (D-303) | Medium — depends on font GSUB tables behaving identically under HarfBuzz | 3.3, 4.2 |
| Core Graphics (path fill/stroke, CGContext) | `android.graphics.Canvas` / Skia (D-305) | Low — both are mature 2D vector rasterizers | 4.5, 4.6, 5.1–5.4 |
| CALayer tree (layer-per-node, cheap transforms) | `RenderNode` (API 29+ only — no fallback, FDA-07/D-305) | Medium — no fallback path means the RenderNode path must simply work on every supported device | 4.5, 4.6, 5.1 |
| `UIScrollView` zoom/pan (bounce, zoom bounds, content inset) | Owned transform matrix + `ScaleGestureDetector`/`GestureDetector` (D-306) | High — semantics fully reimplemented, not inherited from a system component | 5.1, 5.2 |
| `UITextView`/TextKit 2 editing overlay | Transparent `EditText` + custom `InputConnection` (D-307) | Medium — IME/Arabic-keyboard/selection-handle behaviour varies by OEM keyboard | 5.4 |
| SwiftUI app shell | Jetpack Compose | Low — comparable declarative UI paradigms | 7.1–7.8 |
| UIKit gestures (`UIGestureRecognizer` family) | Android `GestureDetector`/`ScaleGestureDetector`/raw `MotionEvent` tracking | Medium — gesture-conflict resolution differs by platform | 5.2, 5.3 |
| `.makhtoot` file package | Directory + zip forms, byte-identical layout (D-308/D-309) | Low — plain filesystem layout, well specified | 3.4, 3.5, 3.6 |
| SwiftData (metadata index) | Room (D-308) | Low — both are typed local-database layers over a known schema | 3.6 |
| `UIDocument`/Files app integration | SAF (`ACTION_OPEN_DOCUMENT`)/content-addressed storage | Medium — SAF's content-URI model differs meaningfully from `NSFileCoordinator` semantics | 3.7, 6.5, 7.2 |
| `CGPDFContext` | In-house PDF writer in `:mk-export` (D-314) | High — ~5,000 LOC of new code with no CG equivalent to lean on | 5.7 |
| `CGColorSpace` ICC/CMYK conversion | lcms2 via NDK (D-315) | Medium — different CMS implementation, same relative-colorimetric intent | 2.3, 5.7 |
| `CTFontManagerRegisterFontURLs` | None needed — HarfBuzz opens fonts directly via `hb_blob` from `AssetManager` fd (D-316) | Low — the substitution removes a dependency rather than replacing it 1:1 | 3.7, 1.2 |
| StoreKit 2 | Google Play Billing 7+ (D-311) | High — grace/hold/pause state machine (undistinguishable client-side, `§12`) and 72 h acknowledgement window differ materially | 6.1 |
| Keychain + iCloud KVS (trial persistence) | Unencrypted, HMAC-signed DataStore blob + Android Auto Backup (D-312) | Medium — no reinstall survival if Auto Backup is disabled by the user; no cross-device propagation at all (not "weaker," genuinely absent) | 6.2 |
| CloudKit private DB (project sync) | Google Drive `appDataFolder` (D-310) | High — no CKSyncEngine equivalent; change-token/quota semantics differ; auth is Credential Manager + GIS `AuthorizationClient`, two mechanisms not one | 6.3 |
| CloudKit public DB (analytics upload) | Founder-controlled static host / no-op uploader (FDA-04) | Low — analytics payload shape is unchanged, only the transport moves | 6.4 |
| `os_proc_available_memory` + `DispatchSource` memory pressure | `ActivityManager.MemoryInfo` polling + `ComponentCallbacks2.onTrimMemory` | Medium — Android's trim-memory levels don't map 1:1 to iOS's three-stage ladder | 4.6, 8.4 |
| `OSSignposter` | Android `Trace`/Perfetto tracing | Low — both are OS-native tracing facilities for Instruments/Perfetto-class profiling | 4.6, 8.4 |
| VoiceOver | TalkBack (D-319) | Medium — screen-reader traversal order and gesture vocabulary differ by platform | 8.5 |
| Dynamic Type | `fontScale` (D-319) | Low — both are OS-level text-scaling factors | 7.x panels, 8.5 |
| `.xcstrings` localization | Android `strings.xml` under `resConfigs("ar")` (D-318) | Low — mechanical string-table translation, `ar`-only in both cases | 0.4 |
| App Store Connect | Google Play Console (D-322) | Low — both are standard app-store back-office consoles | 9.1, 9.2, 9.4 |

---

## 5. Module map

18 Gradle modules under `android/` (D-301). Kotlin package root `net.binjamshid.makhtoot`.
Module table and dependency edges below are reproduced verbatim from `ANDROID_SPINE.md` §3.1/§3.2,
which regenerated both directly from `MakhtootKit/Package.swift` on 2026-07-30 — the previous
table here was derived from a stale reading of `FOUNDATION.md` §2 and was wrong for 7 of 17
modules (it invented a `:mk-export → :mk-store` edge and a `:mk-sync → :mk-store` edge that do
not exist).

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
| `:app` | `net.binjamshid.makhtoot` | `Makhtoot` app target — **55 files / 15,280 LOC in port scope** (60/16,227 on disk, minus the 5 excluded files, `§12`); excludes `MakhtootUITests` | 55 | 15,280 | ~14,000 |
| | | **Total in port scope** | **324** | **~53,360** | **~62,000 + ~28,000 test** |

### Dependency edges

Extracted directly from `Package.swift`, not from `FOUNDATION.md` §2 (`§3` of the spine
explains the correction). Entitlement access from any module, including `:mk-export`, is via
the `MKEntitlementProviding` protocol in `:mk-foundation` — **not** a direct dependency on
`:mk-store`; this removes the apparent Batch 5/Batch 6 ordering inversion the old table implied.

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
`:mk-color` — every module that shapes, outlines, or colour-transforms. **There is no
`:mk-export` → `:mk-store` edge and no `:mk-sync` → `:mk-store` edge** — the earlier table
invented both.

### Naming rule (frozen, corrected)

**Every** Kotlin file and top-level type gets an `Mk` prefix. There are no exceptions — the
earlier "files without the prefix keep their name" rule is struck; it was wrong and caused
roughly 97 mismatched file paths across the task packets (fixed in the packets' own pass, not
here).

- `MKShapingEngine.swift` → `MkShapingEngine.kt`
- `ArrangeDeriver.swift` → `MkArrangeDeriver.kt` (previously left unprefixed — that was wrong)
- Acronyms are title-cased after the prefix: `MKStoreIDs` → `MkStoreIds`, `MKRTLUtilities` →
  `MkRtlUtilities`, `ICCProfileStore` → `MkIccProfileStore`.
- Directory structure mirrors the Swift sub-directories (`Sources/MKArrange/…` →
  `mk-arrange/src/main/kotlin/…/arrange/…`).
- Preserve the Swift doc comments' intent and every `D-###`/`INV-###`/`R-###` reference —
  traceability is the point.
- A file with no valid Kotlin filename under this rule as a mechanical transform (e.g. a `+`
  extension file) resolves by merging into the base type's file or a documented alternate
  spelling — the choice is recorded in the agent's impl log, never made silently.

---

## 6. Execution model

10 batches, **66 agents** (`§7`). Every agent in a batch is dispatched in **one message** so the
batch runs concurrently.

One-shot parallel execution across 66 agents is safe because of four mechanisms working
together:

**(a) Exclusive file ownership.** One agent owns a file set; no two agents in a batch touch the
same path. Every batch packet file ends with a collision-proof ownership matrix, in the same
style as this repo's `EXECUTION_PLAN_2026-07-28.md` Appendix.

**(b) Contract-first stubs.** Batch 1 lands every public API of all 16 ported modules plus the
app target as a compiling stub whose body is `throw MkNotYetPorted("<module>.<symbol>")`. Every
later batch's modules therefore compile independently against real signatures from day one —
no agent is ever blocked waiting for another module to exist.

**(c) `android/docs/CONTRACT_CHANGES.md`** is the only channel for cross-module API changes. No
agent edits another module's public API directly; a needed change is appended to this file and
applied by the batch gate, not by the agent mid-batch. This is what makes 66 agents editing in
parallel safe without a live merge process.

**(d) The stub burn-down counter** is the measurable definition of "no coming soons."
`Scripts/android/stub-count.sh` prints the remaining `MkNotYetPorted` count; it is published at
every gate and must reach exactly 0 at G8.

### Ground rules (frozen, verbatim from the shared spine)

1. **Exclusive file ownership.** One agent owns a file set; no two agents in a batch touch the
   same path. Every batch file ends with a collision-proof ownership matrix.
2. **Every agent ends green.** `./gradlew :<module>:testDebugUnitTest :<module>:lintDebug` must
   pass before the agent reports done. An agent that cannot go green reports the blocker in its
   impl-log and leaves the tree compiling.
3. **No "coming soon", ever.** `Scripts/android/check-no-stubs.sh` greps the tree for `TODO(`,
   `NotImplementedError`, `notYetPorted`, `قريبًا`, `coming soon`, `Placeholder` and fails on any
   hit. It is advisory from G1 and **blocking from G8**.
4. **Stub burn-down counter.** Batch 1 lands every public API as a contract stub whose body is
   `throw MkNotYetPorted("<module>.<symbol>")`. `Scripts/android/stub-count.sh` prints the
   remaining count. The count is published at every gate and **must reach exactly 0 at G8, with
   no exception and no escalation path** — there is no "stub count reaches 0 or every remainder
   is a named, escalated gap" clause; an earlier draft of Agent 8.1's acceptance criteria
   contained exactly that clause and it is deleted, not softened.
5. **Contract-first.** No agent edits another module's public API. A needed change is appended
   to `android/docs/CONTRACT_CHANGES.md` and applied by the batch gate, not by the agent. Agent
   1.1 owns `android/docs/CONTRACT_CHANGES.md`, and `Scripts/android/gate.sh N` **fails** if any
   entry in it has status `pending`. Exclusive file ownership (ground rule 1) holds *within a
   batch*; a later batch may take over a path from an earlier batch, but the takeover must be
   declared in both packets' Owns lists.
6. **Port the tests too.** Every ported behaviour brings its Swift test across. Where the Swift
   test used a golden fixture, the Kotlin test consumes the same fixture from
   `android/fixtures/`.
7. **Shaping correctness is non-negotiable** (`CLAUDE.md`). A change that mis-shapes Arabic,
   drops tashkeel or breaks a ligature is never acceptable, on either platform. Mechanically
   enforced by the Class-B shaping-delta rule (`§3` D-325): a Class-B delta cannot be
   registered, full stop — it is a hard gate failure, and the register no longer lets the agent
   that caused a mismatch also be the one who authorises recording it.
8. **Impl log.** Every agent writes `android/docs/impl-log/BATCH-<N>.<k>.md`: what was ported,
   deviations, deltas registered, tests added, stub count delta.
9. **Never touch iOS.** Batches 0 and 9 have explicit, named iOS-side agents. Every other agent
   is forbidden from editing anything outside `android/` (Batch 0 · Agent 0.5 excepted, which
   edits the four decision documents).

---

## 7. At-a-glance batch table

The register is **66 agents**, not 59. Seven agents from the original 59-agent register were not
one unit of work and are split with letter suffixes (3.1a/b, 5.2a/b, 5.4a/b, 5.5a/b, 5.7a/b,
6.3a/b, 7.3a/b) — each split scopes two genuinely separate correctness risks (e.g. HarfBuzz
shaping vs. from-scratch line breaking in 3.1) that one agent should not own together.

| Batch | Agents | Theme | Agent count | Cumulative stub-count target | Gate |
|---|---|---|---|---|---|
| 0 | 0.1–0.5 | Extraction from iOS: parity matrix, golden fixtures, API surface, strings/tokens/assets, decision-doc amendment | 5 | n/a — no stubs exist yet | G0 |
| 1 | 1.1–1.4 | Gradle scaffold · native toolchain · contract stubs A · contract stubs B | 4 | 100 % of public API stubbed (peak count, published at G1) | G1 |
| 2 | 2.1–2.5 | foundation · model · color · designsystem tokens · designsystem components | 5 | 5 modules' stubs burned down | G2 |
| 3 | 3.1a, 3.1b, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7 | textengine (HarfBuzz bridge + line breaking split) ×2, textengine ×2 more · persistence ×3 · fonts core | 8 | +3 modules burned down | G3 |
| 4 | 4.1–4.6 | arrange ×2 · pathtext ×2 · render ×2 | 6 | +3 modules burned down | G4 |
| 5 | 5.1, 5.2a, 5.2b, 5.3, 5.4a, 5.4b, 5.5a, 5.5b, 5.6, 5.7a, 5.7b | canvas view/session ×1, gestures (split) ×2, selection/inspector ×1, IME+interaction (split) ×2, assets (split) ×2, export raster/SVG ×1, export PDF (split) ×2 | 11 | +3 modules burned down | G5 |
| 6 | 6.1, 6.2, 6.3a, 6.3b, 6.4, 6.5 | store billing · store trial+referral · sync Drive transport (split) ×2 · analytics · fonts catalog | 6 | +3 modules burned down (store, sync, analytics) | G6 |
| 7 | 7.1, 7.2, 7.3a, 7.3b, 7.4, 7.5, 7.6, 7.7, 7.8 | app shell: shell/nav · browser · editor core (split) ×2 · canvas host · arrange+path toolbars · inspector/layers · sheets · settings/paywall/onboarding | 9 | `:app` stubs burned down | G7 |
| 8 | 8.1–8.7 | wiring + stub burn-down · shaping parity · render/export parity · performance · accessibility · instrumented UI tests · edge-case compendium | 7 | **0** (mandatory, no exceptions) | G8 |
| 9 | 9.1–9.5 | Play listing/Data Safety · signing/AAB/R8/baseline profile · iOS zip interop · Android store checklist · final parity report | 5 | 0 (unchanged) | G9 |

**Total: 5 + 4 + 5 + 8 + 6 + 11 + 6 + 9 + 7 + 5 = 66 agents across 10 batches.**

---

## 8. Gates

Each gate is a script the founder runs between batches. Gates are the only stopping points.

| Gate | Command | Must be true |
|---|---|---|
| G0 | `bash Scripts/android/gate.sh 0` | `android/PARITY_MATRIX.md` covers all 319 R-ids; `android/fixtures/**` regenerates byte-identically on a second run **for deterministic categories only** — JPEG and PDF outputs are excluded via an explicit exclusion list inside `gate.sh`, since JPEG encoders are not bit-stable and PDF output carries `/CreationDate`; `android/API_SURFACE.md` lists every public symbol of all 16 targets; `android/strings/strings.xml` has every Arabic string from `Localizable.xcstrings`; D-300…D-325 present in `DECISIONS_LOG.md` |
| G1 | `bash Scripts/android/gate.sh 1` | `./gradlew assembleDebug` green on all 18 modules; `:mk-native` smoke test passes on arm64-v8a, armeabi-v7a, x86_64; stub count published; `CONTRACT_CHANGES.md` contains no `pending`-status entry |
| G2 | `…gate.sh 2` | `:mk-foundation :mk-model :mk-color :mk-designsystem` tests green; `mk-model` round-trips all 4 `Tests/Fixtures/*.makhtoot` scenes byte-identically |
| G3 | `…gate.sh 3` | shaping parity measured per **(font family × corpus string × glyph) triple**: gate passes iff zero Class-B deltas, Class-A deltas ≤ 1% of triples, and every Class-C row is signed off in `SHAPING_DELTAS.md` (the earlier "≥99% of golden fixtures" wording had no unit and was unenforceable); persistence journal + crash recovery tests green; font validator rejects the same corpus iOS rejects; `CONTRACT_CHANGES.md` has no `pending` entry |
| G4 | `…gate.sh 4` | arrange derive→decompose→recompose→revert round-trips match golden fixtures; path-text placement within tolerance; render goldens within the tolerance recorded in `android/docs/RENDER_TOLERANCE.md` (Skia and Core Graphics rasterise antialiased vector art differently, so a concrete per-pixel-channel tolerance and a maximum fraction of differing pixels are required, not merely asserted); `CONTRACT_CHANGES.md` has no `pending` entry |
| G5 | `…gate.sh 5` | canvas gesture tests green; export goldens (PNG/JPEG/SVG/PDF) match within tolerance; PDF structural validation (OutputIntent presence, object-stream well-formedness, font-subset integrity) passes as an agent-run automated check. **Opening the PDF in Adobe Acrobat and macOS Preview is a founder gate task, not an agent task** — a headless agent cannot perform it; the founder performs this check by hand between batches (`§10` lists it as a prerequisite blocking G5) |
| G6 | `…gate.sh 6` | Play Billing tested against the six `MKSandboxScenarioStub` scenarios; Drive sync round-trips a project incl. conflict copy, exercising the Credential Manager + GIS `AuthorizationClient` two-step auth (D-310); trial clock-rollback guard holds |
| G7 | `…gate.sh 7` | app runs end-to-end on emulator + a physical device; every screen reachable; zero `Placeholder` composables |
| G8 | `…gate.sh 8` | **stub count = 0, exactly, no exception, no escalation path**; `check-no-stubs.sh` clean against `Scripts/android/no-stubs-allowlist.txt`; all 319 R-ids ✅ in the parity matrix; performance budgets met; TalkBack sweep clean; `MkFloatingBar`'s flat-alpha-surface degradation on API 29–30 visually checked on an API 30 emulator (FDA-07) |
| G9 | `…gate.sh 9` | signed AAB uploads to the internal track; Data Safety complete; referral grep of the release AAB is clean |

---

## 9. How to run this

**Batch 0 must complete before anything else** — it produces `android/fixtures/**`, the golden
artefacts every later batch's acceptance depends on (D-324), plus the parity matrix, API
surface dump, and the D-300…D-325 amendment to the decision documents. No batch after 0 can
start without it.

For each batch N (0 through 9):

1. The founder pastes **one message** that dispatches every agent in Batch N as a single set of
   concurrent `Agent` tool calls — one call per agent, all in the same message, each pointing at
   its packet in `ANDROID_TASK_PACKETS/BATCH-N.md`. The shape of that message is:

   ```
   Agent(description: "Batch N · Agent N.1 — <title>",
         subagent_type: "general-purpose",
         prompt: "Read ANDROID_TASK_PACKETS/BATCH-N.md § 'Batch N · Agent N.1 — <exact title>'
                  in full and execute it exactly as specified. …")
   Agent(description: "Batch N · Agent N.2 — <title>", …)
   … one call per agent in the batch, same message …
   ```

2. Once every agent in the batch reports done, the founder runs:

   ```
   bash Scripts/android/gate.sh N
   ```

3. If the gate passes, proceed to Batch N+1. If it fails, fix within that batch's scope before
   moving on — the same "never carry a broken build forward" discipline as
   `EXECUTION_PLAN_2026-07-28.md`'s waves.

**The only true stopping points are the gates.** Nothing in a batch should require the founder
mid-batch except the external dependencies tabulated in `§10` below — that list is longer than
"FDA-06 alone, first needed at Batch 9" implies.

---

## 10. Prerequisites

An earlier draft of this plan claimed FDA-06 (Play Console + merchant account) was the only
external dependency, first needed at Batch 9. That is false — it is merely the last one to bind.
The full external-dependency ledger, in the order each item first blocks a gate:

| Dependency | Needed for | First blocks |
|---|---|---|
| Android SDK + NDK r27 + JDK 17 toolchain | Building `android/` at all | G1 |
| A Google Cloud project with an Android OAuth client, SHA-1 registration, and a **verified** OAuth consent screen for the `drive.appdata` scope | D-310 sync auth (`§3`); consent-screen verification lead time is measured in **weeks**, not days — start this well before Batch 6 | G6 |
| Two Google accounts + a two-emulator harness | Exercising Drive sync's conflict-copy path (two accounts writing the same project) | G6 |
| Two named physical devices | On-device gesture/IME/accessibility verification that cannot be faked on an emulator | G7 / G8 |
| Adobe Acrobat and macOS Preview access for a human | G5's external-viewer PDF check (`§8`) — explicitly a founder task, not an agent task | G5 |
| Play Console + merchant account (FDA-06) | Signed AAB upload, Data Safety form, release track ladder | G9 |

Batches 0–5 and 7–8 do not require founder-held credentials mid-batch; Batch 6 (G6) and Batch 9
(G9) are where the plan's only real external-dependency waits occur, and the OAuth
consent-screen verification lead time means that item should be started as early as practical,
not deferred until Batch 6 begins.

---

## 11. Risk register

| # | Risk | Why it is real here | Mitigation | First detected at |
|---|---|---|---|---|
| R1 | HarfBuzz ↔ Core Text shaping divergence | Two independent OpenType implementations; Arrange Mode freezes shaped output into user-editable structure, so a divergence is visible and permanent | D-324 golden fixtures + D-325 delta register with the A/B/C classification (`§3`) + per-font fidelity gate mirroring D-222 | G3 |
| R2 | The 45-family bundled catalog behaves differently under FreeType | Variable fonts, Nastaliq (`NotoNastaliqUrdu`, `Gulzar`, `Alkalami`) and ink fonts stress GSUB hardest | Per-family fidelity sweep in Batch 3, blocking; a family that fails ships only after its delta is registered as Class C and signed off | G3 |
| R3 | PDF writer scope | ~5,000 LOC of the hardest new code, no CG equivalent to lean on; now two agents (5.7a core writer, 5.7b subsetting/CMYK/ICC) | Own agents (5.7a/5.7b), byte-golden tests, external-viewer verification in G5 performed by the founder, not an agent | G5 |
| R4 | Play Billing state machine ≠ StoreKit 2 | Grace/hold/pause semantics differ; unacknowledged purchases auto-refund at 72 h; `paymentState`/`subscriptionState` are not observable client-side at all (`§3` D-311) | Dedicated agent (6.1), scenario stubs ported from `MKSandboxScenarioStub`, acknowledgement is a tested invariant, banner copy is deliberately generic rather than state-specific | G6 |
| R5 | Drive sync is not CloudKit | No CKSyncEngine equivalent; change tokens and quotas differ; auth is a two-step Credential Manager + GIS `AuthorizationClient` flow, not one call | Reuse `MKSyncDecisionEngine`'s policy unchanged; only the transport is new | G6 |
| R6 | Trial reinstall-survival is weaker, and has no cross-device propagation at all | Auto Backup can be disabled by the user; it is also a single-slot device-setup restore, not a live sync channel (`§3` D-312) | Documented in-app and in the plan; never presented as equivalent to Keychain, and never presented as cross-device sync | G6 |
| R7 | Two codebases drift | The iOS engine keeps changing | Monorepo (FDA-02) + fixtures regenerated in CI + parity matrix as a checked-in ratchet | G0, re-checked every gate |
| R8 | Canvas performance | Reimplemented pan/zoom, no CALayer, no API 26–28 fallback to fall back to if `RenderNode` underperforms (FDA-07 removed that path deliberately) | D-305 RenderNode-only path + Batch 8.4 budgets on real hardware, including an A12-class Android equivalent (a 2020 mid-range device) | G8 |
| R9 | `Modifier.blur` is a no-op below API 31 | `MkFloatingBar`'s translucent surface has no blur on API 29–30 devices, which are in-scope under minSdk 29 | Documented limitation (flat alpha surface fallback), explicit visual check on an API 30 emulator at Batch 8.5 | G8 |

---

## 12. What is explicitly out of scope for Android v1

The no-"coming soon" contract in §7/§6 is about **iOS parity** — every one of the 319 iOS R-ids
ships. It is not a promise that Android v1 exceeds iOS v1. The following are honestly out of
scope, and none of them is a feature the iOS app has today:

- **iOS↔Android cross-device sync** (FDA-01). Sync is Android↔Android via Drive and
  iOS↔iOS via CloudKit; the two never see each other's projects. This is a documented
  limitation, not a missing feature — the iOS app has no cross-platform sync either.
- **Play grace-period / billing-retry state-specific banner copy** (`§3` D-311). Play Billing
  gives no client-side signal to distinguish the two states, so both retain premium and show one
  generic banner; iOS's state-specific banner copy has no Android equivalent and none is
  planned, since building one would require the server-side Play Developer API, which this plan
  deliberately does not introduce (D-311 stays no-backend).
- **On-screen CMYK soft-proofing.** Matches iOS: D-117/D-315 both explicitly ship without it
  in v1.
- **Apple Pencil equivalents beyond stylus pressure.** iOS v1 has no Pencil-specific features
  beyond standard touch/stylus input; Android inherits the same scope, nothing more.
- **Anything `PRD.md` §23 already lists as a v2 seam** (e.g. animation/video/reels, templates,
  multi-page canvas, Metal/Vulkan adoption, App Store Server API integration, licensed CMYK
  profile) — these are out of scope for iOS v1 too, so they are out of scope for Android v1 by
  the same logic, not a new cut.
- **Commercial foundry font licensing** (FD-07, "post-v1" on iOS) stays post-v1 on Android.
- **Accessibility work beyond D-319's direct substitutions.** `PROJECT_DESCRIPTION.md` records
  "no material scope allocated" for accessibility as an explicit founder "no" for v1 on iOS;
  D-319 ports what already exists (touch targets, VoiceOver→TalkBack, Dynamic Type→fontScale)
  without adding net-new accessibility scope beyond that iOS baseline.
- **The four iOS developer harnesses and `EditorPlaceholderView.swift`** (`§1`, `§5`) — internal
  tooling and dead unrouted code, backing no PRD requirement; excluded from Agent 1.4's stub
  scope explicitly so they cannot inflate the stub-burn-down counter. 947 LOC across 5 files.

---

## 13. Estimate

| Quantity | Estimate | What drives the range |
|---|---|---|
| Kotlin production LOC | ~62,000 | Direct 1:1 module port of 38,080 Swift LOC plus the app target's 15,280 (port scope), inflated by Kotlin/JNI boilerplate (native bridge, Compose scaffolding) and the ~5,000 LOC in-house PDF writer that has no Swift-side equivalent to size from |
| Kotlin test LOC | ~28,000 | Mirrors the 26,771 Swift test LOC roughly 1:1, since D-324/ground-rule 6 require porting every test, plus new instrumented UI tests in Batch 8.6 and the `T-AND-*` Android-only tests |
| Agents | 66 across 10 batches | Fixed by the frozen register in §7 — not an estimate |
| Wall-clock per batch | Low tens of minutes to a few hours, batch-dependent | Driven by the largest single agent in the batch (e.g. Batch 5's PDF writer agents 5.7a/5.7b, or Batch 7's 9-way UI split) rather than agent count, since all agents in a batch run concurrently |
| Token magnitude per batch | Roughly proportional to source+test LOC touched that batch | Batches 5 (`mk-canvas`, `mk-export`) and 7 (`app` UI) are the largest by LOC and should be expected to run longest; Batches 2 and 6 are comparatively light |

These are ranges, not commitments — the real gates (§8) are what determines whether a batch is
actually done, not a token or time budget.

---

## 14. Traceability

- **`FOUNDATION.md` §11 conventions.** This document uses `R-<section>.<n>` exactly as defined
  in `PRD.md` (§1's requirement table cites these ids directly against `PRD.md`'s own
  numbering); `D-3xx` for new decisions, continuing the `D-1xx`/`D-2xx` sequence FOUNDATION.md
  §11 establishes; Arabic UI strings with a Latin gloss in parentheses on first use, per
  FOUNDATION.md §12.
- **PRD.md sections.** All 23 `PRD.md` sections (§1 Overview & Personas … §23 Out of
  Scope/v2 Seams) map to Android v1 one-for-one except where §12 (this document) explicitly
  excludes a §23 v2 seam from both platforms. `android/PARITY_MATRIX.md` (Batch 0 · Agent 0.1)
  is the per-requirement ledger that proves every `R-<section>.<n>` from every PRD section
  ships; this document does not restate that ledger, only its 319-requirement total (§1).
- **`ARCHITECTURE.md` sections.** The platform substitution table (§4) covers the Android
  counterpart of every `ARCHITECTURE.md` mechanism section that has a platform-specific
  implementation (§4 Text Engine → D-303, §9 Path Text → D-303/D-305, §11 Rendering → D-305,
  §13 Persistence → D-308/D-309, §15 Color → D-315, §16 Export → D-313/D-314, §18 StoreKit →
  D-311, §19 Trial/Referral → D-312/D-321, §20 CloudKit Sync → D-310, §21 Analytics → D-320,
  §22 Design System → D-317).
- **`EXECUTION_PLAN_2026-07-28.md` house style.** This document borrows its ground-rules
  numbering style (§6), its at-a-glance table convention (§7), and its file-ownership-matrix
  appendix convention (delegated per-batch to `ANDROID_TASK_PACKETS/BATCH-N.md`, §6 mechanism
  (a)) directly from that plan's structure, per the shared spine's house-style instruction.

> **Writer note:** this document was corrected against `ANDROID_SPINE.md` on 2026-07-30 (see the
> Revision note at the top). Every identifier, decision id, module name, batch number and agent
> number in this document now matches the spine verbatim; numbers were independently re-verified
> against the repo with `find`/`wc` rather than trusted from either document. The prior version's
> claim of "followed without deviation" predated the adversarial review that found this document
> had, in fact, drifted from the spine on the minSdk, the dependency graph, the D-310/311/312
> mechanisms, and the agent count.
