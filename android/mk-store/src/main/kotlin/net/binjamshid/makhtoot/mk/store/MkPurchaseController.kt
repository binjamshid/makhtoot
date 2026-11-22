package net.binjamshid.makhtoot.mk.store

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.store.trial.MkKeyValueStoring

sealed class MkPurchaseOutcome {
    data class Purchased(val showsRedundantSubscriptionSheet: Boolean) : MkPurchaseOutcome()
    object PendingApproval : MkPurchaseOutcome()
    object UserCancelled : MkPurchaseOutcome()
    data class Failed(val arg0: MkStoreError) : MkPurchaseOutcome()
}

sealed class MkRestoreOutcome {
    object RestoredPremium : MkRestoreOutcome()
    object NothingToRestore : MkRestoreOutcome()
    data class Failed(val arg0: MkStoreError) : MkRestoreOutcome()
}

class MkPurchaseController(
    val catalog: MkProductCatalog,
    val resolver: MkEntitlementResolver,
    val sheetMarkerStore: MkKeyValueStoring? = null
) {
    suspend fun purchase(productID: String): MkPurchaseOutcome { throw MkNotYetPorted("mk-store.MkPurchaseController.purchase") }
    suspend fun restore(): MkRestoreOutcome { throw MkNotYetPorted("mk-store.MkPurchaseController.restore") }
}

