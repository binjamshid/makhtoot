package net.binjamshid.makhtoot.mk.sync.errors

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

sealed class MkSyncError : Exception() {
    object QuotaExceeded : MkSyncError()
    object NetworkUnavailable : MkSyncError()
    data class AssetTooLarge(val projectTitle: String) : MkSyncError()
    object ZoneNotFound : MkSyncError()
    object ServerRejected : MkSyncError()
    object PermissionFailure : MkSyncError()
    object AccountUnavailable : MkSyncError()
    data class Throttled(val retryAfter: Double) : MkSyncError()
    data class Unknown(val code: Int) : MkSyncError()
    val localizedMessageText: String
        get() = throw MkNotYetPorted("mk-sync.MkSyncError.localizedMessageText")
    val recoveryAction: MkSyncRecoveryAction
        get() = throw MkNotYetPorted("mk-sync.MkSyncError.recoveryAction")
}

enum class MkSyncRecoveryAction {
    OPEN_I_CLOUD_SETTINGS, NONE
}

object MkSyncErrorMapper {
    fun map(error: Throwable, projectTitle: String = ""): MkSyncError { throw MkNotYetPorted("mk-sync.MkSyncErrorMapper.map") }
}

