package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

/**
 * Coordinate-system documentation and conversion helpers for the shaping
 * capture in this module (WS-03 packet §5 task 3: "documented coordinate
 * convention"). Ports `Sources/MKTextEngine/CoordinateSpace.swift`.
 *
 * **Line-local space.** Every position captured into `MkShapedRun.positions`
 * is exactly what the shaper reported, relative to the **line origin** (not
 * the paragraph origin, not any view). Core Text's space is **y-up** ،
 * increasing `y` moves *up* the page, matching Core Graphics/PDF
 * convention, NOT a y-down view space. This module never flips or rewrites
 * a captured position; the raw shaper value is the source of truth
 * (ARCHITECTURE.md §4.4: "Fractional positions are kept exactly as
 * returned; rounding happens only at rasterization").
 *
 * **Paragraph stacking.** `MkShapingEngine.shapeParagraph` advances each
 * subsequent line downward on the page in the shaper's own y-up terms:
 * line N+1's baseline sits `(ascent + descent + leading) ×
 * lineHeightMultiple` *below* line N's. This module does not itself
 * perform that composition (each `MkShapedLine` stays in its own
 * line-local origin) ، stacking into one paragraph-local frame is a
 * rendering-time concern (MKRender, P4).
 *
 * **View conversion.** Consumers drawing into a y-down view/layer context
 * must flip. [flippedForUIKit] is the one pure helper this module ships
 * for that; it is intentionally minimal.
 */
object MkCoordinateSpace {
    /**
     * Flips a Core-Text-style (y-up, line-relative) point into a y-down
     * frame of the given [frameHeight] (e.g. a line's `ascent + descent`).
     * Pure function, no state, no platform-view dependency.
     */
    fun flippedForUIKit(point: MkPoint, frameHeight: Double): MkPoint =
        throw MkNotYetPorted("MkCoordinateSpace.flippedForUIKit")
}
