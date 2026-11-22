package net.binjamshid.makhtoot.stubs

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementState

class MkAlwaysPremiumEntitlementStub : MkEntitlementProviding {
    override val state: MkEntitlementState
        get() = throw MkNotYetPorted("app.MkAlwaysPremiumEntitlementStub.state")
}

