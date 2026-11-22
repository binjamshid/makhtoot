package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

/**
 * Ports `Sources/MKModel/MKBezierPathData.swift`. Declares two distinct,
 * non-interchangeable path encodings: [MkBezierPathData] (editable
 * anchor/control-point curves) and [MkPathData] (frozen, glyph-scale command
 * stream).
 */

/**
 * Placeholder for `CGPath`, which has no Kotlin equivalent at this
 * platform-agnostic layer. Android's real implementation (Batch 2) is
 * expected to back this with `android.graphics.Path` — documented
 * placeholder, following the same pattern as `mk-foundation`'s
 * `MkPlatformFont` (`ANDROID_SPINE.md` §9).
 */
class MkPlatformPath internal constructor()

/** One cubic Bezier segment: `start` -> `end`, with control points `c1`/`c2`. */
@Serializable
data class MkBezierSegment(
    var start: MkPoint,
    var c1: MkPoint,
    var c2: MkPoint,
    var end: MkPoint,
)

/**
 * Editable cubic Bezier path (control points + anchors, open or closed) — the
 * document representation for path-text paths (D-110) and the `pathData`
 * slot of a path-derived [net.binjamshid.makhtoot.mk.model.arranged.MkSourceTextBackup].
 */
@Serializable
data class MkBezierPathData(
    var segments: List<MkBezierSegment> = emptyList(),
    var isClosed: Boolean = false,
) {
    /** Builds a platform path by walking [segments] as cubic curves. */
    fun cgPath(): MkPlatformPath = throw MkNotYetPorted("MkBezierPathData.cgPath")
}

/**
 * Flat, glyph-scale path command stream: faithful to `CGPath` element
 * semantics, compact in JSON. Ops: `0`=move(2 coords), `1`=line(2), `2`=quad(4),
 * `3`=cubic(6), `4`=close(0). Coordinates are in glyph units scaled to
 * [unitsPerEm] (always `1000` in v1 encodes).
 */
@Serializable
data class MkPathData(
    var commands: List<Double> = emptyList(),
    var unitsPerEm: Double = 1000.0,
) {
    /** Scales `1000/em`-normalized coordinates up to [pointSize] and builds a platform path. */
    fun cgPath(pointSize: Double): MkPlatformPath = throw MkNotYetPorted("MkPathData.cgPath")

    companion object {
        /** Builds an [MkPathData] from a platform path, rounding coordinates to 2 decimals in glyph-unit space. */
        fun from(cgPath: MkPlatformPath, pointSize: Double, unitsPerEm: Double = 1000.0): MkPathData =
            throw MkNotYetPorted("MkPathData.from")
    }
}
