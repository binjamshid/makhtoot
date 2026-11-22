package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.model.MkScene

data class MkManifest(
    var manifestVersion: Int,
    var projectID: MkProjectId,
    var schemaVersion: Int,
    var title: String,
    var canvas: MkCanvasSpec,
    var createdAt: java.time.Instant = java.time.Instant.now(),
    var modifiedAt: java.time.Instant = java.time.Instant.now(),
    var thumbnail: String? = null,
    var assetIndexDigest: String? = null,
    var premiumContentPresent: Boolean = false
)

data class MkDocumentPackage(
    val rootURL: java.net.URI
) {
    val manifestURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.manifestURL")
    val sceneURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.sceneURL")
    val journalURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.journalURL")
    val assetsDirURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.assetsDirURL")
    val backupsDirURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.backupsDirURL")
    val thumbnailURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.thumbnailURL")
    val exists: Boolean
        get() = throw MkNotYetPorted("mk-persistence.MkDocumentPackage.exists")
    fun readManifest(): MkManifest { throw MkNotYetPorted("mk-persistence.MkDocumentPackage.readManifest") }
    fun writeManifest(manifest: MkManifest) { throw MkNotYetPorted("mk-persistence.MkDocumentPackage.writeManifest") }
    fun readScene(): MkScene { throw MkNotYetPorted("mk-persistence.MkDocumentPackage.readScene") }
    fun writeScene(scene: MkScene) { throw MkNotYetPorted("mk-persistence.MkDocumentPackage.writeScene") }
    fun writeThumbnail(pngData: ByteArray) { throw MkNotYetPorted("mk-persistence.MkDocumentPackage.writeThumbnail") }
    companion object {
        fun create(rootURL: java.net.URI, projectID: MkProjectId, title: String, canvas: MkCanvasSpec, schemaVersion: Int? = null): MkDocumentPackage { throw MkNotYetPorted("mk-persistence.MkDocumentPackage.create") }
    }
}

