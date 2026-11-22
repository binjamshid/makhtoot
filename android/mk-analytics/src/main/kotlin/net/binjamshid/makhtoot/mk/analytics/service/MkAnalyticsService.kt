package net.binjamshid.makhtoot.mk.analytics.service

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.analytics.consent.MkConsentManager
import net.binjamshid.makhtoot.mk.analytics.counter.MkUsageCounterStore
import net.binjamshid.makhtoot.mk.analytics.upload.MkAnalyticsUploader
import net.binjamshid.makhtoot.mk.analytics.upload.MkCloudKitPublicDatabase
import net.binjamshid.makhtoot.mk.analytics.upload.MkLiveCloudKitPublicDatabase
import net.binjamshid.makhtoot.mk.foundation.MkFeatureFlags
import net.binjamshid.makhtoot.mk.foundation.MkFontUsageRecording

class MkAnalyticsService(
    val consentManager: MkConsentManager,
    val counterStore: MkUsageCounterStore,
    val uploader: MkAnalyticsUploader,
    val featureFlags: MkFeatureFlags? = null
) : MkFontUsageRecording {
    val lastRecordedWeek: String?
        get() = throw MkNotYetPorted("mk-analytics.MkAnalyticsService.lastRecordedWeek")
    val isConsentGranted: Boolean
        get() = throw MkNotYetPorted("mk-analytics.MkAnalyticsService.isConsentGranted")
    suspend fun bootstrap() { throw MkNotYetPorted("mk-analytics.MkAnalyticsService.bootstrap") }
    override suspend fun recordFontUsed(fontID: String) { throw MkNotYetPorted("mk-analytics.MkAnalyticsService.recordFontUsed") }
    suspend fun grantConsent() { throw MkNotYetPorted("mk-analytics.MkAnalyticsService.grantConsent") }
    suspend fun revokeConsent() { throw MkNotYetPorted("mk-analytics.MkAnalyticsService.revokeConsent") }
    suspend fun triggerUploadIfDue() { throw MkNotYetPorted("mk-analytics.MkAnalyticsService.triggerUploadIfDue") }
    companion object {
        fun production(database: MkCloudKitPublicDatabase = MkLiveCloudKitPublicDatabase()): MkAnalyticsService { throw MkNotYetPorted("mk-analytics.MkAnalyticsService.production") }
    }
}

