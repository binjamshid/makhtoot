package net.binjamshid.makhtoot.mk.analytics.consent

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

sealed class MkConsentStatus {
    object NeverAsked : MkConsentStatus()
    data class Granted(val date: java.time.Instant) : MkConsentStatus()
    data class Revoked(val date: java.time.Instant) : MkConsentStatus()
    val isGranted: Boolean
        get() = throw MkNotYetPorted("mk-analytics.MkConsentStatus.isGranted")
    fun encode(encoder: Any) { throw MkNotYetPorted("mk-analytics.MkConsentStatus.encode") }
}

