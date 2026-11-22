# Android Port — Batch 2 Task Packets

Batch 2 · Theme: **foundation · model · color · designsystem tokens · designsystem components**
· Gate: **G2**

Depends on G1 (Gradle scaffold, native toolchain, contract stubs). Every file this batch touches
already exists as a `throw MkNotYetPorted(...)` stub from Batch 1 · Agents 1.3/1.4 — this batch
replaces those stub bodies with real ports. Dispatch all five agents in one message; they run
concurrently and own disjoint file sets (Appendix). Source of truth is the shipped Swift code at
`MakhtootKit/Sources/**`, read in full for every file listed in each port map below — real LOC
via `wc -l`, no placeholders.

---

### Batch 2 · Agent 2.1 — `mk-foundation`

**Depends on:** G1 · **Parallel-safe with:** every other Batch 2 agent

**Mission.** Port all 15 files of `MakhtootKit/Sources/MKFoundation/**` (1,234 LOC) to
`:mk-foundation` — geometry, transforms, RTL utilities, ids, logging, errors, feature flags, the
cross-module memory-accounting registry every other module's caches register with, and
`Stubs/MKFontProviding.swift` (139 LOC — `mk-foundation` is **15** files, not 14; this file was
previously in no agent's port map anywhere in the plan). `MKFontProviding.swift` declares
`MKFontHandle`, `MKFontVariantRequest`, the `MKFontProviding` protocol, and `SystemFontStubProvider`
— the seam `:mk-textengine` and `:mk-render` both resolve fonts through, carrying a "never
synthesize bold/italic" contract. Left unported, its stub throws at runtime while the data classes
still compile, so nothing catches it. The module also depends on `MkNotYetPorted`
from work item 1.3. Each remaining Batch 1 contract stub throws that exception
until its port replaces it.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKFoundation/**` (15 files) | Source of truth for this port |
| `ANDROID_SPINE.md` §2 (D-300, D-302, D-319, D-320) | Platform/concurrency/accessibility/analytics decisions this module's types must respect |
| `android/API_SURFACE.md` (Batch 0.3) | Confirms every public symbol this module must expose |
| `android/PARITY_MATRIX.md` (Batch 0.1) | R-ids this module's types are traced from |
| `FOUNDATION.md` §1–2 | D-100/D-101/D-102 platform/layout/concurrency context |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/**`
- `android/mk-foundation/src/test/kotlin/net/binjamshid/makhtoot/mk/foundation/**`
- `android/docs/impl-log/BATCH-2.1.md`

**Never touch.** Any other `android/mk-*` module. Any iOS Swift source (read-only). Any file
outside `android/`.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Geometry/MKGeometry.swift` | 37 | `geometry/MkGeometry.kt` | `CGPoint`/`CGSize`/`CGRect` typealiases → plain immutable Kotlin data classes `MkPoint`/`MkSize`/`MkRect` (not `android.graphics.PointF`/`RectF`, which are mutable and lack value-type equality/hashing the scene graph needs). `MKGeometryMath` (normalizeAngle/union/aspectFit) ports as pure functions unchanged. |
| `Geometry/MKTransform2D.swift` | 114 | `geometry/MkTransform2D.kt` | Decomposed position/rotation/scale data class per D-111, ported unchanged (pure math: `affineTransform`, `concatenating`, `inverted`, `init(decomposing:)`). `CGAffineTransform` has no Android analogue used as canonical storage — bridge to `android.graphics.Matrix` only at the render/hit-test boundary (owned by `:mk-canvas`/`:mk-render`, Batch 4/5), never here. The documented non-uniform-scale + non-zero-rotation shear limitation carries over verbatim. |
| `MKID.swift` | 45 | `MkID.kt` | Phantom-typed UUID wrapper. Swift's zero-cost phantom generic (`MKID<Tag>`) has no exact Kotlin equivalent at zero runtime cost, but the same compile-time-distinct-id-types goal is achieved with a generic value class: `value class MkID<Tag>(val rawValue: UUID)` wrapping `java.util.UUID`. `MKNodeTag`/`MKProjectTag`/`MKClusterTag` port as empty marker `object`/`sealed` marker types; `MkNodeID`/`MkProjectID`/`MkClusterID` as typealiases exactly as the Swift file does. |
| `MKFontUsageRecordingProtocol.swift` | 39 | `MkFontUsageRecordingProtocol.kt` | Interface + `MkNoOpFontUsageRecorder` no-op, direct 1:1 port. `async` → `suspend fun`. |
| `Stubs/MKDocumentStoring.swift` | 42 | `stubs/MkDocumentStoring.kt` | Interface + `InMemoryDocumentStore` (Swift `actor`) → Kotlin `class` guarded by a `kotlinx.coroutines.sync.Mutex` around a `MutableMap<MkProjectID, ByteArray>`. Batch 3.4's `MkFilePackageDocumentStore` (mk-persistence) is the real replacement, mirroring the Swift-side `MKPersistence` relationship documented in this file's own header. |
| `MKFeatureFlags.swift` | 54 | `MkFeatureFlags.kt` | Per spine D-300/D-321: `referralProgram`/`analyticsEnabled`/`multiPageSeam`/`metalRenderer`/`alternateAppIcons` move from a runtime `struct` with a `.default` singleton to `BuildConfig` fields (compile-time, mirrors D-225/D-321's compile-time exclusion mechanism) **plus** a Jetpack DataStore-backed runtime overlay for the flags a later workstream exposes in Settings (mirrors the Swift doc comment's own "a later workstream may expose in Settings" seam). `referralProgram` stays `false` by default in every non-debug `BuildConfig` variant. |
| `Entitlement/MKEntitlementProviding.swift` | 48 | `entitlement/MkEntitlementProviding.kt` | Interface `MkEntitlementProviding` + `MkPremiumCapability` enum, direct 1:1 port. Default-implementation extension (`isEntitled` = "any non-`.free` state grants everything") ports as a Kotlin interface default method. |
| `Entitlement/MKEntitlementState.swift` | 64 | `entitlement/MkEntitlementState.kt` | Sealed class `MkEntitlementState` (`Lifetime`/`Subscribed`/`InGracePeriod`/`InBillingRetry`/`Trial(daysLeft: Int)`/`Free`) implementing `Comparable` by D-113 precedence rank, ported unchanged — same precedence order backs D-311's Play Billing resolver in Batch 6.1. |
| `Entitlement/StubEntitlementResolver.swift` | 17 | `entitlement/StubEntitlementResolver.kt` | Trivial `object`/`class` returning `.Lifetime`, direct port. Same "never ship in production wiring" warning carried into the KDoc. |
| `MKLog.swift` | 67 | `MkLog.kt` | Per spine D-300: `os.Logger`/`OSSignposter` → `android.util.Log` (tagged `net.binjamshid.makhtoot.<module>`, mirroring the subsystem-prefix convention) + `androidx.tracing.Trace.beginSection`/`endSection` for the reserved `MkSignpost` interval vocabulary (`manipulationFrame`, `typingEcho`, `documentOpen`, `autosave`, `export`, `arrangeDerive`). The D-115 budget table in the KDoc carries over verbatim (same numbers, same owning modules). |
| `MKError.swift` | 112 | `MkError.kt` | `MkError` interface (`errorCode`, `arabicUserMessage`, `underlying`) + `MkErrorCode` prefix registry + `MkIOError`/`MkValidationError`/`MkEntitlementError` sealed classes, direct 1:1 port. Every Arabic string carries over byte-for-byte with its Latin gloss comment. |
| `ImageDownscale.swift` | 150 | `MkImageDownscale.kt` | `CoreGraphics`/`ImageIO` (`CGImageSourceCreateWithData`, `CGImageDestination`, EXIF-orientation correction) → `android.graphics.BitmapFactory.decodeByteArray` + `Bitmap.createScaledBitmap`/`Canvas`-based redraw for the resize path, and `androidx.exifinterface.media.ExifInterface` for the orientation-tag read + `Matrix`-based rotate/mirror (the same 8-orientation EXIF correction this file's `correctedForOrientation` implements by hand for `CGImagePropertyOrientation` — Android's `ExifInterface` exposes the identical tag semantics via `TAG_ORIENTATION`). Output format stays PNG (alpha-preserving) via `Bitmap.compress(PNG, ...)`, matching the "always PNG, never a lossy re-save" contract. |
| `MKMemoryGovernor.swift` | 152 | `MkMemoryGovernor.kt` | `MkMemoryAccountable` interface (`accountedBytes`/`evictOffscreen`/`evictAll`, `suspend fun`) + `MkMemoryEvictionPriority` enum + the `MkMemoryGovernor` registry itself, ported unchanged as pure cross-module bookkeeping (weak-referenced registration list, prune-on-access). Per spine's explicit note: the actual OS memory-pressure *signal* this governor's driver (`MKDegradationController`, `:mk-render`, Batch 4.6) reacts to moves from `DispatchSource`/`os_proc_available_memory` sampling to `ActivityManager.MemoryInfo` + `ComponentCallbacks2.onTrimMemory` + `Debug.MemoryInfo` — that sampling code lives in `:mk-render`, not here; this file itself has no direct `DispatchSource`/`os_proc_available_memory` call to replace, only the registry it drives. Swift `actor` → Kotlin `class` guarded by `Mutex` (registration list mutation and eviction fan-out both need the same serialization the actor gave for free). |
| `RTL/MKRTLUtilities.swift` | 154 | `rtl/MkRtlUtilities.kt` | Arabic-script detection ranges, first-strong-character base-direction heuristic, and Arabic-Indic ↔ Latin digit conversion are **pure Unicode logic with zero UIKit dependency** — port unchanged, scalar-range-for-scalar-range, to Kotlin `Int`/`Char`/`String` code-point iteration. The `#if canImport(UIKit)` block (`semanticContentAttribute(for:) -> UISemanticContentAttribute`) is **dropped, not ported**: per D-318, Compose/View RTL mirroring is automatic under the app-wide forced `ar` locale + `android:supportsRtl="true"`, so there is no per-view "which way should this mirror" query to answer on Android the way UIKit's rare manual-override case needed. |
| `Stubs/MKFontProviding.swift` | 139 | `stubs/MkFontProviding.kt` | The coverage-hole fix (`§5.3`): `MkFontHandle` (opaque native-face-handle wrapper), `MkFontVariantRequest` (weight/style axis request), the `MkFontProviding` interface (`resolve(request): MkFontHandle`), and `SystemFontStubProvider` (the placeholder conformer every module composes against until Batch 3.7's `MkRegistryFontProvider` supersedes it) — direct 1:1 port, same "never synthesize bold/italic — return the nearest genuine cut or fail" contract carried into the KDoc verbatim. This is the seam `:mk-textengine` (Batch 3.1a) and `:mk-render` (Batch 4.5/4.6) both resolve fonts through; porting it here, not leaving it to whichever later agent first needs it, is what stops its Batch 1 stub from throwing at runtime while everything around it compiles clean. |

Use the existing `android/mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkNotYetPorted.kt`
from Batch 1 work item 1.3. The existing declaration is
`class MkNotYetPorted(symbol: String) : NotImplementedError("$symbol not yet ported")`.
Every Batch 1 contract stub throws it. Use it unchanged.

**Tasks.**
1. Read all 15 Swift files above in full — including `Stubs/MKFontProviding.swift` — and confirm
   the 1,234 LOC total via `wc -l` before writing any Kotlin.
2. Port each file per the table above, one Kotlin file per Swift file (naming rule: `MK`→`Mk`),
   directory structure mirrored under `foundation/{geometry,entitlement,rtl,stubs}/`.
3. Delete or overwrite the Batch 1 contract-stub body at each of the 15 paths this agent owns —
   `geometry/MkGeometry.kt`, `geometry/MkTransform2D.kt`, `MkID.kt`,
   `MkFontUsageRecordingProtocol.kt`, `stubs/MkDocumentStoring.kt`, `stubs/MkFontProviding.kt`,
   `MkFeatureFlags.kt`, `entitlement/MkEntitlementProviding.kt`, `entitlement/MkEntitlementState.kt`,
   `entitlement/StubEntitlementResolver.kt`, `MkLog.kt`, `MkError.kt`, `MkImageDownscale.kt`,
   `MkMemoryGovernor.kt`, `rtl/MkRtlUtilities.kt` — replacing every `throw MkNotYetPorted(...)`
   body with the real implementation (spine §3.3). Do **not** touch or recreate
   `MkNotYetPorted.kt` itself; it is Batch 1 · Agent 1.3's file and stays in place, still used by
   every module whose port batch has not yet run.
4. Ensure `MkFeatureFlags` reads `BuildConfig.REFERRAL_ENABLED` etc. with a DataStore-backed
   overlay class (`MkFeatureFlagsStore`) for the runtime-overridable subset only.
5. Port the existing `MKFoundationTests` suite 1:1 as JUnit5/kotlin-test cases under
   `mk-foundation/src/test`, including the `MKTransform2D` decompose/recompose round-trip cases
   and the RTL digit-conversion/base-direction cases.

**Acceptance.**
- `./gradlew :mk-foundation:testDebugUnitTest` green
- `./gradlew :mk-foundation:lintDebug` green
- Requirements covered: `R-1.3`, `R-2.3` (RTL-first Arabic-only UI — `MkRtlUtilities`), `R-1.18`,
  `R-14.1` (no third-party SDKs / entitlement-tier vocabulary seam — `MkEntitlementState`)
- Tests ported: no dedicated `T-FND-*` id exists in `TEST_MATRIX.md` (MKFoundation has no
  standalone iOS test target of its own); the ported `MKFoundationTests` XCTest cases (RTL,
  transform, memory governor) are carried over as this module's own JUnit suite and are exercised
  indirectly by every downstream `T-MDL-*`/`T-TXT-*`/`T-FNT-*` test that depends on this module
- Fixtures consumed: none (this module has no golden-fixture surface of its own)
- Stub count for this module reaches 0

**Impl log.** `android/docs/impl-log/BATCH-2.1.md`

---

### Batch 2 · Agent 2.2 — `mk-model` (scene graph, codec, migrator)

**Depends on:** G1 · **Parallel-safe with:** every other Batch 2 agent

**Mission.** Port all 15 files of `MakhtootKit/Sources/MKModel/**` (2,176 LOC) to `:mk-model`:
the immutable D-111 scene graph (`MKNode` and its seven cases), node styles, per-object text
style, the arranged-composition family (Glyph/Mark/Ligature nodes, D-106), `SceneCodec`, and
`MKSceneMigrator`. The hard acceptance criterion is **byte-identical JSON** between this port's
encoder and the Swift encoder, verified against the 4 `Tests/Fixtures/*.makhtoot` scenes.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKModel/**` (15 files) | Source of truth for this port |
| `MakhtootKit/Tests/Fixtures/*.makhtoot` (4 files) | The byte-identical-JSON acceptance fixtures |
| `android/fixtures/scenecodec/**` (Batch 0.2) | Golden JSON envelopes for every migration case |
| `ANDROID_SPINE.md` §2 (D-301, D-308, D-309, D-324) | Module layout, persistence layout, interchange format, fixture-as-oracle policy |
| `FOUNDATION.md` §4 (D-111, D-112) | Scene graph and persistence decisions this module's types encode |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/**`
- `android/mk-model/src/test/kotlin/net/binjamshid/makhtoot/mk/model/**`
- `android/docs/impl-log/BATCH-2.2.md`

**Never touch.** `:mk-foundation` (read/depend only). Any other `android/mk-*` module. Any iOS
Swift source (read-only).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKNode.swift` | 605 | `MkNode.kt` | The D-111 node family. `MkNode` → Kotlin `sealed interface` with a `data class` payload per case (`Group`/`LiveText`/`PathText`/`Arranged`/`Shape`/`Image`/`Background`), matching frozen §3 naming. `MkNodeCore`, `MkGroupNode`, `MkStyleRun`, `MkSourceText`, `MkTextFrameSpec`, `MkLiveTextNode`, `MkPathSide`/`MkPathSpacingMode`/`MkPathLayoutOptions`, `MkPathTextNode`, `MkShapeGeometry`/`MkShapeNode`, `MkAssetRef`, `MkImageKind`/`MkImageNode`, `MkBackgroundImageFit`/`MkBackgroundContent`/`MkBackgroundNode` all port field-for-field. Custom `Codable` conformances (the `{"kind","payload"}` discriminated-union shape for `MkNode` and the hand-rolled `{"_0",...}` shape for `MkBackgroundContent` matching Swift's synthesized-enum-Codable convention) become custom `kotlinx.serialization.KSerializer` implementations that reproduce the **exact same JSON shape**, not kotlinx's own default polymorphic-serialization shape (`{"type":...}` with different key names) — this is the single highest-risk file for the byte-identical-JSON acceptance gate. `MkAssetRef`'s hand-written decode validation (digest = 1–64 lowercase hex, ext = 1–8 lowercase alphanumeric, rejecting anything that could form a path-traversal component) ports as a custom deserializer that throws on the same two malformed-input classes (S-2 defense). Additive-field decode-tolerance (`glyphOffsets`, `isPhotoBackgroundUse`, `fit` all `decodeIfPresent(...) ?? default`) ports as `@EncodeDefault(ALWAYS)` fields with default values, verified to **always encode** (not omit) on the Kotlin side to match Swift's own "always encode, only decode is tolerant" behavior. |
| `MKScene.swift` | 246 | `MkScene.kt` | `MkCanvasSpec` + `MkScene` (schemaVersion/canvas/background/nodes) as pure-function immutable data classes: `inserting`, `locate`, `removing`, `reordering`, `reparenting`, `updatingNode`, `node(id:)` all port as functions returning a **new** `MkScene` copy, never mutating `this` — direct algorithmic port, no platform substitution needed (pure recursion over `List<MkNode>`). `MkNodeIndex` (O(1) lookup) ports as a `Map<MkNodeID, MkNode>`-backed class built in one tree walk, same "not cached on `MkScene` itself" rationale (value-type equality would otherwise be corrupted by a class-boxed cache). |
| `Schema/SceneCodec.swift` | 121 | `schema/MkSceneCodec.kt` | `MkModelError` (`schemaTooNew`/`migrationPathMissing`/`malformedEnvelope`) as a sealed class implementing `MkError`. `MkSceneEnvelope` as a `@Serializable data class(schemaVersion, scene)`. The three-step decode (read `schemaVersion` from the raw JSON object first, reject if newer, migrate if older, decode as `MkScene` if current) ports via `kotlinx.serialization.json.JsonObject` for the pre-typed-decode `schemaVersion` peek, mirroring Swift's own `JSONSerialization.jsonObject` pre-parse. `encoder.outputFormatting = [.sortedKeys]` → `Json { prettyPrint = false }` with keys emitted in **declaration order matching Swift's alphabetically-sorted key order** — kotlinx-serialization does not sort keys by default, so this requires either a custom `JsonElement`-tree re-sort pass before final string emission, or hand-ordering every `@Serializable` class's property declarations to alphabetical order and confirming kotlinx emits declaration order (verified empirically against the golden fixtures, not assumed) — record the chosen mechanism in the impl log. |
| `Schema/MKSceneMigrator.swift` | 80 | `schema/MkSceneMigrator.kt` | `MkSceneSchema.currentVersion = 1`, `MkSceneMigrator` interface (`fromVersion`/`toVersion`/`migrate(sceneJson) -> JsonObject`), `MkIdentityMigrator`, `MkSceneMigratorRegistry` (dispatch table + chained `migrate(fromVersion:)` loop) — direct 1:1 port, operating on `kotlinx.serialization.json.JsonObject` in place of `[String: Any]`. Every migration case in `android/fixtures/scenecodec/**` (Batch 0.2) must round-trip through this registry identically to the Swift chain. |
| `MKNodeStyle.swift` | 113 | `MkNodeStyle.kt` | `MkColorSpace` enum (`srgb` only in v1), `MkSolidColor` (r/g/b/a/swatch, extended-range Doubles per D-117 — values may exceed `0...1`, preserved verbatim, never clamped at this layer), `MkFill`/`MkLineJoin`/`MkLineCap`/`MkStroke`/`MkShadow`/`MkStyle` — direct field-for-field `@Serializable data class`/`enum class` port, same JSON key names. |
| `MKTextStyle.swift` | 126 | `MkTextStyle.kt` | `MkLigatureSetting`, `MkBaseDirection`, `MkKernOverride`, `MkTextStyle` (font/pointSize/kerningOverrides/tracking/baselineShift/lineHeightMultiple/ligatureSetting/baseDirection/isBold/isItalic/isUnderline/isStrikethrough/highlightColor) — direct 1:1 port, same defaults (36pt, 1.2× line height, `.standard` ligatures, `.rightToLeft` base direction). |
| `MKBezierPathData.swift` | 166 | `MkBezierPathData.kt` | `MkBezierSegment`/`MkBezierPathData` (editable cubic path, D-110's document representation) and `MkPathData` (flat 1000/em-normalized command stream, D-108/INV-13's lock-resilient glyph-outline representation) both port as data classes. `cgPath()`/`cgPath(at:)` (build a drawable path FROM the stored commands) port to build an `android.graphics.Path` via `moveTo`/`lineTo`/`quadTo`/`cubicTo`/`close` — direct mapping, op-code for op-code. **`MKPathData.from(_ cgPath:pointSize:)` (the reverse direction — capturing a `CGPath`'s elements back into the flat command stream via `CGPath.applyWithBlock`) is NOT ported on Android**: `android.graphics.Path` has no public element-enumeration API equivalent to `CGPath.applyWithBlock`, and on Android this capture direction is never needed from a `Path` object anyway — glyph outlines originate directly from `FT_Outline_Decompose` inside `:mk-native` (Batch 3.1), which already emits the flat command list natively, bypassing an intermediate `android.graphics.Path` round-trip entirely. Document this as a deliberate, one-directional narrowing in the impl log, not a silent gap. |
| `MKFontRef.swift` | 41 | `MkFontRef.kt` | `MkFontRef` (fontID/postScriptName/userImported) + `.system(postScriptName:)` + `.systemFallback` (`"system..SFArabic"` synthetic id) — direct port. The synthetic `"system.<postScriptName>"` id scheme is kept unchanged even though there is no literal `.SFArabic` on Android (Batch 2.4/2.5's design-system fonts and Batch 3.7's `MkFontRegistry` supply the real catalog `fontID`s this type otherwise threads through unresolved). |
| `MKPathGlyphOffset.swift` | 54 | `MkPathGlyphOffset.kt` | `MkPathGlyphOffsetKey` (codepoints + occurrenceOrdinal) + `MkPathGlyphOffset` (offset + rotation) — direct port, same stability contract (keyed by codepoint-sequence + ordinal, not by the non-stable `MkClusterID` UUID minted fresh on every reshape). |
| `Arranged/GlyphNode.swift` | 196 | `arranged/MkGlyphNode.kt` | `MkGlyphRef` (glyphID: UShort/Int, font, fontChecksum, variationCoordinates), `MkGlyphLayout` (position/advance/pathTangentAngle), `MkProvenance` (clusterID/codepoints/utf16Start/utf16Length/bidiLevel/visualIndex/logicalIndex/cursiveAttached — the D-106 "both levels" contract), `MkGlyphNode` itself — direct field-for-field port. `cursiveAttached`'s additive-field decode tolerance (`decodeIfPresent(...) ?? false`, defaulting `false` on any pre-cursive-support document) ports the same way `MkNode.swift`'s additive fields do (`@EncodeDefault(ALWAYS)`, always-encode/tolerant-decode). |
| `Arranged/MarkNode.swift` | 81 | `arranged/MkMarkNode.kt` | `MkMarkClass` enum (`tashkeel`/`quranicAnnotation`/`otherCombining`) + `MkMarkNode` (id/glyph/outline/attachedTo/relativeOffset/followsBase/transform/style/provenance/markClass/stackIndex/isHidden/isLocked) — direct port. `attachedTo: MkNodeID?` (id-reference, not tree containment) ports unchanged, same detach-is-one-field-change property. |
| `Arranged/LigatureGroup.swift` | 107 | `arranged/MkLigatureGroup.kt` | `MkComposedLigature`, `MkFidelityMode`, `MkDecomposedLigature`, `MkLigatureState` (sealed `Composed`/`Decomposed`), `MkLigatureGroup` — direct port. The D-108 "recomposition restores the stored original exactly" guarantee (the original composed glyph retained *inside* the decomposed case, never discarded) is a type-level property of the sealed-class shape and carries over automatically. |
| `Arranged/ArrangedComposition.swift` | 124 | `arranged/MkArrangedComposition.kt` | `MkArrangedChild` (sealed `Glyph`/`Mark`/`Ligature`, custom `{"kind",...}` serializer matching `MkNode`'s own discriminated-union convention), `ArrangedComposition` (nodes/sourceBackup/originFrame), `MkArrangeOrigin` (sealed `LiveText`/`PathText(MkBezierPathData)`), `MkArrangedTextNode` — direct port. The deliberately-out-of-scope `clusterTable`/`bidi` composition-wide index fields (documented in the Swift file as an additive extension seam `MKArrange` may add later) are likewise out of scope here — do not invent them. |
| `Arranged/SourceTextBackup.swift` | 83 | `arranged/MkSourceTextBackup.kt` | `MkSourceTextBackup` (sourceString/style/pathData/createdAt/contentHash) — direct port. The dependency-free FNV-1a `contentHash` (INV-4 tamper/drift check) ports as the same algorithm over UTF-8 bytes of `sourceString + "" + sortedKeysJSON(style)`; must be internally self-consistent (`contentHash == recomputedHash()` on any freshly-constructed or freshly-decoded value) but does **not** need to numerically equal an iOS-computed hash for the same input — this hash is a same-platform tamper/drift guard, not a cross-platform-compared field, since Arrange Mode derivation runs independently per platform (Batch 4). Still port the exact FNV-1a offset/prime constants for consistency with the rest of this codebase's hashing (`MkSceneRevision`/`MkCrc32` in `:mk-persistence`, Batch 3.4). |
| `Arranged/JoiningForm.swift` | 33 | `arranged/MkJoiningForm.kt` | `MkJoiningForm` enum (`isolated`/`initial`/`medial`/`final`) + `MkJoiningState` (form/joinsPrevious/joinsNext/brokenByUser) + `.isolatedDefault` — direct port. |

**Tasks.**
1. Read all 15 Swift files above in full; confirm the 2,176 LOC total via `wc -l`.
2. Port each file per the table, directory structure mirrored under
   `model/{schema,arranged}/`. Delete or overwrite the Batch 1 contract-stub body at each of this
   agent's 15 owned paths — `MkNode.kt`, `MkScene.kt`, `schema/MkSceneCodec.kt`,
   `schema/MkSceneMigrator.kt`, `MkNodeStyle.kt`, `MkTextStyle.kt`, `MkBezierPathData.kt`,
   `MkFontRef.kt`, `MkPathGlyphOffset.kt`, `arranged/MkGlyphNode.kt`, `arranged/MkMarkNode.kt`,
   `arranged/MkLigatureGroup.kt`, `arranged/MkArrangedComposition.kt`,
   `arranged/MkSourceTextBackup.kt`, `arranged/MkJoiningForm.kt` — replacing every
   `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
3. Write the custom `KSerializer`s for `MkNode`, `MkArrangedChild`, and `MkBackgroundContent`
   first, and prove byte-identical round-trip against all 4 `Tests/Fixtures/*.makhtoot` scenes
   (decode the Swift-produced JSON, re-encode, diff bytes) **before** porting anything else in
   this list — this is the file that gates G2.
4. Port `MkSceneMigrator`/`MkSceneMigratorRegistry` and prove every case in
   `android/fixtures/scenecodec/**` migrates identically.
5. Port the remaining node/style/arranged-family files; port the existing `MKModelTests` and
   `MKPersistenceTests`' scene-codec-adjacent cases (`MKAssetRefValidationTests`,
   `MKBackgroundContentTests`, `MKImageNodeTests`) 1:1 as JUnit tests, including the short
   placeholder-digest fixtures (`"deadbeef"`, `"cafebabe"`, `"abc123"`) `MKAssetRef`'s validator
   must keep accepting per that file's own documented character-class-not-length rule.

**Acceptance.**
- `./gradlew :mk-model:testDebugUnitTest` green
- `./gradlew :mk-model:lintDebug` green
- `mk-model` round-trips all 4 `Tests/Fixtures/*.makhtoot` scenes byte-identically (G2 gate)
- Requirements covered: `R-3.1` (project = `.makhtoot` package incl. `scene.json`), `R-6.2`,
  `R-6.4`, `R-6.8` (Arranged Composition dual-level model + provenance completeness), `R-7.1`,
  `R-7.3`, `R-7.5`, `R-7.6` (mark attach/detach/multi-mark model), `R-8.9`, `R-8.10`, `R-8.12`
  (ligature composed/decomposed state + fidelity + recomposition), `R-22.9` (determinism: same
  scene → same encoded bytes)
- Tests ported: `T-MDL-1` (scene graph Codable round trip), `T-MDL-2` (schemaVersion presence +
  migration hook); feeds `T-AR-43` (both levels, glyph + Unicode letter) and `T-TXT-2` (cluster
  bidirectionality) owned by Batch 3
- Fixtures consumed: `android/fixtures/scenecodec/**`; `MakhtootKit/Tests/Fixtures/*.makhtoot`
  (read directly for the byte-identical round-trip proof)
- Stub count for this module reaches 0

**Impl log.** `android/docs/impl-log/BATCH-2.2.md`

---

### Batch 2 · Agent 2.3 — `mk-color` (+ lcms2 binding)

**Depends on:** G1 · **Parallel-safe with:** every other Batch 2 agent

**Mission.** Port all 4 files of `MakhtootKit/Sources/MKColor/**` (467 LOC) to `:mk-color`,
replacing `CGColorSpace(iccData:)`-based CMYK conversion with lcms2 transforms called through
`:mk-native`. Carries FDA-03: the shipping default is lcms2's synthetic generic CMYK, documented
as lower fidelity exactly as D-117 documents Apple Generic CMYK on iOS — and Apple Generic CMYK
itself must never be copied into the APK.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKColor/**` (4 files) | Source of truth for this port |
| `ANDROID_SPINE.md` §1 (FDA-03), §2 (D-304, D-315) | The lcms2 carve-out, the default-profile decision, and the licence-verification requirement |
| `:mk-native`'s lcms2 JNI facade (Batch 1.2) | The native transform entry points this module calls through |
| `FOUNDATION.md` §6 (D-117) | iOS color-pipeline decision this module mirrors (minus the profile choice, which is FDA-03, not D-117) |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/**`
- `android/mk-color/src/test/kotlin/net/binjamshid/makhtoot/mk/color/**`
- `android/mk-color/src/main/assets/ICC/` (empty slot + `README.md` documenting the drop-in
  contract, mirroring the Swift module's own empty `Resources/ICC/` slot — **no ICC file is
  added here**; FDA-03's licensed-profile upgrade seam stays a founder call)
- `android/docs/impl-log/BATCH-2.3.md`

**Never touch.** `:mk-native`'s C++ lcms2 binding sources themselves (Batch 1.2's — this agent
calls the JNI facade, it does not modify it; a needed signature change goes into
`android/docs/CONTRACT_CHANGES.md` per spine ground rule 5). Any other `android/mk-*` module.
`Makhtoot/Resources/ICC/**` or any other iOS resource (never copy Apple Generic CMYK anywhere in
this tree).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKColorSpec.swift` | 103 | `MkColorSpec.kt` | `MkColorSpec` (r/g/b/a/swatch, extended-range Doubles) — direct data-class port. `cgColor()` (extended sRGB, the canonical display/export path) → `android.graphics.Color.valueOf(r, g, b, a, ColorSpace.get(ColorSpace.Named.EXTENDED_SRGB))` (API 26+; `ColorSpace.Named.EXTENDED_SRGB` is the direct Android analogue of `CGColorSpace.extendedSRGB`). `cgColorDisplayP3()` (display-only, D-117: never stored) → `ColorSpace.Named.DISPLAY_P3`, called only from UI/preview code, never from an export or persisted-document path — same "display-only" boundary the Swift KDoc enforces. `cgColorClampedSRGB()` (the finite `0...1`-clamped form every raster encoder actually paints with) → `android.graphics.Color.argb(...)` built from `r/g/b/a` each clamped via `coerceIn(0.0, 1.0)` — same clamp-point-is-explicit rationale. |
| `MKColorSpec+HSB.swift` | 102 | `MkColorSpecHsb.kt` | `MkHsbaComponents` + RGB↔HSB conversion (standard sector formula) — pure math, zero platform dependency, direct 1:1 port including the achromatic-edge-case (`hue = 0`, not NaN) convention. |
| `CMYKConverter.swift` | 108 | `MkCmykConverter.kt` | `CGColor.converted(to:intent:.relativeColorimetric,options:)` → an lcms2 `cmsCreateTransform`/`cmsDoTransform` call through `:mk-native`'s JNI facade, with `INTENT_RELATIVE_COLORIMETRIC` passed explicitly at every call site (mirrors D-226(1)'s "never a framework default" rule). `cmyk(from:profile:)` (single-color, 4-component `[C,M,Y,K]` result) and `cmykPalette(_:profile:)` (de-duplicating batch conversion over the scene palette) port as thin Kotlin wrappers over the native transform call, same dedup-by-equal-`MkColorSpec` logic. `cmykPerceptual(from:profile:)` (test-only, `.perceptual` intent, never used by production export) ports too, for the equivalent intent-divergence unit test. `convertWholeImage(_:profile:)` (whole-`CGImage`→CMYK-bitmap raster path) has **no direct Android `Bitmap` analogue** — Android has no CMYK `Bitmap.Config` — so this becomes a raw pixel-buffer transform: read the source `Bitmap`'s ARGB_8888 pixels into an RGB byte buffer, run one batched lcms2 `cmsDoTransform` call over the whole buffer (native, off the JVM heap for large pages), and return a raw `ByteArray` of CMYK bytes consumed directly by `:mk-export`'s in-house PDF writer (Batch 5.7) — never wrapped back into an `android.graphics.Bitmap`. Document this as a structural, not cosmetic, platform substitution. |
| `ICCProfileStore.swift` | 154 | `MkIccProfileStore.kt` | `MkIccProfileProvenance` sealed class (`BundledIcc(name, licenceEvidencePath)` / `LcmsSyntheticGenericCmyk` — the FDA-03-renamed case; there is no Apple Generic CMYK on this platform, and this case name must not imply there is) with the same `arabicDisclosure`/`mayClaimPdfX` semantics (only a licensed, verified bundled profile may claim the `GTS_PDFX` OutputIntent subtype; the synthetic fallback still embeds a real, honestly-labelled OutputIntent under `GTS_PDFX_no-claim`). `loadBundled()`: `Bundle.url(forResource:...)`/`CGColorSpace(iccData:)` → `context.assets.open("ICC/PressProfile.icc")` (via `AssetManager`) + `cmsOpenProfileFromMem` (lcms2, through `:mk-native`), same "malformed or wrong-model bundled file is treated as absent, never silently misused" guard (verify the loaded profile's colour model is CMYK before accepting it). `appleGenericCMYKFallback()` → **replaced**, not renamed-only: lcms2 has no built-in "generic CMYK" the way `CGColorSpace(name: .genericCMYK)` is a zero-cost system call: construct the FDA-03 synthetic fallback via `cmsCreateProofingTransform`/a small bundled minimal synthetic-CMYK profile built at `:mk-native` init time (naive additive-to-subtractive approximation, e.g. `C=1-R, M=1-G, Y=1-B, K=0`, wrapped as a real lcms2 profile object so the rest of the pipeline sees one consistent `MkIccProfile` type regardless of provenance) — mark this construction `VERIFY-AT-SUBMISSION` for its own disclosure wording, and confirm in the impl log that no Apple-authored ICC bytes are embedded anywhere in this module or its assets. |

**Tasks.**
1. Read all 4 Swift files above in full; confirm the 467 LOC total via `wc -l`.
2. Confirm `:mk-native`'s Batch-1.2 lcms2 JNI facade exposes (or, if a gap is found, file it to
   `android/docs/CONTRACT_CHANGES.md` rather than editing `:mk-native` directly): profile-open-
   from-bytes, transform-create(src, dst, intent), transform-apply(buffer), and a way to query a
   profile's colour model (to replicate the Swift file's `colorSpace.model == .cmyk` guard).
3. Port `MkColorSpec`/`MkColorSpecHsb` first (pure math, zero native dependency, fastest to
   green).
4. Port `MkIccProfileStore`, including the synthetic-CMYK-fallback construction and its
   `VERIFY-AT-SUBMISSION` disclosure note.
5. Port `MkCmykConverter`, including the whole-buffer raster path described above.
6. Delete or overwrite the Batch 1 contract-stub body at each of this agent's 4 owned paths —
   `MkColorSpec.kt`, `MkColorSpecHsb.kt`, `MkCmykConverter.kt`, `MkIccProfileStore.kt` — replacing
   every `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
7. Port the existing `MKColorTests` (RGB↔HSB round trip, CMYK conversion against fixture colours,
   the `.relativeColorimetric` vs `.perceptual` intent-divergence case, `CMYKSpikeEvidenceTests`'
   "the fallback profile always constructs" regression) 1:1 as JUnit tests.

**Acceptance.**
- `./gradlew :mk-color:testDebugUnitTest` green
- `./gradlew :mk-color:lintDebug` green
- Requirements covered: `R-13.10` (color pipeline D-117 → CMYK via explicit relative-colorimetric
  conversion), `R-13.9` (print PDF colour correctness), `R-13.11` (export-sheet CMYK/RGB toggle
  depends on this conversion existing)
- Tests ported: no `T-CLR-*` id exists in `TEST_MATRIX.md` (MKColor has no standalone iOS test
  id prefix); the ported `MKColorTests`/`CMYKSpikeEvidenceTests` XCTest cases are carried over as
  this module's own JUnit suite and feed `T-EXP-11` (print PDF colour, owned by Batch 5.7)
- Fixtures consumed: none checked in for this module; conversion correctness is verified against
  the ported unit-test fixture colours, not a Batch 0 golden (CMYK conversion is
  platform-transform-specific — an lcms2-vs-CoreGraphics numeric match is not expected or
  required, only internal consistency and the documented intent semantics)
- No Apple-authored ICC bytes present anywhere in `:mk-color` (`grep -r` its `assets/ICC/` finds
  only the README)
- Stub count for this module reaches 0

**Impl log.** `android/docs/impl-log/BATCH-2.3.md`

---

### Batch 2 · Agent 2.4 — `mk-designsystem` tokens and themes

**Depends on:** G1 · **Parallel-safe with:** every other Batch 2 agent

**Mission.** Port `MKTheme`, `MKSpacing`, `MKTypeRamp`, `MKMotion`, `MKThemeColorHelpers`, and
all 5 theme files (Hibr, Kufi, Naqsh, Raml, Tayf — 10 files, 878 LOC) to `:mk-designsystem`,
exposed via Compose `CompositionLocal`s per D-317 — **not** `MaterialTheme`. Consumes
`android/strings/theme-tokens.json` (Batch 0.4) for the token values. All 9 UI-chrome fonts are
already bundled custom fonts (`UIChromeFontBootstrap.swift`'s catalog), so no SF-Arabic
substitution is needed anywhere in this file set — every theme's `fonts.display`/`.ui`/`.mono`
PostScript name maps directly to a bundled Android font resource. Also ports
`TokenResolutionTests.swift` and `MKTypeRampDynamicTypeTests.swift` from
`MakhtootKit/Tests/MKDesignSystemTests/` — the real test target for this module's tokens.
**`MKThemeTests`, `MKTypeRampTests`, and `MKSpacingTests` do not exist anywhere in the repo**;
an earlier draft of this packet invented those three names and they are struck here.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKDesignSystem/MKTheme.swift`, `MKSpacing.swift`, `MKTypeRamp.swift`, `MKMotion.swift`, `Themes/MKThemeColorHelpers.swift`, `Themes/HibrTheme.swift`, `Themes/KufiTheme.swift`, `Themes/NaqshTheme.swift`, `Themes/RamlTheme.swift`, `Themes/TayfTheme.swift` (10 files) | Source of truth for this port |
| `MakhtootKit/Tests/MKDesignSystemTests/TokenResolutionTests.swift` (113 LOC), `MKTypeRampDynamicTypeTests.swift` (76 LOC) | The real test source for this module's tokens (verified via `find MakhtootKit/Tests -name '...'` — see writer note below); `MKMotionAccessibilityTests.swift` in the same directory belongs to Agent 2.5, not this agent |
| `android/strings/theme-tokens.json` (Batch 0.4) | Extracted colour/type-ramp/spacing/radius/motion values per theme |
| `android/strings/font-manifest.json` (Batch 0.4) | Bundled-font family → Android asset path mapping this module's `MkFontSet`s reference |
| `ANDROID_SPINE.md` §2 (D-317, D-319) | Compose `CompositionLocal` (not `MaterialTheme`) decision; 48dp touch floor |
| `FOUNDATION.md` §9 (D-126) | iOS design-system token decision this module mirrors |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/{MkTheme,MkSpacing,MkTypeRamp,MkMotion}.kt`
- `android/mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/**`
- `android/mk-designsystem/src/test/kotlin/net/binjamshid/makhtoot/mk/designsystem/{TokenResolutionTest,MkTypeRampDynamicTypeTest}.kt` (token/theme tests only — component tests, and `MKMotionAccessibilityTests`'s port, are 2.5's)
- `android/docs/impl-log/BATCH-2.4.md`

**Never touch.** `android/mk-designsystem/src/main/kotlin/.../components/**` (2.5's). Any other
`android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKSpacing.swift` | 36 | `MkSpacing.kt` | 4-pt grid (`xs`…`xxxl`) — direct port, `CGFloat` → Compose `Dp` (`4.dp`, `8.dp`, … `48.dp`). |
| `MKMotion.swift` | 73 | `MkMotion.kt` | `MkMotionCurve` enum (`EaseInOut` today) + `MkMotionTokens` (fast/standard/modal durations, `reducesMotion` flag). SwiftUI `Animation` → Compose `androidx.compose.animation.core.AnimationSpec` (`tween(durationMillis, easing = FastOutSlowInEasing)` as the `EaseInOut` mapping). The `reducesMotion`-as-plain-data-not-live-environment-read pattern carries over unchanged and for the same reason: this is a plain `Sendable`-equivalent value class usable from non-`@Composable` contexts, so it cannot read `LocalAccessibilityManager`/reduce-motion state directly — Batch 8.5's accessibility sweep is the caller that threads the live D-319 `Settings.Global.TRANSITION_ANIMATION_SCALE` value in at an actual Compose call site, mirroring how Wave 2 Agent 2.1 threaded `@Environment(\.accessibilityReduceMotion)` in on iOS. |
| `MKTypeRamp.swift` | 120 | `MkTypeRamp.kt` | `MkTypeRole` enum (10 roles) + `MkTypeStyle` (font/weight/lineHeightMultiplier/pointSize/`extraLineSpacing`) + `MkTypeRamp.style(for:)`. `Font.custom(_:size:relativeTo:)` → Compose `TextStyle(fontFamily = FontFamily(Font(R.font.<name>)), fontSize = <sp>, lineHeight = <sp>)`, with the ≥1.3 line-height-multiplier floor for tashkeel-stack headroom preserved at every ramp step exactly as tuned on iOS. `mkTypeStyle(_:)`/`mkDefaultFont(_:size:)` View extensions → Compose `Modifier`/`TextStyle` helper functions (`Modifier.mkTypeStyle(style)` applying `androidx.compose.ui.text.style.LineHeightStyle`, and a `LocalTextStyle`-providing composable for the "ambient default font for un-styled native-chrome children" case). |
| `MKTheme.swift` | 198 | `MkTheme.kt` | `MkElevationStyle`/`MkElevationStyles` (radius/yOffset/opacity per panel/floatingBar context) — direct port, consumed by Compose `Modifier.shadow(elevation, ...)`. `MkFontSet` (display/ui/accent?/mono PostScript-name strings) — direct port, now naming Android font-resource ids (resolved via `android/strings/font-manifest.json`) instead of PostScript names, since there is no process-wide font *registration* step to resolve a name against on Android (D-316: fonts are opened by handle, not looked up by name). `MkTheme` **interface** (not `MaterialTheme`, per D-317) with every semantic colour (`bg`/`bgAlt`/`surface`/`surfaceMuted`/`border`/`ink`/`inkMuted`/`inkFaint`/`primary`/`primaryPressed`/`onPrimary`/`secondary`/`canvasBackdrop`/`selectionStroke`/`warning`/`destructive`) as `androidx.compose.ui.graphics.Color`, plus `fonts`/`typeRamp`/`spacing`/`radius`/`elevation`/`motion` token-scale properties — one property per Swift protocol requirement, same names lower-camel-cased for Kotlin convention. `MkThemeID` enum (hibr/naqsh/raml/tayf/kufi) with the same Arabic `displayName`s and a `resolve(): MkTheme` dispatcher. SwiftUI's `EnvironmentValues.mkTheme` custom environment key → `val LocalMkTheme = staticCompositionLocalOf<MkTheme> { HibrTheme }`, injected once at the Compose app root (Batch 7.1) exactly where `MakhtootApp` injects `.environment(\.mkTheme, theme)` on iOS, re-resolved whenever the persisted `MkThemeID` preference changes. |
| `Themes/MKThemeColorHelpers.swift` | 43 | `themes/MkThemeColorHelpers.kt` | `Color(hex:)` → a Kotlin `fun Color(hex: Long): Color` packed-`0xRRGGBB` constructor (Compose `Color` already accepts a packed `Long`/`Int` ARGB constructor natively — this becomes a thin wrapper matching the Swift call-site convention, not new arithmetic). `Color(light:dark:)` (a `UIColor{traits in ...}` dynamic light/dark resolver) → **cannot** stay a plain `val`: Compose has no dynamic-`Color`-object equivalent to a UIKit dynamic-provider closure; every theme colour property that used this helper becomes a `@Composable` property/function reading `isSystemInDarkTheme()` at the call site instead (i.e. `MkTheme.bg` moves from a stored value to a `@Composable get()`), which is a structural difference from the Swift protocol's plain stored-property shape — call this out explicitly in the impl log since it changes `MkTheme`'s own interface shape (properties must be declared with `@Composable get()` or as functions, not implicitly evaluated `val`s). `Color.darkened(hex:by:)` (linear-darken-by-fraction helper for `primaryPressed`) — direct arithmetic port. |
| `Themes/HibrTheme.swift` | 108 | `themes/HibrTheme.kt` | Default theme ("حِبر" / Ink & Parchment). Every hex constant ported verbatim from `android/strings/theme-tokens.json`. The documented dark-mode primary/secondary swap (gold becomes the dominant interactive colour in dark mode, oxblood demotes to secondary — the exact inverse of light mode) ports unchanged, contained entirely inside this one theme object exactly as on iOS. |
| `Themes/KufiTheme.swift` | 74 | `themes/KufiTheme.kt` | "كوفي" / Bauhaus — the one theme with radius `0` everywhere (`MkRadiusScale(button=0, card=0, sheet=0, pill=0)`), collapsing every rounded surface to a hard edge with zero per-theme branching in the components (2.5's `MkChip`/`MkPanel`/etc. read `theme.radius.*` unconditionally). Direct port. |
| `Themes/NaqshTheme.swift` | 76 | `themes/NaqshTheme.kt` | Direct port, same structure as Hibr/Kufi. |
| `Themes/RamlTheme.swift` | 71 | `themes/RamlTheme.kt` | Direct port. |
| `Themes/TayfTheme.swift` | 79 | `themes/TayfTheme.kt` | Direct port. |

**Tasks.**
1. Read all 10 Swift files above in full; confirm the 878 LOC total via `wc -l`.
2. Read `android/strings/theme-tokens.json` and `android/strings/font-manifest.json`
   (Batch 0.4 outputs) and confirm all 5 theme objects and every bundled UI-chrome font are
   present before porting any theme file.
3. Port `MkSpacing`, `MkMotion`, `MkTypeRamp` (token scales, no theme-specific values).
4. Port `MkThemeColorHelpers` and the `MkTheme` interface shape, resolving the `@Composable
   get()` structural change documented above.
5. Port all 5 theme objects, verifying every hex constant against `theme-tokens.json`
   byte-for-byte (no re-derived/eyeballed values).
6. Wire `LocalMkTheme` as a `staticCompositionLocalOf`; do not wire it into the app root yet
   (that is Batch 7.1's job) — this agent only defines the `CompositionLocal` and its default.
7. Delete or overwrite the Batch 1 contract-stub body at each of this agent's owned paths —
   `MkTheme.kt`, `MkSpacing.kt`, `MkTypeRamp.kt`, `MkMotion.kt`, `themes/HibrTheme.kt`,
   `themes/KufiTheme.kt`, `themes/NaqshTheme.kt`, `themes/RamlTheme.kt`, `themes/TayfTheme.kt`,
   `themes/MkThemeColorHelpers.kt` — replacing every `throw MkNotYetPorted(...)` body with the
   real implementation (spine §3.3).
8. Port `TokenResolutionTests.swift` and `MKTypeRampDynamicTypeTests.swift` (line-height-multiplier
   floor, radius-scale-per-role, hex-constant-matches-handoff assertions) 1:1 as JUnit/Compose
   `@Composable`-test cases. Do not port `MKThemeTests`, `MKTypeRampTests`, or `MKSpacingTests` —
   none of the three exists in the repo (verified via `find MakhtootKit/Tests -name '...'`); an
   earlier packet draft invented those names.

**Acceptance.**
- `./gradlew :mk-designsystem:testDebugUnitTest` green
- `./gradlew :mk-designsystem:lintDebug` green
- Requirements covered: `R-1.3`, `R-2.3` (RTL-first Arabic-only UI), no dedicated numbered PRD
  requirement covers the design-system token layer itself on iOS (it is cross-cutting
  infrastructure traced to `D-126`, amended for Android by `D-317`)
- Tests ported: no `T-DS-*` id exists in `TEST_MATRIX.md` (the design system has no standalone
  iOS test-id prefix); the ported `TokenResolutionTests`/`MKTypeRampDynamicTypeTests` XCTest cases
  (`MakhtootKit/Tests/MKDesignSystemTests/`, 189 LOC of this agent's 248-LOC directory total) are
  carried over as this module's own test suite — `MKThemeTests`/`MKTypeRampTests`/`MKSpacingTests`
  do not exist and are not ported
- Fixtures consumed: `android/strings/theme-tokens.json`, `android/strings/font-manifest.json`
- All 5 `MkThemeID` cases resolve to a distinct `MkTheme` instance; Kufi's `radius` is `0` on
  every role
- Stub count for this module reaches 0

**Impl log.** `android/docs/impl-log/BATCH-2.4.md`

---

### Batch 2 · Agent 2.5 — `mk-designsystem` Compose components

**Depends on:** G1 · **Parallel-safe with:** every other Batch 2 agent

**Mission.** Port the 9 files under `MakhtootKit/Sources/MKDesignSystem/Components/**` (527 LOC)
as Compose `@Composable` functions: `MkBanner`, `MkBrandMark`, `MkChip`, `MkFloatingBar`,
`MkInspectorField`, `MkPanel`, `MkSectionHeader`, `MkSlider`, `MkToolbarButton`. RTL-first, 48dp
touch floor (D-319, not 44pt), font-scale aware. Ships a Compose preview gallery mirroring
`Makhtoot/App/DesignSystemGallery.swift`, plus Paparazzi screenshot tests. Also ports
`MKMotionAccessibilityTests.swift` (59 LOC) from `MakhtootKit/Tests/MKDesignSystemTests/` — the
reduce-motion-threading test that pairs with this agent's components, not with 2.4's tokens.
**Dependency note:** Paparazzi requires applying a Gradle plugin to
`mk-designsystem/build.gradle.kts`, which this agent is forbidden to edit (`§3.2` — Agent 1.1 owns
all `build.gradle.kts` files through Batch 8). Another agent adds Paparazzi + Robolectric + the
`android-junit5` plugin to Agent 1.1's version catalog and module build files as a prerequisite;
this agent depends on that landing first and does not attempt the build-file edit itself.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKDesignSystem/Components/**` (9 files) | Source of truth for this port |
| `MakhtootKit/Tests/MKDesignSystemTests/MKMotionAccessibilityTests.swift` (59 LOC) | The real test source this agent ports (verified via `find MakhtootKit/Tests -name '...'`) — `TokenResolutionTests.swift`/`MKTypeRampDynamicTypeTests.swift` in the same directory belong to Agent 2.4, not this agent |
| `Makhtoot/App/DesignSystemGallery.swift` (or equivalent preview scene) | The gallery layout this agent's Compose preview mirrors |
| `android/mk-designsystem/src/main/kotlin/.../MkTheme.kt`, `MkSpacing.kt`, `MkTypeRamp.kt`, `themes/**` (this agent's own Batch 2.4 sibling output — read, do not edit) | Every component in this file set reads `LocalMkTheme.current` |
| `ANDROID_SPINE.md` §2 (D-319) | 48dp touch-target floor (Android convention, replacing iOS's 44pt) |
| `MakhtootKit/Sources/MKFoundation/RTL/MKRTLUtilities.swift` | `MkInspectorField`'s Arabic-Indic digit conversion dependency (ported in Batch 2.1) |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/**`
- `android/mk-designsystem/src/debug/kotlin/net/binjamshid/makhtoot/mk/designsystem/DesignSystemGallery.kt` (Compose preview gallery, debug-variant only)
- `android/mk-designsystem/src/test/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/**` (Paparazzi screenshot tests)
- `android/mk-designsystem/src/test/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkMotionAccessibilityTest.kt`
- `android/docs/impl-log/BATCH-2.5.md`

**Never touch.** `android/mk-designsystem/src/main/kotlin/.../{MkTheme,MkSpacing,MkTypeRamp,MkMotion}.kt`,
`.../themes/**`, or `TokenResolutionTest.kt`/`MkTypeRampDynamicTypeTest.kt` (2.4's).
`mk-designsystem/build.gradle.kts` or any other `build.gradle.kts` (Agent 1.1's exclusively through
Batch 8, `§3.2` — a needed Paparazzi/Robolectric/`android-junit5` addition this agent finds missing
goes to `android/docs/CONTRACT_CHANGES.md`, never a direct edit). `:mk-foundation` (read/depend
only). Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKBanner.swift` | 58 | `components/MkBanner.kt` | `MkBannerSeverity` enum (`info`/`warning`/`destructive`) + `@Composable fun MkBanner(message: String, severity: MkBannerSeverity)`. `Image(systemName:)` SF Symbols → Compose `Icon` with Material Symbols vector assets (`info`/`warning`/`error` glyphs, bundled as `ImageVector` resources — no SF Symbols equivalent exists on Android, so the three icon glyphs are sourced as vector drawables at whatever visual weight matches the SF Symbols originals). |
| `MKBrandMark.swift` | 81 | `components/MkBrandMark.kt` | `MkBrandMarkStyle` enum (`wordmarkOnly`/`circle`/`diamond`) + `@Composable fun MkBrandMark(style: MkBrandMarkStyle, wordmarkRole: MkTypeRole = LargeTitle)`. The circle/diamond geometry (`Circle()`/rotated `RoundedRectangle`) ports to Compose `Canvas`/`Box` with `clip(CircleShape)`/`graphicsLayer(rotationZ = 45f)` — same fixed pixel dimensions (60dp circle, 34dp-rotated-45°≈48dp diamond) carried over verbatim from the design-handoff spec. |
| `MKChip.swift` | 38 | `components/MkChip.kt` | `@Composable fun MkChip(title: String, isSelected: Boolean, onClick: () -> Unit)`. `RoundedRectangle(cornerRadius: theme.radius.pill, style: theme.radius.style)` → Compose `RoundedCornerShape(theme.radius.pill)`, unconditionally (never a hardcoded `CircleShape`), which is exactly what makes Kufi's `pill = 0` collapse it to a rectangle with zero per-component branching — same contract as iOS. |
| `MKFloatingBar.swift` | 70 | `components/MkFloatingBar.kt` | `MKFloatingBarModifier` (`ViewModifier`) → a Kotlin `Modifier` extension function `fun Modifier.mkFloatingBar(padding: Dp? = null, usesMaterial: Boolean = false): Modifier`, applying `.background(...)` (opaque `theme.surface` or, when `usesMaterial`, a translucent blur-backed surface — Compose's `Modifier.blur()`/`androidx.compose.material3.MaterialTheme`'s scrim conventions substitute for `.ultraThinMaterial`, since `UIBlurEffect`'s exact vibrancy has no 1:1 Android API; use `Modifier.background(theme.surface.copy(alpha = 0.7f))` composited over a `Modifier.blur(16.dp)` background-content blur as the nearest equivalent, flagged for visual QA in Batch 8.5) + `.shadow(elevation)` matching `theme.elevation.floatingBar`. Same two-parameter shape (override padding for the two dense popovers; opt into the translucent variant only for the low-content zoom-controls bar) carried over. |
| `MKInspectorField.swift` | 78 | `components/MkInspectorField.kt` | `@Composable fun MkInspectorField(label: String, value: MutableState<Double>, displaysArabicIndicDigits: Boolean = false)`. `TextField`/`.keyboardType(.numbersAndPunctuation)`/`.focused($isFocused)`/`.onSubmit` → Compose `OutlinedTextField`/`BasicTextField` with `KeyboardOptions(keyboardType = KeyboardType.Number)` + `KeyboardActions(onDone = ...)` + a `FocusRequester`/`onFocusChanged` pair mirroring the commit-on-blur behaviour. The Arabic-Indic ↔ Latin digit normalization calls directly into `MkRtlUtilities.toArabicIndicDigits`/`.toLatinDigits` (Batch 2.1) — same dependency edge as the Swift file's `MKFoundation` import. |
| `MKPanel.swift` | 37 | `components/MkPanel.kt` | `@Composable fun MkPanel(title: String? = null, content: @Composable ColumnScope.() -> Unit)`. Direct structural port: `VStack`→`Column`, `.background(...) in RoundedRectangle`→`Modifier.background(theme.surface, RoundedCornerShape(theme.radius.card))`, `.shadow(...)`→`Modifier.shadow(theme.elevation.panel.radius, ...)`. |
| `MKSectionHeader.swift` | 32 | `components/MkSectionHeader.kt` | `@Composable fun MkSectionHeader(title: String, actionTitle: String? = null, onAction: (() -> Unit)? = null)`. `HStack`+`Spacer()` RTL-free-ordering → Compose `Row` under the app-wide `LocalLayoutDirection.Rtl` (D-318), same "no manual reordering" property. |
| `MKSlider.swift` | 32 | `components/MkSlider.kt` | `@Composable fun MkSlider(label: String? = null, value: MutableState<Double>, range: ClosedFloatingPointRange<Double> = 0.0..1.0)`. SwiftUI `Slider` (RTL-mirrored for free under `\.layoutDirection`) → Compose `Slider` (RTL-mirrored for free under `LocalLayoutDirection.Rtl`, same "wrapper adds theming only, does not re-implement track layout" scope). |
| `MKToolbarButton.swift` | 101 | `components/MkToolbarButton.kt` | `@Composable fun MkToolbarButton(icon: ImageVector, contentDescription: String, isProminent: Boolean = false, onClick: () -> Unit)`. SF Symbol `Image(systemName:)` → Compose `Icon(imageVector, ...)` sourced from a bundled Material Symbols set matching each iOS glyph's silhouette (per-icon mapping table recorded in the impl log, not invented ad hoc per call site). **Hit-target floor is 44dp→48dp** per D-319 (Android convention replacing the iOS 44pt HIG minimum) — `Modifier.size(48.dp).clip(...).clickable(...)`, up from the Swift file's `hitTargetSide: CGFloat = 44`. `@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 17` (Dynamic-Type-aware icon scaling) → Compose `with(LocalDensity.current) { (17.sp.toPx() / fontScale-aware-conversion) }`, or more idiomatically `17.sp` sized via `Modifier.size(with(LocalDensity.current) { 17.sp.toDp() })` so the icon scales with the system font-scale setting exactly as `@ScaledMetric` does — verify against a 200% font-scale emulator profile in Batch 8.5, not assumed correct from the type signature alone. `accessibilityLabel` (`LocalizedStringResource`, catalog-extractable per UX-7) → `contentDescription: String`, sourced from `android/strings/strings.xml` (Batch 0.4) string resources, not an inline literal, for the same TalkBack-catalog-extractability reason. |

**Tasks.**
1. Read all 9 Swift files above in full; confirm the 527 LOC total via `wc -l`.
2. Port each component per the table, one Kotlin file per Swift file under
   `designsystem/components/`.
3. Build the icon-glyph mapping table (SF Symbol name → Material Symbols resource) used by
   `MkBanner`/`MkToolbarButton`; record it in the impl log so later batches (7.x app-shell UI)
   reuse the same table instead of re-deriving mappings ad hoc.
4. Build `DesignSystemGallery.kt`, a `@Preview`-annotated Compose screen exercising every
   component across all 5 themes and both light/dark, mirroring the iOS gallery scene's
   coverage.
5. Add Paparazzi screenshot tests (chosen over Compose's official screenshot-testing library
   because Paparazzi runs fully headless on the JVM via Robolectric with no emulator/device
   required, which fits this batch's automated-CI gate; Compose's own screenshot tool needs
   Android Studio or a connected device/emulator per test run) — one golden per component ×
   theme × light/dark combination that is cheap to render (skip the full 5×2 matrix only where a
   component has no theme-color-dependent rendering difference, and say so in the impl log). If
   the Paparazzi/Robolectric/`android-junit5` build-file prerequisite has not landed yet when this
   agent runs, write the test sources against the expected API and note the blocker in the impl
   log rather than editing any `build.gradle.kts` to unblock itself.
6. Delete or overwrite the Batch 1 contract-stub body at each of this agent's owned component
   paths — `components/MkBanner.kt`, `components/MkBrandMark.kt`, `components/MkChip.kt`,
   `components/MkFloatingBar.kt`, `components/MkInspectorField.kt`, `components/MkPanel.kt`,
   `components/MkSectionHeader.kt`, `components/MkSlider.kt`, `components/MkToolbarButton.kt` —
   replacing every `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
7. Port `MKMotionAccessibilityTests.swift` (reduce-motion threading through this file set's
   `Modifier`/animation call sites) 1:1 as a Compose UI test. `MKDesignSystemComponentTests` does
   not exist in the repo as a named XCTest target — this packet's RTL-layout/radius-per-theme/
   hit-target assertions are ported from whichever real per-component test coverage the Swift
   source carries inline (Xcode previews/snapshot infra, not a separate XCTest file), verify the
   actual source location via `grep -rl` before assuming a file name.

**Acceptance.**
- `./gradlew :mk-designsystem:testDebugUnitTest` green (includes Paparazzi screenshot suite)
- `./gradlew :mk-designsystem:lintDebug` green
- Requirements covered: `R-1.3`, `R-2.3` (RTL-first), no dedicated numbered PRD requirement (see
  2.4's note — cross-cutting infrastructure, traced to `D-126`/`D-317`/`D-319`)
- Tests ported: no `T-DS-*` id exists in `TEST_MATRIX.md`; the ported `MKMotionAccessibilityTests`
  XCTest case is carried over as this module's own Compose UI test suite, plus the new Paparazzi
  screenshot suite this agent adds and RTL/radius/hit-target assertions verified against the real
  Swift coverage (not the non-existent `MKDesignSystemComponentTests` name)
- Fixtures consumed: `android/strings/strings.xml` (accessibility-label string resources)
- Every touch target in this file set measures ≥48dp
- No edit to any `build.gradle.kts` appears in this agent's diff
- Stub count for this module reaches 0

**Impl log.** `android/docs/impl-log/BATCH-2.5.md`

---

## Appendix — file-ownership matrix (collision proof)

| Path (prefix) | 2.1 | 2.2 | 2.3 | 2.4 | 2.5 |
|---|---|---|---|---|---|
| `android/mk-foundation/src/main/kotlin/.../foundation/**` | ✅ | | | | |
| `android/mk-foundation/src/test/kotlin/.../foundation/**` | ✅ | | | | |
| `android/mk-model/src/main/kotlin/.../model/**` | | ✅ | | | |
| `android/mk-model/src/test/kotlin/.../model/**` | | ✅ | | | |
| `android/mk-color/src/main/kotlin/.../color/**` | | | ✅ | | |
| `android/mk-color/src/test/kotlin/.../color/**` | | | ✅ | | |
| `android/mk-color/src/main/assets/ICC/**` | | | ✅ | | |
| `android/mk-designsystem/src/main/kotlin/.../{MkTheme,MkSpacing,MkTypeRamp,MkMotion}.kt` | | | | ✅ | |
| `android/mk-designsystem/src/main/kotlin/.../themes/**` | | | | ✅ | |
| `android/mk-designsystem/src/test/kotlin/.../designsystem/{TokenResolutionTest,MkTypeRampDynamicTypeTest}.kt` | | | | ✅ | |
| `android/mk-designsystem/src/main/kotlin/.../components/**` | | | | | ✅ |
| `android/mk-designsystem/src/debug/kotlin/.../DesignSystemGallery.kt` | | | | | ✅ |
| `android/mk-designsystem/src/test/kotlin/.../components/**` | | | | | ✅ |
| `android/mk-designsystem/src/test/kotlin/.../designsystem/MkMotionAccessibilityTest.kt` | | | | | ✅ |
| `android/docs/impl-log/BATCH-2.1.md` | ✅ | | | | |
| `android/docs/impl-log/BATCH-2.2.md` | | ✅ | | | |
| `android/docs/impl-log/BATCH-2.3.md` | | | ✅ | | |
| `android/docs/impl-log/BATCH-2.4.md` | | | | ✅ | |
| `android/docs/impl-log/BATCH-2.5.md` | | | | | ✅ |

No file has two owners. `:mk-designsystem` is split at the package level between 2.4 (tokens and
themes: `MkTheme.kt`, `MkSpacing.kt`, `MkTypeRamp.kt`, `MkMotion.kt`, `themes/**`, plus the two
real `MakhtootKit/Tests/MKDesignSystemTests/` files that pair with tokens) and 2.5 (`components/**`
plus the debug-only preview gallery, plus the one `MakhtootKit/Tests/MKDesignSystemTests/` file
that pairs with components) — the two never write the same path; 2.5 reads 2.4's output
(`LocalMkTheme`) but does not edit it, matching spine ground rule 5 (contract-first: a needed
change to 2.4's surface from 2.5 goes through `android/docs/CONTRACT_CHANGES.md`, not a direct
edit). The `MakhtootKit/Tests/MKDesignSystemTests/` directory's three real files (248 LOC total,
verified via `find`/`wc -l`) are split 2/1 between 2.4 and 2.5 above; the three invented names
(`MKThemeTests`, `MKTypeRampTests`, `MKSpacingTests`) from an earlier packet draft are struck.
Confirms spine §4 ground rule 1 (exclusive file ownership) and ground rule 9 (no agent in this
batch touches anything outside `android/`).

> **Writer note:** the byte-identical-JSON acceptance criterion for `:mk-model` (Agent 2.2) is
> the single highest-technical-risk item in this batch — kotlinx-serialization's default JSON
> key ordering and enum-payload wrapping do not match Swift's synthesized `Codable` output
> out of the box, and Agent 2.2's port map calls out the two places (custom `KSerializer`s,
> alphabetical key ordering) where this must be proven empirically against the 4 fixtures rather
> than assumed from the type declarations alone. If G2 fails specifically on this criterion, the
> fix is almost certainly in the serializer/ordering layer, not in the data-class field shapes,
> which are a straightforward 1:1 port.
>
> **Correction-pass note (this pass, 2026-07-30):** every path in this file was re-verified
> against `ANDROID_SPINE.md` §3.3's frozen naming rule and against the repo directly — no
> stragglers found (`rtl/MkRtlUtilities.kt`, `MkCmykConverter.kt`, `MkIccProfileStore.kt` were
> already correct). Five substantive fixes landed: (1) Agent 2.1 now ports
> `Stubs/MKFontProviding.swift` (139 LOC), closing the coverage hole that left `mk-foundation`
> under-counted at 14 files instead of 15; (2) every agent's Tasks now names the Batch 1 stub
> paths it supersedes and instructs deleting/overwriting them, per spine §3.3, so no superseded
> stub can be silently orphaned and hold the G8 stub count non-zero; (3) Agent 2.1 no longer
> claims to create `MkNotYetPorted.kt` — it already exists from Batch 1 · Agent 1.3, and
> recreating it here would have been a same-file double-write across batches; (4) Agents 2.4/2.5
> no longer port the invented `MKThemeTests`/`MKTypeRampTests`/`MKSpacingTests`/
> `MKDesignSystemComponentTests` names — verified absent via `find`/`grep` — and instead port the
> three real files under `MakhtootKit/Tests/MKDesignSystemTests/` (248 LOC), split 2.4:
> `TokenResolutionTests.swift`/`MKTypeRampDynamicTypeTests.swift`, 2.5:
> `MKMotionAccessibilityTests.swift`; (5) Agent 2.5 now states explicitly that Paparazzi's
> Gradle-plugin dependency is landed by another agent into Agent 1.1's build files, not by 2.5
> itself, which is barred from touching any `build.gradle.kts` (§3.2).
