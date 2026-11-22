# INVARIANTS.md

Cross-boundary facts that are duplicated in more than one place in this repo, with
no single owner the compiler enforces. Pattern source: badan's `INVARIANTS.md` +
`.github/workflows/ci.yml`'s contract-mirror job (portfolio house standard, matrix
row 12). Added 2026-07-20 as part of the portfolio house-standard pass — this file
records what already exists; it introduces no new duplication.

**Precedence rule:** where an invariant below names a canonical source, that source
wins on any disagreement. A mirror that disagrees with its canonical source is a bug
in the mirror, not a reason to re-derive the canonical value from the mirror.

---

## INV-1 — Premium product/subscription-group identifiers

**Canonical source:** `MakhtootKit/Sources/MKStore/MKStoreIDs.swift` (Swift enum
`MKStoreIDs` — the only one of the three locations the compiler checks anything
about; consuming Swift code that misspells an id fails to compile against it).

**Mirrors (data, not code — nothing checks these against the canonical source):**
- `MakhtootKit/Sources/MKStore/Makhtoot.storekit` — StoreKit Testing configuration
  used by `MakhtootKit`'s own package test target.
- `Makhtoot/Config/Makhtoot.storekit` — StoreKit Testing configuration used by the
  app target's Xcode scheme.

**Why this is a real invariant, not a hypothetical one:** the three product ids
(`net.binjamshid.makhtoot.premium.{monthly,annual,lifetime}`) and the subscription
group name (`Makhtoot Premium`) are typed as plain JSON strings in both `.storekit`
files. Nothing stops a future edit to `MKStoreIDs.swift` (e.g. a renamed tier) from
silently drifting from either config — StoreKit Testing would then simulate
purchases against ids the real `MKPurchaseController`/`MKEntitlementResolver` never
requests, and the drift would only surface as a confusing test failure, not a
build error.

**Enforcement:** `Scripts/check-storekit-ids.sh` extracts the canonical id set from
`MKStoreIDs.swift` and diffs it against `productID` values in both `.storekit`
files. Exit 1 on any mismatch. Run it before editing either StoreKit config or
`MKStoreIDs.swift`, and wire it into CI (`.github/workflows/ci.yml`).

---

## Considered and rejected as invariant candidates

Recorded here so this file stays the honest, complete answer to "what duplicates
what" rather than a partial list that quietly grows stale.

- **Bundle id** (`net.binjamshid.makhtoot`) appears in `Makhtoot.xcodeproj/project.pbxproj`
  (both Debug and Release configurations) and is referenced in prose across
  `README.md`, `PRD.md`, `ARCHITECTURE.md`, and `MKStoreIDs.swift`'s doc comment.
  Not treated as an INV: the `.pbxproj` copies are Xcode-generated and always kept
  in lockstep by Xcode itself when the bundle id is edited via the project editor;
  the doc-comment/prose references are documentation, not independently-executing
  logic, and are covered by the doc-truth "code wins on disagreement" rule in
  `README.md` instead of a dedicated equality script.
- **`MKTheme` protocol requirements vs. `InkPaperTheme`'s conformance** — not an
  invariant candidate at all: Swift's compiler already rejects a build where the
  conformer is missing a protocol requirement, so there is no gap a script could
  close that the type system doesn't already close for free.
