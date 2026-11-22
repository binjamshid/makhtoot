# WS-12 — Analytics & Settings (MKAnalytics + Settings screens)

Run-1 agent task packet · Makhtoot (مخطوط) · Targets: `MKAnalytics` (MakhtootKit) + Settings scene group in the `Makhtoot` app target (incl. Settings→Support→Licensing rendering). Consumes FOUNDATION.md D-125, D-126, D-113, module map §2.

---

## 1. Mission

Build the only analytics Makhtoot will ever have in v1 — anonymous, aggregated, **opt-in (default OFF)** font-usage counters (D-125, BRIEF Q43/Q79) — and the complete Settings surface of the app. `MKAnalytics` collects exactly one class of signal: which catalog fonts get used, counted on-device, bucketed by week, and uploaded as anonymous batches to the CloudKit **public** database with a random ephemeral batch UUID, no user record link, no identifiers, no fine timestamps, and a kill switch that halts everything instantly. Never uploaded, ever: text content, projects, device identifiers, font files, or anything traceable. The consent flow is explicit, versioned, and honest — the toggle ships OFF and nothing is collected or even buffered before consent.

The second half of this packet is the Settings information architecture: subscription/entitlement management (rendering WS-10 states), iCloud sync controls (rendering WS-11 status contract), the analytics consent screen, general preferences, and — legally load-bearing — **Settings→Support→Licensing (الإعدادات ← الدعم ← التراخيص)**, which renders WS-09's `MKLicensingDataSource`: per-font license, attribution, foundry, commercial status, character coverage, and source links, with full license texts. This screen is Makhtoot's OFL attribution mechanism; OFL 1.1 requires the copyright notice and license text to accompany the fonts[^26][^28][^30], so this screen is a submission blocker, not a nicety. All UI is Arabic-only RTL, built from `MKDesignSystem` tokens (D-126).

## 2. Scope

**IN:**
- `MKAnalytics` target: consent manager (versioned consent record in SwiftData via MKPersistence), on-device counter store (fontID → weekly usage buckets), aggregation/bucketing rules, CloudKit public-DB uploader, kill switch, data-deletion of local counters, error handling, complete "what we collect" disclosure data.
- Settings scenes (app target): root Settings screen; قسم الاشتراك (subscription status/manage/restore — WS-10 states); المزامنة (sync toggle/status — WS-11 contract); الخصوصية (analytics consent + disclosure); عام (general prefs: canvas defaults, autosave indicator prefs); الدعم (support: about, contact placeholder, **Licensing screen**); legal links (Privacy Policy, Terms — required in-binary by Guideline 3.1.2[^45][^50]).
- Settings→Support→Licensing rendering incl. lazy full-license-text viewer and coverage report display.
- Privacy-nutrition-label input document for APP_STORE_CHECKLIST.

**OUT:**
- Any other analytics (crashes, funnels, screens — none exist in v1), third-party SDKs (prohibited, D-125/D-101), ATT prompts (nothing tracks across apps — not triggered[^57]), paywall UI (WS-13 renders; WS-10 owns state), the font *data* layer (WS-09 provides `MKLicensingDataSource`), onboarding consent (consent lives in Settings only — no consent nag in onboarding), account systems (none).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream:**
- `MKPersistence` (WS-02): SwiftData store for consent records + counters (FOUNDATION D-112 lists analytics counters among SwiftData metadata).
- `MKFonts` (WS-09): `MKLicensingDataSource` for the Licensing screen; font-usage events source (see hook below). **Stub:** if WS-09 is unmerged, code against the `MKLicensingDataProviding` protocol with a 3-font fixture provider.
- `MKStore` (WS-10): entitlement states for the subscription section. **Stub:** `SandboxScenarioStub` presets from WS-10 (or `AlwaysPremiumEntitlementStub` until then).
- `MKSync` (WS-11): `MKSyncStatusPublisher` for the sync section. **Stub:** static-status fake publisher.
- `MKDesignSystem` (WS-01): all tokens/components; no ad-hoc styling.
- Event hook: `MKAnalytics.record(fontUsed: MKFontID)` is called by the editor (WS-13) when a font is applied to a text object — define the protocol `MKFontUsageRecording` in MKFoundation so WS-13 can call without depending on MKAnalytics directly.

**Downstream consumers:** WS-13 (navigates to Settings scenes; calls usage hook), WS-15 (privacy questionnaire answers; Licensing screen screenshot evidence; legal links present), APP_STORE_CHECKLIST (disclosure doc).

## 4. Locked decisions binding this packet

- **D-125**: "default OFF; explicit opt-in switch in Settings (consent record versioned). On-device counters: (fontID → usage count buckets). Upload: anonymous batches to CloudKit **public** database with random ephemeral batch UUID, no user record link, no timestamps finer than week, counts bucketed; no third-party SDK. Never: text, projects, identifiers, font files."
- **D-126**: token-based `MKTheme`, RTL-first components, all UI strings `ar` only; baseline aesthetic "حبر ورق" (Ink & Paper).
- **D-113**: entitlement states rendered in subscription section; restore purchases mandatory UI.
- BRIEF: "Only analytics: anonymous, aggregated, OPT-IN font-usage data (Q43, Q79). Never upload text, projects, identifiers, font files. Specify consent, aggregation, data minimization." Licensing info located at Settings→Support→Licensing (Q66). No ads. Arabic-only RTL UI.
- Module map §2: `MKAnalytics` depends on MKFoundation, MKPersistence only.

## 5. Task breakdown (ordered)

**T1 — Consent model.** `MKConsentRecord` (SwiftData via MKPersistence): `consentVersion: Int` (current = 1), `status: enum {neverAsked, granted(date), revoked(date)}`, `disclosureTextHash`. Rules: default `neverAsked` = OFF; granting stores version + date; a future disclosure change bumps `consentVersion` and *downgrades* status to `neverAsked` (re-consent required). API: `MKConsentManager.status`, `.grant()`, `.revoke()` (revoke also wipes local counters + pending batches — data minimization). **AC:** unit tests for version-bump re-consent; revoke wipes storage (verified empty); no counter API works while not `granted`.

**T2 — Counter store & bucketing.** `MKUsageCounterStore`: keyed (fontID, isoWeek "2026-W29") → count. `record(fontUsed:)` no-ops unless consent granted (checked at call site inside MKAnalytics, cheap). Count bucketing for upload (D-125 "counts bucketed"): raw weekly count → bucket enum `1–4, 5–9, 10–24, 25–49, 50+` at upload time (raw counts never leave device). Retention: local raw counters older than 8 weeks pruned. **AC:** bucketing table test; no-consent no-op test; prune test; concurrency-safe under `Sendable` actor.

**T3 — Upload payload & schema.** CloudKit public DB record type `MKFontUsageBatch`: `batchID: String` (random UUID, generated per upload, never reused, never stored after success), `week: String` (ISO week only — no finer timestamps), `appVersion: String` (major.minor only), `entries: [String]` encoded as JSON asset/field of `{fontID, bucket}` pairs. Explicitly ABSENT: user record references (public DB writes happen with no custom user linkage; do not read `userRecordID`), device model, locale, vendor IDs. Document schema in `Docs/AnalyticsSchema.md` with a field-by-field justification against D-125's prohibition list. **AC:** schema doc + code constants; a test asserts the serialized payload contains only whitelisted keys (allowlist test, fails on any new field).

**T4 — Uploader.** `MKAnalyticsUploader` actor: weekly cadence (opportunistic on launch/foreground, ≥7 days since last successful upload, only closed weeks uploaded); consent re-checked immediately before network call; remote kill-switch record (T5, D-207/DF-2) also re-checked immediately before network call — if disengaged, skip the upload entirely for this run; CloudKit public DB save; on success delete uploaded week's local raw counters. Batch retry retention COMPOSES with T2's 8-week local-counter retention window (DF-7 — corrects the prior independently-chosen "≤2 extra weeks" figure, which could disagree with T2's window): on failure, exponential-backoff retry continues for a given week's batch only as long as that week's underlying local counters still exist; once T2's 8-week prune removes a week's raw counters, that week's pending batch is dropped too (never retained past the data it was built from, never grows unbounded). Network use is one of the three sanctioned uses (BRIEF); zero traffic when consent OFF or kill switch disengaged. **AC:** fake-container tests: consent-off ⇒ zero calls; kill-switch-disengaged ⇒ zero calls even with consent on; success ⇒ counters cleared; failure ⇒ retention bounded by (and never exceeding) T2's 8-week window (assert against R-19.2); batchID uniqueness across runs.

**T5 — Kill switch.** THREE layers, remote mechanism rewritten per D-207/DF-2 (ARCHITECTURE §21.1's prior "no remote config" claim is corrected — a remote config record DOES exist for this one purpose): (a) user revoke (T1) — instant stop + wipe, local and immediate; (b) **remote CloudKit-record kill switch (D-207, the primary "stop everything" lever)** — a single CloudKit PUBLIC-DB record (e.g. `MKAnalyticsConfig` with field `analyticsEnabled: Bool`) is read by the uploader (T4) immediately before every upload attempt; this is serverless (no backend) — the founder can flip the record via the CloudKit Dashboard to halt collection across the entire install base without an app update. Offline/unreachable behavior: use the last-known cached value of the record; default to enabled if the record has never been fetched (never fail permanently closed on a transient network error, but an explicitly-fetched `false` always wins immediately). This record governs UPLOAD only — it does not stop on-device counting, which remains governed solely by local consent (T1); (c) `MKFeatureFlags.analyticsEnabled` compile/runtime flag remains as a supplementary build-time inertness lever (ship-ready if policy changes at review time) — it is now supplementary to, not a substitute for, layer (b). **AC:** flag-off build compiles with zero CloudKit-public references executed (verified via test spy); revoke path re-tested end-to-end; remote-record-disengaged test — uploader makes zero network calls while consent remains granted; offline-with-no-prior-fetch test defaults to enabled (upload proceeds); offline-with-cached-false test blocks upload.

**T6 — Disclosure content.** Write the Arabic disclosure text shown at the consent screen: what is collected (أسماء الخطوط الأكثر استخدامًا فقط، مجمّعة أسبوعيًا وبصورة مجهولة تمامًا), what is never collected (نصوصك، مشاريعك، أي معرّفات), where it goes (قاعدة بيانات عامة مجهولة عبر iCloud), how to stop (أي وقت — والإيقاف يحذف العدادات المحلية). Store as versioned resource tied to `consentVersion`. **AC:** text reviewed against D-125 claims (no overpromise/underpromise); hash recorded in consent record.

**T7 — Settings information architecture.** App-target scene group `Settings/`: root `SettingsView` (NavigationStack, RTL) with sections: الاشتراك (Subscription) · المزامنة عبر iCloud (Sync) · الخصوصية (Privacy) · عام (General) · الدعم (Support). All navigation titles/strings in `ar` only; layout from MKDesignSystem tokens; iPad: settings presented as a sheet/column per WS-13 adaptive rules. **AC:** snapshot-free manual check T-set-01 (see gate); no hardcoded colors/spacing (token audit grep).

**T8 — Subscription section.** Renders WS-10 states: current plan (تجربة — X أيام متبقية / مشترك شهري / سنوي / مدى الحياة / مجاني), grace/billing-retry banners (WS-10 T9 contract), buttons: إدارة الاشتراك (opens `https://apps.apple.com/account/subscriptions`), استعادة المشتريات (mandatory restore UI — D-113), عرض الباقات (paywall via WS-13 route, context `.settingsUpsell`). **AC:** every `MKEntitlementState` case renders a distinct, correct Arabic string (unit test over view model); restore triggers WS-10 `restore()` with result toasts.

**T9 — Sync section.** Toggle "مزامنة المشاريع عبر iCloud" (premium-gated: free users see lock badge + paywall route); renders `MKSyncStatusPublisher` global states (T11 of WS-11) incl. last-sync date (Arabic relative formatting), quota/account errors with recovery actions. **AC:** all global states render; toggle drives MKSync enable/disable; free-tier tap routes to paywall (integration test with stubs).

**T10 — Privacy section (consent flow).** Screen with disclosure (T6), single opt-in toggle default OFF, status line (آخر رفع: الأسبوع الماضي / لا يوجد), "حذف البيانات المحلية" action (= revoke effect without flipping toggle semantics — clarify: revoke wipes and turns off). Links: سياسة الخصوصية (Privacy Policy URL placeholder `PLACEHOLDER-FD-01-domain`), شروط الاستخدام (Terms/EULA). **AC:** toggling ON writes consent v1 record; OFF revokes + wipes; links present (placeholders marked); manual check T-set-02.

**T11 — General section.** v1-minimal: default canvas preset choice, autosave status visibility toggle (display-only pref), language row fixed "العربية" (no switcher — Arabic-only, D-100). **AC:** prefs persist via MKPersistence; nothing here gates features.

**T12 — Support section + About.** حول التطبيق (version/build, credits line "مخطوط — Makhtoot"), تواصل معنا (mailto placeholder — MARKED PLACEHOLDER, founder supplies), **التراخيص (Licensing)** row → T13. **AC:** version string auto-derived from bundle; placeholders marked in code comments.

**T13 — Licensing screen (Settings→Support→Licensing).** Renders `MKLicensingDataSource` (WS-09 T16): grouped list — الخطوط المدمجة (bundled) / خطوط مميزة (premium) / خطوط مستوردة (imported). Per-font row: family (Arabic + Latin), foundry/author, license badge (OFL 1.1 / مستورد من المستخدم), commercial-use status. Detail screen per font: full attribution (copyright line verbatim), reserved font names, **full license text** (lazy-loaded scrollable monospaced view, byte-identical to captured file — Latin text renders LTR inside RTL layout via `.environment(\.layoutDirection, .leftToRight)` on the text block only), source repository link (opens Safari), character-coverage summary (WS-09 T10 report: ranges + tashkeel/Qur'anic-marks/Latin booleans rendered as labeled checks). Imported fonts show the user-responsibility notice (WS-09 T15). **AC:** every registered font appears; OFL full text scrolls performantly; coverage renders; manual check T-set-03 verifies Amiri's entry shows OFL text + `يدعم علامات التجويد` correctly; screen reachable in ≤3 taps from Settings root (Q66 path).

**T14 — Legal links plumbing.** Central `MKLegalLinks` constants (Privacy Policy URL, Terms URL — placeholders) consumed by Settings (T10) AND the paywall (WS-13 must show them per PW-05/PW-06 of WS-10's requirements). One source of truth. **AC:** grep shows no duplicated URL literals; both surfaces reference the constants.

**T15 — Privacy questionnaire input doc.** `Docs/PrivacyNutrition.md`: mapping for App Privacy questions — data collected: "Product Interaction (font usage), not linked to identity, no tracking" ONLY when consent granted; iCloud sync = user content in user's private DB (not developer collection — WS-11 SyncPrivacy cross-ref); no ATT (nothing tracks across apps/websites[^57]); no third-party SDKs. Mark every answer **VERIFY-AT-SUBMISSION** against the live App Store Connect questionnaire wording. **AC:** doc complete; referenced by APP_STORE_CHECKLIST.

**T16 — Usage-hook integration point.** Implement `MKFontUsageRecording` conformance and document the single call site contract for WS-13 (record on font *apply* to an object, not on preview/browse — minimization). Debounce identical consecutive applies within 5 s. **AC:** protocol in MKFoundation; MKAnalytics conforms; contract doc line in module README; debounce test.

**T17 — Analytics error handling & observability.** Local `os_log` category `analytics` (no PII in logs); CloudKit errors mapped (quota on public DB, network, throttle) — all silent to the user (analytics must never nag); status only visible in the Privacy screen line. **AC:** no user-facing alerts from analytics paths (test asserts UI stream emits nothing on failure).

**T18 — Full opt-in end-to-end test.** Integration test: grant consent → record 30 usages across 3 fonts/2 weeks → advance clock → upload → assert payload allowlist, bucket values, batchID randomness, counter cleanup → revoke → assert wipe. **AC:** green in CI-less local `xcodebuild test` run; forms the evidence artifact for §10.

## 6. Compliance & licensing notes

- OFL attribution: OFL 1.1 requires copyright notice + license text to accompany the fonts — the Licensing screen is the delivery mechanism [^26][^28][^30]; missing/partial license text is a ship blocker (gate 4).
- Guideline 3.1.2 requires functional Privacy Policy + Terms links in-binary [^45][^50] — T10/T14; URLs are founder placeholders (**VERIFY-AT-SUBMISSION**).
- No ATT prompt needed: no cross-app/website tracking, no third-party SDKs, first-party aggregate analytics only — market study §9 [^57][^56]; if anything in this design changes, ATT analysis must be redone.
- Anonymity claims in the disclosure must remain literally true (D-125 prohibition list) — the allowlist test (T3) is the technical enforcement.
- CloudKit public-DB writes from all users are visible infrastructure-wise to the developer only in aggregate; do not add fields enabling re-identification (week + bucket coarseness is deliberate).
- Consent default OFF is a locked founder decision (Q43/Q79) — no growth-hack prompts, no pre-checked boxes, no onboarding interstitial for consent.

## 7. Packet acceptance criteria (gates)

1. **Build gate:** MKAnalytics + Settings scenes compile in Swift 6 strict; zero third-party deps; flag-off build inert (T5).
2. **Automated gate:** T1–T5, T16–T18 tests green; payload allowlist test present and passing.
3. **Manual Arabic checks (TEST_MATRIX `T-set-*` / `T-an-*`):** T-set-01 Settings IA renders RTL correctly on iPhone + iPad; T-set-02 consent flow — default OFF, grant, revoke-wipes; T-set-03 Licensing screen — every bundled font listed, Amiri detail shows full OFL text + coverage; T-set-04 subscription section renders all entitlement states (stub presets); T-set-05 sync section states; T-an-01 airplane-mode: zero analytics traffic consent-on and consent-off (network inspector evidence); T-an-02 end-to-end upload against a dev CloudKit container; T-ANL kill-switch test (D-207/DF-2) covers both the local-revoke path and the remote CloudKit-record path (record flipped to disengaged mid-session halts the next upload attempt).
4. **Attribution gate:** cross-check — every font in the shipped bundle appears in the Licensing screen with full license text (script from WS-09 T20 extended to UI data source).
5. **StoreKit sandbox tie-in:** T-set-04 re-run against real WS-10 resolver post-integration.

## 8. Deliverables

- `MakhtootKit/Sources/MKAnalytics/**` (consent, counters, bucketing, uploader, kill switch, errors).
- App target `Makhtoot/Scenes/Settings/**` (root + 5 sections + Licensing screens + view models).
- `Docs/AnalyticsSchema.md`, `Docs/PrivacyNutrition.md`, versioned disclosure resource, `MKLegalLinks` constants.
- Test suites incl. end-to-end opt-in test + allowlist test.
- `MKFontUsageRecording` protocol (MKFoundation) + call-site contract doc.

## 9. References

- FOUNDATION.md §8 D-125, §9 D-126, §8 D-113, §2 module map, §12 conventions (Arabic strings + gloss).
- ARCHITECTURE.md: §21 Analytics; §22 Design System; §23 Security & Privacy; §18 StoreKit & Entitlements (rendered states); §20 CloudKit Sync (rendered status).
- PRD.md: §18 Analytics & Privacy; §20 Settings & Licensing; §14 Free/Premium Gating & Paywall (legal links); §19 Offline Behavior.
- APP_STORE_CHECKLIST.md: App Privacy questionnaire section; legal-links section; font-license substantiation section.
- Market study §9 (privacy/analytics posture), §5 (OFL attribution duty); footnotes [^26][^28][^30][^45][^50][^56][^57].
- TEST_MATRIX.md `T-set-*`, `T-an-*`.

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS-12-A1: consent versioning + re-consent policy"; "WS-12-A2: bucket boundaries and week-granularity rationale (re-identification resistance)"; "WS-12-A3: public-DB batch schema allowlist as enforced contract"; "WS-12-A4: Settings IA and Licensing screen as OFL attribution mechanism".
- Implementation logs per task T1–T18.
- Verification evidence: allowlist test output, T-an-01 zero-traffic capture, T-set-03 Licensing screenshots (Amiri detail), consent grant/revoke storage dumps; log placeholder URLs (Privacy Policy/Terms/contact) as open founder items.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Only analytics: anonymous, aggregated, opt-in font-usage data (Q43, Q79); never text/projects/identifiers/font files; consent + aggregation + data-minimization | §1 Mission; T1–T6, T15–T18 |
| No ads | §2 OUT; §1 Mission |
| License/attribution/foundry/commercial-status/character-coverage/source links at Settings→Support→Licensing (Q66) | T12, T13 |
| Full StoreKit 2: status/restore/precedence/grace/billing-retry/expiration messaging (rendering side) | T8 (engine side: WS-10) |
| $3/mo, $30/yr, $90 lifetime; Apple storefront price localization (rendering side) | T8 (pricing strings sourced from StoreKit, engine side: WS-10) |
| Post-trial free tier retains full editing, premium functions blocked (Q41) | T8 |
| Premium/lifetime iCloud project sync (status/controls rendering) | T9 (engine side: WS-11) |
| Arabic-only RTL UI | T7 (Settings IA, all strings `ar`) |
| No mandatory account; no SIWA surface | T7 (§2 OUT: no account section) |
| Gates (Q59): manual Arabic-script verification checklist | Gate 3, T-set-*, T-an-* |
| Codebase-memory MCP conventions: durable ADRs, implementation logs, verification evidence per phase (Q58) | §10 |
