package net.binjamshid.makhtoot.mk.assets.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

interface MkAssetMetadataStoring {
    suspend fun isFavorite(assetID: String): Boolean
    suspend fun setFavorite(assetID: String, isFavorite: Boolean)
    suspend fun recentAssetIDs(): List<String>
    suspend fun recordUsed(assetID: String)
}

class MkInMemoryAssetMetadataStore : MkAssetMetadataStoring {
    override suspend fun isFavorite(assetID: String): Boolean { throw MkNotYetPorted("mk-assets.MkInMemoryAssetMetadataStore.isFavorite") }
    override suspend fun setFavorite(assetID: String, isFavorite: Boolean) { throw MkNotYetPorted("mk-assets.MkInMemoryAssetMetadataStore.setFavorite") }
    suspend fun favoriteAssetIDs(): Set<String> { throw MkNotYetPorted("mk-assets.MkInMemoryAssetMetadataStore.favoriteAssetIDs") }
    override suspend fun recentAssetIDs(): List<String> { throw MkNotYetPorted("mk-assets.MkInMemoryAssetMetadataStore.recentAssetIDs") }
    override suspend fun recordUsed(assetID: String) { throw MkNotYetPorted("mk-assets.MkInMemoryAssetMetadataStore.recordUsed") }
}

