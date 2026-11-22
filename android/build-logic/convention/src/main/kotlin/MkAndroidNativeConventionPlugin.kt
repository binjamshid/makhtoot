import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure

// `mk.android.native` -- Batch 1 . Agent 1.1's convention plugin for
// `:mk-native` only (D-303/D-304/D-315). Wires the NDK/CMake toolchain; the
// actual CMakeLists.txt and the cpp and kotlin source directories are Agent
// 1.2's (spine section 4 mechanism (a) -- this agent owns configuration
// only, never a line of C++ or Kotlin).
//
// D-300 specifies NDK r27. This machine has only r28 (28.2.13676358)
// installed, so that is what is pinned below -- see
// android/docs/impl-log/BATCH-1.1.md for the explicit deviation note; r27
// remains installable via sdkmanager if the founder wants strict
// adherence, which is a one-line version-catalog change, not a structural
// one.
class MkAndroidNativeConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("mk.android.library")

            extensions.configure<LibraryExtension> {
                ndkVersion = libs.findVersion("ndk").get().requiredVersion

                defaultConfig.externalNativeBuild {
                    cmake {
                        // Four ABIs per Agent 1.2's task (arm64-v8a,
                        // armeabi-v7a, x86_64, x86); G1's smoke-test
                        // acceptance only requires the first three actually
                        // running in CI (spine section 6 G1) -- x86 is
                        // build-verified only there.
                        cppFlags.addAll(listOf("-std=c++17", "-fexceptions", "-frtti"))
                        abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86"))
                    }
                }

                externalNativeBuild {
                    cmake {
                        path = file("CMakeLists.txt")
                        version = libs.findVersion("cmakeVersion").get().requiredVersion
                    }
                }
            }
        }
    }
}
