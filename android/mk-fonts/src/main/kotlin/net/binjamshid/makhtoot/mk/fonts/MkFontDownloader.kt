package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding

class MkFontDownloader(
    val registry: MkFontRegistry,
    val entitlements: MkEntitlementProviding,
    val session: MkPlatformHttpSession = MkPlatformHttpSession(),
    val destinationRoot: java.net.URI? = null
) {
    fun progress(fontID: MkFontId): kotlinx.coroutines.flow.Flow<Double> { throw MkNotYetPorted("mk-fonts.MkFontDownloader.progress") }
    suspend fun download(entry: MkCatalogManifestEntry) { throw MkNotYetPorted("mk-fonts.MkFontDownloader.download") }
}

