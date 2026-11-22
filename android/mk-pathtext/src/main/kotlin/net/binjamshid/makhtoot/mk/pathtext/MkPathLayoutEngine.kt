package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.textengine.MkShapedLine

/**
 * Lays out a shaped line's glyphs along a path (D-110). Ports
 * `Sources/MKPathText/PathLayoutEngine.swift`.
 */
object MkPathLayoutEngine {
    /** Lays out [line] along [path] (builds its own arc-length table internally). */
    fun layout(
        line: MkShapedLine,
        lineIndex: Int = 0,
        path: MkBezierPathModel,
        options: MkPathLayoutOptions,
        userOffsets: Map<MkPathClusterProvenanceKey, MkPathGlyphUserOffset> = emptyMap(),
    ): MkPathLayoutResult = throw MkNotYetPorted("MkPathLayoutEngine.layout(path)")

    /** Lays out [line] along an already-built [lut] (open path). */
    fun layout(
        line: MkShapedLine,
        lineIndex: Int = 0,
        lut: MkArcLengthLUT,
        options: MkPathLayoutOptions,
        userOffsets: Map<MkPathClusterProvenanceKey, MkPathGlyphUserOffset> = emptyMap(),
    ): MkPathLayoutResult = throw MkNotYetPorted("MkPathLayoutEngine.layout(lut)")

    /** Lays out [line] along a closed path's [lut], wrapping the text around the loop as needed. */
    fun layoutClosed(
        line: MkShapedLine,
        lineIndex: Int = 0,
        lut: MkArcLengthLUT,
        options: MkPathLayoutOptions,
        userOffsets: Map<MkPathClusterProvenanceKey, MkPathGlyphUserOffset> = emptyMap(),
    ): MkPathLayoutResult = throw MkNotYetPorted("MkPathLayoutEngine.layoutClosed")
}
