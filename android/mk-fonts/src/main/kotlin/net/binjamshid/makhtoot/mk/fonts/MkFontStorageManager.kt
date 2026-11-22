package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkFontStorageManager(
    val registry: MkFontRegistry,
    val catalogStore: MkFontCatalogStore? = null
) {
    suspend fun delete(fontID: MkFontId, referencingProjectTitles: List<String> = emptyList()): DeletionOutcome { throw MkNotYetPorted("mk-fonts.MkFontStorageManager.delete") }
    sealed class DeletionOutcome {
        object Deleted : DeletionOutcome()
        data class DeletedWithProjectReferenceWarning(val arg0: String) : DeletionOutcome()
        object NotFound : DeletionOutcome()
        object RefusedBundled : DeletionOutcome()
    }
}

