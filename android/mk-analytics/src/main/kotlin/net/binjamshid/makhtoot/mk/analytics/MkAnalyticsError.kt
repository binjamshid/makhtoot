package net.binjamshid.makhtoot.mk.analytics

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

sealed class MkAnalyticsError : Exception() {
    data class ConsentPersistenceFailure(val underlying: Throwable) : MkAnalyticsError()
    data class CounterPersistenceFailure(val underlying: Throwable) : MkAnalyticsError()
    data class UploadFailure(val underlying: Throwable) : MkAnalyticsError()
    data class KillSwitchFetchFailure(val underlying: Throwable) : MkAnalyticsError()
}

