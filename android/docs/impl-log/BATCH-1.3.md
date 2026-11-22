# BATCH-1.3 — Contract stubs A (foundation, model, textengine, arrange, pathtext, render, color)

Agent 1.3, Batch 1 ("Scaffold, native toolchain, contract stubs"). Ports every public
symbol of `MKFoundation`, `MKModel`, `MKTextEngine`, `MKArrange`, `MKPathText`, `MKRender`,
`MKColor` (1,079 symbols across 94 Swift files) to Kotlin contract stubs, mechanically
sourced from `android/API_SURFACE.md`.

## Session note

This packet was executed across several resumed turns, including two API-connection
interruptions and a period where earlier concurrently-dispatched background agents (since
terminated) had landed partial, inconsistent progress on some modules. Every module was
re-verified file-by-file against the port map in this final pass; two modules
(`mk-foundation`, `mk-textengine`) were found missing files after an interruption and were
restored/completed in this session. Numbers below reflect the final, verified state.

## Per-module file/symbol counts vs. expected

| Module | Expected symbols | Port-map files | Files on disk (main) | Test file | Stub (`MkNotYetPorted`) throw sites |
|---|---|---|---|---|---|
| `:mk-foundation` | 118 | 15 | 15 (+1 infra: `MkNotYetPorted.kt`) | 1 | 45 |
| `:mk-model` | 322 | 15 | 15 | 1 | 27 |
| `:mk-textengine` | 167 | 17 | 17 | 1 | 32 |
| `:mk-arrange` | 108 | 11 | 11 | 1 | 41 |
| `:mk-pathtext` | 125 | 9 | 9 | 1 | 40 |
| `:mk-render` | 201 | 23 | 23 (+1 infra: `MkRenderPlatformTypes.kt`) | 1 | 85 |
| `:mk-color` | 38 | 4 (3 after HSB merge) | 3 (+1 infra: `MkColorPlatformTypes.kt`) | 1 | 13 |
| **Total** | **1,079** | **94** | **93 port-map + 3 infra** | **7** | **283** |

Every port-map file exists at the path specified in `ANDROID_TASK_PACKETS/BATCH-1.md`'s port
map tables. Symbol coverage was verified file-by-file against `android/API_SURFACE.md`'s
per-file bullet lists during authoring; a spot re-check of `MKFoundation`, `MKColor`,
`MKArrange` and the `ShapedModels.swift`/`ShapingService.swift` slice of `MKTextEngine`
confirmed exact symbol-for-symbol coverage (the 118/38/108 totals and the individual
per-file counts in `BATCH-1.md` were independently re-derived from the raw `API_SURFACE.md`
bullet counts and matched).

Three files are new supporting infrastructure, not port-map rows (documented per
`ANDROID_SPINE.md` §9, not silent):
- `mk-foundation/.../MkNotYetPorted.kt` — the shared stub-exception type (packet task 2).
- `mk-render/.../MkRenderPlatformTypes.kt` — placeholders for `CGContext`/`CALayer`/`CGImage`/
  `CGPDFPage`/`CGPath`/`CGColor` (`MkDrawingSurface`, `MkPlatformLayer`, `MkPlatformImage`,
  `MkPlatformPdfPage`, `MkPlatformPath`, `MkPlatformColor`) plus `MkImageInterpolationQuality`.
- `mk-color/.../MkColorPlatformTypes.kt` — placeholders for `CGColor`/`CGImage`/`CGColorSpace`/
  `Bundle` (`MkPlatformColor`, `MkPlatformImage`, `MkColorSpaceHandle`, `MkResourceBundle`).
  Also `mk-model`'s `MkPlatformPath` (for `CGPath`, in `MkBezierPathData.kt`) and
  `mk-foundation`'s `MkPlatformFont` (for `CTFont`, in `stubs/MkFontProviding.kt`) — the latter
  pre-existing from the original design, the former added this session.

## `MKColorSpec+HSB.swift` resolution

Resolved by **merging into `MkColorSpec.kt`**: `MKHSBAComponents`, `MKColorSpec.hsba`, and
`MKColorSpec.init(hsba:)` all live in `mk-color/.../MkColorSpec.kt` alongside the base
`MkColorSpec`/`MkColorSpaceTag` types from `MKColorSpec.swift`. No separate
`MkColorSpecHsb.kt` file was created. Chosen over the alternate-spelling option because the
HSB conversion is small (8 symbols) and conceptually inseparable from `MkColorSpec` itself.
Recorded in the file's own KDoc as well as here.

## Symbols/constructs with no direct mechanical Kotlin form (recorded, not silent)

1. **`MKColorSpec+HSB.swift`** — the one `+`-extension file pre-flagged by the packet; see
   resolution above.
2. **A second, unflagged naming-rule collision found during porting:**
   `Sources/MKArrange/PathPlacementProviding.swift`'s `MKPathGlyphPlacement` and
   `Sources/MKPathText/PathGlyphPlacement.swift`'s `PathGlyphPlacement` both mechanically
   transform to `MkPathGlyphPlacement`, but are different types (only distinguished in
   Swift by one carrying the `MK` prefix and the other not). Resolved: `mk-arrange`'s stays
   `MkPathGlyphPlacement` (the plain mechanical transform); `mk-pathtext`'s was renamed to
   `MkPathGlyphPlacementResult` (an alternate spelling, documented in that file's own KDoc)
   since it is the fuller engine-output record. Both packages' own copies compile and are
   referenceable independently; `mk-pathtext/.../MkPathPlacementProvider.kt` imports both
   under their now-distinct names.
3. **A third collision:** `mk-model`'s `MKPathLayoutOptions` (`MKNode.swift`) and
   `mk-pathtext`'s own, fuller `PathLayoutOptions` (`PathLayoutOptions.swift`) also both
   transform to `MkPathLayoutOptions`. Resolved with an import alias
   (`import ... MkPathLayoutOptions as MkModelPathLayoutOptions`) in `mk-pathtext`'s
   `MkPathLayoutOptions.kt` and `MkPathTextCommands.kt` — both keep their own mechanical
   name in their own package; only the file that needs both together disambiguates locally.
4. **Custom `Codable` conformance (`init(from:)`/`encode(to:)` pairs)** — Kotlin's
   serialization model is annotation-driven (`@Serializable`), with no per-type method-pair
   equivalent. Affects `mk-model`'s `MkPathTextNode`, `MkAssetRef`, `MkImageNode`,
   `MkBackgroundContent`, and `MkNode` itself (8 Swift `init(from:)`/`encode(to:)` symbols
   with no separate Kotlin declaration). The additive-field back-compat behavior
   (`decodeIfPresent(...) ?? default`) is achieved for free via Kotlin default property
   values. **Flagged, not silently dropped:** `MkAssetRef`'s hand-written decoder also
   performs S-2 path-traversal validation (character-class restriction on `digest`/`ext`)
   that a plain derived `@Serializable` does **not** reproduce — recorded in that type's own
   KDoc as a must-fix-before-real-use item for whichever Batch 2 agent implements
   `mk-model`/`mk-persistence`'s asset path construction.
5. **Actor → class.** Every Swift `actor` in these seven modules (`MKMemoryGovernor`,
   `InMemoryDocumentStore`, `MKShapingService`, `MKFormResolver`'s isolation intent,
   `BitmapCache`, `MKMemoryPressureMonitor`, `MKLayerTreeController`'s `@MainActor`
   isolation) becomes a plain Kotlin `class`, documented once per file — Kotlin has no
   `actor` language feature; Batch 2+ is expected to back the isolation guarantee with a
   `Mutex`/confined coroutine dispatcher per `ANDROID_SPINE.md` §9.
6. **`MkLayerTreeController.accountedBytes()`** unifies what in Swift is one synchronous
   `@MainActor` method simultaneously satisfying both `LayerTreeBuilder.swift`'s own public
   API and (via Swift's "a synchronous actor-isolated method satisfies an async protocol
   requirement" rule) `MKMemoryAccountable`'s async requirement. Kotlin has no such
   shortcut; modeled as the one `suspend fun` the `MkMemoryAccountable` interface requires,
   not two separate methods — documented in the file to avoid inflating the symbol count
   with a duplicate.

## Type-mapping conventions applied uniformly

- `CGFloat`/`Double`/`Float` → `Double`; `String`/`Character` → `String`/`Char`;
  `Data` → `ByteArray`; `UUID` → `java.util.UUID` (except `MkId<Tag>.rawValue`, stored as
  `String`, documented in that file).
- `UInt32` → `Long`; `UInt8`/`UInt16` → `Int` (documented once, in `mk-arrange`'s
  `MkFormSelectorModel.kt` and `mk-model`'s `arranged/MkGlyphNode.kt`).
- `CGPoint`/`CGSize`/`CGRect`/`CGAffineTransform` → `mk-foundation.geometry.{MkPoint,MkSize,MkRect,MkAffineTransform}`.
- Opaque native/platform types with no JVM equivalent (`CGContext`, `CALayer`, `CGImage`,
  `CGPDFPage`, `CGPath`, `CGColor`, `CGColorSpace`, `CTFont`, `Bundle`) → small local
  placeholder classes (`internal constructor()`), one set per module that needs them,
  following the pattern `mk-foundation`'s `MkPlatformFont` established.
- Swift `enum` with associated values → Kotlin `sealed class` (object/data class per case).
  Swift `enum` with no associated values → Kotlin `enum class`.
- Every function/computed-property/method body (including protocol-extension defaults) is
  `throw MkNotYetPorted("<Type>.<member>")`, with **two** documented exceptions where the
  Swift body is itself a genuine, permanent no-op (not a stub): `MkNoOpFontUsageRecorder
  .recordFontUsed` (`mk-foundation`) and `MkStubRenderTree.commitTransients`/
  `.setVisibleRect` (`mk-render`) — both keep their real empty bodies since that IS the
  correct behavior, not an unported gap.
- A `static let`/`static val` that is a plain literal or a trivial-construction default
  (e.g. `MkTransform2D.identity`, `MkStyle.default`, `MkErrorCode.ioPrefix`) is real, not
  stubbed. A `static val` whose initializer calls a stubbed function is `by lazy` so merely
  referencing the containing object doesn't eagerly throw (`MkLog.foundation`,
  `MkSignpost.signposter`, `MkSceneMigratorRegistry.standard`).
- An `init`/constructor that performs real, non-trivial construction logic (not simple field
  assignment) throw-stubs via an `init { throw MkNotYetPorted(...) }` block
  (`mk-arrange.MkArrangedCompositionIndex`, `mk-model.MkSceneMigratorRegistry`,
  `mk-pathtext.MkBezierPathModel`'s `MkBezierPathData`-converting secondary constructor) —
  documented per file so a reader isn't surprised a "real-looking" constructor throws.

## Corrections found by the real Kotlin/Gradle compiler (not merely reasoned about)

Once Agent 1.1's Gradle scaffold was in place, `./gradlew :<module>:compileDebugKotlin` was
actually run (not merely inspected) and found three real defects, all fixed:

1. **`MkNotYetPorted` could not extend `NotImplementedError`** — `kotlin.NotImplementedError`
   is `final` in Kotlin (unlike the class's originally-assumed shape). Fixed to extend
   `kotlin.Error` instead, same severity, same message shape, still greppable by class name.
2. **`MkPoint`/`MkSize`/`MkRect`/`MkAffineTransform` needed `@Serializable`** — any
   `@Serializable` type embedding one as a field (e.g. `MkTransform2D`) failed to compile
   with "Serializer has not been found for type ...". All four now carry `@Serializable`.
3. **`MkId<Tag>`'s phantom generic type parameter broke the kotlinx.serialization compiler
   plugin** even with a custom `@Serializable(with = MkIdSerializer::class)` — the plugin's
   child-serializer-resolution pass still eagerly tries to resolve a serializer for whatever
   concrete `Tag` a given usage binds (e.g. `MkNodeId = MkId<MkNodeTag>`), crashing with
   "Serializer for element of type ...MkNodeTag has not been found" even though
   `MkIdSerializer` never asks for one. Fixed by making `MkNodeTag`/`MkProjectTag`/
   `MkClusterTag` themselves trivial `@Serializable object`s (zero fields) rather than
   uninstantiable `sealed class`es with no subclasses — the tag still "never needs a
   runtime value" in the sense that matters (one unused singleton instance), it just also
   needs to exist as a resolvable serializer target.

## Literal build status observed

- **`./gradlew :mk-foundation:compileDebugKotlin :mk-color:compileDebugKotlin :mk-model:compileDebugKotlin`
  → `BUILD SUCCESSFUL`**, actually run and observed (not claimed without running it).
- **`:mk-textengine`, `:mk-arrange`, `:mk-pathtext`, `:mk-render` could not be verified via a
  full Gradle build.** All four transitively depend on `:mk-persistence`
  (`mk-textengine`→`mk-fonts`→`mk-persistence`; `mk-arrange`/`mk-pathtext`→`mk-persistence`
  directly; `mk-render`→`mk-pathtext`→`mk-persistence`), and `:mk-persistence` (Agent 1.4's
  module, outside this agent's ownership) currently fails to compile with extensive syntax
  errors (`MkAssetStore.kt`, `MkAutosaveController.kt`, `MkCrashRecovery.kt`,
  `MkCommands.kt`, `MkUndoStack.kt`, `MkMakhtootDocument.kt`, `MkDocumentPackage.kt`,
  `MkPackageImportValidator.kt`, `MkProjectChange.kt`, `metadata/MkLaunchReconciler.kt`,
  `metadata/MkMetadataModels.kt` all show parser-level errors, not just missing
  cross-references). This is **not** a defect in this agent's four modules — running
  `:mk-textengine:compileDebugKotlin` alone reproduces the identical `:mk-persistence`
  failure list, confirming the block is transitive, not something in `mk-textengine`'s own
  source. Per ownership rules this agent must not edit `:mk-persistence`; the blocker is
  reported here for Agent 1.1/the founder to route to whoever owns `:mk-persistence`'s
  repair.
- Every source file in all seven modules was hand-authored/reviewed against
  `android/API_SURFACE.md` and the real Swift source for field shapes and cross-module type
  references; the three modules that DID compile (`mk-foundation`, `mk-model`, `mk-color`)
  give reasonable confidence the same authoring approach applied to the other four is sound,
  but that confidence is not a substitute for an actual green build, which is not claimed for
  those four.

## Stub counts (published, correctly non-zero at this batch)

`MkNotYetPorted(` throw-site counts (a proxy for `Scripts/android/stub-count.sh`, which this
agent does not own — Agent 1.1's script): `mk-foundation` 45, `mk-model` 27, `mk-textengine`
32, `mk-arrange` 41, `mk-pathtext` 40, `mk-render` 85, `mk-color` 13 — **283 total** across
these seven modules. Non-zero and expected at Batch 1 per `ANDROID_SPINE.md` §4 ground rule
4; burn-down is Batches 2-4's job.

## Cross-module contract notes

`mk-pathtext`'s `MkPathTextPlacementProvider` conforms to `mk-arrange`'s
`MkPathPlacementProviding` interface, requiring a `:mk-pathtext -> :mk-arrange` Gradle
dependency edge. `ANDROID_SPINE.md` §3.2's dependency table does not list this edge as
currently drawn from `Package.swift`, but the Swift source itself has the identical
cross-module conformance (`Sources/MKPathText/PathPlacementProvider.swift` imports
`MKArrange` for exactly this reason, with its own documented "acyclic, added to
Package.swift" note). Flagged here as an `android/docs/CONTRACT_CHANGES.md`-worthy entry for
Agent 1.1/the gate to apply, per spine ground rule 5 — not applied in this work item
(no `build.gradle.kts` edits made).

## Blockers

1. **`:mk-persistence` (Agent 1.4's module) does not compile** — blocks any full-pipeline
   Gradle verification of this agent's `mk-textengine`/`mk-arrange`/`mk-pathtext`/`mk-render`
   modules. See "Literal build status observed" above for the exact failing files.
2. No blocker within this agent's own seven modules' scope beyond the above.
