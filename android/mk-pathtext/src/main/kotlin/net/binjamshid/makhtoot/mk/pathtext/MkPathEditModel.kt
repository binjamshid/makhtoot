package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

/**
 * Pure geometry operations over [MkBezierPathModel] for `mk-canvas` to drive
 * from gesture recognizers. Ports `Sources/MKPathText/PathEditModel.swift`.
 * Contains zero gesture/UI code — only pure functions.
 */

/** One hit-testable control point on a live path: an anchor's own point, or one of its handles. */
data class MkPathHandleId(
    var anchorId: MkPathAnchorId,
    var kind: Kind,
) {
    enum class Kind { Anchor, HandleIn, HandleOut }
}

/** A hit target `mk-canvas` can present as a draggable handle. */
data class MkPathHitTarget(
    var id: MkPathHandleId,
    var position: MkPoint,
)

/** How dragging one handle affects its opposite sibling on the same anchor. */
enum class MkPathHandleMode {
    /** The opposite handle mirrors this one exactly — smooth (C1-continuous) curves. */
    Mirrored,

    /** The opposite handle is left untouched — corner points / cusps. */
    Free,
}

object MkPathEditModel {
    /** Every anchor point plus its present handles, as hit targets. */
    fun hitTargets(path: MkBezierPathModel): List<MkPathHitTarget> = throw MkNotYetPorted("MkPathEditModel.hitTargets")

    /** The nearest hit target to [point] within [tolerance], or `null`. */
    fun nearestHitTarget(point: MkPoint, path: MkBezierPathModel, tolerance: Double = Double.MAX_VALUE): MkPathHitTarget? =
        throw MkNotYetPorted("MkPathEditModel.nearestHitTarget")

    /** Moves anchor [id] to [newPoint], optionally moving its handles along with it. */
    fun moveAnchor(id: MkPathAnchorId, newPoint: MkPoint, path: MkBezierPathModel, moveHandles: Boolean = true): MkBezierPathModel =
        throw MkNotYetPorted("MkPathEditModel.moveAnchor")

    /** Moves handle [handleId] to [newPoint] under [mode] (mirrored/free). */
    fun moveHandle(handleId: MkPathHandleId, newPoint: MkPoint, path: MkBezierPathModel, mode: MkPathHandleMode): MkBezierPathModel =
        throw MkNotYetPorted("MkPathEditModel.moveHandle")

    /** Inserts a new anchor at arc [length] along [path], using [lut] for the exact split point. */
    fun insertAnchor(length: Double, path: MkBezierPathModel, lut: MkArcLengthLUT): MkBezierPathModel =
        throw MkNotYetPorted("MkPathEditModel.insertAnchor")

    /** Deletes anchor [id] from [path], or `null` if doing so would make the path structurally invalid. */
    fun deleteAnchor(id: MkPathAnchorId, path: MkBezierPathModel): MkBezierPathModel? =
        throw MkNotYetPorted("MkPathEditModel.deleteAnchor")

    /** Toggles [path]'s open/closed state, or `null` if the result would be structurally invalid. */
    fun toggleClosed(path: MkBezierPathModel): MkBezierPathModel? = throw MkNotYetPorted("MkPathEditModel.toggleClosed")

    /** Whether [path] is structurally valid (>=2 anchors open / >=3 closed). */
    fun isValid(path: MkBezierPathModel): Boolean = throw MkNotYetPorted("MkPathEditModel.isValid")
}
