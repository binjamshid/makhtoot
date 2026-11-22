package net.binjamshid.makhtoot.mk.store

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkEntitlementDetail(
    var gracePeriodExpiration: java.time.Instant? = null,
    var renewalInfo: MkRenewalInfo? = null,
    var activeProductID: String? = null
) {
    companion object {
        val none: MkEntitlementDetail = MkEntitlementDetail()
    }
}

data class MkRenewalInfo(
    var willAutoRenew: Boolean,
    var renewalDate: java.time.Instant? = null,
    var autoRenewProductID: String? = null
)

