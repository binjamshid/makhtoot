package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkFontValidator {
    fun validate(data: ByteArray): Verdict { throw MkNotYetPorted("mk-fonts.MkFontValidator.validate") }
    data class ValidatedFace(
        var postScriptName: String? = null,
        var familyName: String? = null,
        var isVariable: Boolean,
        var format: MkFontFileFormat,
        var tables: Set<String>
    )
    sealed class Verdict {
        data class Ok(val faces: List<ValidatedFace>) : Verdict()
        data class Reject(val arg0: MkFontError) : Verdict()
    }
}

