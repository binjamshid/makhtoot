package net.binjamshid.makhtoot.mk.store

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementState
import net.binjamshid.makhtoot.mk.store.trial.MkTrialManager

class MkEntitlementResolver(
    val catalog: MkProductCatalog,
    val trialManager: MkTrialManager,
    val cacheURL: java.net.URI? = null,
    val cacheStalenessTolerance: Double? = null
) : MkEntitlementProviding {
    override val state: MkEntitlementState
        get() = throw MkNotYetPorted("mk-store.MkEntitlementResolver.state")
    val detail: MkEntitlementDetail
        get() = throw MkNotYetPorted("mk-store.MkEntitlementResolver.detail")
    suspend fun resolve(): MkEntitlementState { throw MkNotYetPorted("mk-store.MkEntitlementResolver.resolve") }
    fun states(): kotlinx.coroutines.flow.Flow<MkEntitlementState> { throw MkNotYetPorted("mk-store.MkEntitlementResolver.states") }
    fun startTransactionListener() { throw MkNotYetPorted("mk-store.MkEntitlementResolver.startTransactionListener") }
    fun stopTransactionListener() { throw MkNotYetPorted("mk-store.MkEntitlementResolver.stopTransactionListener") }
}

