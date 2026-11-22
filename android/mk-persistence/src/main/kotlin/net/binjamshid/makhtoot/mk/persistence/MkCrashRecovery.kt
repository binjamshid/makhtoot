package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkScene

data class MkCrashRecoveryResult(
    val recoveredScene: MkScene,
    val replayedCommandCount: Int,
    val recoveryOccurred: Boolean,
    val damagedTailPreserved: java.net.URI? = null
)

object MkCrashRecovery {
    suspend fun recover(`package`: MkDocumentPackage, savedScene: MkScene, journal: MkCommandJournal): MkCrashRecoveryResult { throw MkNotYetPorted("mk-persistence.MkCrashRecovery.recover") }
}

