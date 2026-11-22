package net.binjamshid.makhtoot.mk.analytics.upload

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.analytics.counter.MkFontUsageBucket

data class MkFontUsageBatch(
    val batchID: String,
    val week: String,
    val appVersion: String,
    val entries: List<Entry>
) {
    fun toCKFieldDict(): Map<String, Any> { throw MkNotYetPorted("mk-analytics.MkFontUsageBatch.toCKFieldDict") }
    fun serializedPayloadKeys(): Set<String> { throw MkNotYetPorted("mk-analytics.MkFontUsageBatch.serializedPayloadKeys") }
    companion object {
        val recordType: String = "MKFontUsageBatch"
        val allowedPayloadKeys: Set<String> = setOf("batchID", "week", "appVersion", "entries")
    }
    data class Entry(
        val fontID: String,
        val bucket: MkFontUsageBucket
    )
}

object MkAppVersion {
    val majorMinor: String
        get() = throw MkNotYetPorted("mk-analytics.MkAppVersion.majorMinor")
}

