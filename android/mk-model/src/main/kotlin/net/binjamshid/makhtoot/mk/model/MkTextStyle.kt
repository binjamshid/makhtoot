package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable

/**
 * Per-object text styling. Ports `Sources/MKModel/MKTextStyle.swift`.
 */

/** D-108's discretionary-ligatures three-state toggle. */
@Serializable
enum class MkLigatureSetting {
    /** Standard ligatures only (font default contextual shaping). */
    Standard,

    /** Standard + discretionary ligatures enabled. */
    DiscretionaryOn,

    /** Ligatures disabled entirely. */
    Off,
}

/** Paragraph base direction (D-109). Default is `RightToLeft`. */
@Serializable
enum class MkBaseDirection {
    RightToLeft,
    LeftToRight,

    /** Explicit RTL override regardless of first-strong-character detection. */
    RightToLeftOverride,
}

/** One cluster-pair kerning override (D-105's cluster model). */
@Serializable
data class MkKernOverride(
    var clusterPairIndex: Int,
    var value: Double,
)

/** Full per-object text style. All fields have documented v1 defaults. */
@Serializable
data class MkTextStyle(
    var font: MkFontRef = MkFontRef.systemFallback,
    var pointSize: Double = 36.0,
    var kerningOverrides: List<MkKernOverride> = emptyList(),
    /** Points added per glyph advance. */
    var tracking: Double = 0.0,
    /** Points, positive = upward. */
    var baselineShift: Double = 0.0,
    /** Multiple of `pointSize`. Default `1.2`. */
    var lineHeightMultiple: Double = 1.2,
    var ligatureSetting: MkLigatureSetting = MkLigatureSetting.Standard,
    var baseDirection: MkBaseDirection = MkBaseDirection.RightToLeft,
    var isBold: Boolean = false,
    var isItalic: Boolean = false,
    var isUnderline: Boolean = false,
    var isStrikethrough: Boolean = false,
    var highlightColor: MkSolidColor? = null,
) {
    companion object {
        /** Documented default: system font, 36pt, no kerning/tracking/baseline adjustment, 1.2x line height, RTL. */
        val default = MkTextStyle()
    }
}
