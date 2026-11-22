# Referral module — App Review risk memo (T15)

**Status: FLAG OFF / COMPILE-TIME EXCLUDED FOR v1. Do not activate without
completing the FD-05 reconfirmation step below.**

## 1. What this module does

`MKStore/Referral/` (T14) implements a referrer-only reward mechanic:

- A user generates a local, offline referral code (`MKReferralCodeGenerator`
  — `base32(SHA-256(installUUID + salt))`, 8 chars, `MK-` prefix).
- A friend manually enters that code in their own copy of the app
  (`MKReferralRedemption` — honor-based; there is no server to verify the
  entry corresponds to a real invitation).
- The **referrer** (code owner) is granted +7 trial days per qualifying
  redemption, capped at 4 extensions (28 days total), enforced by
  `MKReferralLedger`.
- The **invitee** (code enterer) receives nothing for entering the code
  itself — no reward is granted on entry alone.

## 2. Why the mechanic is designed this way (review-risk containment)

Market study §8 documents a consistent Apple App Review enforcement
pattern: rewarding the **invitee** for signup/download/registration is
**documented rejection territory** [^53][^54]. Rewarding only the
**referrer**, and only on a **qualifying paid action** by the invitee, is
the pattern precedent treats as acceptable.

This design follows that pattern strictly:

- No reward fires on code *entry* alone (`codeEntered` is recorded locally
  as a v1-design placeholder for a real qualifying action — see §4).
- The only reward path (`TrialManager.extend(by: 7, source: .referral)`) is
  reachable exclusively through `MKReferralLedger.recordRedemption`, which
  is the referrer's own device recording that someone used the referrer's
  code — the invitee's device never grants itself anything.

**Important caveat, stated plainly:** this restriction is **inferred** from
Guideline 3.1.1 ("Acceptable")/3.2.2 ("Unacceptable Business Models")
enforcement precedent, not from a single quoted clause in the current
Guidelines text [^55]. Treat the risk assessment above as inferred, not
authoritative, and re-verify against the *current* Guidelines text before
any activation (see §5).

## 3. Compile-time exclusion (D-225, supersedes the original runtime-flag
design)

Originally (D-124) dormancy was a runtime check:
`MKFeatureFlags.referralProgram == false`. **FOUNDER-CONFIRMED 2026-07-17
(D-225):** the shipping mechanism is now compile-time exclusion —

- `Sources/MKStore/Referral/**` and every call site (including the app
  target's referral settings section) are wrapped in
  `#if MAKHTOOT_REFERRAL_ENABLED`.
- That compilation condition is defined **only** in Debug/internal build
  configurations — never in Release (see `Makhtoot.xcodeproj/project.pbxproj`
  Release configuration; the flag must be absent there, not merely unset to
  `0`/`false`).
- Referral-specific Arabic vocabulary (دعوة / إحالة / رمز الدعوة) lives
  outside the shared `Localizable.xcstrings` catalog, as Swift string
  literals inside the same `#if`-gated files — so it cannot leak into the
  shared string table's Release build either.
- The CI `referral-removal-check` job (T15, see `Scripts/referral-release-grep.sh`)
  greps the **built Release product itself** — not the source tree, not a
  Debug build — for referral vocabulary, and fails the build if any is
  found. This is the actual proof the exclusion works; the `#if` alone is
  trusted for nothing.

## 4. Attribution design (v1 vs. future)

**v1 (this packet, honor-based):** no backend exists. The only signal
either party has is the code exchange itself:

1. Referrer generates a code locally, shares it (out-of-band — Messages,
   ShareLink, etc.).
2. Invitee enters the code manually. This is recorded on the *invitee's*
   device only, as `codeEntered` — a placeholder for "a real qualifying
   action happened," not the action itself.
3. There is currently no mechanism for the invitee's device to
   automatically inform the referrer's device that a real qualifying
   action (e.g. a paid conversion) occurred, because there is no server.
   `MKReferralLedger.recordRedemption` in this v1 implementation grants
   the referrer's extension at code-entry time on the REFERRER's own
   ledger once the referrer separately learns the code was used — this is
   the documented weakness: **attribution cannot be independently
   verified**, only honor-based.

**Future (extension seam, not v1):** a real backend (App Store Server API
+ owned server, `Docs/ServerAPISeam.md`) would let the invitee's *actual*
purchase event server-side-confirm the referrer's reward, closing this gap
without trusting either device. No code changes to `MKEntitlementProviding`
would be required — the seam is designed to slot in underneath it.

## 5. Activation checklist (FD-05 — founder decision, required before ANY
activation)

Before setting `MAKHTOOT_REFERRAL_ENABLED` in any build configuration that
could ship (i.e. before flipping it on anywhere other than a local Debug
scheme for internal testing of this module itself):

1. Re-read the *current* App Store Review Guidelines §3.1.1/§3.2.2 text —
   guidelines change; the citations above are dated to this packet's
   writing, not guaranteed current at activation time.
2. Confirm no invitee-side reward has been added since this memo (v1 has
   none, by design — re-verify the diff, not just this memo, at
   activation time).
3. Re-run `Scripts/referral-release-grep.sh` against a fresh Release build
   with the flag ON in a non-Release configuration, to confirm the
   isolation still holds against however the code has drifted.
4. Get explicit founder sign-off (FD-05) referencing this checklist.

**VERIFY-AT-SUBMISSION.** This module stays OFF for v1 regardless of the
above — activation is out of this packet's scope entirely (D-124/FD-05).

[^53]: Market study §8, App Review referral precedent (invitee-reward rejection pattern).
[^54]: Market study §8, App Review referral precedent (referrer-only-on-qualifying-action acceptance pattern).
[^55]: Market study §8, footnote on inferred-vs-quoted Guideline text for 3.1.1/3.2.2.
