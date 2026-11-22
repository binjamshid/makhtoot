// android/mk-store/build.gradle.kts
//
// Work item 1.1 — Gradle *configuration* only (ANDROID_SPINE.md §3.2).
// Ports MKStore 1:1 (D-301). Dependency edges below are copied
// verbatim from spine §3.2, regenerated from MakhtootKit/Package.swift — do
// not add an edge not listed there; a needed edge not in §3.2 is an
// android/docs/CONTRACT_CHANGES.md entry, not a direct edit (spine ground
// rule 5).
//
// This agent never adds a src/ file — that is Agent 1.3/1.4's ownership
// (ANDROID_TASK_PACKETS/BATCH-1.md Appendix). The exception is
// src/main/res/values/strings.xml (spine §11 founder amendment — Arabic UI text externalized into Android string resources rather than inline; installed from android/strings/modules/mk-store-strings.xml).
//
// CONTRACT_CHANGES.md 2026-07-31 (Batch 1.4 repair):
// added com.android.billingclient:billing-ktx (D-311). MKProductCatalog.swift's
// product(for:) -> Product? references StoreKit's Product type; Android's
// counterpart is Play Billing's ProductDetails, which needs the Billing Client
// on the classpath to type against — the module-local MkPlatformProductHandle
// placeholder in the 1.4-repair agent's contract stub stays as-is (Batch 6 ·
// Agent 6.1 owns the real implementation); this change only makes the real
// Play Billing types resolvable from mk-store's classpath. No new module edge
// — this is an external library dependency, spine §3.2's module graph is
// unchanged.

plugins {
    alias(libs.plugins.kotlin.serialization)
    id("mk.android.library")
}

android {
    namespace = "net.binjamshid.makhtoot.mk.store"
    buildFeatures {
        androidResources = true
    }
}

dependencies {
    implementation(project(":mk-foundation"))
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.play.billing.ktx)
}
