package net.binjamshid.makhtoot.mk.sync.tunables

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

object MkSyncTunables {
    val singleAssetAdvisoryBytes: Int? = null
    val totalProjectAdvisoryBytes: Int? = null
    val uploadDebounceInterval: kotlin.time.Duration? = null
    val initialRetryBackoff: kotlin.time.Duration? = null
    val maxRetryBackoff: kotlin.time.Duration? = null
    val retryJitterFraction: Double = 0.2
    val supportedSchemaVersion: Long = 1
    val maxRecordsPerBatch: Int = 200
    fun isAssetTooLarge(byteCount: Int): Boolean { throw MkNotYetPorted("mk-sync.MkSyncTunables.isAssetTooLarge") }
    fun isProjectTooLarge(byteCount: Int): Boolean { throw MkNotYetPorted("mk-sync.MkSyncTunables.isProjectTooLarge") }
    fun backoffInterval(attempt: Int, base: Double = 5.0): kotlin.time.Duration { throw MkNotYetPorted("mk-sync.MkSyncTunables.backoffInterval") }
}

