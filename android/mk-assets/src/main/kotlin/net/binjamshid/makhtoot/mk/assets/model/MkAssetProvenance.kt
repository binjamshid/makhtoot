package net.binjamshid.makhtoot.mk.assets.model

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

sealed class MkAssetOrigin {
    data class OriginalWork(val author: String, val date: String) : MkAssetOrigin()
    data class DerivedVerified(val sourceURL: String, val sourceLicense: String, val licenseFilePath: String, val transformationNote: String) : MkAssetOrigin()
}

data class MkAssetProvenance(
    var assetID: String,
    var origin: MkAssetOrigin,
    var verifiedBy: String,
    var notes: String
)

object MkAssetForbiddenSourceMarkers {
    val markers: List<String>? = null
    fun containsForbiddenMarker(notes: String): Boolean { throw MkNotYetPorted("mk-assets.MkAssetForbiddenSourceMarkers.containsForbiddenMarker") }
}

