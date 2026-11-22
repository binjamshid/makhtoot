import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

/**
 * `mk.android.application` — Batch 1 · Agent 1.1's convention plugin for
 * `:app` (D-300/D-301/D-317/D-318/D-321). Enables Compose, pins
 * `resConfigs("ar")` (D-318 — Arabic-only, `ar` is the sole configured
 * locale even though per-app locale pinning is done at runtime via
 * `locales_config.xml` + `AppCompatDelegate`, D-318), and leaves a signing
 * placeholder for Agent 9.2's Batch 9 takeover (spine §17 declared
 * exception — this agent owns `android/app/build.gradle.kts` through Batch
 * 8 only).
 */
class MkAndroidApplicationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            with(pluginManager) {
                apply("com.android.application")
                apply("org.jetbrains.kotlin.android")
                apply("org.jetbrains.kotlin.plugin.compose")
            }

            extensions.configure<ApplicationExtension> {
                configureKotlinAndroid(this)

                defaultConfig.targetSdk = 36
                // D-318: Arabic-only UI, RTL-first. resourceConfigurations
                // keeps every other locale's framework-provided resources
                // out of the APK/AAB (the resConfigs("ar") equivalent in the
                // com.android.build.api.dsl API surface actually available
                // at AGP 8.7.3 -- androidResources.localeFilters is a later
                // AGP addition not present here); per-app locale pinning to
                // `ar` regardless of device locale is `locales_config.xml` +
                // AppCompatDelegate (runtime, not a build config concern).
                defaultConfig.resourceConfigurations.add("ar")

                buildFeatures.compose = true
                buildFeatures.buildConfig = true

                buildTypes {
                    getByName("debug") {
                        isMinifyEnabled = false
                    }
                    getByName("release") {
                        isMinifyEnabled = true
                        // R8/ProGuard rules and the real signing config are
                        // Agent 9.2's Batch 9 takeover of this file (spine
                        // section 17). A placeholder rules file keeps this
                        // build type valid before then.
                        proguardFiles(
                            getDefaultProguardFile("proguard-android-optimize.txt"),
                            file("proguard-rules.pro"),
                        )
                    }
                }

                packaging.resources.excludes.addAll(
                    setOf(
                        "META-INF/LICENSE*",
                        "META-INF/NOTICE*",
                        "META-INF/DEPENDENCIES",
                    ),
                )
            }

            dependencies {
                val bom = libs.findLibrary("compose-bom").get()
                add("implementation", platform(bom))
                add("androidTestImplementation", platform(bom))

                add("implementation", libs.findLibrary("compose-ui").get())
                add("implementation", libs.findLibrary("compose-ui-graphics").get())
                add("implementation", libs.findLibrary("compose-foundation").get())
                add("implementation", libs.findLibrary("compose-material3").get())
                add("implementation", libs.findLibrary("compose-ui-tooling-preview").get())
                add("debugImplementation", libs.findLibrary("compose-ui-tooling").get())
                add("implementation", libs.findLibrary("androidx-activity-compose").get())
                add("implementation", libs.findLibrary("androidx-lifecycle-runtime-ktx").get())
                add("implementation", libs.findLibrary("androidx-lifecycle-viewmodel-compose").get())
                add("implementation", libs.findLibrary("androidx-navigation-compose").get())
                add("implementation", libs.findLibrary("androidx-core-ktx").get())
                add("implementation", libs.findLibrary("kotlinx-coroutines-android").get())
                add("testImplementation", libs.findLibrary("junit4").get())
                add("androidTestImplementation", libs.findLibrary("androidx-test-ext-junit").get())
                add("androidTestImplementation", libs.findLibrary("androidx-espresso-core").get())
                add("androidTestImplementation", libs.findLibrary("compose-ui-test-junit4").get())
                add("debugImplementation", libs.findLibrary("compose-ui-test-manifest").get())
            }
        }
    }
}
