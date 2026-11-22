package net.binjamshid.makhtoot.mk.sync.schema

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.sync.MkPlatformSyncRecordId
import net.binjamshid.makhtoot.mk.sync.MkPlatformSyncZoneId

object MkSyncSchema {
    val containerIdentifier: String = "iCloud.net.binjamshid.makhtoot"
    val zoneName: String = "MakhtootProjects"
    val zoneID: MkPlatformSyncZoneId? = null
    val projectRecordType: String = "MKProject"
    val assetRecordType: String = "MKProjectAsset"
    val fieldName: String = "name"
    val fieldFolderPath: String = "folderPath"
    val fieldSchemaVersion: String = "schemaVersion"
    val fieldModifiedAt: String = "modifiedAt"
    val fieldContentHash: String = "contentHash"
    val fieldManifest: String = "manifest"
    val fieldScene: String = "scene"
    val fieldThumbnail: String = "thumbnail"
    val fieldAssetIndex: String = "assetIndex"
    val assetFieldProjectRef: String = "projectRef"
    val assetFieldHash: String = "hash"
    val assetFieldPayload: String = "payload"
    fun projectRecordName(projectID: java.util.UUID): String { throw MkNotYetPorted("mk-sync.MkSyncSchema.projectRecordName") }
    fun assetRecordName(projectID: java.util.UUID, hash: String): String { throw MkNotYetPorted("mk-sync.MkSyncSchema.assetRecordName") }
    fun projectRecordID(projectID: java.util.UUID): MkPlatformSyncRecordId { throw MkNotYetPorted("mk-sync.MkSyncSchema.projectRecordID") }
    fun assetRecordID(projectID: java.util.UUID, hash: String): MkPlatformSyncRecordId { throw MkNotYetPorted("mk-sync.MkSyncSchema.assetRecordID") }
}

