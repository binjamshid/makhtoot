# Trial model: app-side trial vs. Apple introductory offer (T7)

## Two different mechanisms, easy to conflate

Makhtoot ships exactly one trial mechanism in v1: the **app-side 7-day
trial** (D-123), implemented entirely in `MKTrialManager`. Apple's own
**introductory offer** system (a StoreKit/App Store Connect feature) is
**not configured anywhere** in this app — `Makhtoot.storekit` has no
introductory offer on either subscription product, and no offer is
configured in App Store Connect either (WS-15/FOUNDER own that setup, and
are told not to add one).

The two are easy to conflate because both are commonly called "a free
trial," but they differ in every load-bearing way:

| | App-side trial (Makhtoot, v1) | Apple introductory offer (not used) |
|---|---|---|
| Who grants it | `MKTrialManager`, Makhtoot's own code | StoreKit, per Apple's eligibility rules |
| Eligibility | Everyone, once per install lineage (Keychain-anchored) | Per Apple ID, per subscription group, `isEligibleForIntroOffer` — an Apple ID that has ever had *any* subscription in the group is ineligible again |
| Starts at | First app launch (Q37) — no purchase intent required | Purchase / subscribe action |
| Requires payment method on file | No | Yes (Apple requires a payment method even for a free intro period) |
| Persists across reinstall | Yes (Keychain `kSecAttrAccessibleAfterFirstUnlock`) | No independent persistence — governed by Apple ID eligibility, not app state |
| Persists across devices | Yes (iCloud KVS mirror, earliest-wins) | Governed by Apple ID, so implicitly yes, but Makhtoot has no visibility into or control over it |

## Why v1 uses app-side only (D-123)

Configuring *both* an app-side trial and an Apple introductory offer would
create a **double-trial / eligibility divergence** problem: a user could
get the app-side 7 days, then separately qualify for Apple's intro offer
on top (different eligibility clock, different starting condition), or
conversely be surprised that their Apple ID's intro-offer eligibility was
already consumed by a completely unrelated app in the same subscription
group naming pattern (not actually possible across apps, but the
per-subscription-group eligibility rule is easy to reason about wrong).
Shipping exactly one mechanism — the one Makhtoot fully controls — avoids
that divergence entirely and keeps the trial's behavior fully testable
without any StoreKit sandbox account.

## Consequence: App Store Connect / marketing copy constraints

Because there is no Apple introductory offer configured:

- **App Store product page copy must never claim an Apple free trial.**
  Apple's own product-page trial badges/copy are driven by actual
  introductory offer configuration — since none exists, no such badge will
  appear, and marketing copy must not claim one exists either (this would
  be a factual misstatement reviewable as misleading metadata).
- **In-app paywall copy** uses the app-side framing exclusively:
  **"٧ أيام مجانًا داخل التطبيق"** (roughly: "7 free days, inside the
  app") — deliberately phrased to describe an app-level unlock, not an
  Apple-billing-level trial. `MKPaywallStateMachine`/WS-13's rendering
  must use this exact framing, not "free trial" alone (which in App Store
  context implies the Apple mechanism).
- **`MKTrialManager` never touches `Product.SubscriptionInfo.isEligibleForIntroOffer`
  or any intro-offer API.** If a future version reconsiders this decision,
  it is a new decision (amending D-123), not a silent addition — see
  `Docs/ServerAPISeam.md`/`ARCHITECTURE.md` §18 for where such a change
  would need to be threaded through the entitlement resolver's precedence
  logic (an Apple intro offer would just be additional `.subscribed`
  signal, not a new `MKEntitlementState` case).

## Cross-reference

`APP_STORE_CHECKLIST.md`'s paywall-compliance section should link back to
this document when reviewing product-page copy before submission — the
constraint above ("no Apple free-trial wording") is a review-blocking
factual-accuracy issue, not a style preference.
