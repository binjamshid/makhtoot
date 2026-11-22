package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkScene

sealed class MkPremiumContentItem {
    data class PremiumOrImportedFont(val fontID: String, val postScriptName: String) : MkPremiumContentItem()
    data class PhotoBackground(val nodeID: MkNodeId) : MkPremiumContentItem()
    data class PremiumAsset(val nodeID: MkNodeId) : MkPremiumContentItem()
}

sealed class MkExportBlockReason {
    data class FormatRequiresPremium(val arg0: MkExportFormat) : MkExportBlockReason()
    object CustomDimensionsRequirePremium : MkExportBlockReason()
    data class PresetRequiresPremium(val presetID: String) : MkExportBlockReason()
    data class UnknownPreset(val presetID: String) : MkExportBlockReason()
    data class TransparentBackgroundNotSupported(val arg0: MkExportFormat) : MkExportBlockReason()
    data class PremiumContentPresent(val items: List<MkPremiumContentItem>) : MkExportBlockReason()
    object InvalidTargetSize : MkExportBlockReason()
}

sealed class MkExportGateDecision {
    data class Allowed(val resolvedPixelSize: MkSize) : MkExportGateDecision()
    data class Blocked(val arg0: MkExportBlockReason) : MkExportGateDecision()
    val isAllowed: Boolean
        get() = throw MkNotYetPorted("mk-export.MkExportGateDecision.isAllowed")
}

data class MkExportGate(
    val fontLicense: MkFontLicenseProviding = MkAllOflLicenseStub(),
    val presets: MkExportPresetCatalog? = null
) {
    fun premiumContentPresent(scene: MkScene, premiumAssetNodeIDs: Set<MkNodeId> = emptySet()): List<MkPremiumContentItem> { throw MkNotYetPorted("mk-export.MkExportGate.premiumContentPresent") }
    fun resolvedPixelSize(request: MkExportRequest, isPremiumUser: Boolean): MkSize? { throw MkNotYetPorted("mk-export.MkExportGate.resolvedPixelSize") }
    fun evaluate(request: MkExportRequest, scene: MkScene, entitlement: MkEntitlementProviding, premiumAssetNodeIDs: Set<MkNodeId> = emptySet()): MkExportGateDecision { throw MkNotYetPorted("mk-export.MkExportGate.evaluate") }
}

