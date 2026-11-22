# Makhtoot Android Port — BATCH-9.md

> The App Store capture set cited in this historical packet is omitted from this source edition.

## Batch 9 · Distribution and iOS Interop (5 agents)

**Depends on:** G8 (stub count = 0; `check-no-stubs.sh` clean; all 319 `R-…` ids ✅ in
`android/PARITY_MATRIX.md`; performance budgets met; TalkBack sweep clean). **Gate:** G9 —
`bash Scripts/android/gate.sh 9`.

Batch 9 is the last batch: it gets the Android app onto the internal Play track and closes
the loop the founder opened by authorizing this port — iOS gains the interchange format
Android needed all along (D-309). Per FDA-06, Play Console and merchant-account access are
founder-only and are first needed here; every step needing them is tagged `[FOUNDER]`
mirroring `APP_STORE_CHECKLIST.md`'s own `[AGENT]`/`[FOUNDER]` convention. No Play policy
fact is ever asserted from memory — every specific claim is either cited or marked
`VERIFY-AT-SUBMISSION` (consolidated list in 9.4), exactly as `APP_STORE_CHECKLIST.md` §15
already does for iOS.

Agent 9.3 is the **only iOS engineering agent outside Batch 0** (spine §4 ground rule 9's
named exception). Agent 9.5 is a **second, explicitly named exception** to the same rule:
spine §5 requires it to update `FOUNDATION.md`, `CLAUDE.md` and `PROJECT_DESCRIPTION.md`
alongside `android/PARITY_MATRIX.md` — the closing decision-doc update that supersedes
the mid-port amendment from work item 0.5 now that the app has actually shipped. Every other
Batch 9 agent stays inside `android/`, `Scripts/android/`, and — for 9.1/9.2 — the Play
Console itself.

The plan's register is **66 agents** across 10 batches (spine §5): 0:5 · 1:4 · 2:5 · 3:8 ·
4:6 · 5:11 · 6:6 · 7:9 · 8:7 · **9:5**, with seven letter-suffixed splits elsewhere in the
plan (3.1a/b, 5.2a/b, 5.4a/b, 5.5a/b, 5.7a/b, 6.3a/b, 7.3a/b) — none of Batch 9's own 5
agents are split, and 9.3's own file scope was widened rather than split into a 6th Batch 9
agent (see the closing writer note below, whose "59 total" figure is corrected there to the
plan's current 66). Where this batch cites a component from an earlier work item with a letter suffix, it cites the specific letter (e.g. the
in-house PDF writer this agent's own zip codec
follows as precedent is 5.7a core writer/5.7b subsetting-CMYK-ICC; the Drive sync engine
whose scope Android↔Android-only limitation this batch documents is 6.3a transport/6.3b
policy) rather than the pre-split parent number.

### At-a-glance

| Agent | Title | Primary deliverable |
|---|---|---|
| 9.1 | Play Console listing (Arabic), screenshots, Data Safety, content rating | Play Console listing draft + Data Safety form answers |
| 9.2 | Signing, AAB, R8/ProGuard for native + reflection, baseline profile | Signed release AAB on the internal track |
| 9.3 | iOS-side zipped-`.makhtoot` import/export (D-309) | `MakhtootKit/Sources/MKPersistence` zip codec + tests |
| 9.4 | `ANDROID_APP_STORE_CHECKLIST.md` and release runbook | `android/ANDROID_APP_STORE_CHECKLIST.md`, `android/docs/RELEASE_RUNBOOK.md` |
| 9.5 | Final parity report: 319 R-ids, zero stubs, docs updated | `android/PARITY_REPORT.md` + four decision-doc updates |

### Android-specific test IDs introduced in this batch

One numbered block, `T-AND-9<agent><seq>`, collision-free against Batch 8's `T-AND-8<n>`
range and every other batch's own block.

| ID | Owner | What it proves |
|---|---|---|
| T-AND-9101 | 9.1 | Data Safety form declarations match actual code behavior (grep-verified against `mk-analytics`/`mk-sync` consent and upload paths, mirroring iOS `T-DST-2`) |
| T-AND-9102 | 9.1 | Screenshot set completeness and pixel-dimension compliance across phone/tablet/foldable classes |
| T-AND-9201 | 9.2 | Referral grep of the release AAB is clean (D-321 Android sibling of `referral-release-grep.sh`/T15) |
| T-AND-9202 | 9.2 | R8/ProGuard keep-rules smoke test: every `external fun` JNI holder class and every `kotlinx.serialization`/Room-annotated class survives a release-minified build unstripped |
| T-AND-9203 | 9.2 | Baseline profile measurably improves cold start (Macrobenchmark `StartupTimingMetric`, before/after) |
| T-AND-9204 | 9.2 | Native debug symbols upload verified against a deliberately forced native crash, symbolicated in Play Console's crash report |
| T-AND-9301 | 9.3 | Zip round-trip: project created on Android opens on iOS, scene identical |
| T-AND-9302 | 9.3 | Zip round-trip: project created on iOS opens on Android, scene identical |
| T-AND-9303 | 9.3 | Path-traversal-safe extraction: crafted zip entries (`../`, absolute paths, symlink entries) rejected on the iOS extractor, mirroring `PackageImportValidator`'s existing directory-form checks |
| T-AND-9304 | 9.3 | `schemaVersion` lockstep: a zip written by the current Android schema version opens correctly (or degrades per the existing forward-compat rule, R-21.43) on the current iOS schema version, and vice versa |
| T-AND-9401 | 9.4 | Staged-rollout halt/rollback drill executed against a real (internal-track) release, confirmed reversible |
| T-AND-9501 | 9.5 | Full-suite regression gate: every `T-AND-1…9` id plus every ported `T-…` id green in one aggregate run, referenced as the evidence base for the final parity report |

---

### Batch 9 · Agent 9.1 — Play Console listing (Arabic), screenshots, Data Safety, content rating

**Depends on:** G8 · **Parallel-safe with:** every other Batch 9 agent

**Mission.** Arabic store listing (title, short and full description, what's new), feature
graphic, phone/tablet/foldable screenshots (mirroring the iOS set in `assets/ASC/`),
content rating questionnaire, and the Data Safety form — declared precisely: nothing
collected by default; opt-in anonymous bucketed font-usage counters per D-320/FDA-04;
what Drive `appDataFolder` access means for the form; the Play account-deletion
requirement addressed honestly (Makhtoot has no accounts). Target countries, pricing tiers
matching the iOS ids (FDA-05), and Family Library ON/OFF as the Play analogue of FD-06 —
irreversible per product, flagged for the founder, never decided by this agent.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `APP_STORE_CHECKLIST.md` §2 (App record creation), §5 (Privacy/nutrition label), §8 (Territories), §10 (Metadata package) | the iOS sibling this listing mirrors in structure and Arabic copy intent |
| `assets/ASC/iPhone screenshots/**`, `assets/ASC/iPad screenshots/**`, `assets/ASC/resized/**` | the existing screenshot set this agent's phone/tablet/foldable set mirrors |
| `FOUNDATION.md` D-320 (spine §2), `PRD.md` §18 (R-18.1…R-18.7) | the exact, minimal analytics surface to declare — no more, no less |
| spine §1 FDA-01 (Drive sync), FDA-05 (product ids), FDA-06 (Play Console founder-only) | Android-specific facts this listing must reflect accurately |
| `android/PARITY_MATRIX.md`, `android/PARITY_REPORT.md` (once 9.5 lands — read-only cross-check) | confirms the listing doesn't overclaim or underclaim a feature |
| spine §2 D-312, §11 (`android/app/src/main/res/xml/dataExtractionRules.xml` and `backup_rules.xml`, both in work item 1.1) | the actual backup-scope mechanism this form's data-collection/retention answers must match: at targetSdk 36, `dataExtractionRules.xml` governs cloud backup and device-to-device transfer on Android 12+, while `fullBackupContent` (in `backup_rules.xml`) covers only Android 11 and below — both files are required and both are restricted to exactly the D-312 trial blob, never the scene/project tree or the Room metadata index |

**Owns (creates or edits — no other agent may touch these).**
- `android/docs/PLAY_LISTING.md` (new — Arabic listing copy, drafts for founder approval, mirroring `APP_STORE_CHECKLIST.md` §10's `[AGENT]` draft / `[FOUNDER]` approve convention)
- `android/docs/DATA_SAFETY.md` (new — line-by-line Data Safety form answers + justification, mirroring §5A)
- `android/assets/play/**` (new — feature graphic, phone/tablet/foldable screenshot exports, resized per Play's current spec)
- `:app/src/androidTest/kotlin/**/DataSafetyDeclarationAuditTest.kt` (new — T-AND-9101)
- `android/docs/impl-log/BATCH-9.1.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`, `assets/ASC/**` (read-only reference —
this agent creates its own `android/assets/play/**` tree, never edits the iOS screenshot
set); any other Batch 9 agent's deliverable.

**Port map.**
| Swift source | LOC | Kotlin/Android target | Notes / platform substitution |
|---|---|---|---|
| `assets/ASC/iPhone screenshots/**`, `assets/ASC/iPad screenshots/**` | — | `android/assets/play/phone/**`, `android/assets/play/tablet/**`, `android/assets/play/foldable/**` | Same scenes (onboarding, editor, Arrange Mode, export sheet), captured on `DEV-AND-PRO`/a tablet emulator/a foldable emulator instead of iPhone/iPad simulators |
| `APP_STORE_CHECKLIST.md` §5A (~L318–369, nutrition label) | — | `android/docs/DATA_SAFETY.md` | Same substance (D-125/D-320: opt-in anonymous font-usage counters only, nothing else) restated in Play's Data Safety taxonomy instead of Apple's nutrition-label taxonomy |

**Tasks.**
1. Draft Arabic store listing: title (`مخطوط`, ≤30 chars per Play's own limit — VERIFY the
   current character cap at submission), short description, full description, "what's
   new" for the first release — same target audience and tone as
   `APP_STORE_CHECKLIST.md` §10's drafts, adapted for Play's field structure.
2. Produce the feature graphic (1024×500, Play's fixed spec — VERIFY current dimension at
   submission) and phone/7"+10" tablet/foldable screenshot sets mirroring the iOS scene
   selection in `assets/ASC/`.
3. Content rating questionnaire: answer to the actual app substance (no user-generated
   content shared publicly, no violence/gambling/ads, in-app purchases present) — cite
   Play's rating authority (IARC) or mark `VERIFY-AT-SUBMISSION`.
4. Data Safety form: declare **Usage Data → App interactions** (font-usage counters) as
   the only collected category, **Collected: optional/opt-in**, **Shared: no**, **Purpose:
   Analytics**, mirroring D-320's default-OFF versioned-consent design exactly; every other
   category **Not collected**, each with the same substance-based justification style as
   `APP_STORE_CHECKLIST.md` §5A's table. Explicitly address:
   - **Drive `appDataFolder` scope**: declare this as the app requesting access to its own
     hidden per-app folder in the user's Drive, not user Drive files in general — Play's
     Data Safety form distinguishes these; state which Drive data-type category this
     actually falls under per the live form (`VERIFY-AT-SUBMISSION`).
   - **Account-deletion requirement**: Makhtoot has no accounts (Drive sign-in via
     Credential Manager authorizes sync only, creates no Makhtoot-side account or profile)
     — state this as the substance and confirm whether Play's account-deletion policy
     applies at all to an app with no account concept (`VERIFY-AT-SUBMISSION`, mirroring
     `APP_STORE_CHECKLIST.md` §5D's N/A justification pattern for the same non-fact on iOS).
   - **Backup/data-retention basis**: cite `android/app/src/main/res/xml/dataExtractionRules.xml`
     and `backup_rules.xml` (Agent 1.1, spine §11) as the disclosure basis for what actually
     leaves the device via Android's own backup path, not just what `mk-analytics` uploads —
     both files scope Auto Backup/cloud backup/device-to-device transfer to exactly the D-312
     trial blob. Without citing this pair explicitly, the form's implicit claim would be that
     nothing else is backed up, when in fact an unscoped or `fullBackupContent`-only
     configuration would silently back up the entire project tree and the Room metadata index
     on Android 12+ — a D-312 violation and a Data Safety misstatement this task exists to
     prevent.
5. Write `T-AND-9101`: grep `mk-analytics`'s consent/upload code paths and confirm every
   Data Safety claim matches actual behavior (default OFF, no text/project/identifier/font
   file ever leaves the device — R-18.3).
6. Target countries and pricing tiers: mirror the iOS territory list and product ids
   (FDA-05: `net.binjamshid.makhtoot.premium` monthly/annual, `net.binjamshid.makhtoot
   .premium.lifetime`) as a starting point; flag any Play-specific territory requirement
   (e.g., Play's own trader-disclosure/tax-registration prompts) `[FOUNDER]`,
   `VERIFY-AT-SUBMISSION`, never asserted from memory.
7. Family Library ON/OFF (Play's analogue of FD-06): **flag as a `[FOUNDER]`-only,
   irreversible-per-product decision**, note the iOS precedent (FD-06 resolved OFF for all
   three products) as context, but do not decide it — this agent drafts the listing, the
   founder executes the toggle in Play Console.
8. **D-311 limitation check.** Play Billing gives no client-side signal distinguishing
   grace period from billing retry (spine §2 D-311, §14 out-of-scope); this is a named
   limitation in the master plan, not a feature to imply. Before finalizing, re-read every
   subscription/premium-related sentence drafted in this packet (listing copy, pricing-tier
   description, any renewal/billing-status language) and confirm none of it promises or
   implies iOS-equivalent state-specific subscription messaging — the Android banner is
   deliberately generic for both states, and the listing must not overclaim beyond that.

**Acceptance.**
- `./gradlew :app:connectedDebugAndroidTest` green (`DataSafetyDeclarationAuditTest`)
- Requirements covered: `R-18.1`–`R-18.7`, `R-20.1`; D-320, D-310 (Drive scope), D-312 (backup scope), FDA-01, FDA-05
- Tests: `T-AND-9101`, `T-AND-9102`
- Every listing/policy claim is either cited to a live Play source at submission time or explicitly marked `VERIFY-AT-SUBMISSION` in `PLAY_LISTING.md`/`DATA_SAFETY.md` — no asserted-from-memory policy fact
- Screenshot set covers phone + 7"/10" tablet + foldable at Play's current required dimensions (or the gap is named, not silently skipped)

**Impl log.** `android/docs/impl-log/BATCH-9.1.md`

---

### Batch 9 · Agent 9.2 — Signing, AAB, R8/ProGuard for native + reflection, baseline profile

**Depends on:** G8 · **Parallel-safe with:** every other Batch 9 agent

**Mission.** Play App Signing enrolment, upload key generation and storage, `signingConfigs`
from a keystore outside the repo, a release AAB covering the right ABI set (recommended
below, with rationale), R8/ProGuard rules for the JNI surface, kotlinx-serialization, Room,
and any reflection; `-keep` rules for every `external fun` class; baseline profile
generation for cold start and editor open; native debug symbols upload for crash
symbolication; `android:allowBackup`, `dataExtractionRules.xml` and `backup_rules.xml`
verified to cover only the D-312 trial blob (an unencrypted, HMAC-integrity-signed DataStore
blob — not Keystore-wrapped). This agent also takes over `android/app/build.gradle.kts` from
Agent 1.1 for the signing/AAB/R8 additions named in Owns below, per spine §17's cross-batch
ownership rule. Verify the release AAB passes the referral grep (D-321).

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `APP_STORE_CHECKLIST.md` §11A (~L833–901) | the iOS archive/upload mechanics this agent's `gradlew`/`bundletool` sibling mirrors in rigor (exact commands, exact pre-flight checklist) |
| `Scripts/referral-release-grep.sh` (74 LOC) | the Swift sibling this agent's Android referral-grep must match in method (grep the BUILT artifact, not source) |
| spine §2 D-301 (18 modules, version catalog), D-304 (native carve-out: harfbuzz/freetype/lcms2/hb-subset vendored under `android/mk-native/third_party/`), D-311 (Play Billing), D-312 (trial: unencrypted, HMAC-integrity-signed DataStore blob mirrored to Auto Backup — **not** Keystore-wrapped; a Keystore-wrapped blob is explicitly the wrong, corrected-away formulation, since a Keystore key is destroyed on uninstall and would leave zero reinstall survival), D-321 (referral debug-only source set) | the exact native/signing/backup surface this agent locks down |
| `android/mk-native/**` (Batch 1.2) | the JNI facade whose native method holder classes must survive R8 |
| `android/gradle/libs.versions.toml`, `android/build-logic/**` (Batch 1.1) | the scaffold this agent's release build config extends |
| `android/app/src/main/res/xml/dataExtractionRules.xml`, `backup_rules.xml` (Agent 1.1, spine §11) | the actual targetSdk-36 backup-scope files this agent's Task 7 audit verifies — `dataExtractionRules.xml` governs Android 12+ cloud backup/device-to-device transfer, `backup_rules.xml`'s `fullBackupContent` covers only Android 11 and below; both must already restrict to exactly the D-312 blob |

**Owns (creates or edits — no other agent may touch these).**
- `android/app/build.gradle.kts` — **cross-batch takeover, declared here per spine §17**: Agent
  1.1 creates and owns this file exclusively during Batches 2–8; this agent takes it over
  starting Batch 9, scoped specifically to signing/AAB/R8 additions (release `signingConfigs`,
  `buildTypes.release` — R8 minify + resource shrink, `ndk.debugSymbolLevel` — and ABI
  packaging config); this is not a violation of 1.1's exclusivity, which is itself scoped to
  Batches 2–8, not Batch 9
- `android/app/proguard-rules.pro` (new)
- `android/app/src/main/baselineProfiles/**` (new — Macrobenchmark-generated baseline profile)
- `Scripts/android/referral-release-grep.sh` (new — Android sibling of `referral-release-grep.sh`)
- `android/docs/SIGNING_AND_RELEASE.md` (new — keystore procedure, ABI decision + rationale, symbol-upload procedure)
- `android/docs/impl-log/BATCH-9.2.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`; any module's `src/main` production
source (this agent's job is build/signing/shrink configuration, not feature code); any
other Batch 9 agent's deliverable. **Never commit a keystore file, key alias password, or
Play API key to the repo** — `SIGNING_AND_RELEASE.md` documents the procedure and the
external (outside-repo, founder-controlled) storage location, never the secret itself.

**Port map.**
| Swift source | LOC | Android target | Notes / platform substitution |
|---|---|---|---|
| `APP_STORE_CHECKLIST.md` §11A `xcodebuild archive`/`-exportArchive` sequence | — | `android/docs/SIGNING_AND_RELEASE.md` `./gradlew bundleRelease` + `bundletool` sequence | Same rigor: exact commands, exact pre-flight list, exact "what a stale/misconfigured signing artifact looks like" warning box (iOS's provisioning-profile trap ~L835–867 has a direct Android analogue: an upload-key/app-signing-key mismatch after Play App Signing enrolment) |
| `Scripts/referral-release-grep.sh` (74 LOC) | 74 | `Scripts/android/referral-release-grep.sh` | Same method — grep the BUILT release artifact (unpacked AAB/APK contents: DEX strings via `bundletool`, resources), not source; same fail-fast contract (exit 0 clean / exit 1 leaked / exit 2 usage) |

**Tasks.**
1. **Play App Signing enrolment** (`[FOUNDER]`-gated: requires Play Console access per
   FDA-06): document the enrolment procedure and the upload-key vs. app-signing-key
   distinction; generate the upload keystore via `keytool`, store it outside the repo
   (document the exact external path convention, never the key itself).
2. **`signingConfigs`**: wire `android/app/build.gradle.kts`'s release signing config to
   read keystore path/passwords from environment variables or a local, gitignored
   `keystore.properties` — never hardcoded, never committed.
3. **ABI packaging decision**: recommend building a single Android App Bundle (`.aab`)
   covering `arm64-v8a` (primary — minSdk 29/Android 10, FDA-07, was released September
   2019, well after 64-bit ARM became the mainstream default; this is the ABI essentially
   every minSdk-29 device serves from), `armeabi-v7a` (32-bit-only compatibility) and
   `x86_64` (Chromebook/emulator/x86 tablet coverage), explicitly **excluding** `x86`
   (32-bit x86 — deprecated on Play since 2019, no realistic minSdk-29 target device needs
   it). **`armeabi-v7a`'s justification is weaker at minSdk 29 than it was under the earlier
   minSdk-26 draft of this decision, not stronger — say so plainly rather than carrying the
   old rationale forward unchanged.** A 32-bit-only chipset that can also run Android 10
   is a materially smaller and different population than "any 2017-onward device": most
   devices that shipped Android 10 shipped 64-bit-capable silicon, and the surviving
   32-bit-only cohort at this minSdk is concentrated in low-cost/Android-Go-class emerging-
   market hardware rather than the broad "still meaningfully present" install base the
   minSdk-26 framing implied. The recommendation is still to **keep** `armeabi-v7a` in the
   ABI list — dropping it costs real reach in exactly the price-sensitive markets Play's own
   device catalog would show still run it, and Dynamic Delivery makes carrying it near-free
   (see below) — but the actual current share is `VERIFY-AT-SUBMISSION` against Play
   Console's Android vitals/device-catalog data at build time, not asserted from memory
   here or in the earlier minSdk-26 draft. Rationale: Play's own Dynamic
   Delivery already generates per-device-optimized split APKs from a single `.aab` at
   serving time, so this is an `ndk.abiFilters` inclusion list, not a manual multi-APK
   build — matching D-300/D-301's Kotlin+NDK toolchain without hand-rolled ABI splitting.
4. **R8/ProGuard rules** (`proguard-rules.pro`): `-keep` every class holding an
   `external fun` (the JNI method table — a stripped/renamed method breaks the native
   binding silently, the single most dangerous minification failure for this app given
   D-304's HarfBuzz/FreeType/lcms2 JNI facade); `-keepclassmembers` for every
   `kotlinx.serialization`-annotated class (scene/manifest codec, D-308); `-keep` for
   every Room entity/DAO (metadata index, D-308); audit for any reflection use (Play
   Billing callback classes, DataStore) and add matching keep rules.
5. **Baseline profile**: generate via Macrobenchmark's `BaselineProfileRule` covering
   cold start (browser) and editor open (mirrors 8.4's `T-AND-8408` launch budget and
   `T-AND-8404` open-project budget); measure the before/after cold-start delta
   (`T-AND-9203`).
6. **Native debug symbols**: set `ndk.debugSymbolLevel = FULL` for the release build type
   and document the Play Console native-symbol-upload step; verify against a deliberately
   forced native crash that Play's crash report symbolicates correctly (`T-AND-9204`).
7. **Backup-scope audit**: confirm `android:allowBackup`, `dataExtractionRules.xml`
   (Android 12+ cloud backup/device-to-device transfer) and `backup_rules.xml`'s
   `fullBackupContent` (Android 11 and below) all scope to exactly the D-312 trial blob —
   the unencrypted, HMAC-integrity-signed DataStore blob, never a Keystore-wrapped one — and
   nothing else: no scene data, no asset cache, no Room metadata index leaks into Auto
   Backup on any supported Android version.
8. **Referral grep**: port `Scripts/referral-release-grep.sh` to
   `Scripts/android/referral-release-grep.sh`, run it against the built release AAB
   (unpacked via `bundletool`), confirm clean (D-321).

**Acceptance.**
- `./gradlew bundleRelease` succeeds; `bundletool build-apks` from the resulting `.aab` installs and launches on `DEV-AND-PRO` and `DEV-AND-MID`
- `Scripts/android/referral-release-grep.sh build/outputs/bundle/release/app-release.aab` exits 0
- Requirements covered: `R-22.17` (no dynamic code, TLS-only network); D-311, D-312, D-321
- Tests: `T-AND-9201`…`T-AND-9204`
- No JNI/serialization/Room class stripped or renamed by R8 (verified by running the full instrumented suite from Batch 8 against the minified release build type, not just debug)
- Baseline profile present and measurably improves cold start; native crash symbolicates in Play Console

**Impl log.** `android/docs/impl-log/BATCH-9.2.md`

---

### Batch 9 · Agent 9.3 — iOS-side zipped-`.makhtoot` import/export (D-309)

**Depends on:** G8 · **Parallel-safe with:** every other Batch 9 agent
(no shared files with 9.1/9.2/9.4/9.5)

**Mission.** The only iOS engineering agent outside Batch 0. Per D-309/FDA-08: iOS gains
import and export of the zip form of `.makhtoot`, with path-traversal-safe extraction, the
same `PackageImportValidator` checks reused (not reimplemented), and a shared
`schemaVersion` contract with the Android side. Owns files under
`MakhtootKit/Sources/MKPersistence/` and its tests, **plus** the app-level UI wiring that
makes the zip form reachable by an actual user: the open-in path in `RootShellView.swift`,
an export-as-zip action alongside the existing `ExportFormatSheet` export/share actions in
`EditorScene.swift`/`EditorViewModel.swift`, and the document-type/UTI declaration in
`Info.plist` if the zip form needs its own. (Widened during review — see the Batch 9
appendix note below; this was a scoping gap in the original spine, not a deliberate
deferral.) Round-trip test: a project created on Android opens on iOS and vice versa, with
the scene identical, verified both at the codec level and end-to-end through the real
Files-app/export-sheet UI — not the codec alone.

**No third-party dependency.** R-22.12/D-101 forbid third-party runtime dependencies on
iOS exactly as they always have — this agent does **not** add a zip library (e.g.
ZIPFoundation). It builds a minimal, in-house STORED/DEFLATE zip codec against the system
`Compression`/`libz` frameworks (already linked on Darwin), matching this codebase's own
precedent of in-house format writers (the PDF writer — split across Agents 5.7a/5.7b — and
the SVG serializer) rather than a new dependency — and matching D-309's own
STORED/DEFLATE-only scope, which needs nothing more exotic than what `libz`'s
deflate/inflate already provides.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKPersistence/PackageImportValidator.swift` (120 LOC) | the exact caps + allowlist (200 MB total, 5,000 files, `{manifest.json, scene.json, thumbnail.png, journal.mkj, assets, backups}` top-level allowlist) this agent's zip-entry validation must reuse via `DocumentPackage.validateForImport`, not reimplement |
| `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift` (146 LOC) | the exact package layout (`manifestURL`/`sceneURL`/`journalURL`/`assetsDirURL`/`backupsDirURL`/`thumbnailURL`) and `schemaVersion` field this zip codec must preserve byte-for-byte inside the archive |
| `MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift` (292 LOC) | the document lifecycle this agent's new zip entry points must not disturb |
| `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift` (435 LOC) | the existing `importExternalPackage(at:)` conformer this agent's `RootShellView.swift` wiring calls, unmodified, once a zip has been extracted — read-only, this agent does NOT own or edit this file (see Never touch) |
| `Makhtoot/AppShell/Navigation/RootShellView.swift` (420 LOC) | the `.onOpenURL` → `openExternalPackage(at:)` open-in path this agent extends (additively) to detect and extract a zip-form `.makhtoot` before delegating to the unchanged `importExternalPackage(at:)` call |
| `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` (`ExportFormatOption`/`ExportFormatSheet`, ~L808–1018), `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (`exportForSharing`/`exportPNGForSharing`-style methods, ~L850–950) | the real, existing export/share action pattern this agent's new export-as-zip action follows (additively) — the concrete host files for "wherever the existing export/share actions live" |
| `Makhtoot/Config/Info.plist` (`UTExportedTypeDeclarations` ~L68–87, `CFBundleDocumentTypes` ~L88–100) | the current directory-form-only UTI declaration this agent extends (additively) if the zip form needs its own conforming `public.zip-archive` type, per Task 5's investigation |
| `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift` (122 LOC) | the existing iOS UI test covering directory-form open-in-place; this agent extends it (does not replace it) to cover the zip form |
| spine §2 D-308, D-309 | the frozen package layout and the zip-interchange contract this agent implements on the iOS side |
| `android/fixtures/**` zip test fixtures (from the Android `:mk-persistence` zip work, Batch 3.4/3.6) | the cross-platform round-trip fixtures this agent's tests consume |

**Owns (creates or edits — no other agent may touch these).**
- `MakhtootKit/Sources/MKPersistence/ZipPackageCodec.swift` (new — in-house STORED/DEFLATE reader+writer over `Compression`/`libz`)
- `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift` — additive only: `exportAsZip(to:)` and `static importFromZip(at:extractingTo:limits:) throws -> DocumentPackage` methods appended, no existing method signature changed
- `MakhtootKit/Tests/MKPersistenceTests/ZipPackageCodecTests.swift` (new)
- `MakhtootKit/Tests/MKPersistenceTests/ZipRoundTripAndroidFixtureTests.swift` (new — consumes the Android-exported zip fixtures)
- `MakhtootKit/CONTRACTS.md` — new section documenting the zip codec's public API
- `FILE_MAP.md` — new rows for the new/extended files
- `APP_STORE_CHECKLIST.md` — only if the document-type declaration actually changes (see Tasks step 5); otherwise leave untouched
- `Makhtoot/AppShell/Navigation/RootShellView.swift` — additive only: extend
  `openExternalPackage(at:)` to detect a zip-form `.makhtoot` (by extension/magic number),
  extract it via the new `DocumentPackage.importFromZip(at:extractingTo:limits:)`, then hand
  the extracted directory to the existing, unmodified
  `container.projectLibrary.importExternalPackage(at:)` call — no change to
  `MKPersistenceProjectLibrary.swift` or `ProjectLibraryProviding` needed or permitted
- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` — additive only: a new
  `exportProjectAsZipForSharing()`-style method paralleling the existing
  `exportForSharing()`/`exportPNGForSharing()` methods, built on this agent's own
  `DocumentPackage(rootURL: packageURL).exportAsZip(to:)`
- `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` — additive only: a new
  `ExportFormatOption` case and `ExportFormatSheet` row wiring the new export-as-zip action
  into `perform(_:)`, alongside the existing jpeg/png/pdfRaster/svg/pdfVector cases
- `Makhtoot/Config/Info.plist` — additive only, and only if Task 5's investigation finds the
  zip form needs its own UTI: a new `UTExportedTypeDeclarations` entry conforming to both
  `public.zip-archive` and `net.binjamshid.makhtoot.project`, plus a matching
  `CFBundleDocumentTypes` entry; the existing directory-form declaration is left unchanged
- `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift` — extended, not replaced: a new
  test method covering the zip-form open-in-place path alongside the existing
  `testOpeningAMakhtootPackageFromFilesImportsItInPlace`
- `android/docs/impl-log/BATCH-9.3.md`

**Never touch.** Any file outside the paths named in Owns above. Specifically still
off-limits: `Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift`,
`ProjectLibraryProviding.swift`, `Makhtoot/AppShell/Scenes/Browser/**`,
`Makhtoot/AppShell/AppContainer.swift`, and every other file under `MakhtootKit/**` or
`Makhtoot/**` not explicitly listed in Owns. The three app-level edits above (open-in
wiring, export-as-zip action, UTI declaration) closed a scoping gap found during review
(spine §5 originally scoped this agent to "files under `MakhtootKit/Sources/MKPersistence/`
and its tests only," leaving no owner anywhere for the UI wiring that makes the codec
reachable by a user) — they are done here, in full, not deferred as a follow-on.

**Port map.**
| Android source (the side this mirrors) | Kotlin target | Swift target | Notes |
|---|---|---|---|
| `mk-persistence`'s zip reader/writer (Batch 3.4/3.6, built on `java.util.zip`, no extra JVM dependency) | `mk-persistence/src/main/kotlin/**/ZipPackageCodec.kt` | `MakhtootKit/Sources/MKPersistence/ZipPackageCodec.swift` | Same wire format (STORED/DEFLATE zip, same internal package layout) from the opposite platform; `java.util.zip` (JVM built-in) ↔ `Compression`/`libz` (Darwin built-in) — both are "no third-party dependency" on their own platform |
| `PackageImportValidator.swift` (120 LOC, existing) | (Android's own import-limits equivalent, Batch 3.4) | `ZipPackageCodec.swift` calls `DocumentPackage.validateForImport` on the EXTRACTED directory before treating it as a package | Reuse, not reimplementation — the validator was already written platform-agnostically at the `DocumentPackage` level |
| Android's SAF `ACTION_OPEN_DOCUMENT` zip-import UI + export-as-zip action (Batch 7/8) | (already ported) | `RootShellView.swift` open-in wiring, `EditorScene.swift`/`EditorViewModel.swift` export-as-zip action | The iOS-side UI wiring this agent adds is the direct analogue of Android's own zip import/export UI, closing the gap `MakhtootFileOpenInPlaceUITests.swift`'s Batch-8 port-map entry already anticipated ("also covers D-309 zip import specifically, which the iOS original could not [yet]") |

**Tasks.**
1. Implement `ZipPackageCodec.swift`: a minimal in-house zip writer (local file headers +
   central directory + end-of-central-directory record, STORED for already-compressed
   assets like `thumbnail.png`, DEFLATE via `Compression`'s `COMPRESSION_ZLIB` filter for
   `manifest.json`/`scene.json`/`journal.mkj`) and reader (parses the central directory,
   never trusts local-header sizes alone — matching standard zip-bomb/truncation defenses).
2. Path-traversal-safe extraction: reject any entry name containing `..` path components,
   an absolute path, a symlink entry (`external file attributes` symlink bit), or a name
   escaping the target extraction root after normalization — extract to a temporary
   directory, THEN call `DocumentPackage.validateForImport(at:limits:)` on the extracted
   directory before it is treated as a real package, reusing the exact same 200 MB/5,000-
   file/allowlist caps zip form gets no special exemption from directory form.
3. Add `DocumentPackage.exportAsZip(to:)`: walks the existing directory-form package
   (`manifestURL`/`sceneURL`/`journalURL`/`assetsDirURL`/`backupsDirURL`/`thumbnailURL`)
   and writes it into a single zip archive at the target URL, preserving `schemaVersion`
   inside `manifest.json`/`scene.json` unchanged.
4. Add `DocumentPackage.importFromZip(at:extractingTo:limits:)`: extraction + validation +
   construction of a `DocumentPackage` value over the extracted directory, ready for the
   existing `readManifest()`/`readScene()` calls to work unmodified.
5. **`schemaVersion` lockstep**: confirm (with a test, `T-AND-9304`) that a zip written by
   the current schema version opens correctly on the other platform's current schema
   version, and that a genuinely newer `schemaVersion` still triggers the existing R-21.43
   read-only forward-compat path rather than a destructive rewrite — the zip form changes
   nothing about that contract. If this reveals the zip form needs its own UTI
   (`UTExportedTypeDeclarations` conforming to both `public.zip-archive` and
   `net.binjamshid.makhtoot.project`), implement that declaration in `Info.plist` (Task 9
   below) and document it in `CONTRACTS.md`/`FILE_MAP.md`/`APP_STORE_CHECKLIST.md`.
6. Round-trip tests: `T-AND-9301` (Android-created zip fixture opens on iOS, scene
   identical field-for-field) and `T-AND-9302` (iOS-created zip opens on the Android
   fixture consumer — produced here, verified by the Android side's own test suite,
   already built at Batch 3.4/3.6/9.4-adjacent work).
7. `T-AND-9303`: a deliberately malicious fixture (entries containing `../../../etc/x`,
   an absolute-path entry, a symlink entry) is rejected before any file lands outside the
   extraction root.
8. **Open-in wiring**: extend `RootShellView.openExternalPackage(at:)` to detect a zip-form
   `.makhtoot` (extension or magic-number sniff), extract it to a temporary directory via
   `DocumentPackage.importFromZip(at:extractingTo:limits:)`, then call the existing,
   unmodified `container.projectLibrary.importExternalPackage(at:)` on the extracted
   directory — the directory-form path through `MKPersistenceProjectLibrary.swift` stays
   untouched and is reused as-is.
9. **Export-as-zip action**: add an `exportProjectAsZipForSharing()`-style method to
   `EditorViewModel.swift` (parallel to `exportForSharing()`/`exportPNGForSharing()`) that
   calls `DocumentPackage(rootURL: packageURL).exportAsZip(to:)` and returns a URL for
   `UIActivityViewController`; wire it into `EditorScene.swift`'s `ExportFormatOption`/
   `ExportFormatSheet`/`perform(_:)` as a new option alongside jpeg/png/pdfRaster/svg/
   pdfVector. If Task 5 determined the zip form needs its own UTI, add the corresponding
   `UTExportedTypeDeclarations`/`CFBundleDocumentTypes` entry to `Info.plist`, additive only
   — the existing directory-form declaration is left unchanged.
10. **Extend the existing UI test**: add a new test method to
    `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift` covering the zip-form open-in-
    place path (same Files.app-driven pattern as the existing
    `testOpeningAMakhtootPackageFromFilesImportsItInPlace`, with a zip-form fixture), and
    verify the new export-as-zip action end to end (export from the editor, confirm the
    produced file opens back via the same open-in-place path).

**Acceptance.**
- `cd MakhtootKit && swift test --no-parallel --filter MKPersistenceTests` green, including the two new test files
- Requirements covered: `R-21.43` (schema forward-compat, zip form included), `R-22.17` (no dynamic code — the zip codec is data-only, executes nothing)
- Tests: `T-AND-9301`…`T-AND-9304`
- Zero new third-party dependencies added (`Package.swift`/project dependencies unchanged) — confirmed by diff
- `CONTRACTS.md` documents the zip codec's public API and, if added, the new UTI declaration
- A user can export a project as a zipped `.makhtoot` from the iOS editor's export sheet and
  open an Android-produced zip from the Files app end to end — not merely that the codec
  exists in `MKPersistence` — verified by the extended
  `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift`
- No existing method signature in `MKPersistenceProjectLibrary.swift`, `DocumentPackage.swift`, or `ProjectLibraryProviding` is changed — only additive methods/cases throughout

**Impl log.** `android/docs/impl-log/BATCH-9.3.md`

---

### Batch 9 · Agent 9.4 — `ANDROID_APP_STORE_CHECKLIST.md` and release runbook

**Depends on:** G8, and reads 9.1/9.2's outputs where available ·
**Parallel-safe with:** every other Batch 9 agent (may finalize cross-references to 9.1/9.2
after they land — no file overlap)

**Mission.** The Android sibling of `APP_STORE_CHECKLIST.md`. Pre-submission checklist, the
internal → closed → production track ladder, staged rollout percentages, the rollback/halt
procedure, review-risk memo (in-app purchase policy, the direct-HTTPS font download under
D-121 — fonts are data not code, the Drive scope justification, and the Arabic-only
listing), plus a release runbook with the exact `gradlew` and `bundletool` commands.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `APP_STORE_CHECKLIST.md` (whole document, 1,111 lines) | the structure this file mirrors: numbered `§section.item` checkboxes, `[AGENT]`/`[FOUNDER]` tags, a consolidated `VERIFY-AT-SUBMISSION` list at the end |
| `APP_STORE_CHECKLIST.md` §6 (~L438–487, downloadable premium fonts) | the exact "data not code" compliance argument this file's Android review-risk memo restates for Play's own downloaded-executable-code policy |
| `APP_STORE_CHECKLIST.md` §7 (~L489–564, referral risk memo + dormancy protocol) | the pattern this file's own referral risk memo mirrors for D-321's Android sibling |
| `android/docs/PLAY_LISTING.md`, `android/docs/DATA_SAFETY.md` (9.1), `android/docs/SIGNING_AND_RELEASE.md` (9.2) | source material this checklist assembles and cross-references, not duplicates |
| spine §2 D-321, D-322 | the referral compile-time exclusion and the AAB + Play App Signing distribution decision this checklist enforces |

**Owns (creates or edits — no other agent may touch these).**
- `android/ANDROID_APP_STORE_CHECKLIST.md` (new)
- `android/docs/RELEASE_RUNBOOK.md` (new)
- `:app/src/androidTest/kotlin/**/StagedRolloutHaltDrillTest.kt` (new, or a documented manual drill if Play Console API access makes an automated test impractical — state which, do not silently skip)
- `android/docs/impl-log/BATCH-9.4.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`, `APP_STORE_CHECKLIST.md`; `android/docs/PLAY_LISTING.md`, `android/docs/DATA_SAFETY.md`, `android/docs/SIGNING_AND_RELEASE.md` (9.1/9.2 own these — this agent reads and cross-references, never edits); `android/PARITY_REPORT.md` (9.5).

**Port map.**
| Swift source | LOC | Android target | Notes / platform substitution |
|---|---|---|---|
| `APP_STORE_CHECKLIST.md` §1–15 (whole document structure) | 1,111 | `android/ANDROID_APP_STORE_CHECKLIST.md` | Section-for-section sibling: prerequisites → app record → IAP → Data Safety → downloadable fonts → referral → territories → export compliance → metadata → build/track/submission mechanics → rejection contingency → post-approval → traceability → `VERIFY-AT-SUBMISSION` consolidated list |
| `APP_STORE_CHECKLIST.md` §11A (`xcodebuild archive`/`-exportArchive`, ~L833–901) | — | `android/docs/RELEASE_RUNBOOK.md` (`./gradlew bundleRelease`, `bundletool build-apks`/`validate`, Play Console track-promotion commands) | Same rigor, same "read the entitlements/provisioning trap before touching this" warning-box convention, ported to Android's own signing pitfalls (upload-key vs. app-signing-key confusion after Play App Signing enrolment) |

**Tasks.**
1. Write the pre-submission checklist mirroring `APP_STORE_CHECKLIST.md`'s section
   structure: account/agreements (Play Console enrolment, merchant account per FDA-06,
   `[FOUNDER]`-gated), app record creation, IAP setup (subscription base plans
   `monthly`/`annual` + lifetime INAPP per FDA-05, cross-referencing 9.1's Data Safety
   work and 9.2's signing work rather than restating them).
2. Track ladder: internal testing → closed testing (alpha/beta) → production, with the
   entry/exit criteria for each rung (internal: sanity pass on `DEV-AND-PRO`/`DEV-AND-MID`;
   closed: a named cohort size and duration; production: staged rollout).
3. Staged rollout percentages: recommend a concrete ladder (e.g., 5% → 20% → 50% → 100%,
   with a minimum dwell time and a crash-rate/ANR-rate halt threshold at each rung) and the
   exact Play Console/`gradlew`/API command to advance or halt at each step.
4. Rollback/halt procedure: the exact steps to halt a staged rollout, and — because Play
   (unlike a simple pull) cannot force-downgrade already-updated devices — the exact
   mitigation (a fast-follow patch release) this runbook commits to instead of promising an
   impossible instant rollback; document this honestly rather than overclaiming.
5. Review-risk memo, mirroring `APP_STORE_CHECKLIST.md` §6/§7's structure:
   - **In-app purchase policy**: Play Billing is the sole payment path for premium
     entitlement (D-311); no external payment link, matching Play's own IAP policy intent
     — cite the current policy section or mark `VERIFY-AT-SUBMISSION`.
   - **Direct-HTTPS font download (D-121)**: restate the iOS "data, not code" compliance
     position (§6.01) in Play's own terms — downloaded `.ttf`/`.otf`/`.ttc` files are
     static data rendered through the same already-reviewed HarfBuzz/FreeType pipeline,
     nothing downloaded is executed or changes app behavior/features beyond making
     additional typefaces available; cite Play's policy on downloading executable
     code/updating outside Play's own mechanism, or mark `VERIFY-AT-SUBMISSION` — never
     assert the current wording from memory.
   - **Drive scope justification**: `appDataFolder` is the narrowest available Drive
     scope (no access to the user's visible Drive files), used solely for the user's own
     project sync (D-310) — restate 9.1's Data Safety justification here for reviewer
     context.
   - **Arabic-only listing**: state the deliberate Arabic-only positioning (CLAUDE.md) as
     a product decision, not a completeness gap, matching how `APP_STORE_CHECKLIST.md`
     frames the same fact for iOS.
6. Assemble the consolidated `VERIFY-AT-SUBMISSION` list (mirroring §15's `V-01`…`V-13`
   table) from every `VERIFY-AT-SUBMISSION` tag raised across 9.1/9.2/9.4 itself, numbered
   `AND-V-01`…, each with what to verify and where.
7. Write `android/docs/RELEASE_RUNBOOK.md`: exact command sequence from a clean checkout
   to an uploaded internal-track build (`./gradlew clean bundleRelease`, checksum/signature
   verification, `bundletool` validation, Play Console API or manual upload step, track
   promotion commands), mirroring the precision of `APP_STORE_CHECKLIST.md` §11A.
8. Staged-rollout halt/rollback drill: execute (or, if Play Console API access is not
   available to this agent, document as a precise `[FOUNDER]`-executed manual drill — state
   which, honestly) a real halt on an internal-track release, confirm it is reversible.

**Acceptance.**
- Requirements covered: `R-22.16` (distribution automation where technically possible), `R-14.x` gating/IAP-policy alignment via D-311, D-321, D-322
- Tests: `T-AND-9401`
- Every policy claim in `ANDROID_APP_STORE_CHECKLIST.md` is cited or listed in its own `AND-V-…` `VERIFY-AT-SUBMISSION` table — zero asserted-from-memory policy facts
- `RELEASE_RUNBOOK.md`'s command sequence has been executed at least once against a real internal-track upload (evidence in the impl log)
- Rollback/halt procedure stated honestly (fast-follow patch, not a false "instant rollback" claim)

**Impl log.** `android/docs/impl-log/BATCH-9.4.md`

---

### Batch 9 · Agent 9.5 — Final parity report: 319 R-ids, zero stubs, docs updated

**Depends on:** G8, and reads every other Batch 9 agent's output ·
**Parallel-safe with:** every other Batch 9 agent for its own drafting, but its final pass
over `android/PARITY_MATRIX.md` should run last since it aggregates 9.1–9.4's evidence too

**Mission.** `android/PARITY_REPORT.md`: all 319 `R-…` ids ✅ with implementing file and
proving test; stub count 0 with the `stub-count.sh` output pasted; the shaping-delta
register summarized by family; performance results against every D-115 budget; the honest
limitations list (Android↔Android sync only, FDA-03 CMYK fidelity, D-312 trial reinstall
survival, no soft-proofing — same as iOS). Update `PARITY_MATRIX.md`, `FOUNDATION.md`,
`CLAUDE.md` and `PROJECT_DESCRIPTION.md` to reflect a shipped Android app. State plainly
whether the no-"coming soon" contract was met.

This is the **second named exception** (alongside Batch 0 · Agent 0.5) to spine §4 ground
rule 9's "never touch anything outside `android/`" — spine §5 explicitly assigns this agent
the closing update to the four project-wide decision documents, superseding 0.5's mid-port
amendment now that the port has actually shipped.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `android/PARITY_MATRIX.md` (8.7's close-out, further updated by 9.1–9.4's own work) | the 319-row ledger this report summarizes and finalizes |
| `Scripts/android/stub-count.sh`, `Scripts/android/check-no-stubs.sh` output | the literal evidence for "stub count 0" — pasted, not asserted |
| `android/SHAPING_DELTAS.md` (8.2) | source for the by-family delta summary |
| `android/docs/PERF_REPORT.md` (8.4) | source for the D-115 budget results |
| `android/docs/A11Y_REPORT.md` (8.5), `android/docs/WIRING_AUDIT.md` (8.1), `android/docs/RENDER_EXPORT_PARITY.md` (8.3) | supporting evidence for the report's own claims |
| spine §1 FDA-01 (Android↔Android-only sync), §2 D-313/D-315/FDA-03 (CMYK fidelity), D-312 (trial reinstall weaker than Keychain), D-315 (no soft-proofing) | the exact honest-limitations items to carry forward, matching the iOS TEST_MATRIX §22 Gap Statement's own tone |
| `CLAUDE.md`, `FOUNDATION.md` §1 (D-100), `PROJECT_DESCRIPTION.md` §Overview (~L24 "no Android port and none is planned") | the four documents this agent updates to reflect a shipped Android app |

**Owns (creates or edits — no other agent may touch these).**
- `android/PARITY_REPORT.md` (new)
- `android/PARITY_MATRIX.md` (final aggregation pass — incorporates 9.1–9.4's own closures)
- `FOUNDATION.md` — status-language update only (D-100/D-300 cross-reference now reads "shipped," not "planned/in progress"); no `D-1xx` locked decision content changed
- `CLAUDE.md` — "Platform and scope" section updated to state Android now ships alongside iPhone/iPad, cross-referencing this port's own `D-3xx` block; "Never" list unchanged in substance (still no unauthorized backend/accounts/network dependency, still no further script localization)
- `PROJECT_DESCRIPTION.md` — the "There is no Android port and none is planned for v1" line (~L24) and any other now-stale platform-scope prose corrected
- `android/docs/impl-log/BATCH-9.5.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**` (actual iOS source/tests — this agent
edits project-wide documentation and may update the status wording of locked
`D-1xx` decisions); `DECISIONS_LOG.md` (the existing `D-3xx` block belongs to work item 0.5);
`PRD.md`, `TEST_MATRIX.md`,
`APP_STORE_CHECKLIST.md` (iOS-specific, untouched by the Android port); every other Batch 9
agent's own file set (9.1/9.2/9.3/9.4).

**Port map.**
| Swift/doc source | LOC | Android target | Notes / platform substitution |
|---|---|---|---|
| `TEST_MATRIX.md` §22 (Gap statement — deliberately untested in v1, ~L974) | — | `android/PARITY_REPORT.md`'s honest-limitations section | Same tone and same kind of claim (named, bounded, not hidden) applied to the Android-specific limitations: Drive sync (Agent 6.3a transport / 6.3b policy port) is Android↔Android only (FDA-01, no cross-platform sync — an iOS device and an Android device never see each other's projects), FDA-03's synthetic CMYK profile is lower-fidelity than a licensed one exactly as D-117 documents for iOS, D-312's trial persistence is weaker than Keychain when Auto Backup is off, and there is no on-screen soft-proofing, matching D-117/D-315 on both platforms |
| `CLAUDE.md` "Platform and scope" (~L20) | — | `CLAUDE.md` (this agent's own edit) | "iPhone and iPad only. No Android port, and none is planned for v1." → corrected to state Android ships, cross-referencing `D-300`, while keeping "Arabic-only at launch" and "No backend" substance intact for both platforms |

**Tasks.**
1. Run `Scripts/android/stub-count.sh` and `Scripts/android/check-no-stubs.sh`; paste their
   literal output into `android/PARITY_REPORT.md` — the report's stub-count claim is this
   output, not a restated number.
2. Aggregate `android/PARITY_MATRIX.md`: confirm all 319 `R-…` ids are ✅ with an
   implementing file and a proving test; if 9.1–9.4's own work closed any residual matrix
   gap (e.g., a Play-policy-driven behavior change), fold that update in here as the final
   pass. Any id still open is named with reason and owner — the report states plainly
   whether this actually reached zero.
3. Summarize `android/SHAPING_DELTAS.md` by family: how many families shipped clean, how
   many shipped with N registered deltas, how many were held.
4. Summarize `android/docs/PERF_REPORT.md` against every D-115 budget (nine hard-gate
   numbers per T-PRF-1/2/3/5/6/7/9/10/13's D-218 set), both named devices.
5. Write the honest limitations list, matching the iOS TEST_MATRIX §22 Gap Statement's
   tone: Android↔Android sync only (FDA-01) — an iOS device and an Android device never
   see each other's synced projects (only zip-file interchange via D-309 crosses
   platforms, not live sync); FDA-03 CMYK fidelity (synthetic generic profile, not a
   licensed one, exactly as documented for iOS's own Apple Generic CMYK fallback); D-312
   trial reinstall survival is weaker than iOS Keychain when Android Auto Backup is
   disabled by the user; no on-screen soft-proofing (same as iOS, D-315).
6. State plainly: was the "zero deferred features, no coming soon" contract from spine §0
   met? Yes/no, with the stub count and matrix result as the evidence, not assertion.
7. Update `FOUNDATION.md`, `CLAUDE.md`, `PROJECT_DESCRIPTION.md`: change platform-scope
   language from "iPhone and iPad only, no Android port planned" to "iPhone, iPad, and
   Android," cross-referencing the existing `D-3xx` block from work item 0.5 — status
   language only, no re-litigation of any locked decision's substance.

**Acceptance.**
- Requirements covered: all 319 `R-…` ids (final aggregation, not new coverage)
- Tests: `T-AND-9501` (full-suite regression gate — every `T-AND-1…9` id plus every ported `T-…` id green in one aggregate run)
- `android/PARITY_REPORT.md` pastes literal `stub-count.sh`/`check-no-stubs.sh` output, not a restated claim
- `FOUNDATION.md`, `CLAUDE.md`, `PROJECT_DESCRIPTION.md` no longer say "no Android port" anywhere
- The report states plainly, in one unambiguous sentence, whether the no-"coming soon" contract was met

**Impl log.** `android/docs/impl-log/BATCH-9.5.md`

---

## Appendix — file-ownership matrix (collision proof)

One row per owned path prefix, one column per owning agent. Every path prefix below is
touched by exactly one Batch 9 agent.

| Path prefix | Owning agent |
|---|---|
| `android/docs/PLAY_LISTING.md` | 9.1 |
| `android/docs/DATA_SAFETY.md` | 9.1 |
| `android/assets/play/**` | 9.1 |
| `:app/src/androidTest/kotlin/**/DataSafetyDeclarationAuditTest.kt` | 9.1 |
| `android/docs/impl-log/BATCH-9.1.md` | 9.1 |
| `android/app/build.gradle.kts` | 9.2 |
| `android/app/proguard-rules.pro` | 9.2 |
| `android/app/src/main/baselineProfiles/**` | 9.2 |
| `Scripts/android/referral-release-grep.sh` | 9.2 |
| `android/docs/SIGNING_AND_RELEASE.md` | 9.2 |
| `android/docs/impl-log/BATCH-9.2.md` | 9.2 |
| `MakhtootKit/Sources/MKPersistence/ZipPackageCodec.swift` | 9.3 |
| `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift` (additive zip methods only) | 9.3 |
| `MakhtootKit/Tests/MKPersistenceTests/ZipPackageCodecTests.swift` | 9.3 |
| `MakhtootKit/Tests/MKPersistenceTests/ZipRoundTripAndroidFixtureTests.swift` | 9.3 |
| `MakhtootKit/CONTRACTS.md` (zip codec section only) | 9.3 |
| `FILE_MAP.md` (new rows only) | 9.3 |
| `APP_STORE_CHECKLIST.md` (only if doc-type declaration changes, else untouched) | 9.3 |
| `Makhtoot/AppShell/Navigation/RootShellView.swift` (additive: zip-form detection in `openExternalPackage(at:)` only) | 9.3 |
| `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` (additive: new export-as-zip method only) | 9.3 |
| `Makhtoot/AppShell/Scenes/Editor/EditorScene.swift` (additive: new `ExportFormatOption` case/row only) | 9.3 |
| `Makhtoot/Config/Info.plist` (additive: new zip-form UTI entry only, if needed) | 9.3 |
| `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift` (extended: new zip-form test method only) | 9.3 |
| `android/docs/impl-log/BATCH-9.3.md` | 9.3 |
| `android/ANDROID_APP_STORE_CHECKLIST.md` | 9.4 |
| `android/docs/RELEASE_RUNBOOK.md` | 9.4 |
| `:app/src/androidTest/kotlin/**/StagedRolloutHaltDrillTest.kt` | 9.4 |
| `android/docs/impl-log/BATCH-9.4.md` | 9.4 |
| `android/PARITY_REPORT.md` | 9.5 |
| `android/PARITY_MATRIX.md` (final aggregation pass) | 9.5 |
| `FOUNDATION.md` (status-language only) | 9.5 |
| `CLAUDE.md` (platform-and-scope section only) | 9.5 |
| `PROJECT_DESCRIPTION.md` (platform-scope prose only) | 9.5 |
| `android/docs/impl-log/BATCH-9.5.md` | 9.5 |

No file has two writers in this batch. `android/PARITY_MATRIX.md` is written by both 8.7
(Batch 8's close-out pass) and 9.5 (Batch 9's final aggregation pass) — never in the same
batch, so this is not a same-batch collision; 9.5's pass strictly follows and folds in
8.7's, per its own Depends-on note. `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift`
is edited by 9.3 only in this batch (additive methods, no existing signature touched) —
no other Batch 9 agent, and no Batch 8 agent, owns this path. The same check was made for
9.3's four newly widened `Makhtoot/**` paths (`RootShellView.swift`, `EditorViewModel.swift`,
`EditorScene.swift`, `Info.plist`) and for `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift`:
every Batch 8 and Batch 9 reference to these files elsewhere in the spine (e.g.
`RootShellView.swift`/`MKPersistenceProjectLibrary.swift` in Batch 8's own composition-root
audit port map, `MakhtootFileOpenInPlaceUITests.swift` in Batch 8.6's port map) is read-only
oracle material for an Android port, never an edit — no collision.

> **Writer note (found and closed during review):** spine §5's frozen agent list originally
> scoped 9.3 to "files under `MakhtootKit/Sources/MKPersistence/` and its tests only." That
> left the app-level UI wiring for zip import/export — the `RootShellView.swift` open-in
> path, an export-as-zip action, and any `Info.plist` UTI addition — with no owning agent
> anywhere in the plan: a scoping error in the shared spine, not a deliberate deferral. It
> was found during review and closed by widening 9.3's owned-file set (see Owns above)
> rather than adding a 6th Batch 9 agent, keeping Batch 9 at 5 agents. (At the time this
> note was first written the plan's total was tallied at 59 agents, before a separate
> correction pass split seven agents elsewhere in the plan — 3.1a/b, 5.2a/b, 5.4a/b, 5.5a/b,
> 5.7a/b, 6.3a/b, 7.3a/b — into 66; that split is unrelated to 9.3 and did not touch Batch 9,
> so Batch 9 is still 5 agents, but the plan's current total is **66**, not 59.) 9.3's title
> is unchanged; only its file scope grew.
