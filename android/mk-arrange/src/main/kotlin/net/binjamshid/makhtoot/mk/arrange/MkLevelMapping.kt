package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkProvenance

/**
 * An indexed view over an [MkArrangedComposition] for O(1) node/entry
 * lookup. Ports `Sources/MKArrange/LevelMapping.swift`'s
 * `ArrangedCompositionIndex`.
 */
class MkArrangedCompositionIndex(val composition: MkArrangedComposition) {
    /** Discriminates an index entry's node kind. Ports the nested `Kind` enum. */
    enum class Kind {
        Glyph,
        Mark,
        Ligature,
    }

    /** One indexed node's summary. Ports the nested `Entry` struct. */
    data class Entry(
        var id: MkNodeId,
        var provenance: MkProvenance,
        var kind: Kind,
        var attachedTo: MkNodeId?,
    )

    /** Every node in [composition], indexed by id. Populated at construction time. */
    var entries: Map<MkNodeId, Entry> = emptyMap()
        private set

    init {
        throw MkNotYetPorted("MkArrangedCompositionIndex.init")
    }

    /** The indexed entry for [id], or `null` if absent. */
    fun entry(id: MkNodeId): Entry? = throw MkNotYetPorted("MkArrangedCompositionIndex.entry")

    /** Whether [id] refers to a mark node. */
    fun isMark(id: MkNodeId): Boolean = throw MkNotYetPorted("MkArrangedCompositionIndex.isMark")
}

/**
 * UTF-16-range <-> node-id mapping helpers over an [MkArrangedComposition].
 * Ports `LevelMapping`.
 */
object MkLevelMapping {
    /** Every node id whose provenance UTF-16 span intersects [range]. */
    fun nodeIds(range: IntRange, composition: MkArrangedComposition, includeMarks: Boolean = true): Set<MkNodeId> =
        throw MkNotYetPorted("MkLevelMapping.nodeIds")

    /** The UTF-16 spans covered by [ids] within [composition]. */
    fun utf16Ranges(ids: Set<MkNodeId>, composition: MkArrangedComposition): List<IntRange> =
        throw MkNotYetPorted("MkLevelMapping.utf16Ranges")

    /** Every node id sharing [id]'s source cluster. */
    fun clusterSiblings(id: MkNodeId, composition: MkArrangedComposition): Set<MkNodeId> =
        throw MkNotYetPorted("MkLevelMapping.clusterSiblings")
}
