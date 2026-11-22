# WS-15 — Distribution (archive, TestFlight, App Store submission)

Run-1 agent task packet · Makhtoot (مخطوط) · Target: build/release automation + submission execution. Consumes FOUNDATION.md D-101, FD-01, FD-05, FD-06, PLAN.md P15; executes APP_STORE_CHECKLIST.md.

---

## 1. Mission

Take Makhtoot from green local builds to a phased App Store release with the maximum automation the toolchain allows: `xcodebuild` archive/export/upload scripts (no Fastlane/CI services — D-101), TestFlight internal distribution, App Store Connect configuration driven through Chrome-control steps where no CLI/API exists, screenshot generation from the Simulator with real Arabic RTL compositions, a phased-release plan, and a rollback plan. The packet's agent automates everything technically possible and PAUSES at the founder boundary: Apple Developer credentials/session login, legal agreement acceptance, paid enrollments, provisioning-profile/team selections requiring the founder account, price confirmation, and final visual approval (BRIEF Q56/Q84). Every founder pause is an explicit numbered HOLD point with exactly what the founder must do and what evidence resumes the run.

Hard gates before anything uploads: FD-01 (real bundle id, team, repo) must be resolved — every placeholder (`com.example.makhtoot`, derived IAP ids, CloudKit container, UTI) must be swapped by a single scripted rename step and never hand-edited piecemeal. FD-06 (Family Sharing, irreversible per product[^46][^49]) must have a founder decision recorded BEFORE IAP creation in App Store Connect. Submission evidence bundles — font license records (WS-09), asset provenance audit (WS-14), paywall compliance walkthrough (WS-10/13 PW checklist), privacy questionnaire mapping (WS-12) — are collected here into one review-ready folder so an App Review question never triggers a scramble.

## 2. Scope

**IN:**
- `Scripts/` release automation: version/build-number management, archive (`xcodebuild archive`), export (`-exportArchive` with ExportOptions.plist for App Store), validate + upload (`xcrun altool`-successor: `xcrun notarytool` n/a for iOS — use `xcodebuild -exportArchive` + `xcrun altool --upload-package` alternatives; primary path: `xcodebuild` + Transporter-compatible `xcrun altool`/`App Store Connect API` — see T4 for the decided mechanism), placeholder-swap script (FD-01), preflight audit script.
- Code-signing boundary definition: exactly which steps are [FOUNDER] (certificates, profiles, team agreement, ASC users) vs agent-automatable.
- TestFlight internal-testing pipeline + build notes template (Arabic).
- App Store Connect setup via Chrome-control: app record, IAPs (3 products + subscription group), App Privacy questionnaire, pricing/availability (all eligible territories per BRIEF Q46), app metadata (ar primary locale), review notes — each mapped to APP_STORE_CHECKLIST.md sections.
- Screenshot generation: scripted Simulator runs (`xcrun simctl`) producing required device-size sets from staged Arabic RTL compositions; App Preview video explicitly out (v1 skip).
- Release phasing: internal TestFlight → founder acceptance → submission → phased release ON; version/build discipline.
- Rollback plan: phased-release halt, build rejection/developer-reject, expedited re-submission procedure, "pull from sale" last resort, local git tag discipline for shipped builds.
- Submission evidence bundle assembly.

**OUT:**
- Feature work/bug fixes (other packets), marketing/ASO copywriting beyond functional metadata drafts (founder approves all public copy), paid App Store features (ads etc. — none), external CI (prohibited D-101), Android/web (n/a), App Store Server API setup (v1 has no backend — WS-10 seam), actual founder credential entry (never performed by an agent — HOLD points only).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream:** ALL packets WS-01…WS-14 must be integrated and their gates green; specifically consumes: WS-09 license bundle + audit, WS-10 `.storekit`/sandbox plan + PW checklist, WS-11 CloudKit container requirement, WS-12 privacy docs + legal links, WS-13 shell (the binary + screenshot flows), WS-14 provenance audit. TEST_MATRIX.md full manual pass (Arabic verification checklist) is a precondition for submission, not part of this packet's work.

**Stub strategy:** none — this packet runs last (PLAN P15) against the real integrated app. Exception: screenshot staging may use seeded demo documents created via a debug-only fixture loader (T8) — fixtures are content, not stubs. If FD-04 hosting is unresolved, the D-121 bundle-fallback build mode (WS-09 T13) is elected here and recorded.

**Downstream consumers:** the founder (HOLD points + final approval), App Review, post-launch ops (rollback plan is the on-call document).

## 4. Locked decisions binding this packet

- **D-101**: "No XcodeGen/Tuist/Fastlane/CI services; build and distribute with `xcodebuild` + `gh` + App Store Connect (Chrome-driven where API-less)."
- **FD-01**: "Real bundle id, team, repo name/org (`git init` by founder) — blocking: Distribution phase." All derived ids (IAP, CloudKit container, UTI `com.example.makhtoot.project`) swap together.
- **FD-05**: referral stays OFF (`MKFeatureFlags.referralProgram`) — verify in the shipped binary; activation requires guideline recheck (never in this run).
- **FD-06**: Family Sharing decision precedes IAP creation (irreversible[^46][^49]).
- **D-123**: no introductory offer in ASC (app-side trial only) — IAP setup must NOT configure intro offers; App Store copy must not claim an Apple trial.
- BRIEF Q46: territories = all requiring no extra legal documentation/local registration + submission-time eligibility checklist; Q56/Q84 pause boundary; gates (Q59): build success, performance budgets, StoreKit sandbox tests, manual Arabic checklist.
- FOUNDATION §0 naming: Makhtoot / مخطوط everywhere; never "Masoon".

## 5. Task breakdown (ordered)

**T1 — Preflight audit script.** `Scripts/preflight.sh`: fails on — any `com.example.makhtoot` placeholder remaining (post-swap runs), `PLACEHOLDER-FD` markers in shipping code paths, referral flag ON, missing license dirs (delegates to WS-09 FontLicenseAudit + WS-14 AssetProvenanceAudit test runs), missing Privacy Policy/Terms URLs (still-placeholder `MKLegalLinks`), `.storekit` intro-offer presence, build warnings count regression, `ar` not sole localization. **AC:** script exits non-zero on each seeded violation (test each); wired as the first step of every release script.

**T2 — FD-01 placeholder swap script.** `Scripts/apply-identity.sh <bundle-id> <team-id>`: single-pass replacement of bundle id + derived ids (IAP `\(bundle).premium.monthly/.annual/.lifetime`, CloudKit `iCloud.\(bundle)`, UTI `\(bundle).project` — KVS store id is NOT a separate literal grep/replace target (DF-11): `NSUbiquitousKeyValueStore`'s scope auto-derives from the app's iCloud entitlement/bundle id formula, so once the bundle id and iCloud capability are swapped, the KVS store id follows automatically; this script's job for KVS is verifying the derived id, not rewriting a string) across project.pbxproj, entitlements, Info.plist, `MKStoreIDs.swift`, MKSync constants, docs; prints a diff summary; idempotent. Known side effect (D-211/DF-11, documented, not a bug): because the trial record's Keychain/KVS identity is tied to the placeholder bundle id during pre-launch development, swapping to the real bundle id at this step resets any placeholder-id trial state accrued on dev/test devices — this is expected and confined to pre-launch builds only; production users are never affected since they only ever see the real bundle id. **[FOUNDER HOLD H1]**: founder supplies real bundle id + team id + creates App ID/capabilities in the developer portal (CloudKit container, iCloud KVS, push OFF). **AC:** dry-run mode shows complete replacement set; post-run preflight passes placeholder check; grep count of old id == 0; KVS store id is verified (not grepped) to have followed the bundle-id swap; the pre-launch trial-reset side effect is documented in the run's evidence output, not silently absorbed.

**T3 — Version/build discipline.** `Scripts/bump.sh`: marketing version (semver, v1 launch = 1.0.0) + monotonically increasing build number (UTC timestamp form yyyymmddHHMM); tags: on every uploaded build, `git tag build/1.0.0-<build>` (founder-owned repo — agent tags only after founder `git init`, else records in evidence folder). **AC:** two consecutive runs produce increasing builds; tag naming documented.

**T4 — Archive/export/upload scripts.** `Scripts/release.sh`:
```
xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot \
  -destination 'generic/platform=iOS' -archivePath build/Makhtoot.xcarchive \
  archive CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=$TEAM
xcodebuild -exportArchive -archivePath build/Makhtoot.xcarchive \
  -exportOptionsPlist Scripts/ExportOptions-AppStore.plist -exportPath build/export
xcrun altool --upload-app -f build/export/Makhtoot.ipa \
  --type ios --apiKey $ASC_KEY_ID --apiIssuer $ASC_ISSUER   # ASC API key path
```
Mechanism decision: prefer App Store Connect API key (founder creates key — **[FOUNDER HOLD H2]**: generate ASC API key with App Manager role, store locally in Keychain-protected path, never committed) so upload is non-interactive; fallback: Xcode Organizer manual upload documented as the degraded path. If `altool` upload is deprecated in the current Xcode 16.x, use `xcrun` Transporter equivalent — **VERIFY-AT-IMPLEMENTATION**, record actual tool+flags in ADR. ExportOptions: `method=app-store-connect`, automatic signing, symbols ON. **AC:** archive+export succeed locally post-H1; upload succeeds to TestFlight (first real build) post-H2; scripts have `--dry-run`.

**T5 — Code-signing boundary doc.** `Docs/SigningBoundary.md`: [FOUNDER] — Apple Developer Program enrollment/agreements, ASC API key creation, certificates (automatic signing preferred: Xcode-managed distribution cert), device registration (none needed for App Store), accepting Paid Apps agreement + banking/tax (blocks IAP!). [AGENT] — everything in T4, capability plumbing, profile troubleshooting guidance. Explicit rule: agent never handles founder credentials/passwords/2FA; Chrome-control sessions require the founder to be logged in already. **AC:** doc enumerates every signing artifact with owner; Paid-Apps-agreement listed as IAP blocker (H3).

**T6 — TestFlight internal pipeline.** Post-upload: processing wait, export-compliance answer (uses only exempt encryption: HTTPS/CloudKit — set `ITSAppUsesNonExemptEncryption=NO` in Info.plist so no manual question per build; **VERIFY-AT-SUBMISSION** that exemption applies), internal group "Makhtoot Core" (founder + devices), Arabic build-notes template (ما الجديد/ما يُختبر/المشكلات المعروفة). **[FOUNDER HOLD H3]**: founder accepts agreements incl. Paid Apps, creates internal testers. **AC:** first build installable via TestFlight on founder device; notes template used; compliance key present.

**T7 — App Store Connect configuration via Chrome-control.** Execute APP_STORE_CHECKLIST.md sections as a scripted click-path (agent drives founder-authenticated Chrome; founder present). Sub-steps, each mapped to its checklist section: (a) create app record — name "مخطوط - Makhtoot" (availability check; fallback names listed), primary locale ar, bundle id from H1, SKU; (b) subscription group "Makhtoot Premium" + monthly/annual products at $2.99/$29.99 tiers + lifetime non-consumable $89.99 — **Family Sharing set per FD-06 founder decision recorded BEFORE this step [FOUNDER HOLD H4]**; NO introductory offers (D-123); localized ar display names (اشتراك شهري/سنوي/مدى الحياة); (c) App Privacy questionnaire from WS-12 `PrivacyNutrition.md` mapping; (d) pricing base tier + availability: start from all territories, remove any requiring local registration per submission-time eligibility checklist (APP_STORE_CHECKLIST territories section; Oman storefront OMR spot-check[^market §8]); (e) age rating questionnaire (expect 4+); (f) metadata: ar description/keywords/support URL/privacy URL (founder-approved copy — **[FOUNDER HOLD H5]** copy + URLs approval); (g) review notes: demo instructions in English for the review team (app is Arabic-only — provide a short usage walkthrough + note that no account is needed; sandbox tester creds for IAP). **AC:** each sub-step has screenshot evidence saved to the evidence bundle; IAP states reach "Ready to Submit"; privacy answers match the shipped binary behavior.

**T8 — Screenshot staging fixtures.** Debug-only fixture loader (compile-flagged out of release IPA) seeding 5 polished demo documents showcasing: Arrange Mode glyph manipulation, tashkeel detachment, ligature decomposition, path text on a Bézier curve, ornaments+frames composition — all pure Arabic compositions (user-neutral poetry/proverbs, NO Qur'anic verses per BRIEF). **AC:** fixtures load on simulator via launch argument `-MKScreenshotMode`; release build strips the loader (preflight checks symbol absence).

**T9 — Screenshot generation from Simulator.** `Scripts/screenshots.sh`: boots required sims (`xcrun simctl boot`), launches with `-MKScreenshotMode` + a screen-sequence launch arg, captures via `xcrun simctl io <udid> screenshot` for required App Store sizes: iPhone 6.9" (1320×2868), iPhone 6.5"-class if still required, iPad 13" (2064×2752) — **VERIFY-AT-SUBMISSION** the current required size list in ASC and adjust; ≥5 screenshots per size from: browser, editor+arrange mode, tashkeel manipulation, font catalog, export sheet. RTL correctness reviewed frame-by-frame; status bar cleaned via `simctl status_bar override` (9:41, full battery). Text overlays/marketing frames: none in v1 (raw UI screenshots — honest + fastest); seam for framed marketing later. **AC:** script produces complete size sets deterministically; visual review pass logged; uploaded to ASC via Chrome-control (T7 flow) or API where available.

**T10 — Submission-time eligibility & compliance sweep.** Execute APP_STORE_CHECKLIST.md final sections: territories eligibility (Q46 rule), current App Review Guidelines re-read for: 3.1.2 paywall items vs PW walkthrough evidence, 4.8 non-trigger confirmation (no third-party login), referral-off confirmation, trial-copy accuracy (no "free trial" claim implying Apple intro offer), font-license substantiation ready (WS-09 records), export-compliance. Every item ticked with evidence link or marked blocking. **AC:** completed checklist committed to evidence bundle; zero unresolved blockers before H6.

**T11 — Submit for review.** **[FOUNDER HOLD H6]**: founder final visual approval of build + metadata + screenshots. Then: attach build to version 1.0.0, phased release = ON (7-day gradual for updates — note: phased release applies to *updates*, not initial release; document that v1.0 releases to 100% and phasing protects 1.0.x+ — **VERIFY-AT-SUBMISSION** current ASC behavior), release option "Manually release this version" so the founder controls go-live moment, submit. Monitor review status daily via Chrome-control; prepare Resolution-Center response templates (English) for likely questions: font licensing (attach OFL records), trial mechanics (app-side, no intro offer), CloudKit data handling. **AC:** submitted; monitoring log started; response templates in evidence bundle.

**T12 — Rollback & incident plan.** `Docs/RollbackPlan.md`: (1) pre-approval: developer-reject the build in ASC, fix, re-upload (new build number, same version); (2) post-approval pre-release: reject/hold manual release; (3) post-release critical bug: halt phased release (updates), expedited review request procedure + criteria, hotfix branch from shipped tag `build/…`, version 1.0.1 fast path with minimal-diff policy; (4) StoreKit incidents (broken purchases): remediation via re-submission ONLY (no server switches exist v1) — hence sandbox gate is mandatory pre-submission; (5) catastrophic: Remove-from-sale (founder decision, documented consequences: existing users keep the app; subscriptions keep billing — pair with subscription-price/product deactivation guidance); (6) CloudKit schema incidents: schema is additive-only once deployed to production container — document the promote-to-production step and its irreversibility in the same file. **AC:** plan covers all 6 scenarios with owner + exact click/command paths; shipped-build tag discipline (T3) referenced.

**T13 — Release-phasing & post-launch monitoring.** First-week runbook: daily crash review (Xcode Organizer crashes — no third-party SDK), App Store review responses (founder voice, Arabic), TestFlight-vs-prod parity check, sync/StoreKit incident triage into T12 paths. **AC:** runbook with daily checklist; handed to founder.

**T14 — Evidence bundle assembly.** `ReleaseEvidence/1.0.0/`: preflight output, audits (fonts/assets), PW walkthrough, privacy mapping, TEST_MATRIX manual-pass sign-offs (T-arabic full checklist), sandbox StoreKit results, screenshots as-submitted, checklist as-completed, ADR index, HOLD log (H1–H6 timestamps + who). **AC:** bundle complete + immutable copy zipped; referenced from codebase-memory evidence entries.

## 6. Compliance & licensing notes

- IAP config: subscription + lifetime coexistence approved pattern[^45][^47]; restore mandatory[^47]; Family Sharing irreversible[^46][^48][^49] — H4 gate. No intro offers (D-123) — mismatch between ASC config and app trial copy is a rejection vector; T10 checks both directions.
- Paywall 3.1.2 evidence from WS-10/13 [^45][^50][^51][^52] attached at submission; review notes preempt questions.
- Referral must be OFF in the shipped binary (D-124/FD-05; rejection precedent [^53][^54], inferred from 3.1.1/3.2.2 [^55]).
- 4.8 not triggered (no third-party login) [^56][^57][^58][^59] — keep review notes explicit that no account exists.
- Font licenses: OFL records ship in-app (WS-09/WS-12) and in the evidence bundle [^26][^28][^30]; KFGQPC absence re-verified by preflight (prohibited [^31][^32]).
- Territories/pricing: Apple tier localization handles currency (BRIEF); Oman OMR spot-check at submission (market study §8 note). Grace-period durations never hardcoded in copy — **VERIFY-AT-SUBMISSION** [^43].
- Export compliance: HTTPS/CloudKit-only crypto exemption claim — **VERIFY-AT-SUBMISSION** current questionnaire.
- Screenshot content: honest, current-build UI only; Arabic-only UI is acceptable (primary locale ar) — provide reviewer walkthrough in review notes.

## 7. Packet acceptance criteria (gates)

1. **Build gate:** `Scripts/release.sh --dry-run` green; real archive/export green post-H1; preflight green with zero waivers.
2. **StoreKit sandbox gate:** full WS-10 SandboxTestPlan executed against a TestFlight build with real ASC products (T-store-01..08 re-run in sandbox) — evidence in bundle.
3. **Manual Arabic gate:** complete TEST_MATRIX manual checklist (T-arabic-*, T-shell-*, T-fonts-*, T-sync-*, T-asset-*, T-set-*) signed off on the release candidate build on physical iPhone + iPad.
4. **Checklist gate:** APP_STORE_CHECKLIST.md 100% completed with evidence links; H1–H6 HOLD log complete.
5. **Submission gate:** build submitted; screenshots/metadata as approved; rollback plan + runbook delivered to founder.

## 8. Deliverables

- `Scripts/`: `preflight.sh`, `apply-identity.sh`, `bump.sh`, `release.sh`, `screenshots.sh`, `ExportOptions-AppStore.plist`.
- `Docs/SigningBoundary.md`, `Docs/RollbackPlan.md`, post-launch runbook, Resolution-Center response templates.
- Screenshot fixture loader (debug-only) + generated screenshot sets.
- Chrome-control click-path transcripts for every ASC section (mapped to APP_STORE_CHECKLIST.md).
- `ReleaseEvidence/1.0.0/` bundle; HOLD log H1–H6.

## 9. References

- FOUNDATION.md §1 D-101, §8 D-123/D-124, §10 FD-01/FD-05/FD-06, §0 naming/ids.
- PLAN.md: P15 Distribution (and P14 gates as preconditions).
- ARCHITECTURE.md: §18 StoreKit & Entitlements; §20 CloudKit Sync (container promotion); §23 Security & Privacy.
- PRD.md: §14–§15 (store states for review notes); §22 Non-Functional Requirements.
- APP_STORE_CHECKLIST.md: ALL sections — this packet is its execution vehicle; each T7/T10/T11 sub-step cites its section.
- Market study §8 (StoreKit/App Review), §10 (pricing); footnotes [^26][^28][^30][^31][^32][^43][^45]–[^59].
- TEST_MATRIX.md: full manual matrix as precondition; sandbox suite re-run.

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS-15-A1: upload mechanism actually used (altool vs successor) + ASC API key handling"; "WS-15-A2: FD-06 Family Sharing decision as recorded"; "WS-15-A3: D-121 hosted-vs-bundled premium font election at submission"; "WS-15-A4: phased-release + manual-release strategy"; "WS-15-A5: territories exclusion list + rationale".
- Implementation logs per task T1–T14 incl. every HOLD (who/when/what unblocked).
- Verification evidence: preflight outputs, sandbox re-run results, signed manual-checklist scans, ASC screenshots, submission confirmation, review correspondence — mirrored in `ReleaseEvidence/1.0.0/` and linked from evidence entries.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Distribution: automate prep + submission where technically possible; pause only for founder credentials/legal acceptance/license purchases/provisioning/final visual approval (Q56, Q84) | §1 Mission; T1–T14; HOLD points H1–H6 |
| Tools: Xcode, xcodebuild, gh only (Q49); no XcodeGen/Tuist/Fastlane/external CI unless necessary | T4 (`release.sh`); §4 D-101 |
| Bundle ID marked placeholder — founder will supply the real one | T2 (`apply-identity.sh`, HOLD H1) |
| Repository: founder will `git init` and name it | T3 (build-tag discipline coordinated with founder-owned repo) |
| Territories: all needing no extra legal documentation/local registration (Q46) + concrete submission-time eligibility checklist | T7(d), T10 |
| Referral flow: architect but default OFF; do not activate without reconfirmation against current guidelines (Q78) | T1 (preflight referral-flag check); §4 FD-05 |
| Full StoreKit 2: sandbox testing, grace period/billing retry/expiration messaging verification | Gate 2 (StoreKit sandbox gate); T6, T11 |
| $3/mo, $30/yr, $90 lifetime; Apple storefront price localization | T7(b) |
| 7-day trial from FIRST APP LAUNCH (Q37); no Apple introductory offer configured | T7(b) ("NO introductory offers"); §4 D-123 |
| Provide concrete acquisition/verification process for fonts | T10 (font-license substantiation ready), T14 (evidence bundle) |
| No preloaded Qur'anic content of any kind (Q67–68) — extended to screenshot compositions | T8 (fixtures explicitly exclude Qur'anic verses) |
| Gates (Q59): build success, performance profiling vs budgets, StoreKit sandbox tests, manual Arabic-script verification checklist | §7 gates 1–3 |
| Known research gaps: exact Apple grace-period durations, current App Review Guidelines text for referral, export-compliance/ICC questions — verify at implementation/submission time, do not invent | T6, T10 (VERIFY-AT-SUBMISSION markers) |
| Codebase-memory MCP conventions: durable ADRs, implementation logs, verification evidence per phase (Q58) | §10 |
