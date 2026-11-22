package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkSnapshotRenderer

interface MkExportMemoryCooperating {
    fun isCancelled(): Boolean
    fun shouldPauseBeforeNextStrip(): Boolean
}

class MkNoOpMemoryCooperation : MkExportMemoryCooperating {
    override fun isCancelled(): Boolean { throw MkNotYetPorted("mk-export.MkNoOpMemoryCooperation.isCancelled") }
    override fun shouldPauseBeforeNextStrip(): Boolean { throw MkNotYetPorted("mk-export.MkNoOpMemoryCooperation.shouldPauseBeforeNextStrip") }
}

object MkTiledRasterExporter {
    suspend fun renderAssembled(scene: MkScene, pixelSize: MkSize, renderer: MkSnapshotRenderer = MkSnapshotRenderer(), quality: MkRenderQuality? = null, maxTileBytes: Int? = null, cooperation: MkExportMemoryCooperating = MkNoOpMemoryCooperation(), pausePollNanoseconds: UInt64 = 200000000): Any { throw MkNotYetPorted("mk-export.MkTiledRasterExporter.renderAssembled") }
}

