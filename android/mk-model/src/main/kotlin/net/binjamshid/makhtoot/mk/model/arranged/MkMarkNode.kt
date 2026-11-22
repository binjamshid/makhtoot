package net.binjamshid.makhtoot.mk.model.arranged

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkStyle

/**
 * Combining mark (glossary: Mark Node) — tashkeel and Qur'anic annotation
 * glyphs, attached to a base [MkGlyphNode] by id reference (not tree
 * containment). Ports `Sources/MKModel/Arranged/MarkNode.swift`.
 */

@Serializable
enum class MkMarkClass {
    /** Standard tashkeel: fatha, damma, kasra, sukun, shadda, tanwin, etc. */
    Tashkeel,

    /** Qur'anic recitation annotation marks. */
    QuranicAnnotation,

    /** Any other Unicode Mn/Me combining mark not covered above. */
    OtherCombining,
}

/** One attached (or explicitly detached) combining mark (glossary: Mark Node). D-106. */
@Serializable
data class MkMarkNode(
    var id: MkNodeId = MkNodeId(),
    var glyph: MkGlyphRef,
    var outline: MkPathData? = null,
    /** Base glyph node this mark is anchored to; `null` = detached. */
    var attachedTo: MkNodeId?,
    /** GPOS-captured offset from the base's anchor point, in base-local space (D-105). */
    var relativeOffset: MkSize = MkSize.zero,
    /** Default `true`: the base's transform composes onto this mark's position. */
    var followsBase: Boolean = true,
    /** The mark's own transform, applied AFTER `relativeOffset`. */
    var transform: MkTransform2D = MkTransform2D.identity,
    var style: MkStyle = MkStyle.default,
    var provenance: MkProvenance,
    var markClass: MkMarkClass,
    /** Paint/stacking order among multiple marks on the same base. */
    var stackIndex: Int = 0,
    var isHidden: Boolean = false,
    var isLocked: Boolean = false,
)
