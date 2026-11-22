package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.foundation.stubs.MkDocumentStoring
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand
import net.binjamshid.makhtoot.mk.persistence.undo.MkUndoStack

class MkMakhtootDocument(
    val undoStack: MkUndoStack = MkUndoStack()
) {
    fun apply(command: MkCommand) { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.apply") }
    fun undo() { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.undo") }
    fun redo() { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.redo") }
    fun rename(newTitle: String) { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.rename") }
    suspend fun saveNow(reason: MkSaveReason) { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.saveNow") }
    fun assetStoreHandle(): MkAssetStore { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.assetStoreHandle") }
    companion object {
        fun create(rootURL: java.net.URI, projectID: MkProjectId = MkProjectId(), title: String, canvas: MkCanvasSpec): MkMakhtootDocument { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.create") }
        suspend fun open(rootURL: java.net.URI): Pair<MkMakhtootDocument, MkCrashRecoveryResult> { throw MkNotYetPorted("mk-persistence.MkMakhtootDocument.open") }
    }
}

class MkFilePackageDocumentStore(
    val rootURL: java.net.URI
) : MkDocumentStoring {
    override suspend fun save(data: ByteArray, id: MkProjectId) { throw MkNotYetPorted("mk-persistence.MkFilePackageDocumentStore.save") }
    override suspend fun load(id: MkProjectId): ByteArray? { throw MkNotYetPorted("mk-persistence.MkFilePackageDocumentStore.load") }
    override suspend fun delete(id: MkProjectId) { throw MkNotYetPorted("mk-persistence.MkFilePackageDocumentStore.delete") }
}

