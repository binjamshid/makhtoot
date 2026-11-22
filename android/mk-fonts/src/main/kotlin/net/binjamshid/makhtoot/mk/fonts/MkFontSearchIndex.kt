package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkFontSearchIndex {
    fun search(query: String, entries: List<Entry>): List<MkFontId> { throw MkNotYetPorted("mk-fonts.MkFontSearchIndex.search") }
    companion object {
        fun normalize(input: String): String { throw MkNotYetPorted("mk-fonts.MkFontSearchIndex.normalize") }
    }
    data class Entry(
        var fontID: MkFontId,
        var familyName: String,
        var familyNameArabic: String? = null,
        var tags: List<String>,
        var categories: List<MkFontCategory>,
        var isFavorite: Boolean
    )
}

