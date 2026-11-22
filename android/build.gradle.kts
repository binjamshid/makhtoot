// android/build.gradle.kts (root)
//
// Work item 1.1. Declares plugin versions once at the root (`apply false`)
// so every module applies them without re-resolving a version; actual
// application happens per module via the build-logic convention plugins
// (android/build-logic/convention/src/main/kotlin/mk.*.gradle.kts).

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.ksp) apply false
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
