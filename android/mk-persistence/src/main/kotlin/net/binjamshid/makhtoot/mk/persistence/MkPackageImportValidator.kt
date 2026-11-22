package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkPackageImportLimits(
    var maxTotalBytes: Int = 209715200,
    var maxFileCount: Int = 5000,
    var allowedTopLevelMembers: Set<String> = setOf("manifest.json", "scene.json", "thumbnail.png", "journal.mkj", "assets", "backups")
) {
    companion object {
        val default: MkPackageImportLimits = MkPackageImportLimits()
    }
}

sealed class MkPackageImportValidationError : Exception() {
    data class ByteCapExceeded(val limit: Int) : MkPackageImportValidationError()
    data class FileCountCapExceeded(val limit: Int) : MkPackageImportValidationError()
    data class UnexpectedMember(val arg0: String) : MkPackageImportValidationError()
}


