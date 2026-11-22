// android/mk-pathtext/build.gradle.kts
//
// Work item 1.1 — Gradle *configuration* only (ANDROID_SPINE.md §3.2).
// Ports MKPathtext 1:1 (D-301). Dependency edges below are copied
// verbatim from spine §3.2, regenerated from MakhtootKit/Package.swift — do
// not add an edge not listed there; a needed edge not in §3.2 is an
// android/docs/CONTRACT_CHANGES.md entry, not a direct edit (spine ground
// rule 5).
//
// This agent never adds a src/ file — that is Agent 1.3/1.4's ownership
// (ANDROID_TASK_PACKETS/BATCH-1.md Appendix). The exception is
// src/main/res/values/strings.xml does not apply to this module — it has no owning strings file in the Batch 0 · 0.6b module string split.

plugins {
    alias(libs.plugins.kotlin.serialization)
    id("mk.android.library")
}

android {
    namespace = "net.binjamshid.makhtoot.mk.pathtext"
}

dependencies {
    implementation(project(":mk-foundation"))
    implementation(project(":mk-model"))
    implementation(project(":mk-textengine"))
    implementation(project(":mk-persistence"))
    implementation(project(":mk-arrange"))
    implementation(libs.kotlinx.serialization.json)
}
