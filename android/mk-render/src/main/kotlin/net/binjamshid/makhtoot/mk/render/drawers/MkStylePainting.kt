package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkSolidColor
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkPlatformColor
import net.binjamshid.makhtoot.mk.render.MkPlatformPath
import net.binjamshid.makhtoot.mk.render.MkRenderQuality

// Ports `Sources/MKRender/Drawers/StylePainting.swift`. Shared fill/stroke/
// shadow application every drawer uses on its own content path — one place
// implementing the "shadow applied per node, documented" rule (no double-
// darkening of overlapping mark/base shadows) and the degradation-ladder
// shadow simplification (`.reduced` fidelity: flat offset fill at 30% alpha,
// no blur, no transparency layer). Swift namespace enum (no cases) → Kotlin
// `object`.
object MkStylePainting {
    /**
     * Fills+strokes [path] per [style], honoring shadow + the current
     * [MkRenderQuality] fidelity's shadow simplification. Does NOT apply
     * opacity (that's a `MkSceneRenderer`-level transparency-layer concern).
     *
     * @param strokeWidthCompensationScale P14 hardening: cancels a painted
     *   node's own transform scale out of the stroke width so `stroke.width`
     *   means an absolute document-point value regardless of the shape's box
     *   dimensions. Defaults to `(1, 1)` (no compensation).
     */
    fun paint(
        path: MkPlatformPath,
        style: MkStyle,
        quality: MkRenderQuality,
        into: MkDrawingSurface,
        strokeWidthCompensationScale: MkSize = MkSize(1.0, 1.0),
    ): Unit = throw MkNotYetPorted("MkStylePainting.paint")

    /**
     * `.reduced`-fidelity flat shadow fallback, drawn explicitly against
     * [path] (offset copy, 30% alpha, no blur) — called by drawers BEFORE
     * [paint] when quality fidelity is `.reduced` and `style.shadow != null`.
     */
    fun paintReducedShadowIfNeeded(
        path: MkPlatformPath,
        style: MkStyle,
        quality: MkRenderQuality,
        into: MkDrawingSurface,
    ): Unit = throw MkNotYetPorted("MkStylePainting.paintReducedShadowIfNeeded")
}

/**
 * sRGB platform color (D-117: working space = extended sRGB; document
 * stores plain sRGB components). Ports the Swift `extension MKSolidColor`
 * computed property `cgColor: CGColor` — a top-level Kotlin extension
 * property, since Kotlin has no `extension` declaration syntax tied to the
 * origin type's own file. Renamed from `cgColor` to `platformColor`
 * (documented deviation, `ANDROID_SPINE.md` §9): "cg" names CoreGraphics,
 * which has no meaning on Android; the return type is [MkPlatformColor],
 * this module's placeholder for the eventual `android.graphics.Color`-backed
 * type.
 */
val MkSolidColor.platformColor: MkPlatformColor
    get() = throw MkNotYetPorted("MkSolidColor.platformColor")
