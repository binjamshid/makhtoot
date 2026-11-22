package net.binjamshid.makhtoot.mk.analytics.upload

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.analytics.consent.MkConsentManager
import net.binjamshid.makhtoot.mk.analytics.counter.MkUsageCounterStore
import net.binjamshid.makhtoot.mk.foundation.MkFeatureFlags

class MkAnalyticsUploader(
    val consentManager: MkConsentManager,
    val counterStore: MkUsageCounterStore,
    val database: MkCloudKitPublicDatabase,
    val featureFlags: MkFeatureFlags? = null,
    val lastUploadURL: java.net.URI
) {
    suspend fun runUploadCycle() { throw MkNotYetPorted("mk-analytics.MkAnalyticsUploader.runUploadCycle") }
    companion object {
        fun production(consentManager: MkConsentManager, counterStore: MkUsageCounterStore, database: MkCloudKitPublicDatabase = MkLiveCloudKitPublicDatabase()): MkAnalyticsUploader { throw MkNotYetPorted("mk-analytics.MkAnalyticsUploader.production") }
    }
}

object MkAnalyticsStorage {
    fun analyticsDirectory(): java.net.URI { throw MkNotYetPorted("mk-analytics.MkAnalyticsStorage.analyticsDirectory") }
}

