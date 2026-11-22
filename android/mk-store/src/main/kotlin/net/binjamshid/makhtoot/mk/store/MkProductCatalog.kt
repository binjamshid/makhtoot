package net.binjamshid.makhtoot.mk.store

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkStoreProduct(
    val id: String,
    val displayPrice: String,
    val displayName: String,
    val kind: Kind
) {
    sealed class Kind {
        data class Subscription(val period: String) : Kind()
        object NonConsumable : Kind()
    }
}

sealed class MkCatalogState {
    object Loading : MkCatalogState()
    data class Loaded(val arg0: List<MkStoreProduct>) : MkCatalogState()
    object CatalogUnavailable : MkCatalogState()
}

class MkProductCatalog(
    val ids: List<String>? = null,
    val maxRetries: Int = 3,
    val baseBackoff: kotlin.time.Duration? = null
) {
    val cachedProjection: List<MkStoreProduct>
        get() = throw MkNotYetPorted("mk-store.MkProductCatalog.cachedProjection")
    fun product(id: String): Any? { throw MkNotYetPorted("mk-store.MkProductCatalog.product") }
    suspend fun load(): MkCatalogState { throw MkNotYetPorted("mk-store.MkProductCatalog.load") }
}

