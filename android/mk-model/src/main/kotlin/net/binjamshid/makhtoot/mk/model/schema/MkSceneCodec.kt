package net.binjamshid.makhtoot.mk.model.schema

import net.binjamshid.makhtoot.mk.foundation.MkError
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * `mk-model`'s error taxonomy (follows the `MkError` pattern from
 * `mk-foundation`). Reserves the `"model"` error-code prefix. Ports
 * `Sources/MKModel/Schema/SceneCodec.swift`'s `MKModelError`.
 */
sealed class MkModelError : Exception(), MkError {
    /** This project was created with a newer version of Makhtoot. */
    data class SchemaTooNew(val found: Int, val supported: Int) : MkModelError()

    /** No registered migrator covers a step in the migration chain. */
    data class MigrationPathMissing(val fromVersion: Int) : MkModelError()

    /** The decoded JSON envelope is missing required keys, or `scene.json` is not valid JSON at all. */
    data class MalformedEnvelope(val underlyingDescription: String) : MkModelError()

    override val errorCode: String
        get() = throw MkNotYetPorted("MkModelError.errorCode")
    override val arabicUserMessage: String?
        get() = throw MkNotYetPorted("MkModelError.arabicUserMessage")
    override val underlying: Throwable?
        get() = throw MkNotYetPorted("MkModelError.underlying")
}

/** The on-disk envelope wrapping a scene: `{"schemaVersion": 1, "scene": {...}}`. */
data class MkSceneEnvelope(
    var schemaVersion: Int,
    var scene: MkScene,
)

/**
 * Encodes/decodes `scene.json`, applying migration + the
 * newer-than-supported rejection path. Ports `MKSceneCodec`.
 */
object MkSceneCodec {
    /** Encodes [scene] as the `{schemaVersion, scene}` envelope. */
    fun encode(scene: MkScene): ByteArray = throw MkNotYetPorted("MkSceneCodec.encode")

    /** Decodes [data] as a `scene.json` envelope, migrating and rejecting a too-new schema version as needed. */
    fun decode(data: ByteArray, registry: MkSceneMigratorRegistry = MkSceneMigratorRegistry.standard): MkScene =
        throw MkNotYetPorted("MkSceneCodec.decode")
}
