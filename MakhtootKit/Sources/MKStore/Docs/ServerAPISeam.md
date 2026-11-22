# App Store Server API — extension seam (T18)

**No code in this document. No backend exists in v1 (D-113).** This
records what a *future* backend would add and, more importantly, which
protocol surfaces stay stable so that future work is additive rather than
a rewrite.

## What v1 does instead

All verification in v1 is **on-device**: StoreKit 2's own JWS
(`VerificationResult`) check, performed by `checkVerified(_:)` on every
transaction/renewal-info/subscription-status this module reads. This is
Apple's own recommended baseline and requires no server, no API keys, no
infrastructure — appropriate for a v1 with no other backend dependency
(the app is otherwise fully offline-first).

## What a future App Store Server API integration would add

1. **Server-side receipt validation** — an independent cross-check of
   transactions against Apple's servers, catching the (rare) case where
   on-device JWS verification alone is insufficient (e.g. certain refund/
   chargeback edge cases surface faster server-side than via
   `Transaction.updates`).
2. **Referral qualifying-event confirmation** — closes the v1 referral
   attribution gap documented in `Referral/REVIEW_RISK_MEMO.md` §4: a
   server could confirm the invitee's actual purchase and push a
   verified reward to the referrer, instead of the current honor-based
   code exchange.
3. **Refund/revocation observability** — server-side notifications
   (App Store Server Notifications V2) as a second, push-based signal
   alongside the on-device `Transaction.updates` listener, useful for
   analytics/support tooling that needs to know about refunds without the
   affected device being online at the time.

## Protocols that stay stable

- **`MKEntitlementProviding`** (`MKFoundation`) — the synchronous `state`
  property + `isEntitled(_:)` — is the seam every downstream consumer
  (`MKExport`, `MKFonts`, `MKSync`, app UI) already codes against (D-230).
  A server-backed resolver would still conform to this exact protocol;
  nothing downstream would need to change.
- **`MKEntitlementResolver`'s internal shape** — `resolve()` gathering
  StoreKit signals and folding them through `MKEntitlementPrecedence.resolve`
  — would gain an additional signal source (server confirmation) merged in
  alongside the on-device StoreKit signal, not a replacement of it. The
  pure precedence function itself (`MKEntitlementPrecedence`) would not
  need to change at all — it already treats "the subscription signal" as
  an opaque input regardless of how it was gathered.
- **`MKPurchaseController`** — `purchase(productID:)`/`restore()` — would
  gain a server-confirmation step inserted between "StoreKit says
  success" and "grant locally," but the public outcome enum
  (`MKPurchaseOutcome`) would not need new cases for this; a server
  rejection of an already-StoreKit-verified transaction is exceptional
  enough to be logged/reported rather than modeled as a new UI state in
  v1's design space.

## Extension-seam protocol sketch (ARCHITECTURE §24.5)

ARCHITECTURE.md §24.5 names the intended seam protocol —
`MKEntitlementVerifying`, with v1 registering an `MKOnDeviceVerifier`
conformer (i.e. today's `checkVerified(_:)` helper, wrapped). This packet
does not introduce that protocol type (no code, per this document's own
header) — it is recorded here as the named landing point for whichever
future workstream adds the actual server integration, so that work starts
from an agreed name/shape rather than inventing one from scratch.

## Cross-references

- `ARCHITECTURE.md` §18 (StoreKit & Entitlements), §24 (Extension Seams).
- `Referral/REVIEW_RISK_MEMO.md` §4 (the specific gap this seam closes for
  referral attribution).
- `MakhtootKit/CONTRACTS.md` (protocol-seam-not-concrete-module rule,
  D-230 — the same rule this seam would have to respect).
