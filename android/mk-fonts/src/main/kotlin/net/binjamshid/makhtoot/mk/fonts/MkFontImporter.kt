package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding

class MkFontImporter(
    val registry: MkFontRegistry,
    val entitlements: MkEntitlementProviding,
    val validator: MkFontValidator = MkFontValidator(),
    val destinationRoot: java.net.URI? = null
) {
    suspend fun importFont(sourceURL: java.net.URI, originalFilename: String): MkFontId { throw MkNotYetPorted("mk-fonts.MkFontImporter.importFont") }
}

