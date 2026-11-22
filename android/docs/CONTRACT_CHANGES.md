# CONTRACT_CHANGES.md

Append-only log of cross-module API/Gradle-configuration change requests
(`ANDROID_SPINE.md` §4 ground rule 5, §11; owned by Batch 1 · Agent 1.1).

No agent edits another module's public API, or any `build.gradle.kts`
(Agent 1.1 is the sole owner of every Gradle configuration file through
Batch 8, spine §3.2/§17), directly. A needed change is appended below as a
new row and applied by the batch gate (`Scripts/android/gate.sh N`) in its
"apply pending contract changes" step, run immediately before that gate's
own checks re-run — never applied by the requesting agent mid-batch.

`Scripts/android/gate.sh N` **fails** the run if any row below still has
status `pending` after that step.

## Entry format

`date | requesting agent | target module | requested change | rationale | status (pending/applied/rejected)`

## Log

| date | requesting agent | target module | requested change | rationale | status |
|---|---|---|---|---|---|
| 2026-07-31 | Batch 1.4-repair | `:mk-store` | Add `com.android.billingclient:billing-ktx` (already in `gradle/libs.versions.toml` as `play-billing-ktx`, just not wired into this module's `build.gradle.kts`) | `MKProductCatalog.swift`'s `product(for:) -> Product?` references StoreKit's `Product` type, which has no Kotlin equivalent; Android's counterpart (D-311) is Play Billing's `ProductDetails`. Fixed for now with a module-local placeholder `MkPlatformProductHandle` (`mk-store/.../MkProductCatalog.kt`) so the contract stub compiles without the dependency; real typing needs the Billing Client on the classpath. Batch 6 · Agent 6.1 owns the real `:mk-store` implementation. | applied |
| 2026-07-31 | Batch 1.4-repair | `:mk-persistence` | Add a Room dependency (`androidx.room:room-runtime`/`room-ktx`, not yet in this module's `build.gradle.kts`) | `MKMetadataStore.swift`'s `makeContainer(url:) -> ModelContainer` and `MKMetadataSchema.models: [any PersistentModel.Type]` reference SwiftData types with no Kotlin equivalent; D-308 specifies Room replaces SwiftData for metadata only. Fixed for now with module-local placeholders (`MkMetadataContainer` in `mk-persistence/.../metadata/MkMetadataStore.kt`, `List<kotlin.reflect.KClass<*>>` in `MkMetadataModels.kt`) so the contract stub compiles without the dependency; real typing needs Room on the classpath. Batch 3 (persistence agents, spine §5.1) owns the real `:mk-persistence` implementation. | applied |
| 2026-07-31 | Batch 1.4-repair2 | `:mk-fonts` | Add `okhttp3:okhttp` (already in `gradle/libs.versions.toml` as `okhttp`, D-304's named carve-out for the Android `URLSession` substitute, just not wired into this module's `build.gradle.kts`) | `MKCatalogManifestFetchService.swift`'s `session: URLSession` and `MKFontDownloader.swift`'s `session: URLSession` reference Foundation's `URLSession`, which has no Kotlin equivalent. Fixed for now with a module-local placeholder `MkPlatformHttpSession` (`mk-fonts/.../MkFontsPlatformTypes.kt`) so the contract stub compiles without the dependency; real typing needs OkHttp on the classpath. Batch 3 (`:mk-fonts` implementation, per spine batch register) owns the real download/fetch wiring. | pending |
