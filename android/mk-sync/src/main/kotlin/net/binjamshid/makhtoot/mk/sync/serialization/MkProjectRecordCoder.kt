package net.binjamshid.makhtoot.mk.sync.serialization

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.persistence.MkDocumentPackage
import net.binjamshid.makhtoot.mk.persistence.metadata.MkProjectSummary
import net.binjamshid.makhtoot.mk.sync.MkPlatformSyncRecord
import net.binjamshid.makhtoot.mk.sync.MkPlatformSyncZoneId
import net.binjamshid.makhtoot.mk.sync.conflict.MkSyncSnapshot

data class MkProjectRecordCoder(
    val zoneID: MkPlatformSyncZoneId? = null
) {
    fun pack(`package`: MkDocumentPackage, projectID: java.util.UUID, summary: MkProjectSummary, tempDir: java.net.URI): Pair<MkPlatformSyncRecord, List<MkPlatformSyncRecord>> { throw MkNotYetPorted("mk-sync.MkProjectRecordCoder.pack") }
    fun unpack(projectRecord: MkPlatformSyncRecord, assetRecords: List<MkPlatformSyncRecord>, tempDir: java.net.URI): MkUnpackResult { throw MkNotYetPorted("mk-sync.MkProjectRecordCoder.unpack") }
    fun snapshot(record: MkPlatformSyncRecord): MkSyncSnapshot? { throw MkNotYetPorted("mk-sync.MkProjectRecordCoder.snapshot") }
    fun schemaVersion(record: MkPlatformSyncRecord): Long { throw MkNotYetPorted("mk-sync.MkProjectRecordCoder.schemaVersion") }
}

data class MkUnpackResult(
    val `package`: MkDocumentPackage,
    val projectID: java.util.UUID,
    val title: String,
    val folderID: java.util.UUID? = null,
    val contentHash: String,
    val schemaVersion: Long,
    val modifiedAt: java.time.Instant
)

sealed class MkSyncCoderError : Exception() {
    data class MissingField(val arg0: String) : MkSyncCoderError()
    data class InvalidRecordName(val arg0: String) : MkSyncCoderError()
    data class AssetMissing(val arg0: String) : MkSyncCoderError()
}

