package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkPlatformPath

/**
 * Builds the highlight-ribbon path used to paint a path-text selection
 * (render + export). Ports `Sources/MKPathText/PathHighlightRibbon.swift`.
 */
object MkPathHighlightRibbon {
    /** The ribbon path spanning arc length [from]/[to] along [lut], or `null` for a degenerate span. */
    fun path(
        lut: MkArcLengthLUT,
        from: Double,
        to: Double,
        ascent: Double,
        descent: Double,
        baselineOffset: Double,
        insideOut: Boolean,
        overflow: MkPathOverflowPolicy,
        maxJoinAngleDegrees: Double = 25.0,
    ): MkPlatformPath? = throw MkNotYetPorted("MkPathHighlightRibbon.path")
}
