package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkFontCatalogStore {
    fun upsertCatalogEntry(fontID: MkFontId, displayNameAr: String, postScriptName: String, category: MkFontCategory, origin: MkFontOrigin, downloadState: DownloadStateValue? = null, coverageClass: Int = 0) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.upsertCatalogEntry") }
    fun setFavorite(isFavorite: Boolean, fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.setFavorite") }
    fun setTags(tags: List<String>, fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.setTags") }
    fun setDownloadState(state: DownloadStateValue, fontID: MkFontId, localPath: String? = null) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.setDownloadState") }
    fun setLocked(locked: Boolean, fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.setLocked") }
    fun setLocked(locked: Boolean, tiers: Set<Int>) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.setLocked") }
    fun allEntries(): List<Summary> { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.allEntries") }
    fun removeEntry(fontID: MkFontId) { throw MkNotYetPorted("mk-fonts.MkFontCatalogStore.removeEntry") }
    sealed class DownloadStateValue {
        object NotDownloaded : DownloadStateValue()
        data class Downloading(val progress: Double) : DownloadStateValue()
        object Downloaded : DownloadStateValue()
        data class Failed(val errorCode: String) : DownloadStateValue()
        val rawValue: Int
            get() = throw MkNotYetPorted("mk-fonts.DownloadStateValue.rawValue")
        companion object {
            fun from(rawValue: Int): DownloadStateValue { throw MkNotYetPorted("mk-fonts.DownloadStateValue.from") }
        }
    }
    data class Summary(
        var fontID: String,
        var displayNameAr: String,
        var category: String,
        var tier: Int,
        var downloadState: Int,
        var isFavorite: Boolean,
        var tags: List<String>,
        var lockedByExpiry: Boolean
    )
}

