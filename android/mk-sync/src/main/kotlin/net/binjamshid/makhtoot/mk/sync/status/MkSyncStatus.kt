package net.binjamshid.makhtoot.mk.sync.status

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.sync.errors.MkSyncError

sealed class MkSyncGlobalState {
    object Disabled : MkSyncGlobalState()
    object PausedEntitlement : MkSyncGlobalState()
    data class PausedAccount(val reason: MkSyncAccountReason) : MkSyncGlobalState()
    data class Idle(val lastSyncDate: java.time.Instant?) : MkSyncGlobalState()
    data class Syncing(val uploaded: Int, val total: Int) : MkSyncGlobalState()
    data class Error(val arg0: MkSyncError) : MkSyncGlobalState()
    val localizedMessage: String
        get() = throw MkNotYetPorted("mk-sync.MkSyncGlobalState.localizedMessage")
}

enum class MkSyncAccountReason {
    NO_ACCOUNT, RESTRICTED, TEMPORARILY_UNAVAILABLE;
    val localizedMessage: String
        get() = throw MkNotYetPorted("mk-sync.MkSyncAccountReason.localizedMessage")
}

sealed class MkSyncProjectState {
    object LocalOnly : MkSyncProjectState()
    object PendingUpload : MkSyncProjectState()
    object Syncing : MkSyncProjectState()
    object Synced : MkSyncProjectState()
    object ConflictCopy : MkSyncProjectState()
    data class Error(val arg0: MkSyncError) : MkSyncProjectState()
    object NeedsAppUpdate : MkSyncProjectState()
    val badgeLabel: String?
        get() = throw MkNotYetPorted("mk-sync.MkSyncProjectState.badgeLabel")
}

class MkSyncStatusPublisher {
    fun update(globalState: MkSyncGlobalState) { throw MkNotYetPorted("mk-sync.MkSyncStatusPublisher.update") }
    fun update(projectID: java.util.UUID, state: MkSyncProjectState) { throw MkNotYetPorted("mk-sync.MkSyncStatusPublisher.update") }
    fun recordConflictCopy(original: java.util.UUID, copy: java.util.UUID) { throw MkNotYetPorted("mk-sync.MkSyncStatusPublisher.recordConflictCopy") }
    fun projectState(id: java.util.UUID): MkSyncProjectState { throw MkNotYetPorted("mk-sync.MkSyncStatusPublisher.projectState") }
}

