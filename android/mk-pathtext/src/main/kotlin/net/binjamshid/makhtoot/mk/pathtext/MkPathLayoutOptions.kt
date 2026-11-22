package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkPathSide
import net.binjamshid.makhtoot.mk.model.MkPathSpacingMode
import net.binjamshid.makhtoot.mk.model.MkPathLayoutOptions as MkModelPathLayoutOptions

/**
 * `mk-model`'s `MkPathLayoutOptions` (`startOffset`/`side`/`spacingMode`) is
 * the PERSISTED slice of these knobs. This module's [MkPathLayoutOptions]
 * is the fuller ENGINE-level options set (alignment, baseline-offset
 * magnitude, overflow policy, inside-out flip, closed-path gap, extra
 * letter spacing, join-continuity thresholds) — engine-only, not yet
 * persisted. Ports `Sources/MKPathText/PathLayoutOptions.swift`.
 *
 * **Naming-rule collision, documented (`ANDROID_SPINE.md` §3.3/§9), not
 * silent:** both this module's `PathLayoutOptions` and `mk-model`'s
 * `MKPathLayoutOptions` (`Sources/MKModel/MKNode.swift`) mechanically
 * transform to the same simple name `MkPathLayoutOptions`. Both keep that
 * exact name in their own package (mechanical transform preserved, matching
 * how the two coexist disambiguated only by module in Swift); this file
 * imports the `mk-model` one under the alias `MkModelPathLayoutOptions` so
 * both are referenceable together without a rename.
 */

enum class MkPathAlignment {
    /** The laid text's arc-length start sits at `startOffset`. */
    Start,

    /** The laid text is centered within the available path span. */
    Center,

    /** The laid text's arc-length end sits at the path's end (open) or wraps flush before the gap (closed). */
    End,
}

enum class MkPathOverflowPolicy {
    /** Glyphs whose span exceeds the path's remaining length are excluded from the placement list. */
    Clip,

    /** Glyphs beyond the end continue in a straight line along the exit tangent. */
    ContinueTangent,
}

data class MkPathLayoutOptions(
    // Persisted slice (mirrors mk-model's MkPathLayoutOptions)
    var startOffset: Double = 0.0,
    var side: MkPathSide = MkPathSide.Center,
    var spacingMode: MkPathSpacingMode = MkPathSpacingMode.Natural,

    // Engine-only (not yet persisted)
    /** Points, magnitude only — sign/side is resolved from `side`. */
    var baselineOffsetMagnitude: Double = 0.0,
    var alignment: MkPathAlignment = MkPathAlignment.Start,
    var overflow: MkPathOverflowPolicy = MkPathOverflowPolicy.ContinueTangent,
    /** Flips text to the inside of a circle (rotate placement by PI). */
    var insideOut: Boolean = false,
    /** Points of blank arc length inserted once per revolution on a closed path. */
    var closedPathGap: Double = 0.0,
    /** Extra points of advance added per glyph span, on top of the captured advance. */
    var letterSpacingExtra: Double = 0.0,
    /** If the tangent swings by more than this many degrees across one glyph's span, rotation smooths across it. Default 25 degrees. */
    var maxJoinAngleDegrees: Double = 25.0,
    /** If adjacent base glyphs' rotation differs by more than this many degrees, `curvatureWarning` is set. Default 40 degrees. */
    var curvatureWarningThresholdDegrees: Double = 40.0,
) {
    /** Seeds the persisted slice from a `pathText` node's stored layout options; engine-only fields at their defaults. */
    constructor(node: MkModelPathLayoutOptions) : this(
        startOffset = node.startOffset,
        side = node.side,
        spacingMode = node.spacingMode,
    )

    /** The persisted slice, for writing back into `MkPathTextNode.layout`. */
    val persistedSlice: MkModelPathLayoutOptions
        get() = throw MkNotYetPorted("MkPathLayoutOptions.persistedSlice")

    /** Signed baseline offset (points, along the frame's left normal). */
    val signedBaselineOffset: Double
        get() = throw MkNotYetPorted("MkPathLayoutOptions.signedBaselineOffset")
}
