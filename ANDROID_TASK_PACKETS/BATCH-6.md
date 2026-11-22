# BATCH-6 — Commerce, sync, analytics, font catalog

Batch 6 of 10 (spine §5). Dispatch the 6 assignments concurrently. Depends on **G5** and gates at **G6**
(`bash Scripts/android/gate.sh 6`).

Ports `MKStore` (1,668 LOC), `MKSync` (1,945 LOC), `MKAnalytics` (1,004 LOC), and the
premium-catalog slice of `MKFonts` (963 LOC of the target's 2,480) from the shipped Swift
source into `:mk-store`, `:mk-sync`, `:mk-analytics`, and `:mk-fonts` respectively. Every
Swift file named below was read in full (`wc -l`) before this port map was written — no
placeholders.

All four modules are networking-capable per D-304/R-19.1 (only `MKFonts`, `MKSync`,
`MKAnalytics` — plus `MKStore`'s StoreKit-equivalent billing calls — may own networking
code); every other module stays offline-only, unchanged from Batch 1–5.

**`:mk-sync` is split into two agents (spine §5.2).** The parent `MKSync` port owned
1,945 source + 1,321 test LOC including an 841-LOC engine controller rewritten onto a new
Drive transport — not one unit of work. **6.3a** owns the Drive transport (auth, REST
client, resumable upload, `changes.list`/`startPageToken`, `appProperties`, WorkManager
scheduling, 403-quota backoff). **6.3b** owns the policy port, which carries over from iOS
essentially unchanged: `MkSyncDecisionEngine`, `MkConflictNaming`, `MkSyncPendingQueue`,
`MkProjectRecordCoder`, `MkSyncSchema`, `MkSyncStatus`, `MkSyncAccountState`,
`MkSyncError`, `MkSyncTunables`. A citation of "6.3" without a suffix in older material
means "6.3a and 6.3b together."

Ground rules (spine §4) apply unchanged: exclusive file ownership, green
`testDebugUnitTest`+`lintDebug` before done, zero `check-no-stubs.sh` regressions, stub
count published and driven toward 0, contract-first (no cross-module public-API edits —
route through `android/docs/CONTRACT_CHANGES.md`), tests ported alongside behavior, impl
log per agent.

**Frozen convention (all six agents):** `android/*/build.gradle.kts` and
`android/gradle/libs.versions.toml` are Batch 1.1-owned and stay frozen through Batch 8 —
Batch 1.1 already declared the D-304 JVM dependencies each module needs (Play Billing,
AndroidX Security-Crypto, DataStore, WorkManager, OkHttp, kotlinx-serialization). No Batch
6 agent edits a build file; a genuinely missing dependency is appended to
`android/docs/CONTRACT_CHANGES.md` for the gate to apply, per ground rule 5.

---

### Batch 6 · Agent 6.1 — `mk-store` Play Billing, entitlement resolver, precedence, paywall state

**Depends on:** G5 · **Parallel-safe with:** every other Batch 6 agent

**Mission.** Replace the Batch 1.4 `mk-store` contract stubs for the billing/entitlement/
paywall surface with real Google Play Billing 7+ implementations: product catalog,
purchase controller (incl. mandatory 72-hour acknowledgement), entitlement resolver +
precedence, paywall state machine, and the six sandbox scenario stubs, per D-311.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKStore/MKProductCatalog.swift` (135 LOC) | Product loading contract to port |
| `MakhtootKit/Sources/MKStore/MKPurchaseController.swift` (133 LOC) | Purchase/restore flow to port |
| `MakhtootKit/Sources/MKStore/MKEntitlementResolver.swift` (290 LOC) | `Transaction.currentEntitlements` + `SubscriptionInfo.Status` observer this agent replaces with a Play equivalent |
| `MakhtootKit/Sources/MKStore/MKEntitlementPrecedence.swift` (74 LOC) | The pure D-113 precedence function — ports with a straight `Sendable` enum translation, no logic change |
| `MakhtootKit/Sources/MKStore/MKEntitlementDetail.swift` (69 LOC), `MKStoreError.swift` (60), `MKStoreIDs.swift` (37), `Verification.swift` (16) | Supporting types/ids/verification seam |
| `MakhtootKit/Sources/MKStore/Paywall/MKPaywallStateMachine.swift` (102 LOC) | Paywall state machine to port unchanged in shape |
| `MakhtootKit/Sources/MKStore/Testing/MKSandboxScenarioStub.swift` (67 LOC) | The six `Scenario` cases (`free`, `trialDay3`, `expired`, `grace`, `billingRetry`, `lifetime`) to re-key to Play test-product ids |
| `MakhtootKit/Tests/MKStoreTests/{MKEntitlementResolverTests,MKEntitlementPrecedenceTests,MKPaywallStateMachineTests,MKStoreErrorTests,MKPurchaseControllerTests,MKProductCatalogTests,GatingIntegrationTests,StoreKitTestSupport}.swift` | Tests to port |
| `PRD.md` §14.2 (R-14.10…R-14.17), §15.1 (R-15.1…R-15.4, R-15.11…R-15.13) | Paywall/entitlement product requirements |
| `FOUNDATION.md` §8 (D-113) | Entitlement precedence, on-device-only verification |
| `TEST_MATRIX.md` §12 T-SK-1…13, T-SK-18, T-SK-19, T-SK-21 | Tests this agent's Kotlin suite must have equivalents for |
| `ANDROID_SPINE.md` §1 FDA-05, §2 D-311 | Play product ids, precedence-to-Play-signal mapping |
| `android/mk-store/src/main/kotlin/.../store/*.kt` (Batch 1.4 stubs) | Existing `MkNotYetPorted` bodies this agent replaces |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (see Tasks, final item).
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkProductCatalog.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkPurchaseController.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementResolver.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementPrecedence.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementDetail.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkStoreIds.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkStoreError.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkVerification.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/paywall/MkPaywallStateMachine.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/billing/MkBillingClientLifecycle.kt` (new — no Swift analogue, see Tasks §3)
- `android/mk-store/src/debug/kotlin/net/binjamshid/makhtoot/mk/store/testing/MkSandboxScenarioStub.kt` (`#if DEBUG` → Android `debug` source set)
- `android/mk-store/src/debug/kotlin/net/binjamshid/makhtoot/mk/store/testing/MkTestEntitlementStub.kt`
- `android/mk-store/src/test/kotlin/net/binjamshid/makhtoot/mk/store/*Test.kt` (one per file above, plus `MkBillingClientLifecycleTest.kt`, `MkAcknowledgePurchaseTest.kt` — new, no Swift analogue)
- `android/docs/impl-log/BATCH-6.1.md`

**Never touch.** `android/mk-store/.../trial/**`, `android/mk-store/.../referral/**` (Agent
6.2); `:mk-sync`, `:mk-analytics`, `:mk-fonts` (Agents 6.3a/6.3b–6.5); any `build.gradle.kts`
or `libs.versions.toml` (frozen, see header); `android/mk-persistence/**`,
`android/mk-model/**` (Batch 3, frozen).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKProductCatalog.swift` | 135 | `store/MkProductCatalog.kt` | `Product.products(for:)` → `BillingClient.queryProductDetailsAsync` for `INAPP` (`net.binjamshid.makhtoot.premium.lifetime`) + `SUBS` (`net.binjamshid.makhtoot.premium`, base plans `monthly`/`annual`, FDA-05); localized price strings from `ProductDetails.OneTimePurchaseOfferDetails`/`SubscriptionOfferDetails`, never hardcoded, mirroring R-14.10. |
| `MKPurchaseController.swift` | 133 | `store/MkPurchaseController.kt` | `launchBillingFlow` replaces `Product.purchase()`; `PurchasesUpdatedListener` replaces `Transaction.updates`; **every** successful purchase (INAPP and SUBS) must call `acknowledgePurchase()` — see Tasks §2. Restore = `queryPurchasesAsync` over both product types (R-14.13, T-SK-7). |
| `MKEntitlementResolver.swift` | 290 | `store/MkEntitlementResolver.kt` | Replaces `Transaction.currentEntitlements`/`SubscriptionInfo.Status` observation with `queryPurchasesAsync` + `PurchasesUpdatedListener` feeding `MkEntitlementPrecedence.resolve(...)`. See Tasks §1 for the full six-state mapping table — this is the file where the mapping lives. |
| `MKEntitlementPrecedence.swift` | 74 | `store/MkEntitlementPrecedence.kt` | Pure function, ports near-verbatim: `MKSubscriptionSignal` (`none`/`subscribed`/`inGracePeriod`/`inBillingRetry`/`expired`) and `MKTrialState` become Kotlin sealed classes/enums; the D-113/D-228 ordering logic (lifetime dominates unconditionally; only `.none`/`.expired` subscription states let trial vote) is copied unchanged — this is the one file in the module with zero StoreKit/Billing dependency on either platform. |
| `MKEntitlementDetail.swift` | 69 | `store/MkEntitlementDetail.kt` | Data class port; `renewalInfo`/`gracePeriodExpiration`/`activeProductID` fields unchanged in meaning. |
| `MKStoreError.swift` | 60 | `store/MkStoreError.kt` | Sealed class; Play `BillingResult.responseCode` cases (`USER_CANCELED`, `SERVICE_DISCONNECTED`, `ITEM_ALREADY_OWNED`, `NETWORK_ERROR`, …) map onto the same Arabic-facing error taxonomy the Swift type already defines. |
| `MKStoreIDs.swift` | 37 | `store/MkStoreIds.kt` | **Not a verbatim port (FDA-05 correction).** Play base-plan ids may contain only lowercase letters, digits and hyphens — no dots — so the iOS dotted ids `net.binjamshid.makhtoot.premium.monthly`/`.annual` cannot be created as Play base-plan ids at all. Android instead ships ONE `SUBS` product, `net.binjamshid.makhtoot.premium`, with two base plans named plainly **`monthly`** and **`annual`** (mirrors iOS's monthly/annual terms, not iOS's dotted id spelling); lifetime alone ports its dotted id verbatim as the `INAPP` product `net.binjamshid.makhtoot.premium.lifetime`. Note the shape difference: StoreKit models monthly/annual as two sibling products in one subscription group; Play Billing 7 models them as two base plans of ONE subscription product — `MkStoreIds` must expose the `SUBS` product id and the two bare base-plan ids (`monthly`/`annual`) separately so `MkProductCatalog` queries correctly. The Android subscription product id has no iOS counterpart in `MKStoreIDs.swift` at all, so the planned Android sibling of `Scripts/check-storekit-ids.sh` compares deliberately non-identical id sets across platforms — document that in the impl log rather than treating a mismatch as a bug. |
| `Verification.swift` | 16 | `store/MkVerification.kt` | On-device only, no backend (D-311): RSA signature check of `Purchase.getOriginalJson()`/`getSignature()` against the Play Console licensing public key (`BillingClient` does NOT verify signatures for you — this is the direct analogue of StoreKit 2's JWS `VerificationResult` check, and unlike JWS it is 100% this agent's responsibility to implement, not a library guarantee). |
| `Paywall/MKPaywallStateMachine.swift` | 102 | `store/paywall/MkPaywallStateMachine.kt` | State shape (`idle`/`loading`/`purchasing`/`pending`/`succeeded`/`failed`) ports unchanged; `.pending` now also covers Play's own async purchase-flow latency, not just StoreKit's `.pending` transaction state. |
| `Testing/MKSandboxScenarioStub.swift` | 67 | `debug/testing/MkSandboxScenarioStub.kt` + `MkTestEntitlementStub.kt` | Same six `Scenario` cases; re-keyed to Play Console License Testing test accounts / test product ids at G6 (Play has no local `.storekit`-config-file equivalent — see Acceptance). `#if DEBUG` → Android `debug` source set, mirroring the Swift file's own gate. |

**Tasks.**
1. **D-113 → D-311 six-state mapping table (the core of this agent).** Implement
   `MkEntitlementPrecedence.resolve(hasLifetime, subscription, trial)` exactly as ported,
   then feed it from `MkEntitlementResolver` using this mapping — and be explicit in code
   comments and the impl log about which signals are real vs. heuristic, since D-311
   forgoes a backend and Play does not expose grace/hold to the client the way StoreKit 2
   exposes `SubscriptionInfo.Status` directly:

   | D-113 state | Play signal | Availability |
   |---|---|---|
   | `lifetime` | `Purchase` for `.premium.lifetime`, `purchaseState == PURCHASED`, `isAcknowledged == true` | Client-side, reliable |
   | `subscribed` | `Purchase` for `.premium` (SUBS), `purchaseState == PURCHASED`, within its last-known valid period | Client-side, reliable |
   | `inGracePeriod` | Same `Purchase` still returned by `queryPurchasesAsync` PAST the locally-cached expected renewal timestamp — Play keeps returning a grace-period subscription as `PURCHASED` while it retries billing, but exposes no explicit "grace" flag to `BillingClient` | Client-side, **heuristic only**. A confirmed `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` requires the Play Developer API Subscriptions v2 endpoint, which is server-side and out of scope per D-311/D-304 ("no backend"). Document this gap plainly — it is real, not an oversight. |
   | `inBillingRetry` | The subscription `Purchase` DISAPPEARS from `queryPurchasesAsync` after having been present in a recent prior check (account hold) | Client-side, **heuristic only**, same caveat: a confirmed `SUBSCRIPTION_STATE_ON_HOLD` needs Subscriptions v2 server-side. |
   | `trial` | D-312 local trial record (Agent 6.2's `MkTrialManager`) | Client-side, app-owned, not a Play signal at all |
   | `free` | None of the above | — |

   This is a materially weaker signal set than StoreKit 2 on iOS, which surfaces
   `.inGracePeriod`/`.inBillingRetry` as first-class `Product.SubscriptionInfo.Status`
   values. Ship the heuristic, keep the D-113 precedence ordering intact regardless (grace
   and billing-retry still retain premium access exactly as iOS does — R-15.3), and record
   the gap in `android/docs/impl-log/BATCH-6.1.md` rather than silently matching iOS's
   confidence level.
2. **`acknowledgePurchase` within 72 hours (first-class work item, own tests).** Play
   auto-refunds any unacknowledged purchase — INAPP or SUBS — after 3 days. Every purchase
   path (initial purchase via `PurchasesUpdatedListener`, and every purchase surfaced by
   `queryPurchasesAsync` restore) must check `isAcknowledged` and call
   `BillingClient.acknowledgePurchase()` before granting/re-confirming entitlement. Write
   `MkAcknowledgePurchaseTest.kt` asserting: (a) a fresh unacknowledged purchase is
   acknowledged synchronously as part of the purchase-update handler, not deferred; (b) a
   purchase already acknowledged is never re-acknowledged (idempotent); (c) an
   acknowledgement failure is retried, not silently dropped (a dropped purchase here is a
   silent 72-hour countdown to an involuntary refund — treat it with the same severity as a
   shaping regression).
3. **`BillingClient` connection lifecycle and reconnection (first-class work item, own
   tests).** New file `billing/MkBillingClientLifecycle.kt` (no Swift analogue — StoreKit 2
   has no connection object): wraps `startConnection()`/`onBillingServiceDisconnected()`
   with exponential backoff reconnection (cap the backoff, cite the chosen ceiling in the
   impl log), exposes `isReady` to every other file in this agent's port map, and ensures
   `MkPurchaseController`/`MkEntitlementResolver` queue calls rather than crash when the
   connection drops mid-session. `MkBillingClientLifecycleTest.kt` drives a fake
   `BillingClient` through disconnect→reconnect and asserts backoff timing and that queued
   calls flush in order once reconnected.
4. **Restore = `queryPurchasesAsync` (mandatory UI, first-class work item).** Port
   `MKPurchaseControllerTests.swift`'s restore-path assertions; the restore action must
   query both `INAPP` and `SUBS` product types, re-run entitlement resolution, and be
   reachable from both the paywall and Settings per R-14.13 (ported into Batch 7.8's
   `MkSettingsRootView`/subscription section — this agent only owns the controller method,
   not the UI call site).
5. Port `MKEntitlementResolverTests.swift`, `MKEntitlementPrecedenceTests.swift`,
   `MKPaywallStateMachineTests.swift`, `MKStoreErrorTests.swift`,
   `MKPurchaseControllerTests.swift`, `MKProductCatalogTests.swift`,
   `GatingIntegrationTests.swift` to JUnit5 + a fake `BillingClient` test double replacing
   `StoreKitTestSupport.swift`'s role (rename acknowledged in the port map — "StoreKit" in
   a filename has no meaning on Android; note the rename in the impl log per the naming
   rule's spirit).
6. Port the six `MKSandboxScenarioStub` scenarios to Play Console License Testing test
   accounts/products, cross-referenced against FDA-05's product ids; `MkTestEntitlementStub`
   ports as a plain mutable test double, `#if DEBUG`-gated → `debug` source set exactly as
   the Swift file is gated, per D-229(3)'s "can never end up in a Release composition root
   by accident" reasoning.
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-6.1.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-store:testDebugUnitTest` green
- `./gradlew :mk-store:lintDebug` green
- Requirements covered: R-14.10, R-14.11, R-14.12, R-14.13, R-14.14, R-14.15, R-15.1,
  R-15.2, R-15.3, R-15.4, R-15.11, R-15.12, R-15.13
- Tests ported: T-SK-1, T-SK-2, T-SK-3, T-SK-4, T-SK-5, T-SK-6, T-SK-7, T-SK-8, T-SK-9,
  T-SK-10, T-SK-11, T-SK-12, T-SK-13, T-SK-18, T-SK-19, T-SK-21 — re-run against Play
  License Testing accounts at G6 (Play has no local config-file equivalent to
  `Makhtoot.storekit`; T-SK's `[SANDBOX]` tag becomes "[PLAY-LICENSE-TESTING]" for this
  port, recorded in the impl log)
- Fixtures consumed: none — these are logic/billing-flow tests, not golden-fixture tests
- Stub count for `mk-store`'s billing/entitlement/paywall files reaches 0 (trial/referral
  stubs remain Agent 6.2's until that agent lands)

**Impl log.** `android/docs/impl-log/BATCH-6.1.md`

---

### Batch 6 · Agent 6.2 — `mk-store` trial, secure store, referral (debug-only source set)

**Depends on:** G5 · **Parallel-safe with:** every other Batch 6 agent

**Mission.** Port the app-side 7-day trial (D-312) and the compile-time-excluded referral
program (D-321) into `:mk-store`, disjoint from Agent 6.1's billing/entitlement files.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKStore/Trial/MKClockProviding.swift` (63 LOC) | Clock abstraction seam |
| `MakhtootKit/Sources/MKStore/Trial/MKSecureStore.swift` (117 LOC) | Keychain wrapper this agent replaces with an unencrypted, HMAC-signed store (D-312 correction — see Port map; NOT Keystore-wrapped) |
| `MakhtootKit/Sources/MKStore/Trial/MKTrialManager.swift` (182 LOC) | Trial state machine + earliest-timestamp-wins merge logic |
| `MakhtootKit/Sources/MKStore/Trial/MKTrialRecord.swift` (64 LOC) | Persisted record shape |
| `MakhtootKit/Sources/MKStore/Trial/MKUbiquitousStore.swift` (65 LOC) | iCloud KVS mirror this agent replaces with Android Auto Backup (single-slot device-setup restore, not a live sync channel — see Port map) |
| `MakhtootKit/Sources/MKStore/Referral/MKReferralCodeGenerator.swift` (42 LOC), `MKReferralLedger.swift` (100), `MKReferralRedemption.swift` (52) | Dormant referral mechanic, D-124/D-225/D-321 |
| `MakhtootKit/Tests/MKStoreTests/MKTrialManagerTests.swift` (194 LOC), `ReferralTests.swift` (72 LOC) | Tests to port |
| `PRD.md` §15.2 (R-15.5…R-15.9), §16 (R-16.1…R-16.5) | Trial and referral product requirements |
| `FOUNDATION.md` §8 (D-123, D-124) | Original trial/referral decisions this agent's D-312/D-321 amend |
| `TEST_MATRIX.md` §12 T-SK-14…17, T-SK-20 | Tests this agent's Kotlin suite must have equivalents for |
| `ANDROID_SPINE.md` §2 D-312 | The corrected mechanism: unencrypted, HMAC-signed trial blob + Auto Backup — an AndroidKeyStore-wrapped blob is explicitly wrong (destroyed on uninstall, so Auto Backup would restore an undecryptable blob — zero reinstall survival, not "weaker than Keychain") |
| `ANDROID_SPINE.md` §2 D-321 | DataStore/Auto-Backup substitution, debug-only referral source set |
| `Scripts/referral-release-grep.sh` | The grep this agent's Android sibling script must mirror (script itself lives in `android/` and is owned by whichever Batch 1/9 agent scaffolds CI — this agent only makes the source layout it greps correct) |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (see Tasks §6).
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkClockProviding.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkSecureStore.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkTrialManager.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkTrialRecord.kt`
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkUbiquitousStore.kt`
- `android/mk-store/src/debug/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralCodeGenerator.kt`
- `android/mk-store/src/debug/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralLedger.kt`
- `android/mk-store/src/debug/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralRedemption.kt`
- `android/mk-store/src/test/kotlin/net/binjamshid/makhtoot/mk/store/trial/*Test.kt`
- `android/mk-store/src/test/kotlin/net/binjamshid/makhtoot/mk/store/referral/*Test.kt`
- `android/docs/impl-log/BATCH-6.2.md`

**Never touch.** `android/mk-store/.../{store root files, paywall, billing, testing}/**`
(Agent 6.1); `:mk-sync`, `:mk-analytics`, `:mk-fonts` (Agents 6.3a/6.3b, 6.4, 6.5); any
`build.gradle.kts` or `libs.versions.toml` (frozen, see header).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Trial/MKClockProviding.swift` | 63 | `trial/MkClockProviding.kt` | Interface ports unchanged; production conformer becomes `SystemClockProviding` reading both wall-clock (`System.currentTimeMillis()`) and `SystemClock.elapsedRealtime()` for the D-224-equivalent uptime cross-check (D-312 mirrors D-123's clock-rollback guard). |
| `Trial/MKSecureStore.swift` | 117 | `trial/MkSecureStore.kt` | **Corrected mechanism (D-312).** `kSecAttrAccessibleAfterFirstUnlock` Keychain → an **unencrypted, HMAC-signed** `DataStore<Preferences>` blob — NOT AndroidKeyStore-wrapped. An AndroidKeyStore key is destroyed on uninstall and Auto Backup never restores key material, so a Keystore-wrapped blob restored after reinstall would be permanently undecryptable — zero reinstall survival, a correctness bug, not merely "weaker than Keychain." The correct mechanism: sign the plaintext trial record with HMAC using a key embedded in the app binary (tamper-evident, an appropriate posture for a 7-day trial, not a secrecy guarantee); verify the signature on every read and reject a tampered blob. Same `read(key:)`/`write(key:value:)`/`delete(key:)` seam shape as the Swift `MKKeyValueStoring` protocol both this and `MKUbiquitousStore` conform to. |
| `Trial/MKTrialManager.swift` | 182 | `trial/MkTrialManager.kt` | Earliest-timestamp-wins merge across `MkSecureStore` + `MkUbiquitousStore` ports unchanged; the D-224 wall-clock-high-water-mark + uptime cross-check guard (never extends the trial on clock rollback) ports using `MkClockProviding`'s two readings. **"Earliest timestamp wins across devices" is deleted as a claim** (D-312): Auto Backup is a single-slot restore performed once at device setup, not a live sync channel, so there is no cross-device propagation at all — the merge only ever reconciles the local blob against a single restored-at-setup snapshot, never a second live device. |
| `Trial/MKTrialRecord.swift` | 64 | `trial/MkTrialRecord.kt` | `Codable` struct → `@Serializable` data class (kotlinx-serialization), same fields, plus the HMAC signature field the corrected `MkSecureStore` needs. |
| `Trial/MKUbiquitousStore.swift` | 65 | `trial/MkUbiquitousStore.kt` | `NSUbiquitousKeyValueStore` → Android Auto Backup, with the app's backup rules (`dataExtractionRules.xml` on Android 12+, `android:fullBackupContent` on Android 11 and below — both required at targetSdk 36, spine §11) restricted to EXACTLY the unencrypted HMAC-signed trial blob's DataStore file — no other app data is backed up through this path. `changeNotifications()`'s `AsyncStream` analogue: Auto Backup has no live cross-device change notification the way `NSUbiquitousKeyValueStore.didChangeExternallyNotification` does, and — per the corrected D-312 — no cross-device channel at all, live or otherwise; the merge instead re-runs opportunistically on process start and on-resume against whatever was restored once at device setup. Document this plainly in the impl log as "no cross-device propagation," not "weaker than iOS," per D-312's honesty requirement. |
| `Referral/MKReferralCodeGenerator.swift` | 42 | `referral/MkReferralCodeGenerator.kt` | Local Arabic-safe short-code generation, unchanged logic. |
| `Referral/MKReferralLedger.swift` | 100 | `referral/MkReferralLedger.kt` | Local ledger of qualifying events, unchanged; still honor-based (no server), same documented weakness as iOS. |
| `Referral/MKReferralRedemption.swift` | 52 | `referral/MkReferralRedemption.kt` | Manual code-entry redemption + the max-4-extensions abuse cap, unchanged. |

**Tasks.**
1. Port `MkClockProviding`/`MkTrialManager`/`MkTrialRecord` maintaining the exact
   D-123-derived state machine (`active(daysLeft)` → `expired`) and the earliest-wins merge
   rule against a single restored-at-setup snapshot (not a live cross-device merge — see Port
   map); the trial NEVER extends on a detected rollback (T-SK-17's Android equivalent).
2. Implement `MkSecureStore` as the **unencrypted, HMAC-signed** blob described in the Port
   map — embed the HMAC key in the app binary, sign on write, verify on read, reject and
   treat as absent on signature mismatch. Do NOT wrap the blob in an AndroidKeyStore cipher;
   that mechanism gives zero reinstall survival once Auto Backup restores a blob whose
   Keystore key no longer exists, which is the exact defect this correction removes.
3. Implement `MkUbiquitousStore` on Android Auto Backup and write the backup-rules XML
   (`dataExtractionRules.xml` + `fullBackupContent`, spine §11) scoping it to only the trial
   DataStore file (verify no other app-private file is swept into the same backup set — a
   broad backup rule here would be an unreviewed data exposure, not just a scope creep).
4. Document the D-312 honesty requirements explicitly in code comments on
   `MkUbiquitousStore`/`MkTrialManager`: (a) Auto Backup can be disabled by the user (device
   settings or backup quota), unlike iOS Keychain's `kSecAttrAccessibleAfterFirstUnlock`,
   which is unconditional; (b) Auto Backup is a single-slot restore performed once at device
   setup, not a live sync channel — there is no cross-device propagation at all, full stop,
   not merely a weaker version of it. State both plainly in the impl log as known, accepted
   platform gaps — never present either as equivalent to iOS.
5. Port `Referral/**` into the `debug` Gradle source set only (D-321 mirrors D-225's
   compile-time exclusion — not a runtime flag). Add the `buildConfigField("boolean",
   "REFERRAL_ENABLED", ...)` wiring this agent's files need (the `BuildConfig` field
   declaration itself is a `build.gradle.kts` edit and therefore goes in
   `android/docs/CONTRACT_CHANGES.md` for Batch 1.1/the gate to apply per the header
   convention — this agent's job is to make the `debug`-source-set code correct assuming
   that field exists).
6. Port `MKTrialManagerTests.swift` and `ReferralTests.swift` to JUnit5, adding: a
   Kotlin-only regression test asserting the `release` variant's compiled classes contain
   zero `referral` package references (the local equivalent of what
   `Scripts/referral-release-grep.sh` checks at the AAB level in Batch 9 — this agent's test
   is the unit-level early warning, not a replacement for that Batch 9 gate); and a
   `MkSecureStoreTamperTest.kt` asserting a mutated blob fails HMAC verification and is
   treated as no-trial-record-present, not a crash.
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-6.2.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-store:testDebugUnitTest` green
- `./gradlew :mk-store:lintDebug` green
- Requirements covered: R-15.5, R-15.6, R-15.7, R-15.8, R-15.9, R-16.1, R-16.2, R-16.3,
  R-16.4, R-16.5
- Tests ported: T-SK-14, T-SK-15, T-SK-16, T-SK-17, T-SK-20, plus new
  `MkSecureStoreTamperTest.kt` (no Swift analogue — guards the corrected HMAC mechanism)
- Fixtures consumed: none
- Stub count for `mk-store`'s trial/referral files reaches 0
- `MkSecureStore.kt` contains no AndroidKeyStore/Keystore-cipher usage anywhere (verify by inspecting the source) — the corrected D-312 mechanism is unencrypted + HMAC-signed

**Impl log.** `android/docs/impl-log/BATCH-6.2.md`

---

### Batch 6 · Agent 6.3a — `mk-sync` Drive transport: auth, REST client, resumable upload, WorkManager

**Depends on:** G5 · **Parallel-safe with:** every other Batch 6 agent
(including 6.3b — disjoint file sets, both consume the same read-only `android/mk-model/**`/
`android/mk-persistence/**` inputs)

**Mission.** Port `MKSyncEngineController.swift` (841 LOC — the largest single file in this
batch) from `CKSyncEngine`/CloudKit onto Google Drive v3 REST against the `appDataFolder`,
plus the two-step D-310 authentication flow this engine needs and which the Swift source has
no analogue for at all (StoreKit/CloudKit apps never separately request an OAuth scope).
This agent owns the transport only; the policy this transport calls into (conflict decision,
naming, pending queue, record encoding, schema, status, account state, error taxonomy,
tunables) is Agent 6.3b's, consumed here through 6.3b's public API, never reimplemented.

**The hardest correctness risk in this agent's scope is D-310 auth, corrected here.**
Credential Manager's `GetGoogleIdOption` returns a Google **ID token** for authentication
only — it grants no OAuth scopes and yields no access token. Authorizing
`https://www.googleapis.com/auth/drive.appdata` requires the separate Google Identity
Services (GIS) authorization API: `Identity.getAuthorizationClient()` with an
`AuthorizationRequest` naming the requested scope. An earlier draft of this packet treated
Credential Manager sign-in as sufficient for Drive access; as written, every Drive call would
have returned 401. Because this agent's unit tests use a fake HTTP transport (Task 6 below),
that defect would have gone green in this agent's own test suite and surfaced only at G6's
two-account harness — so the auth flow is written correctly the first time, not caught by
review of a passing test suite.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKSync/Engine/MKSyncEngineController.swift` (841 LOC) | The `CKSyncEngine` lifecycle controller this agent replaces with a Drive-backed equivalent |
| `MakhtootKit/Tests/MKSyncTests/*.swift` (10 files, 1,321 LOC total — read in full to identify the transport-dependent subset) | Source for this agent's transport-level test ports (Task 6) |
| `PRD.md` §17 (R-17.1…R-17.9) | Sync product requirements — transport-level rows verified here, full list re-verified jointly with 6.3b at G6 |
| `FOUNDATION.md` §8 (D-112's CloudKit clause) | Original decision D-310 amends on Android |
| `TEST_MATRIX.md` §13 T-SYN-1…10 | This agent owns the subset requiring live/two-account behavior: T-SYN-1, T-SYN-2, T-SYN-3, T-SYN-6, T-SYN-7, T-SYN-9 (see Acceptance) |
| `ANDROID_SPINE.md` §1 FDA-01, §2 D-310 | Drive `appDataFolder` decision, the corrected two-step auth mechanism, Android↔Android-only scope, `WorkManager` scheduling |
| `ANDROID_SPINE.md` §7 Prerequisites | The Google Cloud project + Android OAuth client + SHA-1 registration + **verified** OAuth consent screen for `drive.appdata` — lead time measured in **weeks**, first blocks G6; this agent's auth code has nothing to authenticate against until this external prerequisite lands, so flag it early in the impl log rather than discovering it at G6 |
| `android/mk-sync/**` (Agent 6.3b's `MkSyncDecisionEngine`, `MkConflictNaming`, `MkSyncPendingQueue`, `MkProjectRecordCoder`, `MkSyncSchema`, `MkSyncStatus`, `MkSyncAccountState`, `MkSyncError`, `MkSyncTunables`) | The policy/encoding/error-taxonomy API this transport calls into — read their public signatures, do not edit; if 6.3b lands in the same batch dispatch, build against its documented contract from this packet's Port map, reconciling at G6 |
| `android/mk-persistence/**` (Batch 3.4–3.6 output) | Document package + metadata index this controller reads/writes against |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 7).
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/engine/MkSyncEngineController.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/auth/MkDriveAuthController.kt`
  (new — no Swift analogue; the two-step Credential Manager + GIS `AuthorizationClient` flow)
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/work/MkSyncWorker.kt` (new
  — WorkManager entry point, no Swift analogue)
- `android/mk-sync/src/test/kotlin/net/binjamshid/makhtoot/mk/sync/engine/MkSyncEngineControllerTest.kt`
- `android/mk-sync/src/test/kotlin/net/binjamshid/makhtoot/mk/sync/auth/MkDriveAuthControllerTest.kt`
  (new — no Swift analogue)
- `android/mk-sync/src/test/kotlin/net/binjamshid/makhtoot/mk/sync/work/MkSyncWorkerTest.kt`
- `android/docs/impl-log/BATCH-6.3a.md`

**Never touch.** `android/mk-sync/.../{conflict,changetracking,serialization,schema,status,
account,errors,tunables}/**` (Agent 6.3b — this agent calls into that public API, never edits
it); `:mk-store`, `:mk-analytics`, `:mk-fonts` (Agents 6.1, 6.2, 6.4, 6.5); `android/mk-
persistence/**`, `android/mk-model/**` (Batch 2–3, frozen — read-only dependencies); any
`build.gradle.kts` or `libs.versions.toml` (frozen, see header).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Engine/MKSyncEngineController.swift` | 841 | `engine/MkSyncEngineController.kt` | `CKSyncEngine` → Drive v3 REST client scoped to `appDataFolder`; the delegate-shim retain-cycle workaround (`MKSyncDelegate` holding a weak ref) has no Kotlin analogue — a `CoroutineScope`-owned controller with no delegate object needed; `CKSyncEngine.State.Serialization` (opaque resumable state token) → change detection via Drive `changes.list` + a persisted `startPageToken` (Drive's direct equivalent — both exist so a client can resume incremental sync without re-scanning everything); large-blob uploads use Drive's resumable-upload protocol (chunked PUT with `Content-Range`) rather than `CKAsset` chunking; encoding is delegated to Agent 6.3b's `MkProjectRecordCoder` (manifest+scene → Drive file content + `appProperties`), never reimplemented here; the three start conditions (`isEnabled`, entitlement gate, `accountState == .available` via 6.3b's `MkSyncAccountState`) port unchanged as gate checks before any Drive call — this is also where D-229(4)'s engine-entry entitlement gate (T-SYN-10, owned by 6.3b since it is a pure logic assertion) is honored. |
| *(no Swift source — new)* | — | `auth/MkDriveAuthController.kt` | **Step 1 — identity.** Credential Manager `GetGoogleIdOption` → a Google **ID token**, proving who the user is; grants zero OAuth scopes. **Step 2 — authorization.** `Identity.getAuthorizationClient()` with an `AuthorizationRequest` naming `https://www.googleapis.com/auth/drive.appdata` → an access token scoped to Drive's app-private folder; this is a genuinely separate API call from Step 1, not a parameter on it. Caches and refreshes the access token, exposes a suspend accessor `MkSyncEngineController` calls before every Drive request, and re-runs Step 2 (not Step 1) on a 401 that Step 1's ID token is still valid for — a scope-only re-authorization, never a needless re-sign-in. |
| *(no Swift source — new)* | — | `work/MkSyncWorker.kt` | `WorkManager` periodic/triggered sync entry point, network + battery constraints per D-310, replacing `CKSyncEngine`'s automatic background-drain behavior, which has no direct Android equivalent. |

**Tasks.**
1. Build `MkDriveAuthController.kt` first — every other file in this agent's set depends on
   it producing a valid Drive access token. Implement the two steps as genuinely separate
   calls (Credential Manager for the ID token, GIS `AuthorizationClient` for the scope grant),
   never conflated into one call. Write `MkDriveAuthControllerTest.kt` against fake Credential
   Manager and `AuthorizationClient` doubles, asserting: Step 2 is attempted only after Step 1
   succeeds; a Step-2-only 401 triggers Step-2-only retry, not a full re-sign-in; the cached
   access token is reused across calls until expiry/401.
2. Build `MkSyncEngineController.kt` against Drive v3 REST using `MkDriveAuthController`'s
   token: `appDataFolder` scoping, `changes.list`+`startPageToken` change detection,
   resumable upload for large blobs, exponential backoff on 403 rate-limit/quota (calling
   6.3b's `MkSyncTunables`), and `appProperties` produced by 6.3b's `MkProjectRecordCoder`.
   Wire the three start conditions.
3. Add `MkSyncWorker.kt` with network + battery constraints.
4. Write `MkSyncEngineControllerTest.kt` and `MkSyncWorkerTest.kt` against a fake Drive HTTP
   transport, porting the transport-dependent assertions from the 10 `MKSyncTests` Swift
   files (the ones this agent's Reads/Acceptance identify as T-SYN-1/2/3/6/7/9-class).
5. **Explicit blind-spot note (do not skip).** Record in `android/docs/impl-log/BATCH-6.3a.md`,
   in plain language: this agent's fake-HTTP-transport unit tests cannot catch an auth-flow
   defect where Step 2 is silently skipped or malformed, because the fake transport never
   checks the Authorization header's actual validity against Google's servers. The only real
   check is G6's two-account harness. State this so the gap is visible to whoever reviews the
   green test run, not discovered for the first time when G6 fails.
6. Document plainly in the impl log and in `MkSyncEngineController`'s header comment (D-310):
   Android syncs Android↔Android only — an iOS device and an Android device never see each
   other's projects through this engine, since Drive `appDataFolder` and CloudKit are
   disjoint storage systems with no bridge. This is a documented v1 limitation, not a bug.
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-6.3a.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-sync:testDebugUnitTest` green
- `./gradlew :mk-sync:lintDebug` green
- Requirements covered: R-17.1 (sync capability exists — transport prerequisite), R-17.2
  (offline/quota handling — transport-level backoff); full R-17.1…R-17.9 coverage is a joint
  claim with 6.3b, re-verified together at G6, not double-counted
- Tests ported: T-SYN-1, T-SYN-2, T-SYN-3, T-SYN-6, T-SYN-7, T-SYN-9 — all six require the
  two-emulator/two-account harness at G6 for final confirmation; this agent's fake-transport
  unit tests cover what is unit-testable of each, per Task 5's documented blind spot
- Fixtures consumed: none
- Stub count for `mk-sync`'s transport files (`engine/`, `auth/`, `work/`) reaches 0
  (6.3b's policy files are that agent's stub-count responsibility)
- `MkDriveAuthController.kt` performs Credential Manager and GIS `AuthorizationClient` as two
  distinct calls, verified by `MkDriveAuthControllerTest.kt`, not merely asserted in prose

**Impl log.** `android/docs/impl-log/BATCH-6.3a.md`

---

### Batch 6 · Agent 6.3b — `mk-sync` conflict policy, pending queue, record coder, schema, status, account, errors, tunables

**Depends on:** G5 · **Parallel-safe with:** every other Batch 6 agent
(including 6.3a — disjoint file sets)

**Mission.** Port the nine `MKSync` policy/support files (1,104 of the module's 1,945 source
LOC) that carry over from iOS essentially unchanged: the conflict decision engine,
conflict-copy naming, offline pending queue, manifest+scene record encoding, schema
constants, per-project status publisher, account-state handling, the Drive-mapped error
taxonomy, and retry/backoff tunables. None of these files talk to Drive directly — Agent
6.3a's `MkSyncEngineController` calls into this agent's public API; this agent never calls
Drive.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKSync/Conflict/MKSyncDecisionEngine.swift` (139 LOC), `MKConflictNaming.swift` (51 LOC) | Last-writer-wins policy + `(نسخة متعارضة)` naming — ports unchanged |
| `MakhtootKit/Sources/MKSync/ChangeTracking/MKSyncPendingQueue.swift` (120 LOC) | Offline-queue-then-drain semantics |
| `MakhtootKit/Sources/MKSync/Serialization/MKProjectRecordCoder.swift` (253 LOC) | manifest+scene → CKRecord encoding this agent replaces with Drive `appProperties`/file-content encoding |
| `MakhtootKit/Sources/MKSync/Schema/MKSyncSchema.swift` (104 LOC) | Record-type/field-name constants |
| `MakhtootKit/Sources/MKSync/Status/MKSyncStatus.swift` (146 LOC) | Per-project sync status publisher |
| `MakhtootKit/Sources/MKSync/Account/MKSyncAccountState.swift` (74 LOC) | Account-state handling this agent replaces with Credential Manager identity states (the ID-token half of D-310 — Agent 6.3a owns the separate authorization half) |
| `MakhtootKit/Sources/MKSync/Errors/MKSyncError.swift` (138 LOC) | Error taxonomy — `CKError` cases map to Drive API error/HTTP-status cases |
| `MakhtootKit/Sources/MKSync/Tunables/MKSyncTunables.swift` (79 LOC) | Retry/backoff constants |
| `MakhtootKit/Tests/MKSyncTests/*.swift` (10 files, 1,321 LOC total — read in full to identify the policy-level subset) | Source for this agent's logic-level test ports (Task 6) |
| `PRD.md` §17 (R-17.1…R-17.9) | Sync product requirements — policy-level rows verified here, full list re-verified jointly with 6.3a at G6 |
| `FOUNDATION.md` §8 (D-112's CloudKit clause) | Original decision D-310 amends on Android |
| `TEST_MATRIX.md` §13 T-SYN-1…10 | This agent owns the unit-testable subset: T-SYN-4, T-SYN-5, T-SYN-8, T-SYN-10 |
| `ANDROID_SPINE.md` §2 D-310 | Drive `appDataFolder` decision, Android↔Android-only scope; the corrected two-step auth is Agent 6.3a's mechanism, this agent only needs the resulting identity/account-state shape |
| `android/mk-model/**` (Batch 2.2 output) | Scene-graph/codec types `MkProjectRecordCoder` serializes |
| `android/mk-persistence/**` (Batch 3.4–3.6 output) | Document package + metadata index the status publisher and pending queue read/write against |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (Task 7).
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/conflict/MkSyncDecisionEngine.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/conflict/MkConflictNaming.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/changetracking/MkSyncPendingQueue.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/serialization/MkProjectRecordCoder.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/schema/MkSyncSchema.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/status/MkSyncStatus.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/account/MkSyncAccountState.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/errors/MkSyncError.kt`
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/tunables/MkSyncTunables.kt`
- `android/mk-sync/src/test/kotlin/net/binjamshid/makhtoot/mk/sync/{conflict,changetracking,serialization,schema,status,account,errors,tunables}/**/*Test.kt`
- `android/docs/impl-log/BATCH-6.3b.md`

**Never touch.** `android/mk-sync/.../{engine,auth,work}/**` (Agent 6.3a); `:mk-store`,
`:mk-analytics`, `:mk-fonts` (Agents 6.1, 6.2, 6.4, 6.5); `android/mk-persistence/**`,
`android/mk-model/**` (Batch 2–3, frozen — read-only dependencies); any `build.gradle.kts` or
`libs.versions.toml` (frozen, see header).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Conflict/MKSyncDecisionEngine.swift` | 139 | `conflict/MkSyncDecisionEngine.kt` | Pure last-writer-wins policy function — ports unchanged, zero Drive/CloudKit dependency either platform. |
| `Conflict/MKConflictNaming.swift` | 51 | `conflict/MkConflictNaming.kt` | `(نسخة متعارضة)` suffix + Arabic-Indic numeral disambiguation — ports verbatim, byte-for-byte same Arabic strings. |
| `ChangeTracking/MKSyncPendingQueue.swift` | 120 | `changetracking/MkSyncPendingQueue.kt` | Offline mutation queue — ports unchanged; drains on Agent 6.3a's `MkSyncWorker` runs instead of `CKSyncEngine`'s automatic drain (call site is 6.3a's, this agent only exposes the drain API). |
| `Serialization/MKProjectRecordCoder.swift` | 253 | `serialization/MkProjectRecordCoder.kt` | manifest.json+scene.json → `CKRecord` fields → Drive: the project's manifest+scene become the Drive file's binary content (same byte layout D-308 already gives the on-disk package), and the metadata CloudKit kept in typed record fields (project id, revision, folder, name) moves to Drive `File.appProperties` (a flat string-keyed map — the direct Drive analogue of CKRecord fields, per the spine's explicit call-out). Pure encoding — never issues a Drive HTTP call itself; Agent 6.3a's engine controller calls this to produce the bytes/properties it then uploads. |
| `Schema/MKSyncSchema.swift` | 104 | `schema/MkSyncSchema.kt` | CKRecord type/field-name constants → `appProperties` key constants; same naming discipline (single source of truth for the schema). |
| `Status/MKSyncStatus.swift` | 146 | `status/MkSyncStatus.kt` | Per-project status publisher (`synced`/`pending`/`error`) — `StateFlow`-based port, same states, feeds Batch 7.2's browser status glyphs and Batch 7.8's `MkSyncSettingsView` port. |
| `Account/MKSyncAccountState.swift` | 74 | `account/MkSyncAccountState.kt` | Sign-in/out/switch/restricted states — `CKContainer.accountStatus` → Credential Manager's **identity** state (the ID-token half of D-310; Agent 6.3a's `MkDriveAuthController` separately holds the authorization/scope half — this file tracks "who is signed in," not "do we have Drive access"); account-switch re-scoping (local DB re-scoped to the new account id, local projects stay local) ports unchanged in policy. |
| `Errors/MKSyncError.swift` | 138 | `errors/MkSyncError.kt` | `CKError` cases (`.quotaExceeded`, `.networkFailure`, `.serverRejectedRequest`, `.zoneBusy`, …) map to Drive API error taxonomy: HTTP 403 `storageQuotaExceeded` → quota; HTTP 403 `rateLimitExceeded`/`userRateLimitExceeded` → exponential-backoff retry (replaces `.zoneBusy`); network-layer `IOException` → `.networkFailure`; HTTP 4xx non-retryable → `.serverRejectedRequest`; HTTP 401 after a 6.3a re-authorization attempt → a distinct auth-failure case surfaced to the user, not folded into `.networkFailure`. Same Arabic user-facing copy per error class. |
| `Tunables/MKSyncTunables.swift` | 79 | `tunables/MkSyncTunables.kt` | Retry/backoff constants — ports unchanged; consumed by Agent 6.3a's engine controller for the exponential backoff on 403 rate-limit/quota. |

**Tasks.**
1. Port `MkSyncDecisionEngine`, `MkConflictNaming`, `MkSyncPendingQueue`, `MkSyncSchema`,
   `MkSyncTunables` first — pure, zero-dependency logic files with no Drive/auth coupling at
   all.
2. Port `MkProjectRecordCoder` against the `appProperties`/file-content split described in
   the Port map, matching D-308's byte layout exactly so 6.3a's uploads round-trip correctly.
3. Port `MkSyncStatus`, exposing the `StateFlow` Batch 7.2/7.8 will consume.
4. Port `MkSyncAccountState` against Credential Manager's identity-state surface only —
   explicitly do NOT model Drive authorization/scope state here, that is Agent 6.3a's
   `MkDriveAuthController`; this file answers "who is signed in," never "do we have Drive
   access."
5. Port `MkSyncError`'s taxonomy against the Drive API error/HTTP-status mapping in the Port
   map, preserving the same Arabic-copy-per-class contract (`android/strings/strings.xml`,
   Batch 0.4 output); add the distinct post-re-authorization-401 case named in that row.
6. Port the policy-level assertions from the 10 `MKSyncTests` Swift files to JUnit5 — this
   agent's files have zero Drive/HTTP dependency, so no fake transport is needed, only plain
   unit tests. Keep `MkSyncBatchTempCleanupTests` (temp-dir hygiene) and
   `MkSyncDurableDirtyMarkingTests` (S-3-class regression coverage) as direct 1:1 ports — both
   guard real bugs already found and fixed on iOS (per `EXECUTION_PLAN_2026-07-28.md` Wave 1
   Agent 1.5/1.2), and a Kotlin rewrite must not silently drop that coverage. Also port
   `MkSyncDecisionEngineTest`/`MkConflictNamingTest`, which stand in for golden-fixture
   coverage in this module (see Acceptance).
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-6.3b.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-sync:testDebugUnitTest` green
- `./gradlew :mk-sync:lintDebug` green
- Requirements covered: R-17.3, R-17.4, R-17.5, R-17.6, R-17.7, R-17.8, R-17.9 (conflict
  policy, naming, offline queueing, status surfacing, account-state policy); full
  R-17.1…R-17.9 coverage is a joint claim with 6.3a, re-verified together at G6, not
  double-counted
- Tests ported: T-SYN-4, T-SYN-5, T-SYN-8, T-SYN-10 — all four are unit-testable without a
  live Drive connection or a second account
- Fixtures consumed: none — sync correctness is validated by the ported
  `MkSyncDecisionEngineTest`/`MkConflictNamingTest` logic tests plus the G6 two-device
  round-trip (jointly with 6.3a), not golden fixtures
- Stub count for `mk-sync`'s policy files (`conflict/`, `changetracking/`, `serialization/`,
  `schema/`, `status/`, `account/`, `errors/`, `tunables/`) reaches 0 (6.3a's transport files
  are that agent's stub-count responsibility) — `mk-sync`'s combined stub count across 6.3a
  + 6.3b reaches 0

**Impl log.** `android/docs/impl-log/BATCH-6.3b.md`

---

### Batch 6 · Agent 6.4 — `mk-analytics` consent, counters, uploader

**Depends on:** G5 · **Parallel-safe with:** every other Batch 6 agent

**Mission.** Port all 13 `MKAnalytics` files (1,004 LOC, one module, no internal split):
consent management, on-device font-usage bucket counters, the two-layer kill switch, and
the (no-op-until-FDA-04) uploader.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKAnalytics/Consent/MKConsentManager.swift` (107 LOC), `MKConsentRecord.swift` (62), `MKConsentStatus.swift` (59) | Versioned, default-OFF consent record + re-consent-on-version-bump logic |
| `MakhtootKit/Sources/MKAnalytics/Counter/MKFontUsageBucket.swift` (33 LOC), `MKUsageCounterStore.swift` (191) | On-device fontID→bucket counters |
| `MakhtootKit/Sources/MKAnalytics/MKAnalyticsError.swift` (15), `MKAnalyticsLog.swift` (9), `MKLegalLinks.swift` (22) | Small supporting types |
| `MakhtootKit/Sources/MKAnalytics/Service/MKAnalyticsService.swift` (125), `MKDisclosureContent.swift` (42) | Orchestration + the exact Arabic disclosure text (must ship byte-identical) |
| `MakhtootKit/Sources/MKAnalytics/Upload/MKAnalyticsUploader.swift` (183), `MKFontUsageBatch.swift` (90) | Batch-build + upload orchestration, kept transport-agnostic |
| `MakhtootKit/Sources/MKAnalytics/Upload/MKCloudKitPublicDatabase.swift` (66) | The ONE file in this module with no Android analogue — see Port map |
| `MakhtootKit/Tests/MKAnalyticsTests/*.swift` (6 files, 696 LOC total) | Tests to port |
| `PRD.md` §18 (R-18.1…R-18.7) | Analytics/privacy product requirements |
| `FOUNDATION.md` §8 (D-125) | Original decision this agent's D-320 mirrors verbatim |
| `TEST_MATRIX.md` §14 T-ANL-1…6 | Tests this agent's Kotlin suite must have equivalents for |
| `ANDROID_SPINE.md` §1 FDA-04, §2 D-320 | No-op uploader posture, "never a third-party analytics SDK" |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (see Tasks, final item).
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentManager.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentRecord.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentStatus.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/counter/MkFontUsageBucket.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/counter/MkUsageCounterStore.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkAnalyticsError.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkAnalyticsLog.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkLegalLinks.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/service/MkAnalyticsService.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/service/MkDisclosureContent.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkAnalyticsUploader.kt`
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkStaticHostUploader.kt` (new — replaces `MkCloudKitPublicDatabase.kt`, see Port map)
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkFontUsageBatch.kt`
- `android/mk-analytics/src/test/kotlin/net/binjamshid/makhtoot/mk/analytics/**/*Test.kt`
- `android/docs/impl-log/BATCH-6.4.md`

**Never touch.** `:mk-store`, `:mk-sync`, `:mk-fonts` (Agents 6.1, 6.2, 6.3a, 6.3b, 6.5); any
`build.gradle.kts` or `libs.versions.toml` (frozen, see header).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Consent/MKConsentManager.swift` | 107 | `consent/MkConsentManager.kt` | Actor → a `Mutex`-guarded class or a `DataStore`-backed singleton; JSON file in Application Support → JSON file in app-private storage (`filesDir`) via the same atomic-write pattern D-308 already establishes elsewhere. Version-bump downgrade-to-`neverAsked` logic ports unchanged — this is the mechanism that forces re-consent whenever the disclosure text changes. |
| `Consent/MKConsentRecord.swift` | 62 | `consent/MkConsentRecord.kt` | `Codable` struct → `@Serializable` data class; `currentConsentVersion` constant ports unchanged. |
| `Consent/MKConsentStatus.swift` | 59 | `consent/MkConsentStatus.kt` | `neverAsked`/`granted(date:)`/`revoked(date:)` sealed class port. |
| `Counter/MKFontUsageBucket.swift` | 33 | `counter/MkFontUsageBucket.kt` | Bucket enum/struct — ports unchanged, same bucket boundaries (ARCHITECTURE §21, per T-ANL-6). |
| `Counter/MKUsageCounterStore.swift` | 191 | `counter/MkUsageCounterStore.kt` | On-device fontID→count store; `wipeAll()` (called on consent revoke) ports unchanged. |
| `MKAnalyticsError.swift` / `MKAnalyticsLog.swift` / `MKLegalLinks.swift` | 15 / 9 / 22 | Same-name `.kt` files at module root | Trivial ports — sealed error type, `os.Logger` → `android.util.Log`/`Timber`-style tagged logger, static legal-link URLs. |
| `Service/MKAnalyticsService.swift` | 125 | `service/MkAnalyticsService.kt` | Orchestrates consent-gated counter increments + scheduled upload attempts; `bootstrap()`/`triggerUploadIfDue()` port unchanged in shape, called from Batch 7.1's composition root (`MkAppContainer.kt`) the same way `AppContainer.swift` calls them today. |
| `Service/MKDisclosureContent.swift` | 42 | `service/MkDisclosureContent.kt` | The exact Arabic consent-screen copy — port byte-identical, cross-checked against `android/strings/strings.xml` (Batch 0.4) so there is exactly one source of truth, not two divergent copies. |
| `Upload/MKAnalyticsUploader.swift` | 183 | `upload/MkAnalyticsUploader.kt` | Batch-build, consent+kill-switch double-check immediately before any network call (T-ANL-2/T-ANL-5 contract), 8-week unuploaded-batch drop policy (R-19.2) — ports unchanged; the actual network call is injected via the `MkStaticHostUploader` seam below rather than talking to CloudKit. |
| `Upload/MKCloudKitPublicDatabase.swift` | 66 | `upload/MkStaticHostUploader.kt` | **The one file in this module with no direct analogue** (per FDA-04, spine explicit call-out): posts anonymous bucketed batches to the SAME founder-controlled static host `MKFontDownloader`/`MKCatalogManifestFetchService` (Agent 6.5) use for premium fonts, via a plain HTTPS POST (OkHttp) — not CloudKit's public database. It is a **no-op until that host exists** (FDA-04's default posture): implement the interface and the OkHttp call path fully, but gate the actual network call behind a `hostConfigured: Boolean` flag defaulting `false`, and make the consent/privacy screen (Batch 7.8) say so plainly, mirroring the Swift file's own `fetchAnalyticsConfig()` "record doesn't exist yet → treated as enabled" default-honesty pattern for the analogous "host doesn't exist yet → uploader is inert" case. Never wire a third-party analytics SDK here under any circumstance — D-304/D-320 are explicit and absolute on this point. |
| `Upload/MKFontUsageBatch.swift` | 90 | `upload/MkFontUsageBatch.kt` | Batch payload shape (random ephemeral batch UUID, fontID→bucketed counts, week-granularity period, zero user/device identifiers) — ports unchanged; `toCKFieldDict()`'s CloudKit-field-dict shape becomes a plain JSON body builder for the OkHttp POST. |

**Tasks.**
1. Port `Consent/**` first (no upload dependency), preserving the version-bump
   re-consent-forces-`neverAsked` behavior exactly — this is the mechanism that keeps
   consent honest across future disclosure-text changes.
2. Port `Counter/**`, wiring `wipeAll()` to fire on consent revoke (T-ANL-4).
3. Port `Service/**`, keeping `MkDisclosureContent`'s Arabic text byte-identical to
   `android/strings/strings.xml`'s copy of the same disclosure (single source of truth,
   verified by a string-equality test).
4. Port `Upload/MkAnalyticsUploader.kt` and `MkFontUsageBatch.kt` unchanged in policy;
   implement `MkStaticHostUploader.kt` as the FDA-04 no-op-by-default uploader described in
   the port map, sharing the same static host `MKFontDownloader`/`MKCatalogManifestFetchService`
   target once configured (coordinate the shared `hostConfigured`/base-URL constant with
   Agent 6.5 — if a genuine shared-constant collision risk exists, escalate via
   `android/docs/CONTRACT_CHANGES.md` rather than editing `:mk-fonts` directly).
5. Implement the two-layer kill switch exactly as T-ANL-5 specifies: local
   `MkFeatureFlags`-equivalent build-time/runtime flag AND a remote stop mechanism read at
   upload time, independent of user consent, default-enabled when no cached value exists
   offline, and honoring the last-known cached value when offline with a prior value.
6. Port all 6 `MKAnalyticsTests` files to JUnit5, keeping `MKPayloadAllowlistTests`'s
   schema-snapshot-fails-on-any-added-field discipline intact — this is the test that
   enforces R-18.3's "never text, projects, identifiers, font files" boundary mechanically,
   not just by code review.
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-6.4.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-analytics:testDebugUnitTest` green
- `./gradlew :mk-analytics:lintDebug` green
- Requirements covered: R-18.1, R-18.2, R-18.3, R-18.4, R-18.5, R-18.6, R-18.7
- Tests ported: T-ANL-1, T-ANL-2, T-ANL-3, T-ANL-4, T-ANL-5, T-ANL-6
- Fixtures consumed: none
- Stub count for `mk-analytics` reaches 0

**Impl log.** `android/docs/impl-log/BATCH-6.4.md`

---

### Batch 6 · Agent 6.5 — `mk-fonts` premium catalog, downloader, lock controller, licensing, premium delivery

**Depends on:** G5 · **Parallel-safe with:** every other Batch 6 agent

**Mission.** Port the premium-catalog-download slice of `MKFonts` (963 of the target's
2,480 LOC) — manifest fetch/cache, resumable downloads, expiry locking, and licensing
metadata. The bundled-font registry/validator/import core (the other 1,517 LOC) is Batch
3.7's territory and stays untouched here.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKFonts/MKFontCatalog.swift` (100 LOC), `MKFontCatalogStore.swift` (153) | Catalog entry model + on-disk cache this agent ports |
| `MakhtootKit/Sources/MKFonts/CatalogManifest.swift` (101 LOC), `MKCatalogManifestFetchService.swift` (132) | Static JSON manifest schema + fetch/24h-staleness-TTL/cache service |
| `MakhtootKit/Sources/MKFonts/MKFontDownloader.swift` (148 LOC) | Resumable, checksum-verified download |
| `MakhtootKit/Sources/MKFonts/MKPremiumDelivery.swift` (27 LOC) | `.hosted`/`.bundledFallback` delivery-mode election (FD-04/FDA-06 open) |
| `MakhtootKit/Sources/MKFonts/MKFontLockController.swift` (55 LOC) | D-119 expiry locking |
| `MakhtootKit/Sources/MKFonts/MKLicenseRecord.swift` (148 LOC), `MKLicensingDataSource.swift` (99) | Per-font license/attribution/foundry/coverage records feeding Batch 7.8's Licensing screen |
| `MakhtootKit/Sources/MKAssets/Instantiation/MKPremiumContentLedger.swift` (63 LOC) | **Read-only dependency, already ported in Batch 5.5** — the `premiumContentPresent` walk (R-14.5/R-14.17/D-229) this agent's lock controller must stay consistent with; do not re-port, only consume the Batch 5.5 Kotlin output |
| `MakhtootKit/Tests/MKFontsTests/{CatalogManifestTests,MKCatalogManifestFetchServiceTests,MKFontDownloaderTests,MKFontCatalogStoreTests,MKFontLockControllerTests,MKLicensingDataSourceTests,StubURLProtocol}.swift` | Tests to port |
| `PRD.md` §12.2 (R-12.5…R-12.11), §12.1 (R-12.2) | Catalog UX and delivery product requirements |
| `FOUNDATION.md` §7 (D-121) | Direct-HTTPS-download-post-entitlement decision, unchanged on Android |
| `TEST_MATRIX.md` §10 T-FNT-3, T-FNT-7, T-FNT-8, T-FNT-9 | Tests this agent's Kotlin suite must have equivalents for |
| `ANDROID_SPINE.md` §2 D-121 (unchanged), D-119 (expiry locking) | Fonts-are-data-not-code posture, locked-font render policy |
| `android/mk-fonts/**` (Batch 3.7 output: `MkFontRegistry`, `MkFontValidator`, `MkFontImporter`, `MkCoverageAnalyzer`, `MkFontRegistrar`, `MkFontSearchIndex`, `MkFontStorageManager`, `MkFontTypes`, `MkFontError`, `MkBundledFontIndex`) | Frozen upstream this agent's catalog files call into — read-only |
| `android/mk-foundation/**` (Batch 2.1 output: `MKEntitlementProviding`) | The protocol seam `MkFontLockController` observes — `:mk-fonts` depends on `:mk-foundation`, not `:mk-store` (spine §3.2), so entitlement state is consumed only through this interface, never through a direct reference to Agent 6.1's concrete resolver type |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes
the identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite
each stub body as part of landing the real implementation (see Tasks §8).
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontCatalog.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontCatalogStore.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCatalogManifest.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCatalogManifestFetchService.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontDownloader.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkPremiumDelivery.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontLockController.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkLicenseRecord.kt`
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkLicensingDataSource.kt`
- `android/mk-fonts/src/test/kotlin/net/binjamshid/makhtoot/mk/fonts/{MkCatalogManifestTest,MkCatalogManifestFetchServiceTest,MkFontDownloaderTest,MkFontCatalogStoreTest,MkFontLockControllerTest,MkLicensingDataSourceTest,MkStubHttpInterceptor}.kt`
- `android/docs/impl-log/BATCH-6.5.md`

**Never touch.** `android/mk-fonts/**`'s Batch-3.7-owned files listed in Reads above
(`MkFontRegistry.kt`, `MkFontValidator.kt`, `MkFontImporter.kt`, `MkCoverageAnalyzer.kt`,
`MkFontRegistrar.kt`, `MkFontSearchIndex.kt`, `MkFontStorageManager.kt`, `MkFontTypes.kt`,
`MkFontError.kt`, `MkBundledFontIndex.kt`); `android/mk-assets/**` (Batch 5.5, includes
`MkPremiumContentLedger.kt` — read-only dependency here); `:mk-store`, `:mk-sync`,
`:mk-analytics` (Agents 6.1, 6.2, 6.3a, 6.3b, 6.4); any `build.gradle.kts` or
`libs.versions.toml` (frozen, see header).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKFontCatalog.swift` | 100 | `MkFontCatalog.kt` | Catalog entry model (fontID, family, faces, categories, `licenseType`/`embeddingRights`/`foundry`/`commercialStatus` per R-12.4) — ports unchanged, `Codable` → `@Serializable`. |
| `MKFontCatalogStore.swift` | 153 | `MkFontCatalogStore.kt` | On-disk cache of the fetched manifest — JSON file in app-private storage, same atomic-write pattern as elsewhere. |
| `CatalogManifest.swift` | 101 | `MkCatalogManifest.kt` | `catalog-manifest-v1.json` schema; `JSONDecoder`'s tolerant-of-unknown-keys default → kotlinx-serialization's `ignoreUnknownKeys = true`; the hard-fail-on-missing-`licenseRecord` contract ports as a custom deserializer check, not a silent default. |
| `MKCatalogManifestFetchService.swift` | 132 | `MkCatalogManifestFetchService.kt` | 24-hour staleness TTL, foreground-triggered refresh, cache-first read (R-12.11) — ports unchanged via OkHttp + WorkManager for the background refresh; zero-manifest-ever offline state renders the same Arabic empty-state string with retry, not a blank/crashed screen. |
| `MKFontDownloader.swift` | 148 | `MkFontDownloader.kt` | Resumable download with checksum verification (R-12.8) — StoreKit/URLSession resumable-download tasks → OkHttp `Range`-header resumption + WorkManager for backgroundable, retryable downloads; checksum re-verified after resume completes (T-FNT-3's byte-offset-resume assertion, not restart-from-zero). |
| `MKPremiumDelivery.swift` | 27 | `MkPremiumDelivery.kt` | `.hosted(manifestURL)`/`.bundledFallback` election — ports unchanged; the placeholder `.invalid`-TLD URL pattern (fails loudly rather than silently hitting an unintended host) ports verbatim; `.current` stays `.bundledFallback` until FDA-06/FD-04 resolve, exactly mirroring the Swift default. |
| `MKFontLockController.swift` | 55 | `MkFontLockController.kt` | Actor → coroutine-based controller observing an entitlement `Flow<MkEntitlementState>` exposed through the `MKEntitlementProviding` protocol (`:mk-foundation`, spine §2) — **not** a direct reference to Agent 6.1's concrete `MkEntitlementResolver` type, since `:mk-fonts` has no dependency edge on `:mk-store` in the module graph (spine §3.2); the composition root (Batch 7.1's `MkAppContainer`) injects Agent 6.1's resolver as the `MKEntitlementProviding` conformer at wiring time. On transition to non-premium, locks every `premiumDownloaded`/`userImported` catalog record via `MkFontRegistry.setLocked(...)` (Batch 3.7, called not edited); applies within one collection cycle, no debouncing — same contract as the Swift `observe(_:)` loop. |
| `MKLicenseRecord.swift` | 148 | `MkLicenseRecord.kt` | Per-font license/attribution/foundry/commercial-status/coverage/source-link record — ports unchanged; feeds Batch 7.8's `MkLicensingView`/`MkLicenseFontDetailView` port. |
| `MKLicensingDataSource.swift` | 99 | `MkLicensingDataSource.kt` | Aggregates license records across bundled+premium+user-imported fonts for the Settings → Support → Licensing screen — ports unchanged. |

**Tasks.**
1. Port `MkFontCatalog`/`MkCatalogManifest`/`MkFontCatalogStore` first (pure data + cache,
   no network), preserving the hard-fail-on-missing-`licenseRecord` manifest contract.
2. Port `MkCatalogManifestFetchService` against OkHttp with the 24-hour staleness TTL and
   the documented zero-manifest-ever offline empty state (R-12.11).
3. Port `MkFontDownloader` with real resumable-download semantics — write
   `MkFontDownloaderTest.kt`'s interrupted-then-resumed-from-byte-offset case as a hard
   assertion (a restart-from-zero silently "working eventually" is a DF-8-class test
   failure per T-FNT-3, not a pass).
4. Port `MkFontLockController` against the `MKEntitlementProviding` protocol seam (not a
   direct `:mk-store` reference — see Port map), with Agent 6.1's `MkEntitlementResolver`
   wired in as the concrete conformer at the composition root; wire the same flow to Batch
   3.7's `MkFontRegistry.setLocked(...)`; verify the D-119 contract:
   locked-font Live Text renders from last cached shaping with a lock badge, re-shaping is
   blocked, Arranged Compositions (frozen outlines) stay fully manipulable regardless of
   font lock state (R-12.10).
5. Port `MkLicenseRecord`/`MkLicensingDataSource`, cross-checking every license string
   against the captured OFL license files in the repo (no invented license text, per
   T-FNT-7).
6. Port `CatalogManifestTests`, `MKCatalogManifestFetchServiceTests`,
   `MKFontDownloaderTests`, `MKFontCatalogStoreTests`, `MKFontLockControllerTests`,
   `MKLicensingDataSourceTests` to JUnit5, replacing `StubURLProtocol.swift` with an OkHttp
   `Interceptor`-based stub (`MkStubHttpInterceptor.kt`) for deterministic network tests.
7. Note the known flaky font-lock tests documented for this repo's full-suite iOS runs
   (contact-sheet + font-lock tests fail only in full runs, pass with `--filter`) and write
   the Kotlin tests order-independent from the start — no shared mutable static state
   between `MkFontLockControllerTest` cases, no reliance on JUnit run order, so the same
   class of flake cannot reappear on the Android side.
8. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-6.5.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-fonts:testDebugUnitTest` green
- `./gradlew :mk-fonts:lintDebug` green
- Requirements covered: R-12.2, R-12.4, R-12.8, R-12.9, R-12.10, R-12.11
- Tests ported: T-FNT-3, T-FNT-7, T-FNT-8, T-FNT-9
- Fixtures consumed: none — `MkCatalogManifestTest.kt` uses an inline JSON fixture ported
  alongside the test itself (mirroring `CatalogManifestTests.swift`'s own inline fixture),
  not a Batch 0 golden fixture
- Stub count for `mk-fonts`'s catalog-download files reaches 0 (Batch 3.7's registry/
  validator/import stubs were already retired in Batch 3)

**Impl log.** `android/docs/impl-log/BATCH-6.5.md`

---

## Appendix — file-ownership matrix (collision proof)

| Owned path prefix | 6.1 | 6.2 | 6.3a | 6.3b | 6.4 | 6.5 |
|---|---|---|---|---|---|---|
| `android/mk-store/src/main/kotlin/.../store/{MkProductCatalog,MkPurchaseController,MkEntitlementResolver,MkEntitlementPrecedence,MkEntitlementDetail,MkStoreIds,MkStoreError,MkVerification}.kt` | ✔ | | | | | |
| `android/mk-store/src/main/kotlin/.../store/paywall/**` | ✔ | | | | | |
| `android/mk-store/src/main/kotlin/.../store/billing/**` | ✔ | | | | | |
| `android/mk-store/src/debug/kotlin/.../store/testing/**` | ✔ | | | | | |
| `android/mk-store/src/main/kotlin/.../store/trial/**` | | ✔ | | | | |
| `android/mk-store/src/debug/kotlin/.../store/referral/**` | | ✔ | | | | |
| `android/mk-sync/src/main/kotlin/.../sync/{engine,auth,work}/**` | | | ✔ | | | |
| `android/mk-sync/src/test/kotlin/.../sync/{engine,auth,work}/**` | | | ✔ | | | |
| `android/mk-sync/src/main/kotlin/.../sync/{conflict,changetracking,serialization,schema,status,account,errors,tunables}/**` | | | | ✔ | | |
| `android/mk-sync/src/test/kotlin/.../sync/{conflict,changetracking,serialization,schema,status,account,errors,tunables}/**` | | | | ✔ | | |
| `android/mk-analytics/**` (all of `:mk-analytics`) | | | | | ✔ | |
| `android/mk-fonts/src/main/kotlin/.../fonts/{MkFontCatalog,MkFontCatalogStore,MkCatalogManifest,MkCatalogManifestFetchService,MkFontDownloader,MkPremiumDelivery,MkFontLockController,MkLicenseRecord,MkLicensingDataSource}.kt` | | | | | | ✔ |
| `android/mk-fonts/src/test/kotlin/.../fonts/{MkCatalogManifestTest,MkCatalogManifestFetchServiceTest,MkFontDownloaderTest,MkFontCatalogStoreTest,MkFontLockControllerTest,MkLicensingDataSourceTest,MkStubHttpInterceptor}.kt` | | | | | | ✔ |
| `android/mk-store/src/test/kotlin/.../store/{root-file tests}` | ✔ | | | | | |
| `android/mk-store/src/test/kotlin/.../store/trial/**`, `.../store/referral/**` | | ✔ | | | | |
| `android/docs/impl-log/BATCH-6.1.md` | ✔ | | | | | |
| `android/docs/impl-log/BATCH-6.2.md` | | ✔ | | | | |
| `android/docs/impl-log/BATCH-6.3a.md` | | | ✔ | | | |
| `android/docs/impl-log/BATCH-6.3b.md` | | | | ✔ | | |
| `android/docs/impl-log/BATCH-6.4.md` | | | | | ✔ | |
| `android/docs/impl-log/BATCH-6.5.md` | | | | | | ✔ |

**Partition sums.** `:mk-sync`'s 10 source files (1,945 LOC) split as 6.3a = 2 ported files
(`engine/MkSyncEngineController.kt`, and the two new files `auth/MkDriveAuthController.kt` +
`work/MkSyncWorker.kt` with no Swift source) + 6.3b = 9 files (all remaining `MKSync` source);
combined they equal the original single-agent 6.3 scope with zero path overlap — every
`android/mk-sync/**` path above is claimed by exactly one of 6.3a/6.3b, never both. Across all
6 Batch 6 agents: 6.1 (10 main files + paywall/billing/testing dirs) + 6.2 (5 trial files +
3 debug-only referral files) + 6.3a (1 ported + 2 new files) + 6.3b (9 files) + 6.4 (13 files,
whole module) + 6.5 (9 files) — no two agents' Owns lists share a path, verified against the
table above row by row.

`android/mk-fonts/src/main/kotlin/.../fonts/{MkFontRegistry,MkFontValidator,MkFontImporter,
MkCoverageAnalyzer,MkFontRegistrar,MkFontSearchIndex,MkFontStorageManager,MkFontTypes,
MkFontError,MkBundledFontIndex}.kt` are Batch 3.7-owned and untouched by any Batch 6 agent —
listed here only to make the disjointness with Agent 6.5's subset explicit, not because a
Batch 6 agent owns them.

> **D-311 grace/hold note.** The client-only heuristic for `inGracePeriod`/`inBillingRetry` —
> and the reason a confirmed distinction needs the server-side Play Developer API
> Subscriptions v2 endpoint, out of scope per D-311/D-304's "no backend" posture — is stated
> in Agent 6.1's packet body (Mission and Tasks §1's mapping table) as a first-class part of
> the agent's own instructions, not left as an appendix aside. The master plan states the same
> limitation in D-311 itself and lists it in its out-of-scope section; this appendix note is
> kept short deliberately so the two documents stay in sync rather than drifting apart.
