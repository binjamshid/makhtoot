package net.binjamshid.makhtoot.mk.color

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Where the active CMYK profile came from — surfaced in the PDF/print export
 * report and the "never claim PDF/X under an unverified fallback" rule
 * (D-226(4)). Ports `Sources/MKColor/ICCProfileStore.swift`'s
 * `MKICCProfileProvenance`.
 *
 * `AppleGenericCmyk` case name preserved verbatim from the Swift source for
 * mechanical traceability (naming rule, `ANDROID_SPINE.md` §3.3); Android's
 * real fallback (FDA-03) is lcms2's synthetic generic CMYK profile, not
 * Apple's — a Batch 2 implementation decision, not renamed here.
 */
@Serializable
sealed class MkIccProfileProvenance {
    /** A licensed, redistribution-verified profile shipped with the app (post-FD-03/FDA-03). */
    @Serializable
    data class BundledIcc(val name: String, val licenseEvidencePath: String) : MkIccProfileProvenance()

    /** The documented, always-available fallback (D-117/FDA-03). Lower press fidelity, explicitly disclosed. */
    @Serializable
    object AppleGenericCmyk : MkIccProfileProvenance()

    /** Arabic disclosure string for the export report / pre-export sheet (R-13.7, D-227(7)). */
    val arabicDisclosure: String
        get() = throw MkNotYetPorted("MkIccProfileProvenance.arabicDisclosure")

    /** Whether a PDF built against this provenance may claim the `GTS_PDFX` OutputIntent subtype. */
    val mayClaimPDFX: Boolean
        get() = throw MkNotYetPorted("MkIccProfileProvenance.mayClaimPDFX")
}

/**
 * `cmykSpace()` resolution result: the bundled profile if present, else the
 * fallback; `profileProvenance` surfaced into PDF metadata + export report
 * (D-117 §15.2). Ports `MKICCProfile`.
 */
data class MkIccProfile(
    val provenance: MkIccProfileProvenance,
    val iccData: ByteArray,
    val colorSpace: MkColorSpaceHandle,
) {
    /** Display name — the ICC profile's own embedded description when available, else the provenance's label. */
    val name: String
        get() = throw MkNotYetPorted("MkIccProfile.name")
}

/**
 * `Resources/ICC/` scan + fallback resolution. A plain object (no instance
 * state) — profile resolution is a pure function of "what's bundled right
 * now." Ports `ICCProfileStore`.
 */
object MkIccProfileStore {
    /** Loads the active CMYK profile: the bundled ICC file if present, else the documented fallback (D-117). */
    fun loadBundled(bundle: MkResourceBundle? = null): MkIccProfile =
        throw MkNotYetPorted("MkIccProfileStore.loadBundled")
}
