package net.binjamshid.makhtoot.mk.analytics.consent

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.analytics.counter.MkUsageCounterStore

class MkConsentManager(
    val storeURL: java.net.URI
) {
    val isConsentGranted: Boolean
        get() = throw MkNotYetPorted("mk-analytics.MkConsentManager.isConsentGranted")
    fun load() { throw MkNotYetPorted("mk-analytics.MkConsentManager.load") }
    fun grant(disclosureText: String) { throw MkNotYetPorted("mk-analytics.MkConsentManager.grant") }
    suspend fun revoke(counterStore: MkUsageCounterStore) { throw MkNotYetPorted("mk-analytics.MkConsentManager.revoke") }
    companion object {
        fun production(): MkConsentManager { throw MkNotYetPorted("mk-analytics.MkConsentManager.production") }
    }
}

