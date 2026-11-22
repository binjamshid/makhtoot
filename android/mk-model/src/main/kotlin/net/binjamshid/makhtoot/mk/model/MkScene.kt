package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.schema.MkSceneSchema

/**
 * `MkScene` — the root value: canvas spec, background node, ordered
 * top-level nodes, schema version. Ports `Sources/MKModel/MKScene.swift`.
 * Every mutation is a pure function returning a NEW scene.
 */
@Serializable
data class MkCanvasSpec(
    /** Document points. Single canvas per project in v1 (D-111). */
    var size: MkSize,
    /** Export preset provenance, e.g. `"social.portrait.4x5"`. */
    var presetID: String? = null,
)

/** The root scene value (D-111). */
@Serializable
data class MkScene(
    var schemaVersion: Int = MkSceneSchema.currentVersion,
    var canvas: MkCanvasSpec,
    var background: MkBackgroundNode = MkBackgroundNode.defaultBackground(),
    /** Ordered children, z-order: index 0 = backmost. Excludes `background`. */
    var nodes: List<MkNode> = emptyList(),
) {
    /** Inserts `node` at `index` within `parent`'s children (top-level `nodes` when `parent` is `null`). */
    fun inserting(node: MkNode, index: Int? = null, parent: MkNodeId? = null): MkScene =
        throw MkNotYetPorted("MkScene.inserting")

    /** Locates a node's parent group id (`null` = top level) and index within its parent's children array. */
    fun locate(id: MkNodeId): Pair<MkNodeId?, Int>? = throw MkNotYetPorted("MkScene.locate")

    /** Removes the node with [id] wherever it is in the tree. No-op if not found. */
    fun removing(id: MkNodeId): MkScene = throw MkNotYetPorted("MkScene.removing")

    /** Moves the top-level node with [id] to [toIndex] within `nodes`. */
    fun reordering(id: MkNodeId, toIndex: Int): MkScene = throw MkNotYetPorted("MkScene.reordering")

    /** Groups the top-level nodes with [ids] into a new group node inserted at the first grouped node's position. */
    fun reparenting(ids: List<MkNodeId>, groupName: String, groupId: MkNodeId = MkNodeId()): MkScene =
        throw MkNotYetPorted("MkScene.reparenting")

    /** Applies [transform] to the node with [id], wherever it is in the tree. No-op if not found. */
    fun updatingNode(id: MkNodeId, transform: (MkNode) -> MkNode): MkScene =
        throw MkNotYetPorted("MkScene.updatingNode")

    /** Find-by-id over the whole tree (background + nodes, recursing into groups). */
    fun node(id: MkNodeId): MkNode? = throw MkNotYetPorted("MkScene.node")
}

/** O(1)-lookup index over a scene's nodes. */
class MkNodeIndex(scene: MkScene) {
    /** The node with [id], or `null` if absent. */
    fun node(id: MkNodeId): MkNode? = throw MkNotYetPorted("MkNodeIndex.node")

    /** Total number of indexed nodes. */
    val count: Int
        get() = throw MkNotYetPorted("MkNodeIndex.count")
}
