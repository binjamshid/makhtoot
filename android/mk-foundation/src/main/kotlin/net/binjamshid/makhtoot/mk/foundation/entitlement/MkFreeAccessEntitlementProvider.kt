package net.binjamshid.makhtoot.mk.foundation.entitlement

/**
 * Makhtoot's free access policy for all app users.
 *
 * [MkEntitlementState.Lifetime] represents unlimited access at the legacy
 * engine boundary. The app does not use it as purchase or account status.
 */
object MkFreeAccessEntitlementProvider : MkEntitlementProviding {
    override val state: MkEntitlementState = MkEntitlementState.Lifetime
}
