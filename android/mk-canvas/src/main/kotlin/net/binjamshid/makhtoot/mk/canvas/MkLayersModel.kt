package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.model.MkNode

class MkLayersModel(
    val session: MkCanvasSession
) {
    val flattenedRows: List<LayerRow>
        get() = throw MkNotYetPorted("mk-canvas.MkLayersModel.flattenedRows")
    val rowCount: Int
        get() = throw MkNotYetPorted("mk-canvas.MkLayersModel.rowCount")
    fun toggleExpanded(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkLayersModel.toggleExpanded") }
    fun rows(range: Range<Int>): List<LayerRow> { throw MkNotYetPorted("mk-canvas.MkLayersModel.rows") }
    fun select(id: MkNodeId, additive: Boolean = false) { throw MkNotYetPorted("mk-canvas.MkLayersModel.select") }
    fun toggleVisibility(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkLayersModel.toggleVisibility") }
    fun toggleLock(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkLayersModel.toggleLock") }
    fun rename(id: MkNodeId, newName: String) { throw MkNotYetPorted("mk-canvas.MkLayersModel.rename") }
    fun reorder(id: MkNodeId, toIndex: Int) { throw MkNotYetPorted("mk-canvas.MkLayersModel.reorder") }
    fun delete(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkLayersModel.delete") }
    fun duplicate(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkLayersModel.duplicate") }
    companion object {
        fun kindLabel(node: MkNode): String { throw MkNotYetPorted("mk-canvas.MkLayersModel.kindLabel") }
    }
    data class LayerRow(
        var id: MkNodeId,
        var name: String,
        var kindLabel: String,
        var isVisible: Boolean,
        var isLocked: Boolean,
        var depth: Int,
        var hasChildren: Boolean,
        var isExpanded: Boolean,
        var isBackground: Boolean,
        var isSelected: Boolean
    )
}

