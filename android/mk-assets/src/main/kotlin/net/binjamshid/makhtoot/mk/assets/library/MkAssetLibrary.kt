package net.binjamshid.makhtoot.mk.assets.library

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.model.MkAssetCategory
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.assets.model.MkPatternFill

data class MkAssetLibrary(
    val all: List<MkAssetDescriptor>,
    val patternFills: Map<String, MkPatternFill>
) {
    fun descriptor(assetID: String): MkAssetDescriptor? { throw MkNotYetPorted("mk-assets.MkAssetLibrary.descriptor") }
    fun descriptors(category: MkAssetCategory): List<MkAssetDescriptor> { throw MkNotYetPorted("mk-assets.MkAssetLibrary.descriptors") }
    fun patternFill(assetID: String): MkPatternFill? { throw MkNotYetPorted("mk-assets.MkAssetLibrary.patternFill") }
    companion object {
        val standard: MkAssetLibrary
            get() = throw MkNotYetPorted("mk-assets.MkAssetLibrary.standard")
    }
}

