package net.binjamshid.makhtoot.mk.assets.rendering

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.library.MkAssetLibrary
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor

object MkAssetContactSheetGenerator {
    fun generate(descriptors: List<MkAssetDescriptor>, cellSize: Double, columns: Int = 8, library: MkAssetLibrary? = null): Any? { throw MkNotYetPorted("mk-assets.MkAssetContactSheetGenerator.generate") }
    fun generateStandardPair(descriptors: List<MkAssetDescriptor>, library: MkAssetLibrary? = null): Pair<Any?, Any?> { throw MkNotYetPorted("mk-assets.MkAssetContactSheetGenerator.generateStandardPair") }
    fun writePNG(image: Any, url: java.net.URI): Boolean { throw MkNotYetPorted("mk-assets.MkAssetContactSheetGenerator.writePNG") }
}

