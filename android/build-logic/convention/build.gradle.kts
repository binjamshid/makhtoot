// android/build-logic/convention/build.gradle.kts
//
// Work item 1.1. `kotlin-dsl` compiles every `*.gradle.kts` file under
// src/main/kotlin into a precompiled script plugin whose id is the filename
// minus `.gradle.kts` (e.g. `mk.android.library.gradle.kts` -> plugin id
// `mk.android.library`). The AGP/Kotlin Gradle plugin artifacts are declared
// here as `implementation` so those precompiled scripts can `apply(plugin =
// ...)` them.

plugins {
    `kotlin-dsl`
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

// Hardcoded, not catalog-sourced: build-logic is an included build and
// cannot share a version-catalog NAME with the root build's "libs" catalog
// (Gradle 8.11 rejects two Settings' `from(...)` calls against the same
// catalog name once wired together via `pluginManagement { includeBuild
// ("build-logic") }` — see android/build-logic/settings.gradle.kts's note).
// These four MUST be kept in sync by hand with
// android/gradle/libs.versions.toml's `agp` and `kotlin` entries — the only
// two versions a precompiled convention-plugin script needs to `apply(plugin
// = ...)` AGP/Kotlin at all.
val agpVersion = "8.7.3"
val kotlinVersion = "2.1.0"

dependencies {
    compileOnly("com.android.tools.build:gradle:$agpVersion")
    compileOnly("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    compileOnly("org.jetbrains.kotlin:kotlin-serialization:$kotlinVersion")
    compileOnly("org.jetbrains.kotlin.plugin.compose:org.jetbrains.kotlin.plugin.compose.gradle.plugin:$kotlinVersion")
}

gradlePlugin {
    plugins {
        register("mkAndroidLibrary") {
            id = "mk.android.library"
            implementationClass = "MkAndroidLibraryConventionPlugin"
        }
        register("mkAndroidLibraryCompose") {
            id = "mk.android.library.compose"
            implementationClass = "MkAndroidLibraryComposeConventionPlugin"
        }
        register("mkAndroidApplication") {
            id = "mk.android.application"
            implementationClass = "MkAndroidApplicationConventionPlugin"
        }
        register("mkAndroidNative") {
            id = "mk.android.native"
            implementationClass = "MkAndroidNativeConventionPlugin"
        }
    }
}
