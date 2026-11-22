package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkEmbeddingRights
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.model.MkLiveTextNode
import net.binjamshid.makhtoot.mk.model.MkPathTextNode
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkStyle

object MkEmbeddingRestrictionWalker {
    fun restrictedTextNodes(scene: MkScene, fontLicense: MkFontLicenseProviding, right: MkEmbeddingRights, deviceTransform: MkAffineTransform): List<Entry> { throw MkNotYetPorted("mk-export.MkEmbeddingRestrictionWalker.restrictedTextNodes") }
    fun restrictedTextNodes(scene: MkScene, fontLicense: MkFontLicenseProviding, right: MkEmbeddingRights, scale: Double): List<Entry> { throw MkNotYetPorted("mk-export.MkEmbeddingRestrictionWalker.restrictedTextNodes") }
    fun hiding(ids: List<MkNodeId>, scene: MkScene): MkScene { throw MkNotYetPorted("mk-export.MkEmbeddingRestrictionWalker.hiding") }
    data class Entry(
        var id: MkNodeId,
        var worldTransform: MkAffineTransform,
        var style: MkStyle,
        var opacity: Double,
        var fontPostScriptName: String,
        var kind: Kind
    ) {
        sealed class Kind {
            data class LiveText(val arg0: MkLiveTextNode) : Kind()
            data class PathText(val arg0: MkPathTextNode) : Kind()
        }
    }
}

