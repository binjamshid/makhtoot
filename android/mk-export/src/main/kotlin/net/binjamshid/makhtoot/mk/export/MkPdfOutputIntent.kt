package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.color.MkIccProfile

object MkPdfOutputIntent {
    fun auxiliaryInfo(title: String, profile: MkIccProfile): CFDictionary { throw MkNotYetPorted("mk-export.MkPdfOutputIntent.auxiliaryInfo") }
    fun outputIntentDictionary(profile: MkIccProfile): Map<CFString, Any> { throw MkNotYetPorted("mk-export.MkPdfOutputIntent.outputIntentDictionary") }
    fun plainAuxiliaryInfo(title: String): CFDictionary { throw MkNotYetPorted("mk-export.MkPdfOutputIntent.plainAuxiliaryInfo") }
}

