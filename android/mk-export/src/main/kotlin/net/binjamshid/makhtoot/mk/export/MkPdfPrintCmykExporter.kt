package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.color.MkIccProfile
import net.binjamshid.makhtoot.mk.color.MkIccProfileProvenance
import net.binjamshid.makhtoot.mk.color.MkIccProfileStore
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.render.MkSnapshotRenderer

object MkPdfPrintCmykExporter {
    suspend fun export(scene: MkScene, pixelSize: MkSize, dpi: Double, title: String, renderer: MkSnapshotRenderer = MkSnapshotRenderer(), profile: MkIccProfile = MkIccProfileStore.loadBundled(), cooperation: MkExportMemoryCooperating = MkNoOpMemoryCooperation(), url: java.net.URI): Result { throw MkNotYetPorted("mk-export.MkPdfPrintCmykExporter.export") }
    data class Result(
        var fallbacks: List<MkFallbackNote>,
        var profileProvenance: MkIccProfileProvenance
    )
}

