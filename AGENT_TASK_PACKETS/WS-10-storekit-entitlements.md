# WS-10 — StoreKit 2 & Entitlements (MKStore)

Run-1 agent task packet · Makhtoot (مخطوط) · Target module: `MKStore` (MakhtootKit) + paywall state contract for the app target. Consumes FOUNDATION.md D-113, D-123, D-124, FD-05, FD-06.

---

## 1. Mission

Build `MKStore`, the single source of monetization truth for Makhtoot: StoreKit 2 product loading, purchase, restore; the `MKEntitlementResolver` that folds `Transaction.currentEntitlements` + subscription status + the app-side trial into one `MKEntitlementState` with the D-113 precedence (`lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free`); the app-side 7-day trial (D-123) persisted in Keychain + iCloud KVS with a clock-rollback guard; the paywall state machine and its compliance requirements; grace-period/billing-retry UX states; a `.storekit` configuration and sandbox test plan; and the flag-OFF Referral submodule (D-124) with anti-abuse caps, attribution design, a review-risk memo, and a clean-removal procedure. Products: `com.example.makhtoot.premium.monthly` ($2.99/mo), `.premium.annual` ($29.99/yr) in subscription group `Makhtoot Premium`, and `.premium.lifetime` ($89.99 non-consumable) — ids are placeholder-derived from the FD-01 bundle id.

This packet **replaces the `AlwaysPremiumEntitlementStub`** that every earlier packet (WS-08 export gating, WS-09 fonts, WS-11 sync) has been coding against via `MKEntitlementProviding`. Correctness here is existential: a wrong precedence or a resettable trial destroys the business model, and a non-compliant paywall blocks App Review (Guideline 3.1.2 requirements are documented rejection territory[^50][^51][^45]). The module must work fully offline after first resolution (cached entitlement, offline-first product), and must never contact any non-Apple server — there is no Makhtoot backend in v1 (D-113: on-device verification; App Store Server API is an extension seam only).

## 2. Scope

**IN:**
- `MKStore` target: `MKProductCatalog` (load/cache 3 products), `MKPurchaseController` (purchase/restore flows), `MKEntitlementResolver`, `MKTrialManager`, `MKPaywallStateMachine` (state only — UI in WS-13), grace/billing-retry state surfacing, `Makhtoot.storekit` config file, sandbox test plan, Referral submodule (compiled, inert), review-risk memo, App Store Server API extension-seam documentation.
- Entitlement change broadcasting (`AsyncStream<MKEntitlementState>`) consumed by MKFonts/MKExport/MKSync/app UI.
- Offline caching of last-known entitlement with staleness policy.

**OUT:**
- Paywall/settings SwiftUI rendering (WS-13/WS-12 render; this packet defines view-state structs + strings), App Store Connect product creation (WS-15 + FOUNDER), receipt server / backend (does not exist in v1), price localization work (Apple storefront tiers handle it — BRIEF), Family Sharing election (FD-06 founder decision — document both branches, hardcode nothing irreversible), any activation of referral (FD-05).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream:** `MKFoundation` only (D-101 dependency rule; see FOUNDATION §2 — `MKStore` depends on MKFoundation alone). Keychain/iCloud-KVS access wrapped in `MKSecureStore` utilities inside MKStore (kept out of MKFoundation to keep it dependency-free).

**Stub strategy (this packet RETIRES the stub):** `MKFoundation` defines `MKEntitlementProviding` (`var current: MKEntitlementState`, `func states() -> AsyncStream<MKEntitlementState>`, `var isPremium: Bool`). WS-08/09/11/12/13 were built against `AlwaysPremiumEntitlementStub`. Task T16 swaps the app-composition root to the real resolver and deletes the stub from production wiring (keep it for tests only, renamed `TestEntitlementStub`). Also ship `SandboxScenarioStub` presets (`free`, `trialDay3`, `expired`, `grace`, `billingRetry`, `lifetime`) for UI previews and TEST_MATRIX runs.

**Downstream consumers:** WS-08 export gating (D-118/119 free matrix), WS-09 font locks (T17 there), WS-11 sync gate, WS-12 subscription-management settings UI, WS-13 paywall + onboarding trial-start moment, WS-15 submission checklist (paywall compliance evidence).

## 4. Locked decisions binding this packet

- **D-113**: "lifetime > subscribed > grace > billingRetry > trial > free. Grace/billingRetry retain premium + banner. Single source: `MKEntitlementResolver` observing `Transaction.currentEntitlements` + `Product.SubscriptionInfo.Status`; on-device StoreKit 2 verification in v1 (Apple's JWS check via `VerificationResult`); App Store Server API integration is a documented extension seam, not v1 (no backend exists). Restore purchases mandatory UI."
- **D-123**: "app-side 7-day trial from first launch for everyone; persisted in Keychain (`kSecAttrAccessibleAfterFirstUnlock`, survives reinstall) + mirrored to iCloud KVS; earliest timestamp wins across devices; clock-rollback guard (monotonic check, never extends). No App Store Connect introductory offer in v1… Trial state machine: `active(daysLeft)` → `expired`."
- **D-124**: "`MKStore/Referral` module compiled but inert without `MKFeatureFlags.referralProgram`. Design: referrer-only reward, +7 days trial per qualifying event, local code generation + manual code entry attribution (no server in v1 → attribution is honor-based code exchange, documented weakness), abuse caps (max 4 extensions), full review-risk memo, removal = delete folder + flag. Must be reconfirmed against current guidelines before any activation (FD-05)."
- **FD-06**: Family Sharing ON/OFF is an irreversible per-product setting[^46][^49] — founder decision; code must handle both.
- FOUNDATION §0: product ids, subscription group `Makhtoot Premium`, `referralProgram` flag defaults OFF.
- BRIEF monetization: $2.99/$29.99/$89.99 (mapped per D-216); trial starts at FIRST APP LAUNCH (Q37); post-trial free tier retains full editing minus premium functions (Q41).

## 5. Task breakdown (ordered)

**T1 — State types.** `MKEntitlementState` enum exactly matching the FOUNDATION glossary: `lifetime, subscribed(renewalInfo), inGracePeriod(until: Date?), inBillingRetry, trial(daysLeft: Int), free`. Derived helpers: `isPremium` (true for all but `free`), `bannerKind` (grace/billingRetry banners). `Sendable`, `Equatable`. **AC:** unit test proves precedence ordering comparator matches D-113 exactly.

**T2 — Product catalog.** `MKProductCatalog` actor loads the 3 products by id via `Product.products(for:)`; caches; exposes localized display price strings (Apple storefront localization — no custom currency code); retry with backoff on failure; offline → cached-or-empty with `catalogUnavailable` state (paywall must render gracefully without prices, showing the canonical offline-paywall string "يتطلب الاتصال بالإنترنت" — internet connection required; this corrects the prior packet-local variant string to PRD's canonical copy per DF-7). **AC:** works against `.storekit` file in unit tests; product ids come from one constants file `MKStoreIDs.swift` marked `// PLACEHOLDER-FD-01`; offline catalog-unavailable state renders exactly "يتطلب الاتصال بالإنترنت" (not a paraphrase).

**T3 — Purchase flow.** `MKPurchaseController.purchase(_ product:)`: `product.purchase()` → handle `.success(VerificationResult)` (JWS-verify via `checkVerified` helper; unverified ⇒ `MKStoreError.failedVerification`, never grant), `.userCancelled` (silent), `.pending` (Ask-to-Buy: surface `pendingApproval` state with Arabic message "بانتظار موافقة العائلة"). Finish transactions after granting. Pseudocode:
```
switch try await product.purchase() {
case .success(let vr):
  let txn = try checkVerified(vr)       // throws on unverified JWS
  await resolver.refresh()
  await txn.finish()
case .pending: state = .pendingApproval
case .userCancelled: break
}
```
**AC:** all cases handled; no entitlement granted on unverified result; StoreKit-testing purchase test passes for all 3 products.

**T4 — Transaction listener.** Long-lived `Transaction.updates` listener started at app bootstrap (renewals, revocations, Ask-to-Buy completions, Family Sharing revocation `revocationDate`); each update re-runs resolution and finishes the transaction. Revocation-mid-export rule (D-228, resolves the prior "document which" TODO on this behavior): a revocation event that arrives while WS-08 has an export already rendering does NOT cancel that in-flight export — it completes; the NEXT export request re-evaluates entitlement and is gated normally against the now-downgraded state (mirrors R-21.55's existing rule for expiry-mid-export, extended to revocation). **AC:** simulated renewal + refund in StoreKit testing flips state without relaunch; simulated revocation fired mid-export (WS-08 integration test) lets the in-flight export finish and blocks the next export attempt.

**T5 — Entitlement resolver.** `MKEntitlementResolver` (actor, conforms to `MKEntitlementProviding`): resolution algorithm —
```
func resolve() async -> MKEntitlementState {
  if hasVerified(nonConsumable: lifetimeID) → .lifetime
  status = subscription group status (Product.SubscriptionInfo.Status)
  switch highest(status):
    case .subscribed → .subscribed
    case .inGracePeriod → .inGracePeriod(until: renewalInfo.gracePeriodExpirationDate)
    case .inBillingRetryPeriod → .inBillingRetry
    default: break
  if trialManager.state == .active(d) → .trial(daysLeft: d)
  return .free
}
```
Broadcast on change via `AsyncStream`; cache last state in a local file (not Keychain — non-secret) for instant offline startup, marked with resolution timestamp; re-resolve on foreground + on `Transaction.updates`. **AC:** precedence test suite covers the REALIZABLE 3-axis matrix (D-228/R2-11-4 — corrects the prior "6×6 dominance cases" framing, which implied a full cross-product of independent 6-value axes that don't actually exist as independent states): axis 1 = lifetime owned (bool), axis 2 = subscription state (none/subscribed/inGracePeriod/inBillingRetry/expired), axis 3 = trial state (active/expired) — exercised in the realizable combinations only, explicitly including `trial+billingRetry` and `trial+expired-sub` (DF-8), plus `lifetime+expired-sub ⇒ lifetime` and `grace+trial ⇒ grace`; cold-offline launch yields cached state in <50 ms SCOPED to post-first-resolution launches only (i.e. after at least one successful resolution has been cached — the very first launch, with no cache yet, is not held to the 50 ms budget since it may need a StoreKit round-trip).

**T6 — Trial manager (D-123; clock guard hardened per D-224).** `MKTrialManager`: on first launch, if no record exists in Keychain (`kSecAttrAccessibleAfterFirstUnlock`, `kSecAttrSynchronizable = false`) nor iCloud KVS (`NSUbiquitousKeyValueStore`), write `trialStart = now` to both. Reconciliation rule: earliest timestamp wins across the two stores and across devices (KVS sync callback merges). Clock guard — terminology corrected per D-224 from "monotonic guard" to "wall-clock high-water mark + uptime cross-check" (the old name described only half the mechanism): persist `maxObservedNow` (wall-clock high-water mark); if `now < maxObservedNow - tolerance(6h)` treat effective-now as `maxObservedNow` (rollback can never extend trial). ADDITIONALLY wire the reserved `lastObservedBoottime` field (D-224): on every observation, compute elapsed time since first launch two ways — uptime-anchored (`ProcessInfo.systemUptime` now minus systemUptime at first launch, immune to wall-clock changes within one boot session) and wall-clock-anchored (wall-clock now minus `trialStart`); if uptime-elapsed exceeds wall-clock-elapsed beyond tolerance, treat uptime-elapsed as AUTHORITATIVE for trial aging (catches a rollback sustained across the whole boot session, which the high-water mark alone cannot). Residual gap, recorded honestly per D-224/D-211 (not chased further in v1): a reboot preceded by a system clock rollback still evades both guards. State: `active(daysLeft: 7 - elapsedDays)` → `expired`. Keychain record survives reinstall by design. **AC:** unit tests with injected clock — rollback never increases daysLeft; reinstall simulation (clear UserDefaults, keep Keychain fake) preserves expiry; KVS-earlier-date wins test; day boundary uses launch-time calendar in UTC (document choice); NEW uptime-cross-check test — simulate wall-clock rolled back mid-session while `systemUptime` keeps advancing normally, assert uptime-elapsed wins and daysLeft does not appear to increase; sustained pre-launch rollback within a single boot session is caught (reboot+rollback before that boot remains the documented residual).

**T7 — Trial/intro-offer divergence doc.** Write `Docs/TrialModel.md` inside the module documenting: app-side trial (everyone, first launch, reinstall-proof) vs Apple introductory offers (per-Apple-ID, per-subscription-group, `isEligibleForIntroOffer`[^43][^44]); why v1 uses app-side only (D-123: avoids double-trial/eligibility divergence); consequence: App Store product pages must NOT claim an Apple free-trial offer; paywall copy says "٧ أيام مجانًا داخل التطبيق" framing. **AC:** doc exists; APP_STORE_CHECKLIST cross-ref noted.

**T8 — Restore purchases.** `restore()` = `AppStore.sync()` + re-resolve; mandatory UI hook (D-113; Guideline 3.1.2(c) requires a restore mechanism[^45][^47]). Distinct result states: restored-premium, nothing-to-restore ("لا توجد مشتريات سابقة"), failed. **AC:** state machine test; sandbox restore verified in test plan.

**T9 — Grace / billing-retry UX states.** Banner contract: `inGracePeriod` ⇒ premium retained + banner "توجد مشكلة في الدفع — جدّد وسيلة الدفع للاستمرار" with deep link `https://apps.apple.com/account/subscriptions`; `inBillingRetry` ⇒ premium retained + stronger banner. Exact grace-period durations are Apple-side and **VERIFY-AT-SUBMISSION** (market study flags ~16 days as third-party guidance, not authoritative[^43]); never hardcode a duration in copy. **AC:** banner states emitted correctly from resolver in StoreKit-testing grace/billing simulations.

**T10 — Paywall state machine + compliance requirements.** `MKPaywallStateMachine`: contexts (`onboardingTrialIntro`, `trialExpired`, `premiumFeatureTap(feature)`, `settingsUpsell`), states (`browsing`, `purchasing(product)`, `pendingApproval`, `success`, `failed(error)`, `dismissed`). Compliance requirements encoded as invariants the WS-13 UI must satisfy (list them in `PaywallRequirements.md`): visible close/dismiss control always; price + period + "auto-renews, cancel anytime in Settings" adjacent to CTA; both sub options + lifetime shown with localized prices; links to Privacy Policy + Terms (EULA) inside the binary; paywall never before first app content (onboarding shows content first per market study §8 guidance[^50][^51][^45]); no countdown/urgency dark patterns[^51]; free tier remains genuinely usable (Q41). **AC:** state machine unit-tested; requirements doc enumerated with checklist ids `PW-01…PW-10` referenced by WS-13 and APP_STORE_CHECKLIST.

**T11 — `.storekit` configuration.** `Makhtoot.storekit` file: subscription group `Makhtoot Premium` with monthly $2.99-tier / annual $29.99-tier (placeholders matching $3/$30 intent — exact tier is ASC-side), lifetime non-consumable $89.99-tier; no introductory offers configured (D-123); Family Sharing left OFF in the config with comment `// FD-06 FOUNDER DECISION — irreversible in ASC`. **AC:** Xcode scheme uses the file for debug; all StoreKit unit tests run against it.

**T12 — Sandbox test plan hooks.** `Docs/SandboxTestPlan.md`: numbered scenarios mapping to TEST_MATRIX `T-store-*`: purchase monthly/annual/lifetime; upgrade/crossgrade within group; cancel → expiry; billing-retry + grace via StoreKit-testing "Fail renewals"; refund/revocation; Ask-to-Buy; restore on second device; offline cached entitlement; trial expiry day-boundary; lifetime-overrides-everything. Each scenario lists preconditions, sandbox/StoreKit-testing steps, expected `MKEntitlementState`. **AC:** doc complete; at least the StoreKit-testing-automatable subset implemented as XCTests.

**T13 — Store error taxonomy.** `MKStoreError`: `failedVerification, purchaseFailed(underlying), catalogUnavailable, restoreFailed, pendingApproval, networkRequired` — Arabic LocalizedError messages. **AC:** exhaustive tests; no raw StoreKit errors surface to UI.

**T14 — Referral submodule (D-124 design; dormancy mechanism now COMPILE-TIME per D-225, FOUNDER-CONFIRMED 2026-07-17 — supersedes the runtime-flag-only approach below).** `Sources/MKStore/Referral/` — self-contained folder whose entire contents, AND every call site (including the app target's `ReferralSection.swift`), are wrapped in `#if MAKHTOOT_REFERRAL_ENABLED`, a compilation condition defined ONLY in Debug/internal build configurations — never in Release. Components (compiled only under the flag): `MKReferralCodeGenerator` (offline code = base32(hash(installUUID + salt)), 8 chars, prefix `MK-`); `MKReferralRedemption` (manual entry of a friend's code; honor-based local attribution — documented weakness: no server ⇒ cannot verify invitee action; qualifying event recorded locally as `codeEntered` v1-design placeholder for a real qualifying action); `MKReferralLedger` (Keychain-persisted: codes redeemed against me, extensions granted, cap `maxExtensions = 4` ⇒ max +28 days); trial extension API `TrialManager.extend(by: 7, source: .referral)` — the ONLY caller, itself only reachable inside the `#if`. Referral-specific Arabic strings (دعوة / إحالة / رمز الدعوة vocabulary) move OUT of the shared `Localizable.xcstrings` into literals or a separate catalog also gated by the same `#if` — they must not exist in the Release string table at all. Anti-abuse (when compiled in): self-code rejected; one redemption per unique code; cap enforced; extensions never revive an `expired` trial older than 30 days (design constant). **AC:** a Release-configuration build contains ZERO referral symbols AND zero referral strings (verified by T15's CI check, not by manual inspection); a Debug/internal build with `MAKHTOOT_REFERRAL_ENABLED` set enforces cap + self-referral + duplicate rules; a Debug build WITHOUT the flag compiles clean with the folder present but fully excluded (compiled out, not merely runtime-disabled).

**T15 — Referral review-risk memo + attribution design + Release-exclusion CI check.** `Sources/MKStore/Referral/REVIEW_RISK_MEMO.md`: cite market study §8 — Apple rejection precedent: rewarding the *invitee* for download/registration is documented rejection territory; rewarding only the referrer on a qualifying action is the acceptable pattern[^53][^54]; risk inferred from Guideline 3.1.1/3.2.2 precedent, not a single quoted rule[^55] — **VERIFY-AT-SUBMISSION / FD-05 reconfirmation required before activation**. Attribution design section: v1 honor-based code exchange (no server), upgrade path = App Store Server API + backend (extension seam). Release-exclusion CI check (D-225 — replaces the prior manual "removal procedure"; dormancy is compile-time exclusion, not a delete-the-folder step): extend the `referral-removal-check` CI job to grep the built RELEASE binary/product for referral vocabulary (دعوة، إحالة، رمز الدعوة) and FAIL the build if any is found — this is the actual proof that `#if MAKHTOOT_REFERRAL_ENABLED` excludes both code and strings from what ships, rather than trusting the `#if` alone. **AC:** memo complete with citations; CI check fails on a deliberately-broken build (flag leaked into Release) and passes on a clean Release build; the Release-configuration grep is run as its own control case distinct from any Debug/internal build with the flag ON.

**T16 — Composition-root swap (retire the stub).** Replace `AlwaysPremiumEntitlementStub` with `MKEntitlementResolver` in the app's dependency container; move stub to test support as `TestEntitlementStub`; verify WS-08 export gating, WS-09 font locking, WS-11 sync gating all react to real states via the shared `AsyncStream`. **AC:** grep shows no production reference to the stub; integration test: simulate expiry ⇒ fonts lock (WS-09 T17) + export matrix downgrades (WS-08) in one propagation.

**T17 — Offline behavior & staleness.** Cached entitlement honored offline indefinitely for `lifetime`; for `subscribed`, honor cache but re-resolve opportunistically; never downgrade solely because offline (StoreKit's local transaction cache is authoritative on-device). Document in module README with PRD §19 cross-ref. **AC:** airplane-mode launch keeps premium; no network calls except StoreKit's own.

**T18 — App Store Server API extension seam.** `Docs/ServerAPISeam.md`: what a future backend adds (server-side receipt validation, referral qualifying events, refund observability), which protocols (`MKEntitlementProviding`) stay stable. No code. **AC:** doc exists; referenced by ARCHITECTURE §18/§24.

**T19 — Post-lifetime-purchase redundant-subscription sheet (new task, D-228).** On a successful `.lifetime` purchase while the resolver's PRIOR state was `subscribed`/`inGracePeriod`/`inBillingRetry` (i.e. the user already had an active-or-recovering subscription), immediately present a ONE-TIME sheet — not merely a Settings string — prompting the user to cancel the now-redundant subscription, with a direct manage-subscriptions link (`https://apps.apple.com/account/subscriptions`). This is a P0 requirement: without it, a lifetime buyer with an existing subscription keeps paying for both. Sheet fires exactly once per qualifying purchase event (not on every launch). **AC:** StoreKit-testing scenario — purchase lifetime while a monthly/annual subscription is active/grace/billingRetry — triggers the sheet with a working manage-subscriptions link; purchasing lifetime from `free`/`trial` (no prior subscription) does NOT trigger the sheet; sheet does not re-fire on subsequent launches.

## 6. Compliance & licensing notes

- Guideline 3.1.2 paywall requirements — title/length/price in-binary, Privacy Policy + Terms links, restore mechanism: market study [^45][^47][^50][^51][^52]. Encoded as PW-01…PW-10 invariants (T10).
- Subscription + lifetime coexistence is an Apple-approved pattern [^45][^47]; lifetime buyers must never be re-charged and restore must recover it [^47].
- Family Sharing: only auto-renewables + non-consumables eligible; ON is irreversible per product [^46][^48][^49] — FD-06, do not set in ASC without founder sign-off (WS-15 checklist).
- Referral: rejection precedent for invitee incentives [^53][^54]; inferred from 3.1.1/3.2.2, not an explicit clause [^55] — flag stays OFF (D-124/FD-05); **VERIFY-AT-SUBMISSION** current guideline text.
- Grace-period exact durations: **VERIFY-AT-SUBMISSION** (BRIEF known-gaps list; [^43] is third-party guidance).
- App-side trial is not an Apple introductory offer — marketing/App Store copy must not claim an Apple trial (T7); no ATT implications (no tracking; see WS-12).

## 7. Packet acceptance criteria (gates)

1. **Build gate:** module + tests green, Swift 6 strict, StoreKit-testing suite passes on `Makhtoot.storekit`.
2. **StoreKit sandbox gate (TEST_MATRIX `T-store-*`):** T-store-01 purchase each product; T-store-02 restore; T-store-03 precedence matrix over the realizable 3-axis space (D-228/R2-11-4) incl. lifetime dominance; T-store-04 grace/billing-retry banners; T-store-05 trial persistence across reinstall (device test); T-store-06 wall-clock-high-water-mark + uptime-cross-check guard (D-224); T-store-07 Ask-to-Buy pending; T-store-08 offline entitlement; T-store-09 post-lifetime-purchase redundant-subscription sheet (T19, D-228); T-store-10 revocation-mid-export completion (T4, D-228).
3. **Manual Arabic checks:** all store-facing strings render RTL correctly; price strings show Apple-localized currency; banners readable on iPhone SE-class width; offline paywall string is the exact canonical "يتطلب الاتصال بالإنترنت" (DF-7).
4. **Compliance gate:** PW-01…PW-10 checklist signed off against the WS-13 paywall build; REVIEW_RISK_MEMO present; no introductory offer configured anywhere; Release-build referral-vocabulary grep (T15, D-225) passes clean.
5. **Stub retirement:** T16 integration test green.

## 8. Deliverables

- `MakhtootKit/Sources/MKStore/**` (catalog, purchase, resolver, trial, paywall state machine, errors, Referral/ folder gated by `#if MAKHTOOT_REFERRAL_ENABLED`).
- `Makhtoot.storekit`, `Docs/TrialModel.md`, `Docs/SandboxTestPlan.md`, `Docs/PaywallRequirements.md` (PW-ids), `Docs/ServerAPISeam.md`, `Referral/REVIEW_RISK_MEMO.md`.
- Unit + StoreKit-testing test suites; `TestEntitlementStub` + `SandboxScenarioStub` presets; CI `referral-removal-check` Release-grep job (T15).
- Composition-root wiring change in app target.

## 9. References

- FOUNDATION.md §8 (D-113/123/124/125), §0 ids/flags, §10 FD-05/FD-06.
- ARCHITECTURE.md: §18 StoreKit & Entitlements; §19 Trial & Referral; §24 Extension Seams (v2); §23 Security & Privacy.
- PRD.md: §14 Free/Premium Gating & Paywall; §15 Trial/Subscription/Lifetime States; §16 Referral (flagged); §19 Offline Behavior.
- APP_STORE_CHECKLIST.md: paywall compliance section; IAP setup section; Family Sharing FD-06 item; referral risk item.
- Market study §8 (StoreKit/App Review), §10 pricing; footnotes [^43]–[^55].
- TEST_MATRIX.md `T-store-*`.

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS-10-A1: on-device JWS verification only in v1 (no server) — risks + seam"; "WS-10-A2: app-side trial vs intro offer decision consequences"; "WS-10-A3: entitlement cache file format + staleness policy"; "WS-10-A4: referral compile-time exclusion via `#if MAKHTOOT_REFERRAL_ENABLED` + Release-grep CI check (D-225, supersedes the earlier runtime-flag-only design)".
- Implementation logs per task T1–T19 with test evidence (StoreKit-testing screenshots/transcripts for sandbox scenarios).
- Verification evidence: attach T-store-01…10 sandbox run results, the 3-axis precedence matrix test output, and the PW checklist sign-off; log FD-05/FD-06 as open founder decisions with pointers.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| $3/mo, $30/yr, $90 lifetime; Apple storefront price localization everywhere | T2, T11 |
| 7-day trial from first launch, monthly + annual, reinstall-proof; app-side vs intro-offer doc (Q37) | T6, T7 |
| Post-trial free tier: full editing retained, premium functions blocked (Q41) | T1, T5 |
| Lifetime = permanent premium | T1, T5 |
| Referral flow: architected, isolated via compile-time exclusion from Release, default OFF (Q78, mechanism per D-225) | T14, T15 |
| Full StoreKit 2: status, restore, precedence, grace period, billing retry, expiration/cancellation messaging, sandbox testing, on-device verification vs Server API | T3, T4, T5, T8, T9, T12, T18 |
| Engineering gates: StoreKit sandbox tests (Q59) | T12 |
| Known research gap: exact Apple grace-period durations — verify at implementation | T9 |
| Entitlement UX closures: post-lifetime redundant-subscription sheet; revocation-mid-export completes; trial not consumed by purchase (D-228) | T4, T19 |
| Trial clock guard hardened: wall-clock high-water mark + uptime cross-check (D-224) | T6 |
