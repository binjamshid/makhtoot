package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

typealias MkFontId = String

enum class MkFontOrigin(val rawValue: Int) {
    BUNDLED(0), PREMIUM_DOWNLOADED(1), USER_IMPORTED(2)
}

enum class MkFontCategory(val rawValue: String) {
    NASKH(""), RUQAH(""), THULUTH(""), DIWANI(""), KUFI(""), MAGHREBI(""), MODERN_DISPLAY(""), QURANIC_STYLE(""), HANDWRITING(""), BILINGUAL("");
    val arabicDisplayName: String
        get() = throw MkNotYetPorted("mk-fonts.MkFontCategory.arabicDisplayName")
}

enum class MkFontFileFormat(val rawValue: String) {
    TTF(""), OTF(""), TTC("")
}

data class MkFontFace(
    var postScriptName: String,
    var familyName: String,
    var fullName: String,
    var styleName: String,
    var weight: Int,
    var isVariable: Boolean,
    var format: MkFontFileFormat,
    var filename: String,
    var fileURL: java.net.URI
)

data class MkFontRecord(
    var fontID: MkFontId,
    var familyName: String,
    var familyNameArabic: String? = null,
    var origin: MkFontOrigin,
    var faces: List<MkFontFace>,
    var categories: List<MkFontCategory>,
    var tags: List<String> = emptyList(),
    var isLocked: Boolean = false
)

val MkFontRecord.defaultFace: MkFontFace?
    get() = throw MkNotYetPorted("mk-fonts.MkFontRecord.defaultFace")

