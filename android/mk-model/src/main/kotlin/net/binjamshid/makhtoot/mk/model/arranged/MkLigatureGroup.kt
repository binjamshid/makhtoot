package net.binjamshid.makhtoot.mk.model.arranged

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkStyle

/**
 * Multi-codepoint single-glyph cluster (glossary: Ligature Group). D-108:
 * decomposing reshapes constituents, positions them to match the original
 * ligature's visual bounds by default, and recomposition restores the
 * stored original ligature glyph exactly. Ports
 * `Sources/MKModel/Arranged/LigatureGroup.swift`.
 */

@Serializable
data class MkComposedLigature(
    var glyph: MkGlyphRef,
    var outline: MkPathData? = null,
    var layout: MkGlyphLayout,
    /** `false` if constituents cannot be reshaped in this font/context — decompose UI should disable itself. */
    var decomposable: Boolean,
)

@Serializable
enum class MkFidelityMode {
    /** Constituents positioned to match the original ligature's bounds (default, D-108). */
    MatchOriginal,

    /** Constituents use default spacing/forms (explicit user opt-out). */
    DefaultForms,
}

@Serializable
data class MkDecomposedLigature(
    /** Reshaped constituent glyphs, joining-preserving. */
    var components: List<MkGlyphNode>,
    /** Per-component nudge matching the original ligature's bounds when `fidelityMode == MatchOriginal`. */
    var fidelityOffsets: Map<MkNodeId, MkSize> = emptyMap(),
    var fidelityMode: MkFidelityMode = MkFidelityMode.MatchOriginal,
    /** The original composed ligature, retained so recomposition is exact (D-108). */
    var original: MkComposedLigature,
)

/** Combined (one selectable glyph) vs. decomposed (constituent nodes + fidelity offsets) state (D-108). */
@Serializable
sealed class MkLigatureState {
    @Serializable
    data class Composed(var ligature: MkComposedLigature) : MkLigatureState()

    @Serializable
    data class Decomposed(var ligature: MkDecomposedLigature) : MkLigatureState()
}

/** One ligature cluster (glossary: Ligature Group). */
@Serializable
data class MkLigatureGroup(
    var id: MkNodeId = MkNodeId(),
    var state: MkLigatureState,
    /** All constituent codepoints of the ligature (e.g. lam + alif for لا), per D-106. */
    var provenance: MkProvenance,
    var transform: MkTransform2D = MkTransform2D.identity,
    var style: MkStyle = MkStyle.default,
    /** Marks positioned against the ligature as a whole (e.g. shadda over a lam-alif). */
    var attachedMarks: List<MkNodeId> = emptyList(),
    var isHidden: Boolean = false,
    var isLocked: Boolean = false,
)
