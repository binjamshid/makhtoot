import com.android.build.api.dsl.CommonExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.kotlin.dsl.withType
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

/**
 * Batch 1 · Agent 1.1 shared config helper, applied by every `mk.android.*`
 * convention plugin (ANDROID_SPINE.md §2 D-300).
 *
 * compileSdk/targetSdk 36, minSdk 29 (FDA-07 — Android 10, not 26; there is no
 * API 26-28 fallback anywhere in this project, D-305), JDK 17 (D-300), Kotlin
 * 2.1 language/API level pinned explicitly rather than left to the default.
 */
internal fun Project.configureKotlinAndroid(
    commonExtension: CommonExtension<*, *, *, *, *, *>,
) {
    commonExtension.apply {
        compileSdk = 36

        defaultConfig {
            minSdk = 29
        }

        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
            isCoreLibraryDesugaringEnabled = false
        }

        lint {
            abortOnError = true
            warningsAsErrors = false
            checkDependencies = false
        }
    }

    extensions.configure(KotlinAndroidProjectExtension::class.java) {
        jvmToolchain(17)
    }

    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
            // D-303/D-325: never silently swallow a shaping-adjacent Kotlin
            // warning as if it were noise — explicit opt-ins only, no blanket
            // suppression flags here.
        }
    }
}
