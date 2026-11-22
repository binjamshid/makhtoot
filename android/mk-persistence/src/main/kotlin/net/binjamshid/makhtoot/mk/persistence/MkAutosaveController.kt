package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkAssetRef
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

enum class MkSaveReason {
    DEBOUNCED, BACKGROUND, DOCUMENT_CLOSE, BEFORE_EXPORT, MEMORY_PRESSURE_STAGE1, MEMORY_PRESSURE_STAGE2, MEMORY_PRESSURE_CRITICAL
}

class MkAutosaveController(
    val `package`: MkDocumentPackage,
    val assetStore: MkAssetStore,
    val journal: MkCommandJournal,
    val debounceInterval: kotlin.time.Duration? = null
) {
    suspend fun awaitFlushes(target: Int) { throw MkNotYetPorted("mk-persistence.MkAutosaveController.awaitFlushes") }
    suspend fun scheduleDebouncedSave(title: String, sceneProvider: suspend () -> MkScene, referencedAssetsProvider: suspend () -> Set<MkAssetRef>) { throw MkNotYetPorted("mk-persistence.MkAutosaveController.scheduleDebouncedSave") }
    suspend fun flushNow(scene: MkScene, referencedAssets: Set<MkAssetRef>, title: String, reason: MkSaveReason) { throw MkNotYetPorted("mk-persistence.MkAutosaveController.flushNow") }
    suspend fun criticalJournalFlush(command: MkCommand, baseRev: String) { throw MkNotYetPorted("mk-persistence.MkAutosaveController.criticalJournalFlush") }
    fun resetCounters() { throw MkNotYetPorted("mk-persistence.MkAutosaveController.resetCounters") }
    fun lastSavedRevision(): String? { throw MkNotYetPorted("mk-persistence.MkAutosaveController.lastSavedRevision") }
}

