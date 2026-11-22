package net.binjamshid.makhtoot.mk.foundation

/**
 * Compile-time + local-runtime feature flags. Ports `Sources/MKFoundation/MKFeatureFlags.swift`.
 * Makhtoot (and its Android port, `ANDROID_SPINE.md` §0) is offline-first — no
 * remote config, no A/B service, no server-driven toggle.
 *
 * `referralProgram` defaults **OFF** per D-124/D-321 and must not be flipped on
 * anywhere in this packet.
 */
data class MkFeatureFlags(
    /**
     * D-124/D-321: the referral module is compiled but inert unless this is
     * `true`. Default OFF. The *shipping* dormancy mechanism is compile-time
     * exclusion from Release builds (D-321), not this runtime flag alone.
     */
    var referralProgram: Boolean = false,
    /**
     * Supplementary compile/runtime analytics kill switch (D-207/D-320 layer 3).
     */
    var analyticsEnabled: Boolean = true,
    /** v2 extension seam: multi-page canvases. Always OFF in v1. */
    var multiPageSeam: Boolean = false,
    /** v2 extension seam: an alternate GPU renderer, adopted only if profiling gates fail. */
    var metalRenderer: Boolean = false,
    /** Alternate app-icon mechanism gate. Ships OFF until real artwork lands. */
    var alternateAppIcons: Boolean = false,
) {
    companion object {
        /** The process-wide default flag set. */
        val default = MkFeatureFlags()
    }
}
