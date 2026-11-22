# BATCH-1.4-repair impl log — fixing the four modules Agent 1.4 left broken

Repair agent superseding Agent 1.4 on exactly four targets:
`mk-persistence`, `mk-assets`, `mk-store`, `mk-designsystem`. Agent 1.3's
seven modules and Agent 1.4's other six targets (`mk-analytics`, `mk-sync`,
`mk-export`, `mk-fonts`, `mk-canvas`, `:app`) were out of scope and were not
edited.

## Keyword convention chosen

Kotlin hard keywords used as parameter/property names (only `package`
appeared, in `MkAssetStore`, `MkAutosaveController`, `MkCrashRecovery`) are
fixed by **backticking** (`` `package` ``), not renaming. This was already
the in-progress convention on disk when this agent started (some files had
it, some didn't); backticking was picked over renaming because it keeps the
Kotlin parameter name textually identical to the Swift source (`package:`),
which is more traceable back to `ANDROID_TASK_PACKETS`/`API_SURFACE.md` than
a renamed alternative (e.g. `documentPackage:`) would be. Applied
consistently across all four modules — no other hard keyword collisions
were found in this scope.

## Two root causes confirmed, and how they were actually fixed

1. **Kotlin hard keywords as identifiers** — as above, isolated to
   `` `package` `` in three `:mk-persistence` files.
2. **Missing/wrong cross-module imports** — the larger bulk of the work.
   Concrete examples fixed:
   - `mk-store/.../trial/MkTrialManager.kt` imported `MkTrialRecord` from
     `:mk-persistence` (an edge that does not exist in spine §3.2 — and was
     also the *wrong* type: `:mk-store`'s own `MkTrialRecord.kt` in the same
     package already defines the Codable-struct-derived type
     `MKTrialManager` actually uses; `:mk-persistence`'s `MkTrialRecord` in
     `MkMetadataModels.kt` is a genuinely different, SwiftData-derived
     "display-cache mirror" type of the same name in the Swift source).
     Fixed by deleting the wrong import (same-package resolution handles
     the rest).
   - `mk-assets`'s browser/generator/instantiation files were missing
     `net.binjamshid.makhtoot.mk.foundation.MkNodeId` and
     `net.binjamshid.makhtoot.mk.foundation.entitlement.MkStubEntitlementResolver`
     imports (both real, legal edges per spine §3.2 — `:mk-assets` depends
     on `:mk-foundation`).

## Other bug classes fixed (beyond the two named root causes)

- **Swift `AsyncStream<T>` has no Kotlin type** — mapped to
  `kotlinx.coroutines.flow.Flow<T>` throughout (`:mk-store`'s
  `MkEntitlementResolver.states()`, `MkUbiquitousStore.changeNotifications()`;
  `:mk-persistence`'s `MkMetadataStore.changes`). `kotlinx-coroutines-core`
  is already an implicit dependency of every library module via
  `MkAndroidLibraryConventionPlugin`, so no Gradle edit was needed.
- **Swift `() async -> T` closure-type parameters** — mapped to Kotlin
  `suspend () -> T` (`:mk-persistence`'s
  `MkAutosaveController.scheduleDebouncedSave`).
- **Missing no-arg defaults for value types used as `= TypeName()` call
  sites** — `MkTestEntitlementStub`, `MkFakeClock`, `MkUbiquitousStore`,
  `MkExportTempDirectory`, `MkPackageImportLimits`, `MkMotionTokens` all had
  at least one non-defaulted constructor parameter blocking a no-arg
  companion-object singleton or default-parameter call elsewhere. Fixed by
  adding a sensible default per parameter, cross-checked against the Swift
  source's own default where one existed (e.g. `MkPackageImportLimits`'
  `maxTotalBytes`/`maxFileCount`/`allowedTopLevelMembers` defaults now match
  `PackageImportValidator.swift`'s `200 * 1024 * 1024` / `5_000` /
  `["manifest.json", "scene.json", "thumbnail.png", "journal.mkj", "assets",
  "backups"]` exactly).
- **Constructor-property/function name collisions** — `MkFakeClock`'s
  `override val now: Instant` tried to override the interface's `fun now():
  Instant` with a property of the same name (illegal — a property and a
  function can't share a name against the same override target); renamed
  the constructor parameter to a non-colliding local name and kept `now()`
  as the throwing override. Same pattern in `MkTestEntitlementStub` (a
  constructor-promoted `val state` conflicting with a separately-declared
  `override val state` body member) — resolved by keeping one `override var
  state` with explicit `get`/`set` (Swift's original `TestEntitlementStub`
  has a settable `state`, so `var` over the interface's `val` is a faithful
  widening, not an invented capability).
- **`interface MkCommand`'s own members incorrectly marked `override`** — a
  mechanical `sed` pass adding `override` to every `MkCommand`-conforming
  class's `id`/`name`/`coalescingKey`/`apply`/`inverse` member (114 sites
  across `mk-persistence/undo/MkCommand.kt` and `MkCommands.kt`, all sharing
  the exact same "hides member of supertype and needs an `override`
  modifier" shape) initially over-matched the interface's *own* declarations
  too (which must stay bare) — caught by the next compile pass ("overrides
  nothing") and corrected.
- **No Kotlin/Compose equivalent for several SwiftUI/CoreGraphics/
  StoreKit/SwiftData types** — each got a small, documented placeholder
  class, following the existing `mk-render/.../MkRenderPlatformTypes.kt`
  convention (`internal constructor()`, doc comment naming the eventual
  Android/Compose real type):
  - `:mk-assets` has no dependency edge onto `:mk-render`/`:mk-color`
    (spine §3.2), so `CGPath`/`CGImage`/`CGColor` got their own
    module-local `MkPlatformPath`/`MkPlatformImage`/`MkPlatformColor` in a
    new file `mk-assets/.../MkAssetPlatformTypes.kt` (not a Swift source
    1:1 port — flagged as new supporting infrastructure, same category as
    `mk-render`'s file).
  - `:mk-designsystem`'s `EnvironmentValues` (SwiftUI, no Compose
    structural equivalent — Compose uses `CompositionLocal`) got
    `MkEnvironmentValues` in `MkTheme.kt`; `RoundedCornerStyle` (a real,
    finite two-case system enum, not an opaque handle) got a proper
    `enum class MkRoundedCornerStyle { CIRCULAR, CONTINUOUS }` instead of a
    placeholder class, mirroring `mk-render`'s own
    `MkImageInterpolationQuality` precedent. `Font`/`Font.Weight` mapped to
    the real, already-available Compose types
    `androidx.compose.ui.text.font.FontFamily`/`FontWeight` (Compose UI is
    already a dependency via `mk.android.library.compose`). `Color` mapped
    to the real `androidx.compose.ui.graphics.Color` throughout (also
    already available). The `View`-receiver SwiftUI-modifier-convenience
    functions (`mkTypeStyle`, `mkDefaultFont`, `mkFloatingBar`) had their
    receiver corrected from a stray unresolved `MkView` to
    `androidx.compose.ui.Modifier`, per Agent 1.4's own already-documented
    convention for this exact pattern.
  - `:mk-store`'s `Product` (StoreKit) got `MkPlatformProductHandle`; this
    one **is** a missing-dependency case, not a framework-type case (Play
    Billing's `ProductDetails` is a real third-party artifact, not part of
    the Android SDK) — filed as a `CONTRACT_CHANGES.md` request rather than
    silently added to `build.gradle.kts`.
  - `:mk-persistence`'s `PersistentModel`/`ModelContainer` (SwiftData) got
    `List<kotlin.reflect.KClass<*>>` (a dependency-free stand-in, no
    placeholder class needed) and `MkMetadataContainer` respectively —
    also a missing-dependency case (Room), also filed as a
    `CONTRACT_CHANGES.md` request.

## Contract changes filed

Two `pending` rows appended to `android/docs/CONTRACT_CHANGES.md`:
`:mk-store` needs Play Billing (`com.android.billingclient:billing-ktx`,
already in the version catalog as `play-billing-ktx`, just unwired) for the
real `Product`/`ProductDetails` type; `:mk-persistence` needs Room for the
real SwiftData→Room migration (D-308). Both are Batch 6/3 concerns per the
spine's batch register, not Batch 1 stub-compiling blockers — the
placeholders above keep the stub tree compiling in the meantime.

## Compile results actually observed

Run from `android/`, in this order (smallest first, as instructed), each a
real `./gradlew :<module>:compileDebugKotlin --offline` invocation:

| Module | Result |
|---|---|
| `:mk-store` | `BUILD SUCCESSFUL` |
| `:mk-assets` | `BUILD SUCCESSFUL` |
| `:mk-designsystem` | `BUILD SUCCESSFUL` |
| `:mk-persistence` | `BUILD SUCCESSFUL` |

Final joint verification, all four in one invocation
(`./gradlew :mk-store:compileDebugKotlin :mk-assets:compileDebugKotlin
:mk-designsystem:compileDebugKotlin :mk-persistence:compileDebugKotlin
--offline`): **`BUILD SUCCESSFUL`**.

**Environment note, reported honestly.** Repeated `Read`/`Edit` cycles on
files in this scope during this session surfaced "file modified since read"
conflicts, and several already-fixed files were found reverted to an
earlier (sometimes differently broken) state on re-check, independently of this
repair. Every fix in this log was re-applied and re-verified by an actual compiler run after the last
observed reversion; the compile results table above reflects the final,
stable state at the time this log was written, not an assumption. A whole-
tree `./gradlew assembleDebug --continue --offline` was also run: it still
fails, but the only failures observed are `:mk-analytics`, `:mk-sync`, and
`:mk-fonts` — three modules **outside this agent's four-module scope**
(Agent 1.4's other targets, not owned by this repair task). Their errors are
the same bug categories as this log's (`AsyncStream`/`Date`/`Duration`/
`CKRecord`/`Bundle`/enum-body syntax errors), so they likely need the same
kind of repair as the four modules covered here — flagged here for
the next work item that covers it.

## Stub count

`bash Scripts/android/stub-count.sh` at the start of this session (before
any edit): **2023**. (The task briefing cited 2026; the discrepancy predates
this agent's involvement and was not investigated further, since the
constraint is "must not fall as a side effect of this repair," not "must
equal exactly 2026.") At the end of this session: **2025** — net +2, driven
by adding previously missing throwing members
(e.g. `MkThemeColorHelpers.kt`'s `darkened(hex:by:)`, which the original
mechanical generator had silently dropped for `:mk-designsystem`) while
never deleting an existing `MkNotYetPorted` throw. No symbol was removed to
make an error disappear anywhere in this pass.

## Blockers

None preventing hand-off for this agent's four modules — all four compile
cleanly, verified live, as of this log. The one open item is the
`:mk-analytics`/`:mk-sync`/`:mk-fonts` breakage noted above, which is
outside the scope of this repair.
