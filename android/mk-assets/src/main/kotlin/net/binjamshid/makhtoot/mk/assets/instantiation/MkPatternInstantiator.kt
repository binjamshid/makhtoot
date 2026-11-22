package net.binjamshid.makhtoot.mk.assets.instantiation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.assets.model.MkPatternFill
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkNode

class MkPatternInstantiator {
    fun placeBackground(descriptor: MkAssetDescriptor, fill: MkPatternFill, canvasSize: MkSize): Placement { throw MkNotYetPorted("mk-assets.MkPatternInstantiator.placeBackground") }
    data class Placement(
        val node: MkNode,
        val record: MkPlacementRecord
    )
}

