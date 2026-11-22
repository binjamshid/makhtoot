package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkEmbeddingRights
import net.binjamshid.makhtoot.mk.model.MkFontRef

interface MkFontLicenseProviding {
    fun isLockableFont(fontRef: MkFontRef): Boolean
    fun embeddingRights(fontRef: MkFontRef): MkEmbeddingRights
}

class MkAllOflLicenseStub : MkFontLicenseProviding {
    override fun isLockableFont(fontRef: MkFontRef): Boolean { throw MkNotYetPorted("mk-export.MkAllOflLicenseStub.isLockableFont") }
    override fun embeddingRights(fontRef: MkFontRef): MkEmbeddingRights { throw MkNotYetPorted("mk-export.MkAllOflLicenseStub.embeddingRights") }
}

