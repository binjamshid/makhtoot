package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.render.MkAssetProviding
import net.binjamshid.makhtoot.mk.render.MkEmptyAssetProvider

object MkPdfVectorExporter {
    fun export(scene: MkScene, pixelSize: MkSize, dpi: Double, title: String, fontLicense: MkFontLicenseProviding, fonts: MkFontProviding, assets: MkAssetProviding = MkEmptyAssetProvider(), url: java.net.URI): Result { throw MkNotYetPorted("mk-export.MkPdfVectorExporter.export") }
    data class Result(
        var fallbacks: List<MkFallbackNote>
    )
}

