package net.binjamshid.makhtoot.mk.assets.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkUserDefaultsAssetMetadataStore(
    val suiteName: String? = null
) : MkAssetMetadataStoring {
    override suspend fun isFavorite(assetID: String): Boolean { throw MkNotYetPorted("mk-assets.MkUserDefaultsAssetMetadataStore.isFavorite") }
    override suspend fun setFavorite(assetID: String, isFavorite: Boolean) { throw MkNotYetPorted("mk-assets.MkUserDefaultsAssetMetadataStore.setFavorite") }
    suspend fun favoriteAssetIDs(): Set<String> { throw MkNotYetPorted("mk-assets.MkUserDefaultsAssetMetadataStore.favoriteAssetIDs") }
    override suspend fun recentAssetIDs(): List<String> { throw MkNotYetPorted("mk-assets.MkUserDefaultsAssetMetadataStore.recentAssetIDs") }
    override suspend fun recordUsed(assetID: String) { throw MkNotYetPorted("mk-assets.MkUserDefaultsAssetMetadataStore.recordUsed") }
}

