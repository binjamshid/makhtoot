# Makhtoot — App Privacy Nutrition Label Input

**WS-12 T15 / APP_STORE_CHECKLIST cross-reference**

This document maps Makhtoot's data practices to the App Store Connect
"App Privacy" questionnaire fields. Every answer is marked
**VERIFY-AT-SUBMISSION** — cross-check against the live ASC questionnaire
wording before submitting.

---

## Data types collected

### When consent is OFF (default)
**Nothing is collected, buffered, or transmitted. No network calls related to
analytics are made.** (D-125: opt-in default OFF.)

### When consent is ON (user explicitly enabled)

| Data type | Collected? | Linked to identity? | Used for tracking? |
|---|---|---|---|
| Product Interaction (font usage, bucketed weekly) | Yes | No | No |
| User Content | No | — | — |
| Identifiers | No | — | — |
| Location | No | — | — |
| Diagnostics | No | — | — |

**VERIFY-AT-SUBMISSION**: Map to the exact ASC questionnaire categories
(they change; the table above uses the 2024-era category names as a
starting point).

---

## iCloud sync data (WS-11 MKSync)

Project files are stored in the user's **own** iCloud Drive container —
this is user content in the user's private iCloud account, not developer
collection. ASC category: "User Content / Other User Content" — but this
is the user storing their own data, not the developer receiving it. Consult
ASC's "Data used to track you" vs. "Data linked to you" guidance carefully.

**VERIFY-AT-SUBMISSION** with counsel or Apple's own documentation on
iCloud Drive / CloudKit private database classification.

---

## ATT (App Tracking Transparency) analysis

**ATT prompt is NOT required.** Reasoning:
- No cross-app or cross-website tracking (first-party, in-app only).
- No third-party analytics SDKs.
- The analytics data collected (bucketed weekly font-usage counts) is not
  used to track the user across contexts owned by other companies.
- D-125 explicitly prohibits any identifiers that could enable cross-context
  linking.

If any future change adds third-party SDKs or cross-app/website tracking,
this analysis MUST be redone. (D-125/WS-12 packet §6.)

**VERIFY-AT-SUBMISSION**: Confirm ATT analysis remains valid against the
final shipped feature set.

---

## Privacy Policy & Terms of Use

Both URLs are placeholder-pending (PLACEHOLDER-FD-01):
- Privacy Policy: `MKLegalLinks.privacyPolicyURL` — see `MKAnalytics/MKLegalLinks.swift`
- Terms of Use: `MKLegalLinks.termsOfUseURL` — see `MKAnalytics/MKLegalLinks.swift`

**VERIFY-AT-SUBMISSION**: Replace all `PLACEHOLDER-FD-01` markers with
real URLs (grep `PLACEHOLDER-FD-01` repo-wide). Guideline 3.1.2 requires
both to be functional links in the binary.

---

## Third-party SDK inventory

**None.** D-101: zero third-party dependencies in v1. No SDK is used for
analytics, crash reporting, advertising, or any other purpose. All network
calls are first-party (CloudKit, StoreKit 2, iCloud Drive).

**VERIFY-AT-SUBMISSION**: Run `swift package show-dependencies` and confirm
the `dependencies: []` invariant still holds.

---

*Last updated by WS-12 (2026-07-19). Owner: founder + WS-15 for submission.*
