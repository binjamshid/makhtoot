package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementState

class MkFontLockController(
    val registry: MkFontRegistry
) {
    suspend fun observe(states: kotlinx.coroutines.flow.Flow<MkEntitlementState>) { throw MkNotYetPorted("mk-fonts.MkFontLockController.observe") }
    suspend fun apply(state: MkEntitlementState) { throw MkNotYetPorted("mk-fonts.MkFontLockController.apply") }
    suspend fun reconcile(entitlements: MkEntitlementProviding) { throw MkNotYetPorted("mk-fonts.MkFontLockController.reconcile") }
}

