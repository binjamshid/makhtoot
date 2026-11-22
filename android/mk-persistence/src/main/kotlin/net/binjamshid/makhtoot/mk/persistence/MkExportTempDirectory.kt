package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkExportTempDirectory(
    val systemTemporaryDirectory: java.net.URI? = null
) {
    val directoryURL: java.net.URI
        get() = throw MkNotYetPorted("mk-persistence.MkExportTempDirectory.directoryURL")
    fun urlForExport(ext: String): java.net.URI { throw MkNotYetPorted("mk-persistence.MkExportTempDirectory.urlForExport") }
    fun purge() { throw MkNotYetPorted("mk-persistence.MkExportTempDirectory.purge") }
    companion object {
        val shared: MkExportTempDirectory = MkExportTempDirectory()
    }
}

