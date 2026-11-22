package net.binjamshid.makhtoot.mk.foundation.entitlement

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * The six entitlement states a user can be in, precedence **lifetime > subscribed
 * > inGracePeriod > inBillingRetry > trial > free** (D-113). Ports
 * `Sources/MKFoundation/Entitlement/MKEntitlementState.swift`.
 *
 * Mechanically a Swift `enum` with one case (`trial`) carrying an associated
 * value -> Kotlin `sealed class` with `object` cases and one `data class` case,
 * per `ANDROID_SPINE.md` §3.3's naming rule / structural-port convention.
 */
sealed class MkEntitlementState : Comparable<MkEntitlementState> {
    object Lifetime : MkEntitlementState()
    object Subscribed : MkEntitlementState()
    object InGracePeriod : MkEntitlementState()
    object InBillingRetry : MkEntitlementState()
    data class Trial(val daysLeft: Int) : MkEntitlementState()
    object Free : MkEntitlementState()

    /** Whether `this` outranks [other] per D-113 precedence. */
    fun outranks(other: MkEntitlementState): Boolean = throw MkNotYetPorted("MkEntitlementState.outranks")

    /** Whether this state currently grants premium access. */
    val grantsPremiumAccess: Boolean
        get() = throw MkNotYetPorted("MkEntitlementState.grantsPremiumAccess")

    /**
     * Ports the `MKEntitlementState: Comparable` conformance's `static func <`.
     * Kotlin idiom is `Comparable.compareTo`, not an operator function — a
     * documented mechanical substitution, same semantics.
     */
    override fun compareTo(other: MkEntitlementState): Int =
        throw MkNotYetPorted("MkEntitlementState.compareTo")

    companion object {
        /** The higher-precedence of [lhs]/[rhs] per D-113. Ties (equal rank) keep [lhs]. */
        fun highestPrecedence(lhs: MkEntitlementState, rhs: MkEntitlementState): MkEntitlementState =
            throw MkNotYetPorted("MkEntitlementState.highestPrecedence")
    }
}
