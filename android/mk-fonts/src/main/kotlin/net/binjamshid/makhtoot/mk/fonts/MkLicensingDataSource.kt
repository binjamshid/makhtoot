package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkLicensingDataSource(
    val registry: MkFontRegistry,
    val bundle: MkPlatformAssetBundle? = null
) {
    suspend fun sections(): List<Section> { throw MkNotYetPorted("mk-fonts.MkLicensingDataSource.sections") }
    data class Section(
        var fontID: MkFontId,
        var familyName: String,
        var foundryOrAuthor: String,
        var licenseType: MkLicenseType,
        var fullLicenseText: String? = null,
        var reservedFontNames: List<String>,
        var sourceRepoURL: String,
        var commercialUseStatus: String,
        var coverage: MkCoverageReport? = null,
        var origin: MkFontOrigin,
        var isProvisionalShip: Boolean,
        var arrangeFidelityGateNote: String? = null,
        var gposCursiveNote: String? = null
    )
}

object MkFontsStrings {
    val userImportedLicenseNotice: String = "خط مستورد من المستخدم ، التزام الترخيص مسؤولية المستخدم"
}

