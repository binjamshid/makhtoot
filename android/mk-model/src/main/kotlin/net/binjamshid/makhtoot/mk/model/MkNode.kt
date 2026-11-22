package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode

/**
 * `MkNode`, the seven D-111 cases, and their payload structs. Ports
 * `Sources/MKModel/MKNode.swift`.
 *
 * **Custom-`Codable`-conformance note (applies to every type below with a
 * hand-written Swift `init(from:)`/`encode(to:)` pair — `MkPathTextNode`,
 * `MkAssetRef`, `MkImageNode`, `MkBackgroundContent`, `MkNode` itself):**
 * Kotlin's serialization model is annotation-driven (`@Serializable`), not
 * per-type method pairs, so those Swift `init(from:)`/`encode(to:)` methods
 * have **no direct one-to-one Kotlin method equivalent** — this is the one
 * documented exception to "port every symbol" in this module
 * (`ANDROID_SPINE.md` §9), recorded here once rather than per-type. The
 * additive-field back-compat behavior (`decodeIfPresent(...) ?? default`)
 * is achieved for free by giving the corresponding Kotlin property a default
 * value. `MkAssetRef`'s hand-written decoder additionally performs
 * path-traversal validation (S-2) that is NOT free with a derived
 * serializer — flagged explicitly on that type below so Batch 2 does not
 * silently drop it; it must be reintroduced via a custom `KSerializer`.
 */

/** Fields shared by every node case (composition, not inheritance — D-111). */
@Serializable
data class MkNodeCore(
    var id: MkNodeId = MkNodeId(),
    /** User-visible layer name. */
    var name: String,
    var transform: MkTransform2D = MkTransform2D.identity,
    /** Paint order among sibling nodes; index-order in the owning array is the source of truth. */
    var zOrder: Int = 0,
    var opacity: Double = 1.0,
    var style: MkStyle = MkStyle.default,
    var isLocked: Boolean = false,
    var isHidden: Boolean = false,
)

// MARK: - Node payloads

@Serializable
data class MkGroupNode(
    var core: MkNodeCore,
    var children: List<MkNode> = emptyList(),
    /** Parent-group line-height control; `null` = each child's own style applies. */
    var lineHeightOverride: Double? = null,
)

@Serializable
data class MkStyleRun(
    var utf16Start: Int,
    var utf16Length: Int,
    var style: MkTextStyle,
)

/** Source string + per-range style overrides for a reflowable text node. */
@Serializable
data class MkSourceText(
    var string: String,
    var styleRuns: List<MkStyleRun> = emptyList(),
)

@Serializable
sealed class MkTextFrameSpec {
    @Serializable
    object SingleLine : MkTextFrameSpec()

    @Serializable
    data class WidthConstrained(var width: Double) : MkTextFrameSpec()
}

/** Reflowable, shaped text bound to a source string (glossary: Live Text object). */
@Serializable
data class MkLiveTextNode(
    var core: MkNodeCore,
    var text: MkSourceText,
    var style: MkTextStyle = MkTextStyle.default,
    var frame: MkTextFrameSpec = MkTextFrameSpec.SingleLine,
)

@Serializable
enum class MkPathSide {
    Above,
    Below,
    Center,
}

@Serializable
enum class MkPathSpacingMode {
    Natural,
    Justify,
}

@Serializable
data class MkPathLayoutOptions(
    var startOffset: Double = 0.0,
    var side: MkPathSide = MkPathSide.Above,
    var spacingMode: MkPathSpacingMode = MkPathSpacingMode.Natural,
)

/** Live text on a Bezier path — still reflowable until arranged (D-110). */
@Serializable
data class MkPathTextNode(
    var core: MkNodeCore,
    var text: MkSourceText,
    var style: MkTextStyle = MkTextStyle.default,
    var path: MkBezierPathData,
    var layout: MkPathLayoutOptions = MkPathLayoutOptions(),
    /** Per-glyph user-applied nudges. Additive/defaulted field (empty for pre-existing documents). */
    var glyphOffsets: Map<MkPathGlyphOffsetKey, MkPathGlyphOffset> = emptyMap(),
)

@Serializable
sealed class MkShapeGeometry {
    /** `cornerRadius` is expressed in the same unit-square-relative local space as the rest of `.rect`'s geometry. */
    @Serializable
    data class Rect(var cornerRadius: Double) : MkShapeGeometry()

    @Serializable
    object Ellipse : MkShapeGeometry()

    @Serializable
    object Line : MkShapeGeometry()

    @Serializable
    data class Polygon(var points: List<net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint>) : MkShapeGeometry()

    @Serializable
    data class Path(var pathData: MkPathData) : MkShapeGeometry()

    @Serializable
    data class Asset(var ref: MkAssetRef) : MkShapeGeometry()
}

@Serializable
data class MkShapeNode(
    var core: MkNodeCore,
    var geometry: MkShapeGeometry,
)

/**
 * Content-addressed reference into the document's `assets/` store.
 *
 * **S-2 (path traversal via unvalidated asset refs) — flagged, not silently
 * dropped:** the Swift source's hand-written `init(from:)` rejects any
 * `digest`/`ext` value containing a character outside `[a-f0-9]`/`[a-z0-9]`
 * respectively (so neither can ever form `.`/`/`/`..` once interpolated into
 * a filesystem path component). The plain `@Serializable` derived here does
 * **not** perform that validation — Batch 2's `mk-model`/`mk-persistence`
 * implementation MUST reintroduce it via a custom `KSerializer` (or
 * equivalent validating factory) before any asset path is ever built from a
 * decoded `MkAssetRef`, or the same path-traversal vulnerability the Swift
 * fix closes is reopened on Android.
 */
@Serializable
data class MkAssetRef(
    var digest: String,
    var ext: String,
)

@Serializable
enum class MkImageKind {
    Raster,
    VectorPDF,
    VectorSVG,
}

@Serializable
data class MkImageNode(
    var core: MkNodeCore,
    var asset: MkAssetRef,
    var kind: MkImageKind,
    /** D-119 gating marker: true when this placement counts toward `premiumContentPresent`. Additive field, defaults to `false`. */
    var isPhotoBackgroundUse: Boolean = false,
)

/** How a `.image` canvas background fits the canvas bounds (P5.3). */
@Serializable
enum class MkBackgroundImageFit {
    Cover,
    Contain,
}

@Serializable
sealed class MkBackgroundContent {
    @Serializable
    data class Solid(var color: MkSolidColor) : MkBackgroundContent()

    /** `fit` is an additive, defaulted field on an already-persisted case; defaults to `Cover`. */
    @Serializable
    data class Image(var ref: MkAssetRef, var fit: MkBackgroundImageFit = MkBackgroundImageFit.Cover) : MkBackgroundContent()
}

/** Canvas background: solid color (free) or image asset (premium). Exactly one per scene. */
@Serializable
data class MkBackgroundNode(
    var core: MkNodeCore,
    var content: MkBackgroundContent = MkBackgroundContent.Solid(MkSolidColor.white),
) {
    companion object {
        fun defaultBackground(): MkBackgroundNode = throw MkNotYetPorted("MkBackgroundNode.defaultBackground")
    }
}

// MARK: - The node enum

/** The D-111 node enum: `group`, `liveText`, `pathText`, `arranged`, `shape`, `image`, `background`. */
@Serializable
sealed class MkNode {
    @Serializable
    data class Group(var node: MkGroupNode) : MkNode()

    @Serializable
    data class LiveText(var node: MkLiveTextNode) : MkNode()

    @Serializable
    data class PathText(var node: MkPathTextNode) : MkNode()

    @Serializable
    data class Arranged(var node: MkArrangedTextNode) : MkNode()

    @Serializable
    data class Shape(var node: MkShapeNode) : MkNode()

    @Serializable
    data class Image(var node: MkImageNode) : MkNode()

    @Serializable
    data class Background(var node: MkBackgroundNode) : MkNode()

    val id: MkNodeId
        get() = throw MkNotYetPorted("MkNode.id")

    val core: MkNodeCore
        get() = throw MkNotYetPorted("MkNode.core")

    /** Returns a copy of `this` with `core` replaced — the primitive every higher-level command is built on. */
    fun withCore(newCore: MkNodeCore): MkNode = throw MkNotYetPorted("MkNode.withCore")

    /** `.group`'s children, or `null` for every other case. */
    val children: List<MkNode>?
        get() = throw MkNotYetPorted("MkNode.children")
}
