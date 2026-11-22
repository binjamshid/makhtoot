package net.binjamshid.makhtoot.mk.assets.model

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkSolidColor

enum class MkPatternRepeatMode(val rawValue: String) {
    GRID(""), HALF_DROP("")
}

data class MkPatternTile(
    var geometry: MkAssetGeometry,
    var tileSize: MkSize
)

data class MkPatternFill(
    var tile: MkPatternTile,
    var repeatMode: MkPatternRepeatMode,
    var backgroundColor: MkSolidColor,
    var motifColor: MkSolidColor
)

