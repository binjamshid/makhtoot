package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

/**
 * Node-level paint style: fill (v1 = solid color only, D-111/D-117), stroke,
 * shadow. Ports `Sources/MKModel/MKNodeStyle.swift`.
 */

/** Color working space tag persisted alongside every color value (D-117: only `srgb` exists in v1). */
@Serializable
enum class MkColorSpace {
    Srgb,
}

/**
 * Document-stored color: sRGB components (may exceed `0...1`) plus an
 * optional named-swatch reference. Distinct from the `mk-color` *module*
 * (colour-space conversion, CMYK, ICC pipeline) — deliberately named
 * `MkSolidColor` rather than `MkColor` to avoid confusion between "the value
 * stored on a node" and "the conversion engine."
 */
@Serializable
data class MkSolidColor(
    var space: MkColorSpace = MkColorSpace.Srgb,
    var r: Double,
    var g: Double,
    var b: Double,
    var a: Double = 1.0,
    var swatch: String? = null,
) {
    companion object {
        val black = MkSolidColor(r = 0.0, g = 0.0, b = 0.0)
        val white = MkSolidColor(r = 1.0, g = 1.0, b = 1.0)

        /** Default canvas/document ink color — a warm near-black (D-126). */
        val defaultInk = MkSolidColor(r = 0.114, g = 0.098, b = 0.086)
    }
}

/** v1 fill: solid color only (D-111). `None` exists for the many nodes with no paint at all. */
@Serializable
sealed class MkFill {
    @Serializable
    object None : MkFill()

    @Serializable
    data class Solid(var color: MkSolidColor) : MkFill()
}

@Serializable
enum class MkLineJoin {
    Miter,
    Round,
    Bevel,
}

@Serializable
enum class MkLineCap {
    Butt,
    Round,
    Square,
}

@Serializable
data class MkStroke(
    var color: MkSolidColor,
    var width: Double,
    var join: MkLineJoin = MkLineJoin.Miter,
    var cap: MkLineCap = MkLineCap.Butt,
)

@Serializable
data class MkShadow(
    var color: MkSolidColor,
    var blur: Double,
    var offset: MkSize,
)

/**
 * Node paint style bundle (D-111: "style (fill: solid color v1; stroke;
 * shadow)"). Opacity is deliberately **not** a member here — D-111 lists
 * `opacity` as a sibling field of `style` on the node itself ([MkNodeCore.opacity]).
 */
@Serializable
data class MkStyle(
    var fill: MkFill = MkFill.None,
    var stroke: MkStroke? = null,
    var shadow: MkShadow? = null,
) {
    companion object {
        val default = MkStyle()
    }
}
