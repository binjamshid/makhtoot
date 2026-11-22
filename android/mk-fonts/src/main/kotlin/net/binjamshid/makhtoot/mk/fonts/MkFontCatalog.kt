package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkFontCatalog(
    val registry: MkFontRegistry
) {
    suspend fun browse(favorites: Set<MkFontId> = emptySet()): List<BrowseEntry> { throw MkNotYetPorted("mk-fonts.MkFontCatalog.browse") }
    suspend fun fonts(category: MkFontCategory, favorites: Set<MkFontId> = emptySet()): List<BrowseEntry> { throw MkNotYetPorted("mk-fonts.MkFontCatalog.fonts") }
    suspend fun search(query: String, favorites: Set<MkFontId> = emptySet()): List<BrowseEntry> { throw MkNotYetPorted("mk-fonts.MkFontCatalog.search") }
    suspend fun previewAttributedString(fontID: MkFontId, size: Double, text: String? = null): MkPlatformAttributedString? { throw MkNotYetPorted("mk-fonts.MkFontCatalog.previewAttributedString") }
    suspend fun coverageReport(fontID: MkFontId): MkCoverageReport? { throw MkNotYetPorted("mk-fonts.MkFontCatalog.coverageReport") }
    companion object {
        val defaultPreviewText: String = "بسم الحرف العربي وجماله"
        val numeralsPreviewText: String = "١٢٣ 123"
    }
    data class BrowseEntry(
        var fontID: MkFontId,
        var familyName: String,
        var categories: List<MkFontCategory>,
        var tags: List<String>,
        var origin: MkFontOrigin,
        var isLocked: Boolean,
        var isFavorite: Boolean
    )
}

