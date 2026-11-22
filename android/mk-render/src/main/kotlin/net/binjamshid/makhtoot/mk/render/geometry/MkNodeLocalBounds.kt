package net.binjamshid.makhtoot.mk.render.geometry

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkNode

/**
 * Per-node bounding-box math: [localBounds] is a node's own extent BEFORE
 * its `core.transform` is applied; [worldBounds] applies the node's
 * transform on top. Ports `Sources/MKRender/Geometry/NodeLocalBounds.swift`.
 */
object MkNodeLocalBounds {
    /** [localBounds] with the node's own `core.transform` applied. */
    fun worldBounds(node: MkNode): MkRect = throw MkNotYetPorted("MkNodeLocalBounds.worldBounds")

    /** Bounds in the node's own local space — the per-kind intrinsic extent, or the union of a group's children. */
    fun localBounds(node: MkNode): MkRect = throw MkNotYetPorted("MkNodeLocalBounds.localBounds")
}
