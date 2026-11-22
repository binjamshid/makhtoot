package net.binjamshid.makhtoot.mk.assets.instantiation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId

data class MkPremiumContentLedger(
    val entries: Map<MkNodeId, MkPlacementRecord> = emptyMap()
) {
    val isPremiumContentPresent: Boolean
        get() = throw MkNotYetPorted("mk-assets.MkPremiumContentLedger.isPremiumContentPresent")
    val premiumAssetNamesAr: List<String>
        get() = throw MkNotYetPorted("mk-assets.MkPremiumContentLedger.premiumAssetNamesAr")
    val count: Int
        get() = throw MkNotYetPorted("mk-assets.MkPremiumContentLedger.count")
    val premiumCount: Int
        get() = throw MkNotYetPorted("mk-assets.MkPremiumContentLedger.premiumCount")
    fun adding(record: MkPlacementRecord): MkPremiumContentLedger { throw MkNotYetPorted("mk-assets.MkPremiumContentLedger.adding") }
    fun removing(nodeID: MkNodeId): MkPremiumContentLedger { throw MkNotYetPorted("mk-assets.MkPremiumContentLedger.removing") }
}

