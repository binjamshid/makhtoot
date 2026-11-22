package net.binjamshid.makhtoot.mk.sync.conflict

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkSyncSnapshot(
    val contentHash: String,
    val modifiedAt: java.time.Instant
)

enum class MkSyncDecisionResult {
    APPLY_REMOTE, KEEP_LOCAL, CONFLICT, NO_CHANGE, QUARANTINE, APPLY_REMOTE_DELETION, RESURRECT
}

object MkSyncDecisionEngine {
    fun decide(local: MkSyncSnapshot?, remote: MkSyncSnapshot, lastSynced: MkSyncSnapshot?, remoteSchemaVersion: Long = 1, supportedSchemaVersion: Long? = null): MkSyncDecisionResult { throw MkNotYetPorted("mk-sync.MkSyncDecisionEngine.decide") }
    fun decideRemoteDeletion(local: MkSyncSnapshot?, lastSynced: MkSyncSnapshot?): MkSyncDecisionResult { throw MkNotYetPorted("mk-sync.MkSyncDecisionEngine.decideRemoteDeletion") }
}

