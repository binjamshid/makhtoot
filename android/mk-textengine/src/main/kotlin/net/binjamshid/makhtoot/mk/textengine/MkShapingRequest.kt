package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.model.MkSourceText
import net.binjamshid.makhtoot.mk.model.MkTextFrameSpec
import net.binjamshid.makhtoot.mk.model.MkTextStyle

/**
 * A shaping request: the text, style, and frame constraint to shape it
 * under. Ports `Sources/MKTextEngine/ShapingRequest.swift`.
 */
data class MkShapingRequest(
    var text: MkSourceText,
    var style: MkTextStyle,
    var frame: MkTextFrameSpec = MkTextFrameSpec.SingleLine,
) {
    companion object {
        /** Convenience overload constructing [text] from a plain [string]. */
        operator fun invoke(string: String, style: MkTextStyle, frame: MkTextFrameSpec = MkTextFrameSpec.SingleLine): MkShapingRequest =
            throw net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted("MkShapingRequest.init(string)")
    }
}
