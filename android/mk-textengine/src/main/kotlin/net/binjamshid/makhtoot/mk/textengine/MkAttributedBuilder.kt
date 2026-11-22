package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont
import net.binjamshid.makhtoot.mk.model.MkSourceText
import net.binjamshid.makhtoot.mk.model.MkTextStyle

/**
 * Placeholder for the built attributed-text object `NSAttributedString`
 * represents on iOS. HarfBuzz's shape-call model (the Android substitution,
 * D-303) has no equivalent "build a rich, range-styled string object" step —
 * per `ANDROID_TASK_PACKETS/BATCH-3.md` Agent 3.1's notes on this exact
 * file, the eventual real implementation replaces this return type with an
 * intermediate spec (base font handle + paragraph direction + per-range
 * resolved-style list + forced-direction flag) that `MkShapingEngine`
 * consumes to configure each `hb_buffer_t` directly. Kept as a minimal
 * opaque placeholder here (mechanical Batch 1 stub scope, `ANDROID_SPINE.md`
 * §9 documented-deviation convention — `NSAttributedString` has no entry in
 * this agent's type-mapping table) so [MkAttributedStringBuilder.make]'s
 * signature compiles; Batch 3 replaces both the type and the body at this
 * same file path.
 */
class MkAttributedText internal constructor()

/**
 * D-103's single attributed-string construction path (WS-03 packet §5
 * task 1): every shaping call in this module goes through this function so
 * attributes never diverge between capture paths (display, derivation,
 * form resolution ، ARCHITECTURE §4.3). Ports
 * `Sources/MKTextEngine/AttributedBuilder.swift`.
 *
 * P3-completion pass: consumes the real MKModel types ([MkSourceText] with
 * per-range style-run overrides, [MkTextStyle]), applies D-108 feature
 * control on the font via `MkFontFeatureControl`, and applies the forced
 * writing-direction attribute for `.rightToLeftOverride`. Per-cluster-pair
 * kerning overrides (`MkTextStyle.kerningOverrides`) are applied by
 * `MkShapingEngine` in a second pass (cluster boundaries only exist after a
 * first shape).
 */
object MkAttributedStringBuilder {
    /**
     * Builds the fully-attributed text for [text]/[style]. [resolveFont] maps
     * a style to its feature-configured font (the engine passes
     * `MkFontProviding` resolution + D-108 feature application); it is
     * called once for the base style and once per `styleRuns` override.
     * [extraKerning] carries the engine's second-pass per-range kern values
     * (UTF-16 range → points), empty on the first pass.
     */
    fun make(
        text: MkSourceText,
        style: MkTextStyle,
        resolveFont: (MkTextStyle) -> MkPlatformFont,
        extraKerning: List<Pair<IntRange, Double>> = emptyList(),
    ): MkAttributedText = throw MkNotYetPorted("MkAttributedStringBuilder.make")
}
