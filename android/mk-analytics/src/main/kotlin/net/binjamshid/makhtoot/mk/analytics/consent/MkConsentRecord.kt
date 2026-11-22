package net.binjamshid.makhtoot.mk.analytics.consent

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkConsentRecord(
    var consentVersion: Int = currentConsentVersion,
    var status: MkConsentStatus? = null,
    var disclosureTextHash: String = ""
) {
    companion object {
        val currentConsentVersion: Int = 1
    }
}


