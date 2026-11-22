# MKAnalytics — CloudKit Schema Documentation

**WS-12 T3 / WS-12-A3 ADR**

This document records the CloudKit public-database schema for Makhtoot's
anonymous font-usage analytics. Every field decision is justified against
D-125's prohibition list. The `MKPayloadAllowlistTests` test suite asserts
that the serialized upload payload contains ONLY the fields listed below —
any new field will fail that test, which is the technical enforcement gate.

---

## Record type: `MKFontUsageBatch`

| Field       | Type   | D-125 Justification |
|---|---|---|
| `batchID`   | String | Random UUID generated per upload, never stored after success, never reused. Not a user identifier — just a de-duplication key for the public DB write. |
| `week`      | String | ISO 8601 week string (e.g. `"2026-W29"`). Granularity: week only. D-125 prohibition: "no timestamps finer than week". |
| `appVersion`| String | Major.minor only (e.g. `"1.0"`). No build or patch number. Needed for aggregate trend analysis per version. |
| `entries`   | String | JSON array of `{fontID, bucket}` pairs. Raw counts never appear — only the bucket label (one of `1-4`, `5-9`, `10-24`, `25-49`, `50+`). |

## Explicitly ABSENT fields (D-125 prohibition list)

The following fields are intentionally, permanently absent from every upload:

| Absent field | Why prohibited |
|---|---|
| User record reference / `userRecordID` | Public DB writes happen with no custom user linkage — the developer cannot correlate batches to any user account. |
| Device model / `deviceModel` | Not collected. Could narrow re-identification space. |
| Locale / `locale` | Not collected. |
| Vendor ID / IDFV | Not collected. D-125: "no identifiers". |
| Exact date / timestamp | D-125: "no timestamps finer than week". |
| Text content | Never. D-125: "never: text, projects". |
| Font file | Never. D-125: "never: font files". |

## Record type: `MKAnalyticsConfig` (kill-switch, T5 / D-207)

| Field | Type | Purpose |
|---|---|---|
| `analyticsEnabled` | Bool | Remote kill-switch (D-207 layer 2). Founder flips this via CloudKit Dashboard to halt all uploads instantly without an app update. `recordName = "config"`. |

Offline behavior: last-known value cached locally. Default to `true`
(enabled) if the record has never been fetched (T5 AC: "offline-with-no-
prior-fetch defaults to enabled").

---

## Bucket boundaries (WS-12-A2 ADR rationale)

Coarsening raw weekly counts into 5 buckets (rather than uploading exact
counts) provides re-identification resistance: knowing that a user used
font "amiri" in the range 5–9 times in a given week cannot be used to
reconstruct a usage timeline or cross-correlate with other behavioral signals
beyond what the developer already knows in aggregate.

| Bucket label | Raw count range |
|---|---|
| `1-4`   | 1–4   |
| `5-9`   | 5–9   |
| `10-24` | 10–24 |
| `25-49` | 25–49 |
| `50+`   | ≥50   |

---

*VERIFY-AT-SUBMISSION: confirm against the live CloudKit Dashboard schema
before App Store submission (WS-15 checklist).*
