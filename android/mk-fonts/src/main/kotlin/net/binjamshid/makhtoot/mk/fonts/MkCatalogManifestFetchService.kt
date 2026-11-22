package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkCatalogManifestFetchService(
    val session: MkPlatformHttpSession = MkPlatformHttpSession(),
    val cacheURL: java.net.URI? = null,
    val clock: (() -> java.time.Instant)? = null,
    val maxManifestBytes: Int = defaultMaxManifestBytes
) {
    suspend fun fetch(manifestURL: java.net.URI): State { throw MkNotYetPorted("mk-fonts.MkCatalogManifestFetchService.fetch") }
    companion object {
        val emptyStateMessage: String = "لا يمكن تحميل قائمة الخطوط دون اتصال"
        val staleness: Double = 86400.0
        val defaultMaxManifestBytes: Int = 5 * 1024 * 1024
    }
    sealed class State {
        data class Fresh(val arg0: MkCatalogManifestSnapshot) : State()
        data class Stale(val arg0: MkCatalogManifestSnapshot) : State()
        data class Empty(val message: String) : State()
    }
}

data class MkCatalogManifestSnapshot(
    var manifest: MkCatalogManifest,
    var fetchedAt: java.time.Instant
)


