package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.render.MkAssetProviding
import net.binjamshid.makhtoot.mk.render.MkEmptyAssetProvider

object MkSvgSerializer {
    fun export(scene: MkScene, pixelSize: MkSize, fonts: MkFontProviding = MkSystemFontStubProvider(), fontLicense: MkFontLicenseProviding = MkAllOflLicenseStub(), fontData: MkExportFontDataProviding = MkNoFontDataProviding(), assets: MkAssetProviding = MkEmptyAssetProvider()): Result { throw MkNotYetPorted("mk-export.MkSvgSerializer.export") }
    data class Result(
        var svg: String,
        var fallbacks: List<MkFallbackNote>
    )
}

