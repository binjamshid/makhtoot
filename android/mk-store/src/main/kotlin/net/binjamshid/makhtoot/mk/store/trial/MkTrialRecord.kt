package net.binjamshid.makhtoot.mk.store.trial

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkTrialRecord(
    var firstLaunchAt: java.time.Instant,
    var lastObservedWallClock: java.time.Instant,
    var lastObservedBoottime: Double,
    var extensionDays: Int = 0,
    var recordVersion: Int = 1,
    var deviceFirstSeen: String? = null
)

sealed class MkTrialState {
    data class Active(val daysLeft: Int) : MkTrialState()
    object Expired : MkTrialState()
}

enum class MkTrialExtensionSource {
    REFERRAL
}

