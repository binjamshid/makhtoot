package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkAssetRef

// Ports `Sources/MKRender/AssetProviding.swift`. Asset resolution is
// decoupled from `:mk-render` the same way font resolution already is
// (`MkFontProviding`) — this lets any caller (a future `mk-persistence`-aware
// document session, or a test fixture) hand in resolved images without
// `:mk-render` depending on `:mk-persistence`/an asset store (not a
// `ANDROID_SPINE.md` §3.2 dependency edge).

/**
 * Resolves scene asset references to decoded platform images/PDF pages.
 * `nil`/`null` = missing/undecoded — the renderer records a `.missingAsset`
 * substitution and skips drawing that node's image, never crashes or
 * silently draws nothing without reporting it.
 */
interface MkAssetProviding {
    /** Resolves a raster asset (`MkImageKind.Raster`) to a decoded bitmap. */
    fun resolveRasterImage(ref: MkAssetRef): MkPlatformImage?

    /** Resolves a vector PDF asset (`MkImageKind.VectorPdf`) to its first page. */
    fun resolvePdfPage(ref: MkAssetRef): MkPlatformPdfPage?
}

/**
 * Resolves nothing — every asset lookup reports a `.missingAsset`
 * substitution. The default for `MkSceneRenderer`/`MkSnapshotRenderer`
 * until a real provider (document-session-backed) is injected; safe for
 * fixtures/tests that don't exercise `MkImageNode`.
 */
class MkEmptyAssetProvider : MkAssetProviding {
    override fun resolveRasterImage(ref: MkAssetRef): MkPlatformImage? =
        throw MkNotYetPorted("MkEmptyAssetProvider.resolveRasterImage")

    override fun resolvePdfPage(ref: MkAssetRef): MkPlatformPdfPage? =
        throw MkNotYetPorted("MkEmptyAssetProvider.resolvePdfPage")
}
