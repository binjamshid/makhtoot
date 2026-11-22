import org.gradle.api.Project
import org.gradle.api.artifacts.VersionCatalog
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.kotlin.dsl.getByType

/**
 * Shared accessor so every `mk.android.*` convention plugin can reach the
 * root `libs.versions.toml` catalog (android/gradle/libs.versions.toml,
 * Batch 1 · Agent 1.1) without repeating the extension lookup.
 */
internal val Project.libs: VersionCatalog
    get() = extensions.getByType<VersionCatalogsExtension>().named("libs")
