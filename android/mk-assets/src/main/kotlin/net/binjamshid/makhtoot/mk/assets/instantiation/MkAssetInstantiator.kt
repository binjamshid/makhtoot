package net.binjamshid.makhtoot.mk.assets.instantiation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.model.MkAssetCategory
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkNode

class MkAssetInstantiator {
    fun place(asset: MkAssetDescriptor, position: MkPoint? = null, scale: MkSize? = null): Placement { throw MkNotYetPorted("mk-assets.MkAssetInstantiator.place") }
    data class Placement(
        val node: MkNode,
        val record: MkPlacementRecord
    )
}

data class MkPlacementRecord(
    var nodeID: MkNodeId,
    var assetID: String,
    var category: MkAssetCategory,
    var isPremium: Boolean,
    var nameAr: String
)

