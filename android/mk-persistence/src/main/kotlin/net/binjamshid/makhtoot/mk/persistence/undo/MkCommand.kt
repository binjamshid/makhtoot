package net.binjamshid.makhtoot.mk.persistence.undo

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.model.MkScene

interface MkCommand {
    val id: java.util.UUID
    val name: String
    val coalescingKey: String?
    fun apply(scene: MkScene): MkScene
    fun inverse(scene: MkScene): MkCommand
}

sealed class MkPersistenceError : Exception() {
    data class NodeNotFound(val arg0: MkNodeId) : MkPersistenceError()
    data class UnknownCommandType(val arg0: String) : MkPersistenceError()
    data class DocumentPackageNotFound(val arg0: java.net.URI) : MkPersistenceError()
    data class MalformedManifest(val arg0: String) : MkPersistenceError()
    data class MalformedJournalLine(val arg0: String) : MkPersistenceError()
}

data class MkNoOpCommand(
    override val id: java.util.UUID,
    override val name: String
) : MkCommand {
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkNoOpCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkNoOpCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkNoOpCommand.inverse") }
}

