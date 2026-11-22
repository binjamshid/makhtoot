package net.binjamshid.makhtoot.mk.analytics.upload

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

interface MkCloudKitPublicDatabase {
    suspend fun saveBatch(batch: MkFontUsageBatch)
    suspend fun fetchAnalyticsConfig(): MkAnalyticsConfigValue?
}

data class MkAnalyticsConfigValue(
    val analyticsEnabled: Boolean
)

class MkLiveCloudKitPublicDatabase(
    val database: Any? = null
) : MkCloudKitPublicDatabase {
    override suspend fun saveBatch(batch: MkFontUsageBatch) { throw MkNotYetPorted("mk-analytics.MkLiveCloudKitPublicDatabase.saveBatch") }
    override suspend fun fetchAnalyticsConfig(): MkAnalyticsConfigValue? { throw MkNotYetPorted("mk-analytics.MkLiveCloudKitPublicDatabase.fetchAnalyticsConfig") }
}

