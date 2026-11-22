package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkFontRef

interface MkExportFontDataProviding {
    fun fontFileData(fontRef: MkFontRef): ByteArray?
}

class MkNoFontDataProviding : MkExportFontDataProviding {
    override fun fontFileData(fontRef: MkFontRef): ByteArray? { throw MkNotYetPorted("mk-export.MkNoFontDataProviding.fontFileData") }
}

