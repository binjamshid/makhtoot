package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId

sealed class MkFallbackReason {
    object ArrangedGeometry : MkFallbackReason()
    object CustomLigatureDecomposition : MkFallbackReason()
    data class FontEmbeddingRestricted(val fontName: String) : MkFallbackReason()
    object PathTextFidelity : MkFallbackReason()
    object UserFidelityToggle : MkFallbackReason()
    object RasterBelowPrintDpi : MkFallbackReason()
    object PdfAssetRasterized : MkFallbackReason()
    object ColorGlyphRasterized : MkFallbackReason()
    data class LockedFontNoShapedCache(val fontName: String) : MkFallbackReason()
    data class DownscaledForFreeTierBudget(val requestedPixelWidth: Int, val requestedPixelHeight: Int) : MkFallbackReason()
    object CmykContentRasterized : MkFallbackReason()
    data class FontNotEmbedded(val fontName: String) : MkFallbackReason()
    data class AssetUnresolved(val assetRef: String) : MkFallbackReason()
    val eventName: String
        get() = throw MkNotYetPorted("mk-export.MkFallbackReason.eventName")
    val arabicMessage: String
        get() = throw MkNotYetPorted("mk-export.MkFallbackReason.arabicMessage")
}

data class MkFallbackNote(
    var nodeID: MkNodeId? = null,
    var reason: MkFallbackReason,
    var detail: String? = null
) {
    val arabicMessage: String
        get() = throw MkNotYetPorted("mk-export.MkFallbackNote.arabicMessage")
    val eventName: String
        get() = throw MkNotYetPorted("mk-export.MkFallbackNote.eventName")
}

