package net.binjamshid.makhtoot.mk.model.arranged

import kotlinx.serialization.Serializable

/**
 * Joining-form vocabulary shared by [MkGlyphNode]. D-107. Ports
 * `Sources/MKModel/Arranged/JoiningForm.swift`.
 */

/** Contextual joining form of an Arabic letter — isolated / initial / medial / final. */
@Serializable
enum class MkJoiningForm {
    Isolated,
    Initial,
    Medial,
    Final,
}

/** Full joining state of a glyph node: its resolved form plus whether it currently joins its logical neighbors. */
@Serializable
data class MkJoiningState(
    var form: MkJoiningForm,
    var joinsPrevious: Boolean,
    var joinsNext: Boolean,
    var brokenByUser: Boolean = false,
) {
    companion object {
        /** A single, unjoined letter — the default for a freshly-arranged isolated glyph. */
        val isolatedDefault = MkJoiningState(form = MkJoiningForm.Isolated, joinsPrevious = false, joinsNext = false)
    }
}
