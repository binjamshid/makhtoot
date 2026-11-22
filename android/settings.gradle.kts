// android/settings.gradle.kts
//
// Work item 1.1 (ANDROID_SPINE.md §3 module map, §5 Batch 1).
// 18 Gradle modules mirroring MakhtootKit 1:1 (D-301) plus `:mk-native` and `:app`.
// Module list and package roots are frozen by the spine — do not add or rename a
// module here without a spine amendment.

pluginManagement {
    includeBuild("build-logic")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
    // No explicit `versionCatalogs { create("libs") { from(...) } }` block:
    // Gradle auto-registers `gradle/libs.versions.toml` as the "libs" catalog
    // by convention. An explicit declaration of the same name collides with
    // that automatic registration ("you can only call the 'from' method a
    // single time") — discovered the hard way while validating this scaffold,
    // see android/docs/impl-log/BATCH-1.1.md.
}

rootProject.name = "makhtoot-android"

// Native shaping/outline/colour facade (D-303/D-304/D-315) — no Swift target,
// new for Android.
include(":mk-native")

// 16 modules mirroring MakhtootKit's 16 library targets 1:1 (D-301).
include(":mk-foundation")
include(":mk-model")
include(":mk-textengine")
include(":mk-arrange")
include(":mk-pathtext")
include(":mk-canvas")
include(":mk-render")
include(":mk-color")
include(":mk-export")
include(":mk-fonts")
include(":mk-persistence")
include(":mk-sync")
include(":mk-store")
include(":mk-analytics")
include(":mk-designsystem")
include(":mk-assets")

// App shell (Compose), mirrors `Makhtoot/AppShell/**`.
include(":app")
