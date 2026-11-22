package net.binjamshid.makhtoot.mk.model.schema

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Migration protocol + registry. v1 has no real migrations (schemaVersion
 * starts at 1) — this ships the identity migration and the dispatch
 * machinery so schema evolution is testable from day one. Ports
 * `Sources/MKModel/Schema/MKSceneMigrator.swift`.
 */
object MkSceneSchema {
    /** The current schema version this build of `mk-model` writes and can read natively. */
    const val currentVersion: Int = 1
}

/** One `v(n) -> v(n+1)` pure JSON transform. */
interface MkSceneMigrator {
    /** The schema version this migrator's `migrate` expects as input. */
    val fromVersion: Int

    /** The schema version `migrate` produces. */
    val toVersion: Int

    /** Transforms a decoded `scene.json` JSON object from [fromVersion]'s shape to [toVersion]'s. */
    fun migrate(sceneJson: Map<String, Any?>): Map<String, Any?>
}

/** v1 -> v1 no-op migrator, so the registry/dispatch path has at least one real entry to test. */
class MkIdentityMigrator : MkSceneMigrator {
    override val fromVersion: Int = MkSceneSchema.currentVersion
    override val toVersion: Int = MkSceneSchema.currentVersion

    override fun migrate(sceneJson: Map<String, Any?>): Map<String, Any?> = sceneJson
}

/**
 * Ordered registry of migrators, dispatched by `fromVersion`. The Swift
 * initializer builds a `fromVersion -> migrator` dictionary from
 * [migrators] — real construction logic, so it is throw-stubbed here too
 * (via the `init` block) rather than silently succeeding; [standard] is
 * `by lazy` so merely referencing the companion object doesn't eagerly
 * trigger the throw at class-load time.
 */
class MkSceneMigratorRegistry(migrators: List<MkSceneMigrator> = listOf(MkIdentityMigrator())) {
    init {
        throw MkNotYetPorted("MkSceneMigratorRegistry.init")
    }

    companion object {
        /** The registry every production caller should use. */
        val standard: MkSceneMigratorRegistry by lazy { MkSceneMigratorRegistry() }
    }

    /** Runs the full migration chain from [fromVersion] to [MkSceneSchema.currentVersion]. */
    fun migrate(sceneJson: Map<String, Any?>, fromVersion: Int): Map<String, Any?> =
        throw MkNotYetPorted("MkSceneMigratorRegistry.migrate")
}
