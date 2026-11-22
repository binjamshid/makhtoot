// android/mk-export/build.gradle.kts
//
// Work item 1.1 — Gradle *configuration* only (ANDROID_SPINE.md §3.2).
// Ports MKExport 1:1 (D-301). Dependency edges below are copied
// verbatim from spine §3.2, regenerated from MakhtootKit/Package.swift — do
// not add an edge not listed there; a needed edge not in §3.2 is an
// android/docs/CONTRACT_CHANGES.md entry, not a direct edit (spine ground
// rule 5).
//
// This agent never adds a src/ file — that is Agent 1.3/1.4's ownership
// (ANDROID_TASK_PACKETS/BATCH-1.md Appendix). The exception is
// src/main/res/values/strings.xml (spine §11 founder amendment — Arabic UI text externalized into Android string resources rather than inline; installed from android/strings/modules/mk-export-strings.xml).

plugins {
    alias(libs.plugins.kotlin.serialization)
    id("mk.android.library")
}

android {
    namespace = "net.binjamshid.makhtoot.mk.export"
    buildFeatures {
        androidResources = true
    }
}

dependencies {
    implementation(project(":mk-foundation"))
    implementation(project(":mk-model"))
    implementation(project(":mk-render"))
    implementation(project(":mk-color"))
    implementation(project(":mk-fonts"))
    implementation(project(":mk-textengine"))
    implementation(project(":mk-pathtext"))
    implementation(project(":mk-native"))
    implementation(libs.kotlinx.serialization.json)
}
