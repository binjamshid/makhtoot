# StoreKit sandbox test plan (T12)

Maps to `TEST_MATRIX.md`'s `T-SK-*` block (21 ids) and this packet's own
§7 gate shorthand `T-store-01…10`. Each scenario lists preconditions, the
StoreKit-testing (local `.storekit` file, `Makhtoot.storekit`) steps run in
this environment, and — where the scenario genuinely requires a live Apple
sandbox account or a physical second device — what's deferred and why.

Automatable-in-this-environment scenarios are implemented as `Testing`
(swift-testing) suites in `MakhtootKit/Tests/MKStoreTests/` against
`Makhtoot.storekit`, run via `swift test`/`xcodebuild test`. Scenarios
marked **[SANDBOX-DEFERRED]** need either a real Apple ID signed into
TestFlight/App Store Connect Sandbox, a second physical device, or
StoreKit-testing UI features (Xcode's Transactions manager clicking
"Fail renewals"/"Ask to Buy" toggles interactively) not scriptable from
this environment — they're documented here so a founder/CI-with-sandbox-
access run can execute them later.

| id | Scenario | Preconditions | Steps | Expected `MKEntitlementState` | Status |
|---|---|---|---|---|---|
| T-SK-1 | Products load, localized prices | `Makhtoot.storekit` loaded | `MKProductCatalog.load()` | `.loaded([3 products])`, non-empty `displayPrice` for each | Automated |
| T-SK-2 | Purchase monthly | Clean StoreKit-testing container | `MKPurchaseController.purchase(productID: .monthly)`, auto-confirm via `SKTestSession` | `.subscribed` | Automated (StoreKit-testing) |
| T-SK-3 | Purchase annual | Same | Same, `.annual` | `.subscribed` | Automated (StoreKit-testing) |
| T-SK-4 | Purchase lifetime | Same | Same, `.lifetime` | `.lifetime` | Automated (StoreKit-testing) |
| T-SK-5 | Upgrade/crossgrade monthly ⇄ annual | Active monthly purchase | Purchase annual while monthly active | Resolver reflects the highest-precedence single subscribed state post-crossgrade (group semantics — StoreKit itself resolves crossgrade); no double-charge | **[SANDBOX-DEFERRED]** — crossgrade proration/timing needs a real subscription-group sandbox account; StoreKit-testing's crossgrade support is limited |
| T-SK-6 | Lifetime purchased while subscribed | Active monthly/annual | Purchase lifetime | `.lifetime`; T19 redundant-subscription sheet fires once | Automated (StoreKit-testing) |
| T-SK-7 | Restore on second device | Purchase on device A | `AppStore.sync()` on device B (same Apple ID) | Device B resolves the same premium state | **[SANDBOX-DEFERRED]** — requires two physical/simulator devices signed into the same sandbox Apple ID |
| T-SK-8 | Interrupted purchase | — | `.userCancelled` path | State unchanged, no error banner | Automated |
| T-SK-9 | Ask-to-Buy / deferred | Family Sharing sandbox org | `.pending` path | `MKPurchaseOutcome.pendingApproval`; entitlement state unchanged per D-228(5) until a verified transaction arrives | **[SANDBOX-DEFERRED]** for the real Ask-to-Buy flow (needs a Family Sharing sandbox organizer); the `.pending` code path itself is unit-tested with a fake purchase result |
| T-SK-10 | Expiry | Subscription reaches natural expiry | Time-advance in StoreKit-testing | `.free` (or `.trial` if one remains — D-228(3)) | Automated (StoreKit-testing time control) where available; documented deferred otherwise |
| T-SK-11 | Grace period simulation | Active subscription, "Fail renewals" enabled in StoreKit-testing | Trigger renewal failure | `.inGracePeriod`, banner surfaced | **[SANDBOX-DEFERRED]** — "Fail renewals" is an interactive Xcode StoreKit-testing UI toggle, not scriptable from this environment; precedence-level behavior (given a `.inGracePeriod` signal) IS covered by the pure `MKEntitlementPrecedenceTests` suite |
| T-SK-12 | Billing retry | Same as T-SK-11, extended failure | Same | `.inBillingRetry`, stronger banner | **[SANDBOX-DEFERRED]** (see T-SK-11); precedence-level behavior covered by unit tests |
| T-SK-13 | Revocation / refund | Active purchase | Revoke via StoreKit-testing Transactions manager | `.free` (or lower-precedence state); in-flight export (if any) completes, next export re-gates (T4/D-228) | **[SANDBOX-DEFERRED]** for the interactive revocation trigger; the revocation-mid-export non-cancellation behavior is structural (documented in `MKEntitlementResolver.startTransactionListener`'s doc comment) and not independently re-verifiable without WS-08's export pipeline, which is out of this packet's fence |
| T-SK-14 | Trial state machine, first launch | No prior Keychain/KVS record | `MKTrialManager.resolve()` | `.active(daysLeft: 7)` | Automated |
| T-SK-15 | Trial persists across reinstall | Keychain record exists, UserDefaults/app-container wiped | Simulate reinstall (fresh `MKTrialManager` over the same Keychain-backed store, fresh in-memory KVS) | Same anchor, same remaining days | Automated (Keychain persistence itself needs a real device/simulator install-delete-reinstall cycle for full confidence — **[SANDBOX-DEFERRED]** for that end-to-end device pass; the persistence-across-object-lifetime behavior is unit-tested) |
| T-SK-16 | iCloud KVS reconciliation | Two simulated stores with divergent anchors | `mergedRecord()` merge rule | Earliest `firstLaunchAt` wins; includes a delayed/retroactive-shrink case (KVS delivers an EARLIER anchor after local was already observed later) | Automated |
| T-SK-17 | Wall-clock high-water mark + uptime cross-check | Fake clock | Roll wall clock back while uptime advances normally (same session); separately, roll back with a reboot (uptime reset) | daysLeft never increases in the same-session case; reboot+rollback residual documented, not silently "fixed" | Automated |
| T-SK-18 | Entitlement resolver precedence, full 3-axis matrix | — | `MKEntitlementPrecedence.resolve` over the realizable combinations (D-228/R2-11-4) | Matches D-113 exactly, including `trial+billingRetry`, `trial+expired-sub`, `lifetime+expired-sub`, `grace+trial` (DF-8) | Automated |
| T-SK-19 | Offline entitlement | Cached `.lifetime`/`.subscribed` state | Airplane mode, relaunch | Cached state honored; `.lifetime` indefinitely, `.subscribed` until staleness tolerance (3 days) | Automated (cache-file round trip); real airplane-mode device pass is **[SANDBOX-DEFERRED]** |
| T-SK-20 | Referral module inert (flag OFF) | Release build config (no `MAKHTOOT_REFERRAL_ENABLED`) | Build + grep binary | Zero referral symbols/strings | Automated (`Scripts/referral-release-grep.sh`, T15) |
| T-SK-21 | Post-lifetime-purchase redundant-subscription sheet | Active subscription | Purchase lifetime | Sheet fires once; does not re-fire on relaunch; does not fire when purchasing lifetime from free/trial | Automated (`MKPurchaseController` unit tests with a fake product/transaction) |

## Sandbox-deferred summary (for founder/CI-with-sandbox follow-up)

T-SK-5, T-SK-7, T-SK-9 (interactive Ask-to-Buy), T-SK-11, T-SK-12, T-SK-13
(interactive revocation trigger), T-SK-15 (physical reinstall pass), T-SK-19
(physical airplane-mode pass) need either a real sandbox Apple ID, a second
device, or interactive Xcode StoreKit-testing UI manipulation not available
to a scripted environment. Every OTHER scenario is covered by an automated
`Testing`-framework suite in `MakhtootKit/Tests/MKStoreTests/`.
