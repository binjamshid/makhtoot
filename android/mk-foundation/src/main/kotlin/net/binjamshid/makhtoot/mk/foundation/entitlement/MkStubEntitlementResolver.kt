package net.binjamshid.makhtoot.mk.foundation.entitlement

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Always-premium stub conforming to [MkEntitlementProviding]. Ports
 * `Sources/MKFoundation/Entitlement/StubEntitlementResolver.swift`.
 *
 * Never wire this into production — it exists purely to unblock parallel
 * development and tests, exactly as the Swift original documents.
 */
class MkStubEntitlementResolver : MkEntitlementProviding {
    override val state: MkEntitlementState
        get() = throw MkNotYetPorted("MkStubEntitlementResolver.state")
}
