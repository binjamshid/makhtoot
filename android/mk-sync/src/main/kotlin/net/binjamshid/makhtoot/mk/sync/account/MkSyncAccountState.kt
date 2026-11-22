package net.binjamshid.makhtoot.mk.sync.account

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.sync.MkPlatformSyncAccountStatus
import net.binjamshid.makhtoot.mk.sync.status.MkSyncAccountReason

enum class MkSyncAccountState {
    AVAILABLE, NO_ACCOUNT, RESTRICTED, TEMPORARILY_UNAVAILABLE, UNKNOWN;
    val allowsSync: Boolean
        get() = throw MkNotYetPorted("mk-sync.MkSyncAccountState.allowsSync")
    val pauseReason: MkSyncAccountReason?
        get() = throw MkNotYetPorted("mk-sync.MkSyncAccountState.pauseReason")
    companion object {
        fun from(ckStatus: MkPlatformSyncAccountStatus): MkSyncAccountState { throw MkNotYetPorted("mk-sync.MkSyncAccountState.from") }
    }
}

data class MkSyncAccountIdentity(
    val userRecordName: String
) {
    fun accountChanged(other: MkSyncAccountIdentity?): Boolean { throw MkNotYetPorted("mk-sync.MkSyncAccountIdentity.accountChanged") }
}

