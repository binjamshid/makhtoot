package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

data class MkExportPreset(
    var id: String,
    var nameArabic: String,
    var category: String,
    var pixelWidth: Int,
    var pixelHeight: Int,
    var dpi: Double,
    var widthMM: Double? = null,
    var heightMM: Double? = null,
    var freeTierEligible: Boolean
) {
    val pixelSize: MkSize
        get() = throw MkNotYetPorted("mk-export.MkExportPreset.pixelSize")
    val freeResolvedPixelSize: MkSize
        get() = throw MkNotYetPorted("mk-export.MkExportPreset.freeResolvedPixelSize")
}

data class MkExportPresetCatalog(
    val presets: List<MkExportPreset>
) {
    fun preset(id: String): MkExportPreset? { throw MkNotYetPorted("mk-export.MkExportPresetCatalog.preset") }
    companion object {
        val standard: MkExportPresetCatalog
            get() = throw MkNotYetPorted("mk-export.MkExportPresetCatalog.standard")
    }
}

object MkCustomDimensionValidator {
    val minimumSidePixels: Int = 16
    val diskFeasibilityWarningPixelCount: Any = 250000000
    fun validate(size: MkSize): Verdict { throw MkNotYetPorted("mk-export.MkCustomDimensionValidator.validate") }
    enum class Verdict {
        OK, TOO_SMALL, WARN_DISK_FEASIBILITY
    }
}

