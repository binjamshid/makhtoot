package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkEmbeddingRights(
    val rawValue: Int
) {
    /** OptionSet-style membership check, mirrors Swift `OptionSet.contains(_:)`. */
    fun contains(other: MkEmbeddingRights): Boolean = (rawValue and other.rawValue) == other.rawValue

    companion object {
        /** Permits PDF text-subset embedding (`MkTextEmbedPolicy.embedSubset`, ARCHITECTURE §16.5). */
        val pdf: MkEmbeddingRights = MkEmbeddingRights(1 shl 0)
        /** Permits SVG `@font-face` subset embedding (§16.6). */
        val svg: MkEmbeddingRights = MkEmbeddingRights(1 shl 1)
        /** Permits commercial-software bundling/distribution at all (OFL 1.1 §2). */
        val commercialUse: MkEmbeddingRights = MkEmbeddingRights(1 shl 2)
    }
}

enum class MkLicenseType(val rawValue: String) {
    OFL11(""), APACHE_V2_RESERVED(""), COMMERCIAL(""), PROHIBITED(""), USER_PROVIDED("")
}

data class MkLicenseRecord(
    var fontID: MkFontId,
    var familyName: String,
    var licenseType: MkLicenseType,
    var copyrightNotice: String,
    var reservedFontNames: List<String>,
    var sourceRepoURL: String,
    var licenseFileBundlePath: String,
    var verificationDate: String,
    var verifiedBy: String,
    var redistributionConfirmed: Boolean,
    var embeddingRights: MkEmbeddingRights
) {
    companion object {
        fun userProvided(fontID: MkFontId, familyName: String, importedAt: java.time.Instant): MkLicenseRecord { throw MkNotYetPorted("mk-fonts.MkLicenseRecord.userProvided") }
    }
}

data class MkFontVerificationEvidence(
    var arrangeFidelityGate: GateResult,
    var arrangeFidelityNote: String,
    var gposCursiveAttachmentPresent: Boolean,
    var gposNote: String
) {
    enum class GateResult(val rawValue: String) {
        PASS(""), FAIL(""), BLOCKED("")
    }
}

fun MkEmbeddingRights.encode(encoder: kotlinx.serialization.encoding.Encoder) { throw MkNotYetPorted("mk-fonts.MkEmbeddingRights.encode") }
val MkEmbeddingRights.result: MkEmbeddingRights
    get() = throw MkNotYetPorted("mk-fonts.MkEmbeddingRights.result")
fun newMkEmbeddingRights(decoder: kotlinx.serialization.encoding.Decoder): MkEmbeddingRights { throw MkNotYetPorted("mk-fonts.MkEmbeddingRights.init") }

