import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

/**
 * `mk.android.library` — Batch 1 · Agent 1.1's convention plugin for a plain
 * (non-Compose) `MakhtootKit`-mirroring engine module: mk-foundation,
 * mk-model, mk-textengine, mk-arrange, mk-pathtext, mk-render, mk-color,
 * mk-export, mk-fonts, mk-persistence, mk-sync, mk-store, mk-analytics,
 * mk-assets (`ANDROID_SPINE.md` §3.1). `mk-designsystem` and `mk-canvas` use
 * `mk.android.library.compose` instead (they touch Compose surfaces per
 * D-306/D-317); `:app` uses `mk.android.application`; `:mk-native` uses
 * `mk.android.native`.
 *
 * `namespace` is intentionally NOT set here — the 18 modules' package roots
 * are not a single mechanical transform of the Gradle module name (`mk-native`
 * -> `...mk.nativebridge`, everything else -> `...mk.<name-without-mk->`), so
 * each module's own build.gradle.kts sets `android.namespace` explicitly per
 * the frozen table in spine §3.1, rather than this plugin guessing it.
 */
class MkAndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            with(pluginManager) {
                apply("com.android.library")
                apply("org.jetbrains.kotlin.android")
            }

            extensions.configure<LibraryExtension> {
                configureKotlinAndroid(this)

                // Resource merging (androidResources) is enabled by default
                // for a library module; kept implicit rather than forced, so
                // a module with no res/ directory (most Batch 1 stubs) still
                // configures cleanly. The 13 modules that install a
                // per-module strings.xml (spine section 11 amendment, see
                // impl log) rely on this default, not an explicit override.
                testOptions.unitTests.isIncludeAndroidResources = true
                testOptions.unitTests.isReturnDefaultValues = true
            }

            dependencies {
                add("implementation", libs.findLibrary("kotlinx-coroutines-core").get())
                add("testImplementation", libs.findLibrary("junit4").get())
                add("testImplementation", libs.findLibrary("kotlinx-coroutines-test").get())
            }
        }
    }
}
