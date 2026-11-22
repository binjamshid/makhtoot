package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable

/**
 * Stable pointer to a font, independent of whether the font is currently
 * registered/resolvable — resolution against a concrete platform font
 * happens in `mk-fonts`/`mk-textengine`, never here. Ports
 * `Sources/MKModel/MKFontRef.swift`.
 */
@Serializable
data class MkFontRef(
    /** Catalog id, or a synthetic `"system.<postScriptName>"` id for fonts resolved outside the catalog. */
    var fontID: String,
    var postScriptName: String,
    /** D-122: true for a user-imported font (locks on premium expiry). */
    var userImported: Boolean = false,
) {
    companion object {
        /** Convenience constructor for fonts with no catalog entry yet. */
        fun system(postScriptName: String): MkFontRef =
            MkFontRef(fontID = "system.$postScriptName", postScriptName = postScriptName, userImported = false)

        /** The stub-era default: system SF Arabic. */
        val systemFallback: MkFontRef = system(postScriptName = ".SFArabic")
    }
}
