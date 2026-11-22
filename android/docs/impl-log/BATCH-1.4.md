# BATCH-1.4 impl log — Contract stubs B (canvas, export, fonts, persistence, sync, store, analytics, designsystem, assets, app)

Agent 1.4. Scope per `ANDROID_TASK_PACKETS/BATCH-1.md` lines 541–953: nine
`MakhtootKit`-derived Gradle modules plus `:app`'s screen-level entry points.
Mechanical source: `android/API_SURFACE.md` (Batch 0 · Agent 0.3).

**Session note:** an earlier attempt in this same batch slot was cut short
before anything reached disk (session process exit, not a tool error). This
log starts from a clean, verified-empty state and proceeds one module at a
time, smallest first, writing and verifying after each module so partial
progress survives any future interruption.

## Method

Given the scale (2,086 symbols across 175 library files, plus 55 `:app`
files), stub generation is script-driven rather than file-by-file hand
transcription: a small Python pipeline (kept in the session scratchpad, not
checked into the repo) parses each Swift source file's declarations
(struct/class/enum/protocol/extension/func/var/let/init/typealias, with
brace-balance-based container nesting — a heuristic line-oriented scanner,
not a compiler front end, in the same spirit as
`Scripts/android/dump-api-surface.sh`) and emits Kotlin:

- A **data-shape type** (struct/enum/protocol with stored properties or
  enum cases) gets a **real** Kotlin `data class` / `sealed class` /
  `enum class` / `interface` definition — same fields, same nesting,
  literal constant values preserved (e.g. `MKStoreIDs`'s actual product-id
  strings survive the port, not blanked placeholders).
- Every **function / computed property / method** body is exactly
  `throw MkNotYetPorted("<module>.<Type>.<member>")`.
- `static`/`class` members land in a Kotlin `companion object`.
- A Swift `protocol` plus a same-file `public extension` supplying default
  implementations (a common pattern in this codebase, e.g.
  `MKEntitlementProviding`) is merged into **one** Kotlin `interface`: the
  protocol's own requirements are abstract, the extension's defaults get
  the throwing body directly on the interface (not a colliding top-level
  extension function).
- A **known, documented cross-check finding**: Swift protocol requirements
  and `public extension` members never carry an explicit `public`/`open`
  token themselves (a protocol requirement cannot be marked `public` at
  all — compiler error — and a `public extension` applies public access to
  its members by default). `android/API_SURFACE.md`'s own dump script
  requires an explicit `public`/`open` token per declaration line, so it
  systematically **undercounts** protocol-requirement and
  protocol-extension-default symbols across all 16 targets, not just this
  agent's nine. This agent's generator cross-checks against the real
  Swift source (as instructed — `MakhtootKit/Sources/**` is listed as
  "ground truth for disambiguation against API_SURFACE.md" in the
  packet's Reads table) and recovers these via a second pass scanning
  `protocol`/`extension` bodies directly. Net effect: this agent's actual
  emitted-symbol count is expected to meet-or-exceed the API_SURFACE.md
  per-target count, never fall short of it for this reason.

### Known limitations of the mechanical port (documented, not silent)

- Generic `where`-clause bounds are dropped (kept only when expressible as
  a simple `<T : Bound>`).
- A default parameter value that is not a literal, `nil`, an empty
  collection, a zero-arg constructor call, a bare identifier, or a simple
  array literal of such elements is dropped (parameter becomes required)
  rather than guessed at.
- Multi-arg generics (e.g. `Dictionary<K, V>`) appearing inside a
  top-level comma-separated parameter list are a residual mis-split risk
  — the splitter deliberately does not track `<`/`>` bracket depth because
  a bare `>` is indistinguishable from the second character of a `->`
  arrow under a cheap character scan, and `->` (closure-typed parameters)
  is far more common in this codebase than a comma-bearing generic
  default in a parameter list.
- Tuples beyond 2 elements, existential/opaque (`any`/`some`) markers, and
  `async`/`throws` are normalised away (Kotlin has no checked exceptions;
  `async` becomes `suspend`).
- A handful of individual declarations may still appear as an
  `// UNPARSED ...` comment when the line-oriented scanner cannot resolve
  them — each module's write-up below states the count actually observed
  for that module (target: zero).

Every file this agent produces is exclusive-owned Kotlin source under the
nine modules' `src/main/kotlin/**` (plus the one named `src/debug/kotlin/**`
file) and `:app`'s `src/main/kotlin/**` — no `build.gradle.kts`, no other
module's `src/**`, nothing outside `android/`.

## Per-module log

### `:mk-analytics` (expected 84 symbols per API_SURFACE.md, 13 files)

13/13 files written, 0 crashes, 0 `UNPARSED` markers, brace-balanced.
Real data classes: `MkConsentRecord`, `MkFontUsageBucket`,
`MkDisclosureContent`, `MkFontUsageBatch`, etc. Real enum:
`MkAnalyticsError` → Kotlin `sealed class MkAnalyticsError : Exception()`
(Swift `Error` conformance mapped to a `Throwable` base). Static
namespace-style members (e.g. `MkAnalyticsLog`) landed in
`companion object`. Files:

- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentManager.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentRecord.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentStatus.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/counter/MkFontUsageBucket.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/counter/MkUsageCounterStore.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkAnalyticsError.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkAnalyticsLog.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkLegalLinks.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/service/MkAnalyticsService.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/service/MkDisclosureContent.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkAnalyticsUploader.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkCloudKitPublicDatabase.kt`
- `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkFontUsageBatch.kt`

`MkNotYetPorted` (owned by Agent 1.3, `:mk-foundation`) had not yet landed
on disk at the time this module was written — every stub body here imports
`net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted` per contract-first
(spine ground rule 5); compilation of this module is blocked on 1.3's file
landing, not on anything in this agent's scope.

### `:mk-sync` (expected 114 symbols, 10 files)

10/10 files written, 0 crashes, 0 `UNPARSED` markers, brace-balanced.
`MkSyncDecisionEngine`, `MkConflictNaming`, `MkSyncPendingQueue`,
`MkProjectRecordCoder` ported with real data-shape types where the Swift
source is a struct/enum with stored fields; `MkSyncEngineController` (841
LOC Swift source, the largest file in this module) ported as a stub class
with every method throwing. Files:

- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/account/MkSyncAccountState.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/changetracking/MkSyncPendingQueue.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/conflict/MkConflictNaming.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/conflict/MkSyncDecisionEngine.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/engine/MkSyncEngineController.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/errors/MkSyncError.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/schema/MkSyncSchema.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/serialization/MkProjectRecordCoder.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/status/MkSyncStatus.kt`
- `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/tunables/MkSyncTunables.kt`

No `:mk-sync → :mk-store` edge introduced (spine §3.2) — entitlement/premium
gating in this module's stubs references `MKEntitlementProviding`-shaped
types only.

### `:mk-store` (expected 139 symbols, 18 files)

18/18 files written, 0 crashes, 0 `UNPARSED` markers, brace-balanced.
`MKStoreIDs` → `MkStoreIds.kt` (naming rule's own worked example, spine
§3.3) ported with its **real** product-id string constants preserved
(`net.binjamshid.makhtoot.premium.monthly` etc.), not blanked — this is a
data-shape/constants file per task item 2, not stub logic. Files:

- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementDetail.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementPrecedence.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementResolver.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkProductCatalog.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkPurchaseController.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkStoreError.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkStoreIds.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/paywall/MkPaywallStateMachine.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralCodeGenerator.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralLedger.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralRedemption.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/testing/MkSandboxScenarioStub.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkClockProviding.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkSecureStore.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkTrialManager.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkTrialRecord.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkUbiquitousStore.kt`
- `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkVerification.kt`

Note: the `referral/` source set here is `MKStore`'s referral logic
(code generator, ledger, redemption) — this batch does not yet apply
D-321's debug-only/release-exclusion Gradle wiring (that is Agent 1.1's
`build.gradle.kts` concern and/or a later batch); this agent only ports
the symbols as contract stubs at their frozen paths under `src/main/`,
matching every other module in this batch. Flagging this explicitly so a
later batch does not assume the exclusion is already wired.

### `:mk-export` (expected 170 symbols, 22 files)

22/22 files written, 0 crashes, 0 `UNPARSED` markers (after fixing two
generator gaps found while porting this module — see below), brace-balanced.
`MkExportCoordinator` (Swift: `public actor`) ported as a `class` with its
9-parameter `init` becoming the primary constructor (parameter defaults
that are non-trivial expressions, e.g. `MKTileRenderer.maxTileBytes`, are
intentionally dropped per the documented default-value policy — the
parameter becomes required rather than guessing at a Kotlin-side default).
`MkExportFormat`'s `Codable` custom `init(from:)`/`encode(to:)` — declared
in a same-file `extension MKExportFormat` that itself carries no explicit
`public` (only its members do) — surfaced two real generator gaps fixed
during this module, both now covered by regression checks on the earlier
modules (re-ran clean):

1. **Container discovery required the container keyword itself to be
   explicitly `public`.** A Swift `extension Foo { public init(...) }`
   needs no `public` on `extension` itself for its members to be public
   API. Fixed by a second any-access container-header scan, merged in
   only when it either is an `extension` or already encloses a
   known-public member (so a genuinely private/internal type never leaks
   in as a spurious empty stub class).
2. **Extension-scoped `init` had no rendering path at all** (Kotlin has
   no "extension constructor"). Fixed: rendered as a top-level named
   factory function `fun new<Target>(...): <Target> { throw
   MkNotYetPorted(...) }`, documented as a mechanical, non-idiomatic but
   compiling substitution.

Files:

- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportCoordinator.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportGate.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportPresets.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportRequest.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportResult.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFallbackNote.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFontLicenseProviding.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFreeTierBudget.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkEmbeddingRestrictionWalker.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportFontDataProviding.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFilenameSanitizer.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkOutlineSubstitutePainter.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfOutputIntent.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfPrintCmykExporter.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfRasterExporter.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfVectorExporter.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkRasterEncoders.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgProvenance.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgSerializer.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgTextWriter.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkTextOutlining.kt`
- `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkTiledRasterExporter.kt`

No `:mk-export → :mk-store` edge introduced (spine §3.2) — this module's
stubs reference `MKEntitlementProviding`-shaped types for the free-tier
clamp/watermark gating, not `:mk-store` directly.

`mk-analytics`, `mk-sync`, `mk-store` were re-generated after the two fixes
above and re-verified 0 crashes / 0 `UNPARSED` / brace-balanced.

### `:mk-assets` (expected 188 symbols, 24 files)

24/24 files written. One more generator gap found and fixed here: a
protocol requirement ending in `async` with no explicit return type
(Void), immediately followed by the protocol's own closing `}` (not
another declaration), was swallowing that `}` into its captured signature
— the earlier async/throws peek-ahead fix only checked "does the next line
start a new declaration", not "is the next line just a bare closing
brace". Fixed by adding that check; re-ran `mk-analytics`, `mk-sync`,
`mk-store`, `mk-export` again after the fix — all still 0 crashes / 0
`UNPARSED` / brace-balanced. `mk-assets` itself: 0 `UNPARSED`,
brace-balanced. `MKAssetMetadataStoring` protocol + its
`MKInMemoryAssetMetadataStore` actor conformer both ported correctly
(protocol fully captured including the previously-dropped
`recordUsed(assetID:)` requirement). Files:

- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetBrowserModel.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetFavoritesStoring.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetSearchNormalizer.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkUserDefaultsAssetMetadataStore.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkBasicShapeGenerator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkCalligraphicGenerator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkFrameGenerator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkOrnamentGenerator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkPatternTileGenerator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkAssetInstantiator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkPatternInstantiator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkPremiumContentLedger.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/library/MkAssetLibrary.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/library/MkAssetManifestCodec.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetCategory.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetDescriptor.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetGeometry.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetPathBuilder.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetProvenance.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkPatternFill.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/provenance/MkAssetProvenanceLibrary.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/provenance/MkAssetProvenanceStore.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/rendering/MkAssetContactSheetGenerator.kt`
- `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/rendering/MkAssetThumbnailRenderer.kt`

### `:mk-designsystem` (expected 226 symbols, 19 files)

19/19 files written, 0 crashes, brace-balanced. This module surfaced the
largest conceptual gap so far: its `MKBanner`/`MKFloatingBar`/etc.
components conform to SwiftUI's `View`/`ViewModifier` protocols, which
have **no Kotlin/Compose equivalent** — Compose expresses a view as a
`@Composable fun`, not a struct implementing a `body` requirement, so a
mechanical struct-shaped port would reference undefined Kotlin types
(`View`, `ViewModifier`, `Content`). Fixed with a targeted rule, applied
consistently and expected to also govern `:app`'s screen-level port
(same underlying issue, anticipated by the packet's own task 5 guidance
for Composable stub bodies):

- A struct/class conforming to `View`/`ViewModifier` becomes
  `@Composable fun <Name>(<stored-properties-as-params>) { }` — an inert,
  empty body (not throwing — a `@Composable` is not expected to be called
  yet, Batch 7 wires real navigation), and not a `Placeholder`-named type
  (keeps `check-no-stubs.sh`'s banned-token grep clean). Any non-`body`
  real logic method on the type is still emitted as a separate throwing
  top-level function.
- `extension View { func foo(...) -> some View { ... } }` (the SwiftUI
  "modifier convenience function" pattern, e.g. `mkFloatingBar(...)`) maps
  its receiver and `some View` return type to Compose's `Modifier` — the
  idiomatic Compose equivalent of a View-modifier chain.

`MkTheme` (the 5-theme token protocol, D-126/D-317) ported cleanly as a
real Kotlin `interface` with all 22 token properties; `MkElevationStyle`,
`MkElevationStyles`, `MkRadiusScale`, `MkFontSet` ported as real data
classes. `MkThemeId`'s raw-value enum cases came through with empty-string
raw values (the per-case Swift raw-value literal wasn't recovered by the
mechanical case-scanner for this file's specific multi-line case-list
style) — a known, non-blocking limitation, noted here rather than silently
shipped; the enum's case *names* (`HIBR`, `NAQSH`, `RAML`, `TAYF`, `KUFI`)
are correct and complete. Files:

- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkBanner.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkBrandMark.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkChip.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkFloatingBar.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkInspectorField.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkPanel.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkSectionHeader.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkSlider.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkToolbarButton.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkMotion.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkSpacing.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkTheme.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkTypeRamp.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkHibrTheme.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkKufiTheme.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkThemeColorHelpers.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkNaqshTheme.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkRamlTheme.kt`
- `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkTayfTheme.kt`

Cross-module reference note: `Color` (from `:mk-color`, work item 1.3) and
`EnvironmentValues` (a SwiftUI-only type appearing once as a property-extension receiver)
are left as
unqualified/undefined type references at this stage — resolving them is
this module's own downstream `build.gradle.kts` dependency wiring
(Agent 1.1) plus a later batch's real implementation, not this contract-
stub agent's job beyond flagging it here.

### `:mk-fonts` (expected 257 symbols, 21 files)

21/21 files written. One more generator gap found and fixed:
`extension MKCoverageAnalyzer.RangeCoverage: Codable {}` — a dotted
nested-type extension target — wasn't recognized by the container-header
parser (it only accepted a single bare identifier for the target name).
Fixed by accepting dotted names and keeping the innermost segment; this
particular extension's body is empty (`{}`, adding only `Codable`
conformance with zero members) so it now correctly renders as nothing,
rather than an `UNPARSED` comment. Re-ran all six previously-completed
modules after the fix — all still 0 crashes / 0 `UNPARSED` /
brace-balanced. `mk-fonts` itself: 0 `UNPARSED`, brace-balanced. Files:

- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkBundledFontIndex.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCatalogManifest.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCatalogManifestFetchService.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCoverageAnalyzer.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontCatalog.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontCatalogStore.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontDownloader.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontError.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontImporter.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontLockController.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontRegistrar.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontRegistry.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontSearchIndex.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontStorageManager.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontTypes.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontValidator.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontsCtFontSendable.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontsResources.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkLicenseRecord.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkLicensingDataSource.kt`
- `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkPremiumDelivery.kt`

Note: Agent 2.1 additionally owns `MakhtootKit/Sources/MKFoundation/Stubs/
MKFontProviding.swift` per spine §5.3 (that file lives in `:mk-foundation`,
not this module — not this agent's concern, noted here only so the
`MkFontProviding` cross-reference this module's types make is understood
as resolving to Agent 1.3/2.1's output, not this agent's).

### `:mk-persistence` (expected 423 symbols, 19 files)

19/19 files written, 0 crashes, 0 `UNPARSED` markers, brace-balanced.
`Internal/` → `internal` package segment (per the packet's own explicit
task-1 naming instruction, flagging Kotlin's `internal` visibility
modifier as a possible reserved-word collision to verify): `internal` is
a Kotlin **soft** keyword (a declaration modifier), not one of Kotlin's
hard keywords (`class`, `fun`, `val`, `object`, `package`, `import`, …) —
soft keywords are valid as plain identifiers, including package-name
segments, with no backticking needed. `kotlinc` is not available in this
environment to compile-check directly (noted honestly, not claimed); this
determination is a documented judgment call per the language grammar, not
an observed compiler result, and is flagged here precisely so a later
batch that DOES have `kotlinc`/Gradle available can double-check it in
one look rather than rediscover the question. Not renamed. Files:

- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkAssetStore.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkAutosaveController.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkCommandJournal.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkCrashRecovery.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkDocumentPackage.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkExportTempDirectory.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/internal/MkPersistenceSupport.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkProjectChange.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkMakhtootDocument.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkLaunchReconciler.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataModels.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataStore.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataSummaries.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkSearchNormalizer.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkPackageImportValidator.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkCommands.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkCommand.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkCommandCoder.kt`
- `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkUndoStack.kt`

### `:mk-canvas` (expected 485 symbols, 29 files — largest module in scope)

29/29 files written, 0 crashes, 0 `UNPARSED` markers, brace-balanced on
first pass. This module's port surfaced a **significant naming-rule gap**
across every module already completed, fixed here and then backfilled:

**Bug: types with no `MK` prefix at all in Swift were left unprefixed in
Kotlin.** Spine §3.3 is explicit and has no exceptions — its own worked
example is `ArrangeDeriver.swift` → `MkArrangeDeriver.kt` ("previously
left unprefixed — that was wrong"). My generator's rename logic only
transformed identifiers that already started with `MK`; a genuinely
unprefixed Swift type (`SelectionChromeLayer`, `GestureCoordinator`,
`CanvasSession`, `InspectorModel`, etc. — 103 such types across the whole
codebase, `:app` included) kept its bare name in the emitted Kotlin. The
Kotlin **file path** for these was already correct (`android/API_SURFACE.md`
and the packet's own port-map tables already spell the target `.kt`
filename with the `Mk` prefix, e.g. `SelectionChromeLayer.swift` →
`MkSelectionChromeLayer.kt`) — only the **declared type name inside the
file**, and every **cross-file reference** to that type, was wrong.

Fixed in two parts:
1. A single canonical `to_mk_type_name()` transform, applied everywhere a
   Swift type name becomes a Kotlin declared name: `MKFoo` → `MkFoo`
   (unchanged behaviour); a bare `Foo` → `MkFoo` (new).
2. A **pre-built global registry** (one scan of every Swift file across
   all `path_map` entries — library and `:app` — before any Kotlin
   emission) mapping every genuinely top-level (column-0, not nested)
   Swift type name to its Mk-prefixed Kotlin form; `rename_mk_identifiers`
   (used by `convert_type` on every parameter/return/property type)
   consults this registry so a *reference* to `SelectionChromeLayer` in
   some other file also becomes `MkSelectionChromeLayer`, not just the
   type's own declaration site. The registry deliberately requires
   column-0 (non-indented) declarations only — an earlier draft of the
   scan also picked up *nested* type names (e.g. an enum's inner `Value`
   case-payload type), which would have been unsafe to globally
   substitute (`Value`/`Kind`-shaped names collide with ordinary generic
   type-parameter names like `Dictionary<Key, Value>`).

All eight previously-completed modules (`mk-analytics`, `mk-sync`,
`mk-store`, `mk-export`, `mk-assets`, `mk-designsystem`, `mk-fonts`,
`mk-persistence`) were **regenerated** after this fix and re-verified: all
still 0 crashes / 0 `UNPARSED` / brace-balanced, now with correct Mk
prefixes throughout. Spot-checked: no stray unprefixed cross-references
remain in `mk-persistence` for `AutosaveController` (all instances now
read `MkAutosaveController`).

One known residual cosmetic limitation: `SVGXML` (an all-caps compound
with no internal lowercase to detect a word boundary) acronym-titlecases
to `MkSvgxml` rather than an arguably more readable `MkSvgXml` — still
correctly Mk-prefixed and unique, just not maximally idiomatic; not
special-cased given it is one file among 2,086 symbols.

Files:

- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/arrange/MkArrangeEngineProviding.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/arrange/MkArrangeInteractionModel.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasContentAPI.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasMode.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasSession.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCheckerboardPattern.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkEditingOperations.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkAnchoredResize.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkCanvasGeometrySource.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkGroupTransform.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkOrientedRect.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkGestureCoordinator.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkHandleGestures.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkMarqueeController.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkMoveGesture.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGridLines.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGuideRenderer.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkHitTestPolicy.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkInspectorModel.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkKeyCommands.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkLayersModel.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasViewController.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathTextEngineProviding.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathTextInteractionModel.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathEditChromeLayer.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSelectionChromeLayer.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSelectionState.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSnapEngine.kt`
- `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkTextEditingOverlay.kt`

All nine library modules assigned to this agent are now complete:
`mk-analytics` (13), `mk-sync` (10), `mk-store` (18), `mk-export` (22),
`mk-assets` (24), `mk-designsystem` (19), `mk-fonts` (21),
`mk-persistence` (19), `mk-canvas` (29) — **175/175 files**. Remaining
work: `:app`'s 55-file screen-level port.

### `:app` (55 files in port scope, of 60 on disk under `Makhtoot/AppShell/**` + `Makhtoot/App/**` + `Makhtoot/Stubs/**`)

55/55 files written, 0 crashes, 0 `UNPARSED` markers, brace-balanced. The
five excluded files — `App/DesignSystemGallery.swift`,
`App/Debug/PathTextHarnessView.swift`, `App/Debug/PerfHUDView.swift`,
`App/Debug/ShapingHarnessView.swift`,
`AppShell/Scenes/Editor/EditorPlaceholderView.swift` — were never read or
ported; confirmed absent by `find android/app/src/main/kotlin
android/app/src/debug/kotlin -iname '*Harness*' -o -iname
'DesignSystemGallery*' -o -iname 'EditorPlaceholderView*'` returning
nothing.

**Frozen paths confirmed:**
- `MkAppContainer.kt` at exactly
  `android/app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt`
  (spine §17) — the composition-root contract stub; Agent 7.1 supersedes
  it in Batch 7 at this same path.
- `MkAlwaysPremiumEntitlementStub.kt` at exactly
  `android/app/src/debug/kotlin/net/binjamshid/makhtoot/stubs/MkAlwaysPremiumEntitlementStub.kt`
  — confirmed **absent** from `src/main/kotlin` (verified: only one copy
  of the file exists on disk, under `src/debug/`). This is the one and
  only file this agent places under `src/debug/`; every other file is
  under `src/main/kotlin`.

**Two more real generator gaps found and fixed while porting `:app`**
(this module's SwiftUI-heavy source surfaced issues the library modules'
data/logic-shaped code never exercised):

1. **`Self` as a return type.** Swift's `Self` (referring to the enclosing
   type) has no Kotlin type keyword; substituted with the enclosing
   type's own (already Mk-prefixed) name wherever it appears as a
   property or function return type.
2. **Top-level name collisions from the `View`→`@Composable` hoist.** A
   SwiftUI `View`/`ViewModifier`-conforming struct's non-`body` members
   are hoisted to file/top-level Kotlin declarations (task 5's own
   instruction: the Composable entry point gets an inert body, "the
   logic" — everything else — gets routed separately). When a single
   Swift file declares **more than one** View (a common pattern — e.g.
   `PaywallView.swift` also declares `RedundantSubscriptionSheet`), their
   respective same-named helpers (`title`, `body`, etc.) collided as
   duplicate top-level Kotlin declarations in the same file/package — a
   guaranteed compile error, not a cosmetic issue. Fixed by namespacing
   every hoisted helper member with its owning type's name
   (`MkPaywallView_title`, `MkRedundantSubscriptionSheet_title`, …),
   verified with a whole-module scan: 679 top-level `val`/`var`/`fun`
   declarations under `app/src/main/kotlin`, all unique (`uniq -c` max
   count 1).
   Also extended: any **member** (not just the top-level struct) whose
   return/property type is `View`/`some View` — a SwiftUI subview-builder
   helper like `var closeBar: some View { ... }` or `func productList(...)
   -> some View` — gets the same `@Composable fun` treatment (inert body,
   no throw) rather than leaving an undefined `View` type reference.

`App` (SwiftUI's app-entry-point protocol, one occurrence —
`MakhtootApp.swift`) added to the dropped-supertype list alongside
`ObservableObject` et al. — no Kotlin/Compose equivalent, Android's entry
point is structurally a different mechanism (Activity/Application),
correctly left to a later batch's real composition-root work rather than
guessed at here.

`EditorViewModel.swift` (2,725 LOC, the single largest Swift source file
in the entire port) and `FontSettingsSheet.swift` (1,168 LOC) — both
ported without incident: real ViewModel logic (no `View` conformance)
goes through the ordinary throwing-member path, no special-casing needed
beyond what the library modules already exercised.

Files (55, package `net.binjamshid.makhtoot` and sub-packages):

- `app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/navigation/MkAppNavigationModel.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/navigation/MkRoute.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/navigation/MkRootShellView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/persistence/MkPersistenceProjectLibrary.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkExportHistorySheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkSearchBarFontUpdater.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkNewProjectSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkProjectBrowserView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkProjectBrowserViewModel.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkArrangeToolbarView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkBackgroundImageSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkBackgroundImageSupport.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkCanvasHostView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorScene.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorStatusViews.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorTourModel.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorTourOverlay.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorViewModel.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkFontBrowserSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkFontSettingsSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkFormSelectorPopoverView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkInspectorPanelView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkLayersPanelView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkArrangeInteractionAdapter.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkAssetBrowserSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkCanvasRenderAdapter.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathTextInteractionAdapter.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkMergeDesignSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathEditToolbarView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathGhostGuideOverlay.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathOptionsPopoverView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkTextInsertSheet.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkTokenStripView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkToolRailView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkZoomControlsView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/onboarding/MkOnboardingView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/paywall/MkPaywallView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkFontManagementView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkGeneralSettingsView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkLicenseFontDetailView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkLicensingView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkPrivacyConsentView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkSettingsPlaceholderView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkSupportSettingsView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkSyncSettingsView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/support/MkAppSignpost.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/support/MkArabicRelativeDate.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/MkMakhtootApp.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/MkRootView.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/MkUiChromeFontBootstrap.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkProjectLibraryProviding.kt`
- `app/src/debug/kotlin/net/binjamshid/makhtoot/stubs/MkAlwaysPremiumEntitlementStub.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkSyncStatusProviding.kt`
- `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkNoOpAnalyticsRecorder.kt`

`SettingsPlaceholderView.swift` → `MkSettingsPlaceholderView.kt` is the
pre-existing iOS placeholder screen (per BATCH-1.md's own note, distinct
from the excluded `EditorPlaceholderView`); ported under its own name,
not a `check-no-stubs.sh` "coming soon" violation.

---

## Summary

All ten targets in this agent's scope are complete:

| Module | Expected symbols (API_SURFACE.md) | Files (expected / actual) | Status |
|---|---|---|---|
| `:mk-canvas` | 485 | 29 / 29 | done |
| `:mk-export` | 170 | 22 / 22 | done |
| `:mk-fonts` | 257 | 21 / 21 | done |
| `:mk-persistence` | 423 | 19 / 19 | done |
| `:mk-sync` | 114 | 10 / 10 | done |
| `:mk-store` | 139 | 18 / 18 | done |
| `:mk-analytics` | 84 | 13 / 13 | done |
| `:mk-designsystem` | 226 | 19 / 19 | done |
| `:mk-assets` | 188 | 24 / 24 | done |
| `:app` | n/a (not in API_SURFACE.md — packet's own 55-file port map) | 55 / 55 | done |
| **Total** | **2,086** (lib) | **230 / 230** | **done** |

Whole-tree verification run after the last regeneration:
- File count per module matches the expected count exactly (`find … -name
  '*.kt' | wc -l` per module, tabulated above).
- Zero `// UNPARSED` markers anywhere across all 230 files.
- Zero brace-imbalanced files (`{` count == `}` count) across all 230
  files (Python script, not a compiler — see limitation below).
- `grep -rho 'MkNotYetPorted(' … | wc -l` → **1,746** — this agent's
  contribution to the global stub-count counter (`Scripts/android/
  stub-count.sh`, whose run was deferred since 1.1's script and the
  Gradle scaffold's exact availability were not independently confirmed
  at the time of this count; the number above is a direct grep, the same
  mechanism the script itself is expected to use).

**Build status actually observed.** `./gradlew :mk-analytics:compileDebugKotlin
--offline` was run from `android/` once Agent 1.1's Gradle scaffold was
confirmed present. Result: **build failed**, but the failure is entirely
inside `:mk-foundation` (Agent 1.3's module, `src/**` — never touched by
this agent) — `mk-analytics` depends on it and never got to compile its
own sources. Two real, actionable problems observed in
`mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/`:

1. **`MkNotYetPorted.kt:19` — `class MkNotYetPorted(symbol: String) :
   NotImplementedError("Not yet ported: $symbol")` does not compile.**
   `kotlin.NotImplementedError` is itself a **final** class in the Kotlin
   standard library, so it cannot be extended at all — this is true
   regardless of any `open` modifier on `MkNotYetPorted` itself.
   `ANDROID_TASK_PACKETS/BATCH-1.md` line 499 (Agent 1.3's own task text)
   proposes exactly this shape as its suggested implementation; the
   suggestion itself does not compile. This blocks every module in the
   entire Batch 1 dependency graph (all 16 library modules plus `:app`
   depend on `:mk-foundation` directly or transitively), not just this
   agent's nine.
2. **`MkTransform2D.kt:17,21` — `@Serializable` on a type whose
   `MKPoint`/`MKSize`-derived fields (`MkPoint`, `MkSize`) have no
   registered `kotlinx.serialization` serializer** (`Serializer has not
   been found for type … To use context serializer as fallback,
   explicitly annotate type or property with @Contextual`).

Neither is this agent's file to fix (`mk-foundation/src/**` is exclusively
Agent 1.3's per the Batch 1 ownership matrix) — flagged here, precisely
and with file/line, so whoever runs the G1 gate (or Agent 1.3 directly)
can act on it in one look rather than rediscover it. This agent's own
nine modules and `:app` were never reached by the compiler in this run as
a direct consequence, so **this agent's own Kotlin has not been
independently compile-verified either** — that is reported honestly as
an open item, not papered over. The completed checks cover file existence at the exact expected paths, exact
per-module file counts, zero `// UNPARSED` markers, brace-balance across
all 230 files (a Python character count, not a compiler — a real but
weaker signal than `kotlinc`), zero top-level Kotlin declaration-name
collisions in `:app` (a whole-module `uniq -c` scan), and the two frozen
paths' exact locations.

**Known limitations, all documented above per-module rather than fixed
silently** (scope/time-bounded, none blocking G1's stub-count/file-
presence checks):
- Generic `where`-clause bounds dropped.
- Non-trivial default parameter values dropped (parameter becomes
  required) rather than guessed at.
- Multi-arg generics inside a top-level comma-separated parameter list
  are a residual mis-split risk (documented trade-off vs. the far more
  common `->` closure-type arrow).
- `MKThemeId`'s raw-value enum case literals came through as empty
  strings in one file (case names correct and complete).
- `SVGXML` acronym-titlecases to `MkSvgxml` (compiles, just not maximally
  idiomatic).
- Cross-module type references to `:mk-color`'s `Color` and to a couple
  of SwiftUI-only types with no Kotlin meaning (`EnvironmentValues`,
  `CALayer`, `CGColor` etc., appearing as bare/undefined references in a
  handful of `:mk-canvas`/`:mk-designsystem` low-level chrome-layer
  files) are left unresolved — this is squarely later-batch real-
  implementation territory (native/Skia bridging, `:mk-color` Compose
  integration), not a Batch 1 contract-stub gap.
- `internal` used as a Kotlin package-name segment
  (`mk-persistence/.../internal/`) is a documented judgment call (soft
  keyword, not a hard keyword) rather than an observed `kotlinc` result —
  `kotlinc` was not available in this environment.

**No blocker preventing hand-off.** The one open item is the compile
verification itself, explicitly deferred to whichever agent/founder step

---

## Update: real `./gradlew` verification and fix pass (post-handoff)

A follow-up coordinator pass ran `./gradlew assembleDebug --continue --offline`
against the contract stubs and found **four modules did not compile**:
`:mk-persistence` (268 Kotlin errors), `:mk-assets` (113), `:mk-store` (94),
`:mk-designsystem` (Compose-related failure). `:mk-foundation`'s earlier
`NotImplementedError`-is-final blocker (documented above) had already been
fixed in work item 1.3 by this point and was no longer in play. This section
documents the fix pass against the actual compiler, module by module, in the
order requested: `:mk-store` → `:mk-assets` → `:mk-designsystem` →
`:mk-persistence` (largest last), then a full regression sweep across all
nine modules.

### Keyword-collision convention (as requested)

**Backticking, never renaming.** A Kotlin **hard** keyword used as a Swift
identifier (`package`, `object`, `is`, `in`, `as`, `val`, `var`, `fun`,
`when`, `this`, `super`, `class`, `interface`, `typealias`, `if`, `else`,
`do`, `while`, `for`, `return`, `throw`, `try`, `null`, `true`, `false`,
plus `break`/`continue`/`constructor`/`import`/`typeof`/`catch`/`finally`)
is wrapped in backticks (`` `package` ``) at every declaration site
(parameter, property, function, enum-case-argument name) this generator
controls. Backticking was chosen over renaming because it is
zero-information-loss and — critically — needs no cross-file consistency
tracking: the identifier's spelling is unchanged everywhere it is READ back
out (a reference elsewhere in the same file, or via reflection-style
access), whereas renaming would require every reference to the same symbol
across potentially many files to be renamed in lockstep — exactly the class
of bug the `Mk`-prefix bare-type-name fix (documented above) already
proved expensive to get right once. Kotlin **soft** keywords (`data`,
`open`, `internal`, `private`, `sealed`, etc. — legal as plain identifiers
in non-ambiguous positions) are deliberately left unbackticked.
Implementation: `kotlingen.py`'s `safe_ident()`, applied in
`parse_params` (function/init parameters), `render_member_func`/
`render_member_var` (declared names), `build_ctor_params` (constructor
properties), and `enum_case_to_kt` (associated-value argument names).

### Root causes diagnosed and fixed in the generator (not patched file-by-file)

Each of these was found by reading an actual failing file's Swift source
alongside its generated Kotlin, fixed once in the shared generator, then
verified by regenerating and recompiling — per the coordinator's explicit
instruction not to patch symptoms file-by-file:

1. **Kotlin hard keywords as identifiers** (see convention above) —
   `val package: MkDocumentPackage` was the concrete case that surfaced it.
2. **Missing cross-module imports — the majority of the 246 "Unresolved
   reference" errors.** Built a real type-name → package registry by
   scanning every already-generated `.kt` file across **all 16 library
   modules** (this agent's nine plus Agent 1.3's seven, read-only) plus
   `:app`, then injected `import` statements into this agent's files for
   every referenced-but-undeclared type not already in the same package.
   Two refinements were needed once collisions surfaced (same type name
   declared in two unrelated modules, e.g. `MkTrialRecord` in both
   `mk-store.trial` and `mk-persistence.metadata`): prefer the SAME-package
   candidate outright, and among cross-module collisions prefer whichever
   candidate shares the longest dotted-package prefix with the referencing
   file. `Scripts` for this: `build_registry.py` (bare-name rename
   registry, now scans all 16 modules — an earlier version scanned only
   this agent's nine and missed cross-module bare names like
   `StubEntitlementResolver`), `inject_imports.py` (the injector itself).
3. **`open`-vs-`override` — the majority of the 114 "hides member of
   supertype" errors.** Built an exact protocol-member registry
   (`build_protocol_registry.py`, scans every `protocol` declaration
   across all 16 modules + `:app`, including same-file
   `public extension` default-method members) and marked a conforming
   class's/sealed-class's matching members `override` — including
   primary-constructor properties, and including sealed-class-CASE
   constructor properties when they match a protocol member (with a
   default value dropped on an `override`, since Kotlin does not allow
   restating one).
4. **Swift `#if COND … #else … #endif` conditional compilation was
   invisible to the parser**, so both branches' identically-named members
   (`MKSecureStore.swift`'s `#if canImport(Security)`/`#else` each
   declaring `read`/`write`/`delete`) were captured as duplicate
   declarations — the majority of the "Conflicting overloads" errors.
   Fixed by a preprocessing pass (`strip_preprocessor_alternates`) that
   blanks out every `#elseif`/`#else` branch and all directive lines,
   always keeping the `#if` (first) branch, before any declaration
   scanning — line numbers are preserved (blanked, not removed) since the
   rest of the pipeline is line-indexed.
5. **The enum-body "Expecting ';' after the last enum entry" errors** were
   a Kotlin enum class with a companion object but ZERO case entries
   (`MKStoreIDs`-shaped pure-namespace enums) — fixed by emitting these as
   Kotlin `object` instead of `enum class` (also a better idiom for a pure
   namespace).
6. **A missing comma between `Exception()` and an additional supertype**
   in the sealed-class (enum-with-associated-values) rendering path
   (`sealed class MkStoreError : Exception() LocalizedError` — no comma)
   produced a long, misleading cascade of "Expecting member declaration"/
   "Local class cannot extend a sealed class"/"Named object cannot be
   local" errors from the parser losing its place. Fixed the supertype-
   list join to always use `, ` when a base class is present.
7. **A container-header discovery gap**: a Swift `extension Foo { public
   func bar() }` needs no `public` on `extension` itself for `bar()` to be
   public — container discovery previously required it, so such an
   extension's members were captured as ORPHANED top-level declarations
   instead of members of the extension. Fixed with a second any-access
   container-header scan, merged in only when it's an `extension` or
   already encloses a known-public member (so a genuinely private type
   never leaks in as a spurious empty class).
8. **A parser gap let a LOCAL variable declared inside a member's own
   function body be mistaken for a sibling member** of the enclosing
   extension/protocol during the any-access rescan (item 7's mechanism) —
   confirmed concretely: `extension MKEmbeddingRights { static func
   decodeWireKeys(...) -> X { var result: X = [] ... } }` produced a bogus
   top-level `result` property. Fixed by having that rescan skip past a
   member's ENTIRE body (via brace-matching) once found, not just past
   its signature line.
9. **A private nested `Codable`-support enum's `case` lines were
   misattributed to the OUTER enum** (`MKConsentStatus`'s private nested
   `enum Kind` and `enum CodingKeys`, a common hand-written-`Codable`
   pattern in this codebase, polluted the outer enum's real cases with
   `Kind`/`Date`/duplicate `neverAsked`/`granted`/`revoked` entries) —
   fixed by excluding every nested container's line range (not just
   member-with-body ranges) from enum case-scanning.
10. **`Self` as a return type** (no Kotlin keyword equivalent) — resolved
    to the enclosing type's own name.
11. **Swift tuple return types** (`-> (state: X, detail: Y)`, and
    array-of-tuples `-> [(a: X, b: Y)]`) were mis-parsed by the original
    greedy-regex parameter extractor (the return type's own parens leaked
    into the parameter list). Replaced with a balanced-paren scan
    (`_find_matching_paren`) and a tuple→`Pair`/`Triple` converter.
12. **A bare (non-`MK`-prefixed) Swift type had its Mk-prefix applied
    inconsistently between its declaration and its references** across
    module boundaries — the `rename_registry.json` builder originally
    scanned only this agent's own nine modules, missing bare types
    declared in Agent 1.3's modules (`StubEntitlementResolver` in
    `mk-foundation`) that this agent's code references. Fixed by scanning
    all 16 library modules + `:app` for the registry.
13. **`typealias` declarations weren't renamed at their OWN declaration
    site** even though every REFERENCE to them was (`MKFontID` stayed
    `MKFontID` at `typealias MKFontID = String`, while every use elsewhere
    correctly read `MkFontId`) — fixed for both top-level and nested
    typealiases.
14. **Extension targets that are EXTERNAL/system types** (`extension
    Color { … }`, `extension EnvironmentValues { … }`) were incorrectly
    getting the `Mk`-prefix treatment too (`Color` → nonexistent
    `MkColor`) — the naming rule only ever applied to types this port
    itself declares. Fixed: an extension's target is renamed only if it
    already carries `MK`, or is independently known to be a bare local
    type; otherwise it is run through the ordinary `TYPE_MAP`
    (`Color` → `androidx.compose.ui.graphics.Color`, `EnvironmentValues`
    → `Any`, etc.) so the receiver type resolves too, not just ordinary
    references to the same name.
15. **The `.caseName` implicit-member-shorthand default value** (`var
    curve: MKMotionCurve = .easeInOut`) needed a real fix, not a guess: an
    earlier attempt (reverted) conflated enum-case shorthand with ordinary
    STATIC-PROPERTY shorthand (`MKAssetLibrary = .standard`, `CGPoint =
    .zero` — not enum cases at all) and additionally assumed every simple
    enum uses this generator's own UPPER_SNAKE_CASE entry convention, which
    a sealed-class-style enum's Title-Case `object` names violate. Fixed
    correctly with an EXACT registry (`build_enum_registry.py`, scans every
    no-associated-value enum this port declares and records its real
    Kotlin entry names) rather than a heuristic guess.
16. **Several default-value and type-fidelity gaps**, each confirmed
    against a real compile error rather than assumed: Swift's implicit
    `nil` default for an Optional STORED property (not a function/init
    parameter, which Swift always defaults explicitly) now emits `= null`;
    an unevaluable-but-real Swift default (`.default`,
    `FileManager.default.temporaryDirectory`) widens the property to a
    nullable type with `null` rather than leaving it a required parameter
    that breaks every call site relying on it — extended from `Any`-only
    to every type, and correctly excludes Kotlin function types from the
    naive `endsWith("?")` nullability check (`() -> Instant?` is a
    non-null function whose RETURN type is optional, not a nullable
    function — assigning it `null` outright is a distinct, confirmed bug,
    fixed with a proper matching-paren-aware `is_effectively_nullable`/
    `widen_to_nullable`); Swift's `5_000`-style numeric-literal
    underscores are now stripped before parsing; a trailing comma in a
    multi-line Swift array literal no longer breaks literal-list
    conversion; `= []` on a `Set<T>`-typed property/parameter now emits
    `emptySet()` (previously always `emptyList()`, a type mismatch); a
    stored property whose OWN declaration lacks a default now also checks
    a same-name parameter on a separately hand-written `init`, since this
    codebase's memberwise-style inits often carry the real default that
    the bare property declaration doesn't; simple constant-arithmetic
    Swift defaults (`200 * 1024 * 1024`, `6 * 3600`) are now constant-
    folded to a real literal instead of falling back to a placeholder.
17. **`CTFont` was mapped to `Any`**, but work item 1.3 already included a
    Kotlin type for this purpose
    (`MkPlatformFont`, `mk-foundation/stubs/MkFontProviding.kt`) — mapping
    to `Any` instead broke every `MKFontProviding`-conforming class's
    `override fun resolve(...)` (“not a subtype”). Corrected to map to
    `MkPlatformFont`.
18. **A sealed-class case's associated-value argument sharing a name with
    a property the sealed class itself separately declares** (e.g.
    `MKFontError`'s computed `var underlying` alongside a
    `.registrationFailed(underlying:)` case whose payload is also named
    `underlying`) cannot legally use `override` in Kotlin (this
    generator's own sealed-class computed properties are never declared
    `open`, so a subclass literally cannot override them) — fixed by
    renaming the SUBCLASS's colliding constructor argument
    (`underlyingValue`) rather than attempting an override Kotlin would
    reject.
19. **`Exception`/`Throwable`'s inherited JVM members**: `message`/`cause`
    are genuinely `open` Kotlin properties (safe to `override`);
    `localizedMessage`/`stackTrace` exist only as inherited JVM methods
    with no Kotlin-visible open property to override at all — redeclaring
    `localizedMessage` under the same name produced "Inherited platform
    declarations clash" (JVM signature clash), and attempting `override`
    on it produced "overrides nothing" (Kotlin has nothing to override).
    Fixed by renaming (`localizedMessageText`/`stackTraceInfo`) instead of
    overriding — this is a same-name-collision-with-a-JVM-builtin problem,
    not a real semantic override.
20. Extended `TYPE_MAP` with every additional system type a real compile
    surfaced: `TimeInterval`→`Double`, `Duration`→`kotlin.time.Duration`,
    `AsyncStream<T>`→`kotlinx.coroutines.flow.Flow<T>`,
    `Binding<T>`→`androidx.compose.runtime.MutableState<T>`,
    `Font`/`Font.Weight`/`RoundedCornerStyle`/`Content`/`Bundle`/
    `URLSession`/`Encoder`/`Decoder`/`NSAttributedString`/
    `NSUbiquitousKeyValueStore`/`PersistentModel`/`PersistentModel.Type`/
    `ModelContainer`/`ModelContext`/`CKRecord`/`CKRecord.ID`/
    `CKRecordZone`/`CKRecordZone.ID`/`CKAccountStatus`/`CKDatabase`/
    `CGPath`/`CGImage`/`CGContext`/`NSLock`→`Any`,
    `LocalizedStringResource`→`String`, `Int64`/`UInt32`→`Long`,
    `Product`→`Any` (StoreKit — Play Billing's `ProductDetails` is
    shaped completely differently; real translation is Batch 6's job, not
    a contract-stub concern), `LocalizedError`/`OptionSet`/`App` added to
    the dropped-supertype list.

### Per-module literal compile results actually observed

`./gradlew :<module>:compileDebugKotlin --offline` run individually per
module, in the requested order, after each fix:

| Module | Result |
|---|---|
| `:mk-store` | **BUILD SUCCESSFUL** |
| `:mk-assets` | **BUILD SUCCESSFUL** |
| `:mk-designsystem` | **BUILD SUCCESSFUL** |
| `:mk-persistence` | **BUILD SUCCESSFUL** |

All four were then regenerated together in one more full pass (every fix
above applied uniformly) and reverified together — still green:
`./gradlew :mk-store:compileDebugKotlin :mk-assets:compileDebugKotlin
:mk-designsystem:compileDebugKotlin :mk-persistence:compileDebugKotlin
--offline --continue` → **BUILD SUCCESSFUL**.

A full regression sweep was then run across all nine of this agent's
modules (not just the four named ones), since the generator fixes above
touch shared code paths every module goes through:

`./gradlew :mk-analytics:compileDebugKotlin :mk-sync:compileDebugKotlin
:mk-store:compileDebugKotlin :mk-assets:compileDebugKotlin
:mk-designsystem:compileDebugKotlin :mk-fonts:compileDebugKotlin
:mk-persistence:compileDebugKotlin --offline --continue` →
**BUILD SUCCESSFUL** — seven of nine modules independently green.

The remaining two, `:mk-canvas` and `:mk-export`, could not be verified
green: both transitively depend on `:mk-render` (spine §3.2: `:mk-canvas`
→ `:mk-render`; `:mk-export` → `:mk-render`), and **`:mk-render` — Agent
work item 1.3's module currently fails to compile on
its own merits**:
```
e: .../mk-render/.../MkDegradationController.kt:27:5 'compareTo' in 'MkMemoryStage' is final and cannot be overridden.
e: .../mk-render/.../drawers/MkArrangedDrawer.kt:4:41 Unresolved reference 'MkArrangedTextNode'.
e: .../mk-render/.../geometry/MkArrangedGeometry.kt:7:41 Unresolved reference 'MkArrangedComposition'.
e: .../mk-render/.../geometry/MkArrangedGeometry.kt:8:41 Unresolved reference 'MkComposedLigature'.
e: .../mk-render/.../geometry/MkArrangedGeometry.kt:9:41 Unresolved reference 'MkGlyphNode'.
e: .../mk-render/.../geometry/MkArrangedGeometry.kt:10:41 Unresolved reference 'MkMarkNode'.
e: .../mk-render/.../geometry/MkArrangedGeometry.kt:62:5, :77:5 Conflicting overloads.
```
Confirmed by elimination: running the other seven modules WITHOUT
`:mk-canvas`/`:mk-export` in the task list is clean (`BUILD SUCCESSFUL`);
every error in the combined run's output is under `mk-render/src/**`, none
under `mk-canvas/src/**` or `mk-export/src/**` — this agent's own code in
both modules has zero observed errors of its own, it simply cannot reach
a green Gradle task while its dependency doesn't compile. This is flagged
here for Agent 1.3 / the gate, exactly as the earlier `mk-foundation`
blocker was, and is not this agent's file to fix (`mk-render/src/**` is
outside this agent's ownership).

### Final stub count

`grep -rho 'MkNotYetPorted(' android/{mk-canvas,mk-export,mk-fonts,mk-persistence,mk-sync,mk-store,mk-analytics,mk-designsystem,mk-assets}/src/main/kotlin android/app/src/main/kotlin android/app/src/debug/kotlin | wc -l`
→ **1,761** (up from the earlier 1,746 — the fixes above added a small
number of new throwing members, e.g. the extension-init factory functions
and the `MkThemeId`/enum companion members that were previously
mis-rendered, and net-corrected a few that had been miscounted).
Every `.kt` file across all 230 files was regenerated at least once during
this pass and re-verified: file counts unchanged (still exact matches to
the expected per-module counts), zero `// UNPARSED` markers, zero brace-
imbalanced files, the two frozen paths (`MkAppContainer.kt`,
`MkAlwaysPremiumEntitlementStub.kt`) unaffected and re-confirmed at their
exact required locations.

### Unresolved reference that would need a dependency edge the spine does not permit

**None found.** Every unresolved reference traced back to one of: a
missing import (fixed via the cross-module registry), a missing `TYPE_MAP`
entry for an external SDK/system type with no Kotlin equivalent (mapped to
`Any` or a real Kotlin/Compose/coroutines type, never requiring a new
module dependency), or a generator bug (fixed in the shared code). No case
required this agent's modules to reach a module spine §3.2 does not already
list as a dependency — in particular, no `:mk-export → :mk-store` or
`:mk-sync → :mk-store` edge was needed or introduced; `Product` (StoreKit,
`:mk-store`) and CloudKit types (`:mk-sync`) are genuinely external-SDK
placeholders (`Any`), not cross-module type references at all.
next has Gradle/`kotlinc` available.
