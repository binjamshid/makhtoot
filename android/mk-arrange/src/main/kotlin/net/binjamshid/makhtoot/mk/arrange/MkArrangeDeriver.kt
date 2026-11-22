package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkFill
import net.binjamshid.makhtoot.mk.model.MkSolidColor
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.textengine.MkShapingCaptureResult

/**
 * The D-106 derivation pipeline: converts one [MkShapingCaptureResult]
 * (frozen shaping output) plus the originating source string/style into an
 * [MkArrangedComposition] — the non-reflowing, fully-provenanced structure
 * `mk-model` declares. Ports `Sources/MKArrange/ArrangeDeriver.swift`.
 *
 * Only the type's public surface (init + `derive`) is ported here — the
 * Swift file's extensive private helper methods (per-cluster-kind
 * handlers, coordinate math, provenance construction) are Batch 4
 * implementation detail, not part of the Batch 1 contract.
 */
class MkArrangeDeriver(private val fonts: MkFontProviding = MkSystemFontStubProvider()) {
    /**
     * Input: `(sourceText, MkTextStyle, MkShapingCaptureResult, PathPlacementProviding)` ->
     * `MkArrangedComposition`. `paintStyle` is the source node's own style — every
     * arranged child carries its own independent [MkStyle] copied from it.
     */
    suspend fun derive(
        sourceText: String,
        style: MkTextStyle,
        capture: MkShapingCaptureResult,
        paintStyle: MkStyle = MkStyle(fill = MkFill.Solid(MkSolidColor.defaultInk)),
        pathData: MkBezierPathData? = null,
        placement: MkPathPlacementProviding = MkIdentityPlacement(),
    ): MkArrangedComposition = throw MkNotYetPorted("MkArrangeDeriver.derive")
}
