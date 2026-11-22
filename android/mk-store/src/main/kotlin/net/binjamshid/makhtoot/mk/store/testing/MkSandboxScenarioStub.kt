package net.binjamshid.makhtoot.mk.store.testing

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementState

data class MkSandboxScenarioStub(
    val scenario: Scenario
) : MkEntitlementProviding {
    override val state: MkEntitlementState
        get() = throw MkNotYetPorted("mk-store.MkSandboxScenarioStub.state")
    enum class Scenario(val rawValue: String) {
        FREE(""), TRIAL_DAY3(""), EXPIRED(""), GRACE(""), BILLING_RETRY(""), LIFETIME("")
    }
}

class MkTestEntitlementStub(
    state: MkEntitlementState? = null
) : MkEntitlementProviding {
    override val state: MkEntitlementState
        get() = throw MkNotYetPorted("mk-store.MkTestEntitlementStub.state")
}

