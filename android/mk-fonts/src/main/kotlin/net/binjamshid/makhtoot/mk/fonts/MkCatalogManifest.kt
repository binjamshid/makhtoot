package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkCatalogManifest(
    var schemaVersion: Int,
    var generatedAt: String,
    var fonts: List<MkCatalogManifestEntry>
)

data class MkCatalogManifestFace(
    var postScriptName: String,
    var styleName: String,
    var weight: Int,
    var isVariable: Boolean
)

data class MkCatalogManifestEntry(
    var fontID: MkFontId,
    var family: String,
    var faces: List<MkCatalogManifestFace>,
    var categories: List<MkFontCategory>,
    var tags: List<String>,
    var fileURL: java.net.URI,
    var fileSHA256: String,
    var fileSizeBytes: Int,
    var licenseRecord: MkLicenseRecord,
    var minAppVersion: String,
    var previewImageURL: java.net.URI? = null
)

sealed class MkCatalogManifestDecodingError : Exception() {
    data class MissingLicenseRecord(val fontID: String) : MkCatalogManifestDecodingError()
    data class Malformed(val arg0: String) : MkCatalogManifestDecodingError()
    data class UnsupportedSchemaVersion(val arg0: Int) : MkCatalogManifestDecodingError()
}

object MkCatalogManifestDecoder {
    fun decode(data: ByteArray): MkCatalogManifest { throw MkNotYetPorted("mk-fonts.MkCatalogManifestDecoder.decode") }
}

