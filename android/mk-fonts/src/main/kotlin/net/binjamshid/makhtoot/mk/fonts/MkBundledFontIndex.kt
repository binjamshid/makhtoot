package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkBundledFontIndex(
    val bundle: MkPlatformAssetBundle? = null
) {
    fun loadAll(): List<LoadedFont> { throw MkNotYetPorted("mk-fonts.MkBundledFontIndex.loadAll") }
    data class LoadedFont(
        var record: MkFontRecord,
        var license: MkLicenseRecord,
        var evidence: MkFontVerificationEvidence,
        var isProvisionalShip: Boolean
    )
}


