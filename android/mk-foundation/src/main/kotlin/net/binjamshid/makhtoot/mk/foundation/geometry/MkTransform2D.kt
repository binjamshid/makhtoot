package net.binjamshid.makhtoot.mk.foundation.geometry

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * The canonical node transform representation for the scene graph (D-111:
 * "decomposed, not raw matrix"). Ports `Sources/MKFoundation/Geometry/MKTransform2D.swift`.
 *
 * Composition order is scale -> rotate -> translate (standard 2-D sprite
 * convention): a point is first scaled about the origin, then rotated, then
 * translated to [position].
 */
@Serializable
data class MkTransform2D(
    /** Translation, in the parent's coordinate space. */
    var position: MkPoint = MkPoint.zero,
    /** Rotation in radians, counter-clockwise positive (CoreGraphics convention). */
    var rotation: Double = 0.0,
    /** Non-uniform scale factors applied before rotation. */
    var scale: MkSize = MkSize(1.0, 1.0),
) {
    companion object {
        val identity = MkTransform2D()

        /**
         * Decomposes an arbitrary affine transform back into position/rotation/scale.
         * Ports `MKTransform2D.init(decomposing:)`.
         */
        fun decomposing(matrix: MkAffineTransform): MkTransform2D =
            throw MkNotYetPorted("MkTransform2D.decomposing")
    }

    /** The equivalent [MkAffineTransform], derived fresh from the decomposed fields on every access. */
    val affineTransform: MkAffineTransform
        get() = throw MkNotYetPorted("MkTransform2D.affineTransform")

    /** Concatenates `this` followed by [other]. */
    fun concatenating(other: MkTransform2D): MkTransform2D = throw MkNotYetPorted("MkTransform2D.concatenating")

    /** The inverse transform, decomposed. */
    fun inverted(): MkTransform2D = throw MkNotYetPorted("MkTransform2D.inverted")

    /** Maps a point from the transform's local space into its parent space. */
    fun apply(point: MkPoint): MkPoint = throw MkNotYetPorted("MkTransform2D.apply")
}
