// android/build-logic/settings.gradle.kts
//
// Included build (work item 1.1) hosting the three convention plugins
// every module in android/settings.gradle.kts applies: `mk.android.library`,
// `mk.android.library.compose`, `mk.android.application`.

// NOTE: build-logic cannot declare its own version catalog named "libs" here
// — Gradle 8.11 rejects a second `from(...)` call against a catalog of the
// same name once this build is wired in via the root's
// `pluginManagement { includeBuild("build-logic") }` (the two Settings'
// accessor-generation steps collide: "In version catalog libs, you can only
// call the 'from' method a single time"). AGP/Kotlin plugin versions below
// are therefore hardcoded to match android/gradle/libs.versions.toml exactly
// — see MkVersions.kt in convention/src/main/kotlin, which is the single
// place those literals live, kept in sync with the catalog by hand.
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "build-logic"
include(":convention")
