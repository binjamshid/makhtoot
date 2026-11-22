package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkError

sealed class MkFontError : MkError {
    object PremiumRequired : MkFontError()
    data class UnknownFont(val fontID: MkFontId) : MkFontError()
    object ChecksumMismatch : MkFontError()
    object Offline : MkFontError()
    data class UnsupportedFormat(val detected: String) : MkFontError()
    object CorruptFile : MkFontError()
    data class FontLocked(val fontID: MkFontId) : MkFontError()
    data class RegistrationFailed(val underlyingValue: (Throwable)?) : MkFontError()
    data class LicenseRecordMissing(val fontID: MkFontId) : MkFontError()
    override val errorCode: String
        get() = throw MkNotYetPorted("mk-fonts.MkFontError.errorCode")
    override val arabicUserMessage: String?
        get() = throw MkNotYetPorted("mk-fonts.MkFontError.arabicUserMessage")
    override val underlying: (Throwable)?
        get() = throw MkNotYetPorted("mk-fonts.MkFontError.underlying")
}

val MkFontError.errorDescription: String?
    get() = throw MkNotYetPorted("mk-fonts.MkFontError.errorDescription")

