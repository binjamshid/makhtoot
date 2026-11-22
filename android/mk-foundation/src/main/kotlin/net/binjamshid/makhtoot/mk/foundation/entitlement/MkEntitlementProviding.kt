package net.binjamshid.makhtoot.mk.foundation.entitlement

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * The premium capabilities gated by entitlement state (D-118, D-119, D-121).
 * Ports `Sources/MKFoundation/Entitlement/MKEntitlementProviding.swift`.
 */
enum class MkPremiumCapability {
    PremiumFonts,
    FontImport,
    PhotoBackgrounds,
    PremiumExportFormats,
    HiResExport,
    CloudSync,
    PremiumAssets,
}

/**
 * The single-source entitlement query surface every other module consumes.
 * Access from any module (including `:mk-export`) is via this interface, which
 * lives in `:mk-foundation` — never a direct dependency on `:mk-store`
 * (`ANDROID_SPINE.md` §2, D-2xx register note under the decision table).
 */
interface MkEntitlementProviding {
    /** The current entitlement state (D-113 precedence already resolved). */
    val state: MkEntitlementState

    /**
     * Whether [capability] is currently usable under [state]. Default
     * implementation matches D-113: any non-`Free` state grants every
     * capability (ports the `public extension MKEntitlementProviding` default).
     */
    fun isEntitled(capability: MkPremiumCapability): Boolean =
        throw MkNotYetPorted("MkEntitlementProviding.isEntitled")
}
