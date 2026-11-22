import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

/**
 * `mk.android.library.compose` — Batch 1 · Agent 1.1's convention plugin for
 * the two library modules that touch Compose surfaces directly:
 * `mk-designsystem` (`MkTheme` via `CompositionLocal`s, D-317) and
 * `mk-canvas` (`MkCanvasView` hosted via `AndroidView` inside Compose,
 * D-306). Every other engine module uses the plain `mk.android.library`.
 */
class MkAndroidLibraryComposeConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            with(pluginManager) {
                apply("mk.android.library")
                apply("org.jetbrains.kotlin.plugin.compose")
            }

            extensions.configure<LibraryExtension> {
                buildFeatures.compose = true
            }

            dependencies {
                val bom = libs.findLibrary("compose-bom").get()
                add("implementation", platform(bom))
                add("androidTestImplementation", platform(bom))

                add("implementation", libs.findLibrary("compose-ui").get())
                add("implementation", libs.findLibrary("compose-ui-graphics").get())
                add("implementation", libs.findLibrary("compose-foundation").get())
                add("implementation", libs.findLibrary("compose-material3").get())
                add("debugImplementation", libs.findLibrary("compose-ui-tooling").get())
                add("implementation", libs.findLibrary("compose-ui-tooling-preview").get())
            }
        }
    }
}
