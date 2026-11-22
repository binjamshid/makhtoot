package net.binjamshid.makhtoot.mk.assets.model

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkAssetCategory(val rawValue: String) {
    BASIC_SHAPES(""), ORNAMENTS(""), FRAMES(""), CALLIGRAPHIC_ELEMENTS(""), PATTERN_BACKGROUNDS("");
    val id: String
        get() = throw MkNotYetPorted("mk-assets.MkAssetCategory.id")
    val nameAr: String
        get() = throw MkNotYetPorted("mk-assets.MkAssetCategory.nameAr")
    companion object {
        val browserOrder: List<MkAssetCategory>? = null
    }
}

