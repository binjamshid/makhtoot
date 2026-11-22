// android/app/build.gradle.kts
//
// Work item 1.1 — Gradle *configuration* only (ANDROID_SPINE.md §3.2:
// ":app" depends on everything above). Per spine §17, this file is a
// declared cross-batch conflict: Agent 1.1 owns it exclusively through
// Batch 8; Agent 9.2 takes it over in Batch 9 for signing-config/AAB/R8
// additions only (not a violation of this agent's exclusivity — the stated
// exception window).
//
// D-321 (mirrors D-225): the `referral` module and its Arabic strings are
// compile-time excluded from Release. The `referral` source set is present
// only in the `debug` build type; `REFERRAL_ENABLED` is a BuildConfig field
// so Batch 6's referral code can gate on it, and
// Scripts/android/referral-release-grep.sh checks
// the exclusion holds against the built Release AAB, not just the source
// tree, mirroring Scripts/referral-release-grep.sh's iOS rationale exactly.

plugins {
    id("mk.android.application")
}

android {
    namespace = "net.binjamshid.makhtoot"

    defaultConfig {
        applicationId = "net.binjamshid.makhtoot"
        versionCode = 1
        versionName = "1.0"

        // D-321: off by default; the debug build type flips it on below.
        // Release never compiles the `referral` source set in at all — the
        // BuildConfig flag alone is belt-and-suspenders, not the mechanism.
        buildConfigField("boolean", "REFERRAL_ENABLED", "false")
    }

    sourceSets {
        getByName("debug") {
            // D-321: referral Kotlin source + Arabic strings live only
            // here. Agent 1.4 (this batch) does not populate it yet;
            // Batch 6 · Agent 6.2 is the implementing agent. The directory
            // is declared now so the source-set wiring is a Batch 1
            // (infrastructure) concern, not something Batch 6 has to touch
            // this file for.
            kotlin.srcDir("src/referral/kotlin")
            res.srcDir("src/referral/res")
        }
    }

    buildTypes {
        getByName("debug") {
            buildConfigField("boolean", "REFERRAL_ENABLED", "true")
        }
    }
}

dependencies {
    implementation(project(":mk-native"))
    implementation(project(":mk-foundation"))
    implementation(project(":mk-model"))
    implementation(project(":mk-textengine"))
    implementation(project(":mk-arrange"))
    implementation(project(":mk-pathtext"))
    implementation(project(":mk-canvas"))
    implementation(project(":mk-render"))
    implementation(project(":mk-color"))
    implementation(project(":mk-export"))
    implementation(project(":mk-fonts"))
    implementation(project(":mk-persistence"))
    implementation(project(":mk-sync"))
    implementation(project(":mk-store"))
    implementation(project(":mk-analytics"))
    implementation(project(":mk-designsystem"))
    implementation(project(":mk-assets"))
}
