package net.binjamshid.makhtoot.mk.store.paywall

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.store.MkStoreError

sealed class MkPaywallContext {
    object OnboardingTrialIntro : MkPaywallContext()
    object TrialExpired : MkPaywallContext()
    data class PremiumFeatureTap(val feature: String) : MkPaywallContext()
    object SettingsUpsell : MkPaywallContext()
}

sealed class MkPaywallState {
    object Browsing : MkPaywallState()
    data class Purchasing(val productID: String) : MkPaywallState()
    object PendingApproval : MkPaywallState()
    object Success : MkPaywallState()
    object NothingToRestore : MkPaywallState()
    data class Failed(val arg0: MkStoreError) : MkPaywallState()
    object Dismissed : MkPaywallState()
}

class MkPaywallStateMachine(
    val context: MkPaywallContext
) {
    suspend fun purchase(productID: String) { throw MkNotYetPorted("mk-store.MkPaywallStateMachine.purchase") }
    fun acknowledgeRedundantSubscriptionSheet() { throw MkNotYetPorted("mk-store.MkPaywallStateMachine.acknowledgeRedundantSubscriptionSheet") }
    suspend fun restore() { throw MkNotYetPorted("mk-store.MkPaywallStateMachine.restore") }
    fun dismiss() { throw MkNotYetPorted("mk-store.MkPaywallStateMachine.dismiss") }
    fun reset() { throw MkNotYetPorted("mk-store.MkPaywallStateMachine.reset") }
}

