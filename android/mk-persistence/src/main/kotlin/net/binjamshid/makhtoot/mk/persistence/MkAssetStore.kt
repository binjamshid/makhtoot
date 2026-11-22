package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkAssetRef

sealed class MkAssetPathError : Exception() {
    data class PathEscapesAssetsDirectory(val arg0: java.net.URI) : MkAssetPathError()
}

class MkAssetStore(
    val `package`: MkDocumentPackage
) {
    fun storeAsset(data: ByteArray, ext: String): MkAssetRef { throw MkNotYetPorted("mk-persistence.MkAssetStore.storeAsset") }
    fun assetData(ref: MkAssetRef): ByteArray { throw MkNotYetPorted("mk-persistence.MkAssetStore.assetData") }
    fun hasAsset(ref: MkAssetRef): Boolean { throw MkNotYetPorted("mk-persistence.MkAssetStore.hasAsset") }
    fun sweepOrphans(referencedRefs: Set<MkAssetRef>) { throw MkNotYetPorted("mk-persistence.MkAssetStore.sweepOrphans") }
    fun orphanedFilenames(): List<String> { throw MkNotYetPorted("mk-persistence.MkAssetStore.orphanedFilenames") }
}

