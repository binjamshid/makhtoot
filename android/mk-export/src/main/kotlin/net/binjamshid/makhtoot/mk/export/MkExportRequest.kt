package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

sealed class MkExportFormat {
    data class Jpeg(val quality: Double) : MkExportFormat()
    object PdfRaster : MkExportFormat()
    object PngOpaque : MkExportFormat()
    object PngAlpha : MkExportFormat()
    object Svg : MkExportFormat()
    object PdfVectorRgb : MkExportFormat()
    object PdfVectorCmyk : MkExportFormat()
    val isFreeTierFormat: Boolean
        get() = throw MkNotYetPorted("mk-export.MkExportFormat.isFreeTierFormat")
    val supportsTransparentBackground: Boolean
        get() = throw MkNotYetPorted("mk-export.MkExportFormat.supportsTransparentBackground")
    val metadataFormatString: String
        get() = throw MkNotYetPorted("mk-export.MkExportFormat.metadataFormatString")
    val hasImplementedWriter: Boolean
        get() = throw MkNotYetPorted("mk-export.MkExportFormat.hasImplementedWriter")
    companion object {
        val jpegDefault: Any? = null
    }
}

enum class MkExportColorTarget(val rawValue: String) {
    SRGB(""), CMYK_PRINT("")
}

sealed class MkExportTarget {
    data class Preset(val id: String) : MkExportTarget()
    data class Custom(val pixelSize: MkSize) : MkExportTarget()
}

enum class MkExportBackground(val rawValue: String) {
    CANVAS(""), TRANSPARENT("")
}

data class MkExportRequest(
    var format: MkExportFormat,
    var target: MkExportTarget,
    var dpi: Double = 72.0,
    var background: MkExportBackground = MkExportBackground.CANVAS,
    var colorTarget: MkExportColorTarget = MkExportColorTarget.SRGB
)

fun MkExportFormat.encode(encoder: Any) { throw MkNotYetPorted("mk-export.MkExportFormat.encode") }
fun newMkExportFormat(decoder: Any): MkExportFormat { throw MkNotYetPorted("mk-export.MkExportFormat.init") }

