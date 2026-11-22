package net.binjamshid.makhtoot.mk.store

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementState
import net.binjamshid.makhtoot.mk.store.trial.MkTrialState

sealed class MkSubscriptionSignal {
    object None : MkSubscriptionSignal()
    data class Subscribed(val renewalInfo: MkRenewalInfo?) : MkSubscriptionSignal()
    data class InGracePeriod(val until: java.time.Instant?) : MkSubscriptionSignal()
    object InBillingRetry : MkSubscriptionSignal()
    object Expired : MkSubscriptionSignal()
}

object MkEntitlementPrecedence {
    fun resolve(hasLifetime: Boolean, subscription: MkSubscriptionSignal, trial: MkTrialState): Pair<MkEntitlementState, MkEntitlementDetail> { throw MkNotYetPorted("mk-store.MkEntitlementPrecedence.resolve") }
}

