package net.binjamshid.makhtoot.mk.foundation.geometry

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Canonical 2-D point type used across the scene graph, canvas, and export
 * pipelines. Swift's `MKPoint` is a `typealias` to `CGPoint`; Kotlin has no
 * built-in equivalent value type at this (platform-agnostic, non-Compose)
 * layer, so this is a real, ported `data class` rather than a typealias —
 * a documented mechanical substitution (`ANDROID_SPINE.md` §9 deviation
 * logging), not a stub. `@Serializable` (real compiler confirmed this is
 * required: every `@Serializable` type that embeds an `MkPoint`/`MkSize`
 * field, e.g. `MkTransform2D`, fails to compile otherwise with "Serializer
 * has not been found for type ...").
 */
@Serializable
data class MkPoint(val x: Double = 0.0, val y: Double = 0.0) {
    companion object {
        val zero = MkPoint(0.0, 0.0)
    }
}

/** Canonical 2-D size type. See [MkPoint]. Ports `MKSize` (`typealias` to `CGSize`). */
@Serializable
data class MkSize(val width: Double = 0.0, val height: Double = 0.0) {
    companion object {
        val zero = MkSize(0.0, 0.0)
    }
}

/** Canonical rectangle type. See [MkPoint]. Ports `MKRect` (`typealias` to `CGRect`). */
@Serializable
data class MkRect(
    val x: Double = 0.0,
    val y: Double = 0.0,
    val width: Double = 0.0,
    val height: Double = 0.0,
) {
    companion object {
        val zero = MkRect(0.0, 0.0, 0.0, 0.0)
    }
}

/**
 * Ports `CGAffineTransform`, which has no Kotlin/Android built-in equivalent at
 * this layer. Not itself a row in the `MKFoundation` port map (`CGAffineTransform`
 * is a CoreGraphics platform type, not a MakhtootKit source file) — added here as
 * necessary supporting infrastructure for [MkTransform2D], per `ANDROID_SPINE.md`
 * §9's deviation-logging convention. Recorded in `BATCH-1.3.md`.
 */
@Serializable
data class MkAffineTransform(
    val a: Double,
    val b: Double,
    val c: Double,
    val d: Double,
    val tx: Double,
    val ty: Double,
) {
    companion object {
        val identity = MkAffineTransform(a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0)
    }
}

/**
 * Small geometry helpers shared by the canvas, path-text, and export modules.
 * Ports `MKGeometryMath` (`Sources/MKFoundation/Geometry/MKGeometry.swift`).
 */
object MkGeometryMath {
    /** Normalizes an angle in radians into the `[0, 2*PI)` range. */
    fun normalizeAngle(radians: Double): Double = throw MkNotYetPorted("MkGeometryMath.normalizeAngle")

    /** Returns the smallest rectangle that contains both inputs. */
    fun union(a: MkRect, b: MkRect): MkRect = throw MkNotYetPorted("MkGeometryMath.union")

    /** Fits [size] inside [bounds] preserving aspect ratio (contain, not cover). */
    fun aspectFit(size: MkSize, bounds: MkSize): MkSize = throw MkNotYetPorted("MkGeometryMath.aspectFit")
}
