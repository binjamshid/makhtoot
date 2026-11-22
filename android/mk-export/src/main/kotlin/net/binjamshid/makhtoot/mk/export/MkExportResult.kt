package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

data class MkExportResult(
    var fileURL: java.net.URI,
    var pixelSize: MkSize,
    var format: MkExportFormat,
    var fallbacksApplied: List<MkFallbackNote> = emptyList(),
    var colorProvenance: String = "sRGB",
    var durationMS: Double
)

sealed class MkExportError : Exception() {
    data class FormatNotYetImplemented(val format: MkExportFormat) : MkExportError()
    data class Blocked(val arg0: MkExportBlockReason) : MkExportError()
    object DegenerateTargetSize : MkExportError()
    object RenderingProducedNoImage : MkExportError()
    object EncodingFailed : MkExportError()
    object Cancelled : MkExportError()
}

