// android/mk-persistence/build.gradle.kts
//
// Work item 1.1 — Gradle *configuration* only (ANDROID_SPINE.md §3.2).
// Ports MKPersistence 1:1 (D-301). Dependency edges below are copied
// verbatim from spine §3.2, regenerated from MakhtootKit/Package.swift — do
// not add an edge not listed there; a needed edge not in §3.2 is an
// android/docs/CONTRACT_CHANGES.md entry, not a direct edit (spine ground
// rule 5).
//
// This agent never adds a src/ file — that is Agent 1.3/1.4's ownership
// (ANDROID_TASK_PACKETS/BATCH-1.md Appendix). The exception is
// src/main/res/values/strings.xml (spine §11 founder amendment — Arabic UI text externalized into Android string resources rather than inline; installed from android/strings/modules/mk-persistence-strings.xml).
//
// CONTRACT_CHANGES.md 2026-07-31 (Batch 1.4 repair):
// added Room (androidx.room:room-runtime/room-ktx + the KSP compiler). D-308:
// Room replaces SwiftData for metadata ONLY, never the scene graph — that
// boundary is a source-level concern for whoever implements
// MkMetadataStore/MkMetadataModels (Batch 3), not something this dependency
// wiring enforces by itself, but it is the reason Room lands only here and
// not, say, in mk-model. MKMetadataStore.swift's makeContainer(url:) ->
// ModelContainer and MKMetadataSchema.models reference SwiftData types with
// no Kotlin equivalent; the module-local placeholders
// (MkMetadataContainer, List<KClass<*>>) in the 1.4-repair agent's contract
// stub stay as-is. No new module edge — external library dependency only,
// spine §3.2's module graph is unchanged.

plugins {
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    id("mk.android.library")
}

android {
    namespace = "net.binjamshid.makhtoot.mk.persistence"
    buildFeatures {
        androidResources = true
    }
}

dependencies {
    implementation(project(":mk-model"))
    implementation(project(":mk-foundation"))
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
}
