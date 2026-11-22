package net.binjamshid.makhtoot.mk.pathtext

import java.util.UUID
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkPathLayoutOptions as MkModelPathLayoutOptions
import net.binjamshid.makhtoot.mk.model.MkPathTextNode
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkSourceText
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/**
 * Thin, coalescable command builders over a `pathText` node — the primitive
 * `mk-canvas`'s inspector/canvas bindings call directly, same pattern
 * `mk-arrange`'s `MkArrangeStyleEditor` established. Ports
 * `Sources/MKPathText/PathTextCommands.swift`.
 */
object MkPathTextCommands {
    /** Retypes the source string / per-range style overrides. [burstKey] is the coalescing key. */
    fun setText(text: MkSourceText, nodeId: MkNodeId, scene: MkScene, burstKey: String): MkCommand? =
        throw MkNotYetPorted("MkPathTextCommands.setText")

    fun setStyle(style: MkTextStyle, nodeId: MkNodeId, scene: MkScene, gestureId: UUID = UUID.randomUUID()): MkCommand? =
        throw MkNotYetPorted("MkPathTextCommands.setStyle")

    /** Commits an edited [MkBezierPathModel]. [coalescingKey] should stay stable for one continuous drag. */
    fun setPath(path: MkBezierPathModel, nodeId: MkNodeId, scene: MkScene, coalescingKey: String): MkCommand? =
        throw MkNotYetPorted("MkPathTextCommands.setPath(model)")

    /** Commits the persisted slice of layout options (`startOffset`/`side`/`spacingMode`). */
    fun setOptions(
        options: MkModelPathLayoutOptions,
        nodeId: MkNodeId,
        scene: MkScene,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand? = throw MkNotYetPorted("MkPathTextCommands.setOptions")

    /** Convenience overload accepting the document-representation path directly. */
    fun setPath(path: MkBezierPathData, nodeId: MkNodeId, scene: MkScene, coalescingKey: String): MkCommand? =
        throw MkNotYetPorted("MkPathTextCommands.setPath(data)")

    /** Commits one per-glyph user-offset edit into `MkPathTextNode.glyphOffsets`. */
    fun setGlyphOffset(
        offset: MkPathGlyphUserOffset,
        key: MkPathClusterProvenanceKey,
        nodeId: MkNodeId,
        scene: MkScene,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand? = throw MkNotYetPorted("MkPathTextCommands.setGlyphOffset")

    /** Converts a node's persisted per-glyph offsets into the engine input shape `MkPathLayoutEngine.layout` consumes. */
    fun persistedUserOffsets(node: MkPathTextNode): Map<MkPathClusterProvenanceKey, MkPathGlyphUserOffset> =
        throw MkNotYetPorted("MkPathTextCommands.persistedUserOffsets")
}

/**
 * Legacy, session-scoped, non-undo-integrated per-glyph-offset holder (kept
 * for transient use, e.g. live previews that shouldn't touch the undo
 * stack) — not the primary mechanism (`MkPathTextCommands.setGlyphOffset`
 * is). Ports `PathTextOffsetStore` (a Swift `@unchecked Sendable final
 * class` guarded by an `NSLock`) — Android's real implementation (Batch 4)
 * is expected to guard this with a `java.util.concurrent` lock or a
 * `Mutex`.
 */
class MkPathTextOffsetStore {
    fun offsets(nodeId: MkNodeId): Map<MkPathClusterProvenanceKey, MkPathGlyphUserOffset> =
        throw MkNotYetPorted("MkPathTextOffsetStore.offsets")

    fun setOffset(offset: MkPathGlyphUserOffset, key: MkPathClusterProvenanceKey, nodeId: MkNodeId): Unit =
        throw MkNotYetPorted("MkPathTextOffsetStore.setOffset")

    fun clear(nodeId: MkNodeId): Unit = throw MkNotYetPorted("MkPathTextOffsetStore.clear")
}
