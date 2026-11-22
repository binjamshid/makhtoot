package net.binjamshid.makhtoot.mk.sync.engine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.sync.changetracking.MkSyncPendingEntry
import net.binjamshid.makhtoot.mk.sync.status.MkSyncStatusPublisher

class MkSyncEngineController(
    val statusPublisher: MkSyncStatusPublisher
) {
    suspend fun setEnabled(enabled: Boolean) { throw MkNotYetPorted("mk-sync.MkSyncEngineController.setEnabled") }
    suspend fun entitlementDidChange() { throw MkNotYetPorted("mk-sync.MkSyncEngineController.entitlementDidChange") }
    suspend fun checkAccountStatus() { throw MkNotYetPorted("mk-sync.MkSyncEngineController.checkAccountStatus") }
    suspend fun pendingEntry(projectID: java.util.UUID): MkSyncPendingEntry? { throw MkNotYetPorted("mk-sync.MkSyncEngineController.pendingEntry") }
}

