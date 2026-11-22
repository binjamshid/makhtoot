package net.binjamshid.makhtoot.mk.assets.rendering

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.library.MkAssetLibrary
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkSolidColor

class MkAssetThumbnailRenderer(
    val capacity: Int = 256
) {
    val cachedCount: Int
        get() = throw MkNotYetPorted("mk-assets.MkAssetThumbnailRenderer.cachedCount")
    fun thumbnail(descriptor: MkAssetDescriptor, size: MkSize? = null, library: MkAssetLibrary? = null): Any? { throw MkNotYetPorted("mk-assets.MkAssetThumbnailRenderer.thumbnail") }
}

val MkSolidColor.cgColorRGBA: Any
    get() = throw MkNotYetPorted("mk-assets.MkSolidColor.cgColorRGBA")

