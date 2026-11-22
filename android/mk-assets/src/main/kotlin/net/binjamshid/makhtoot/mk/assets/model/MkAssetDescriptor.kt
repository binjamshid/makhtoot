package net.binjamshid.makhtoot.mk.assets.model

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkFrameNineSliceInsets(
    var top: Double,
    var left: Double,
    var bottom: Double,
    var right: Double
) {
    companion object {
        fun uniform(margin: Double): MkFrameNineSliceInsets { throw MkNotYetPorted("mk-assets.MkFrameNineSliceInsets.uniform") }
    }
}

data class MkAssetDescriptor(
    var assetID: String,
    var nameAr: String,
    var category: MkAssetCategory,
    var tags: List<String>,
    var isPremium: Boolean,
    var pathData: MkAssetGeometry,
    var defaultAspect: Double,
    var provenanceRef: String,
    var libraryVersion: Int = 1,
    var nineSliceInsets: MkFrameNineSliceInsets? = null
) {
    val id: String
        get() = throw MkNotYetPorted("mk-assets.MkAssetDescriptor.id")
}

