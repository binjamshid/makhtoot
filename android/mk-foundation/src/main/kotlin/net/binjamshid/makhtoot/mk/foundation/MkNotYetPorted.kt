package net.binjamshid.makhtoot.mk.foundation

/**
 * The shared stub-exception type every Batch 1 contract-stub body throws
 * (`ANDROID_SPINE.md` §4 ground rule 4, `ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3/1.4).
 *
 * Every function/computed-property/method body ported in Batch 1 is exactly
 * `throw MkNotYetPorted("<Target>.<Symbol>")` until a Batch 2+ agent replaces the
 * stub with a real implementation at the same file path (`ANDROID_SPINE.md` §3.3).
 * `Scripts/android/stub-count.sh` (Agent 1.1) greps for this type's name, and
 * `Scripts/android/check-no-stubs.sh` allowlists it (`ANDROID_SPINE.md` §4 ground
 * rule 3) as legitimate, permanent infrastructure — not stub debt itself.
 *
 * **Naming/base-class note, corrected against the real compiler (recorded,
 * not silent, per `ANDROID_SPINE.md` §9):** Kotlin's `kotlin.NotImplementedError`
 * is declared `final` and cannot be subclassed (`./gradlew :mk-foundation:compileDebugKotlin`
 * confirmed this: "This type is final, so it cannot be extended."), unlike
 * what an earlier description of this type assumed. This extends
 * `kotlin.Error` instead — still an `Error` (matching `NotImplementedError`'s
 * own supertype and the same "this is a hard, unrecovered gap" severity),
 * still carries the exact `"Not yet ported: <symbol>"` message
 * `Scripts/android/stub-count.sh`/`check-no-stubs.sh` grep for by class
 * name, not by supertype.
 */
class MkNotYetPorted(symbol: String) : Error("Not yet ported: $symbol")
