package net.binjamshid.makhtoot.mk.assets.model

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkBezierSegment
import net.binjamshid.makhtoot.mk.model.MkPathData

enum class MkAssetFillRule(val rawValue: String) {
    NON_ZERO(""), EVEN_ODD("")
}

data class MkAssetSubpath(
    var segments: List<MkBezierSegment>,
    var isClosed: Boolean
)

data class MkAssetStyleableRegion(
    var name: String,
    var subpathIndices: List<Int>,
    var fillRule: MkAssetFillRule = MkAssetFillRule.NON_ZERO
)

data class MkAssetGeometry(
    var subpaths: List<MkAssetSubpath>,
    var regions: List<MkAssetStyleableRegion>,
    var localBounds: MkRect
) {
    fun toPathData(unitsPerEm: Double? = null): MkPathData { throw MkNotYetPorted("mk-assets.MkAssetGeometry.toPathData") }
    fun cgPath(): Any { throw MkNotYetPorted("mk-assets.MkAssetGeometry.cgPath") }
    companion object {
        fun singleRegion(subpaths: List<MkAssetSubpath>, localBounds: MkRect, fillRule: MkAssetFillRule = MkAssetFillRule.NON_ZERO): MkAssetGeometry { throw MkNotYetPorted("mk-assets.MkAssetGeometry.singleRegion") }
        fun singleRegionAutoBounds(subpaths: List<MkAssetSubpath>, fillRule: MkAssetFillRule = MkAssetFillRule.NON_ZERO): MkAssetGeometry { throw MkNotYetPorted("mk-assets.MkAssetGeometry.singleRegionAutoBounds") }
    }
}

object MkAssetUnits {
    val em: Double = 100.0
    val half: Double? = null
}

