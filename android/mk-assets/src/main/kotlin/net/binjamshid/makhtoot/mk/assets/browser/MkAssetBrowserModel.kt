package net.binjamshid.makhtoot.mk.assets.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.instantiation.MkAssetInstantiator
import net.binjamshid.makhtoot.mk.assets.instantiation.MkPatternInstantiator
import net.binjamshid.makhtoot.mk.assets.library.MkAssetLibrary
import net.binjamshid.makhtoot.mk.assets.model.MkAssetCategory
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkPremiumCapability
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkStubEntitlementResolver
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

class MkAssetBrowserModel(
    val library: MkAssetLibrary? = null,
    val metadataStore: MkAssetMetadataStoring = MkInMemoryAssetMetadataStore(),
    val entitlement: MkEntitlementProviding = MkStubEntitlementResolver()
) {
    suspend fun loadMetadata() { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.loadMetadata") }
    fun setSearchQuery(query: String) { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.setSearchQuery") }
    fun sections(): List<Pair<MkAssetCategory, List<MkAssetDescriptor>>> { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.sections") }
    fun descriptors(category: MkAssetCategory): List<MkAssetDescriptor> { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.descriptors") }
    fun isFavorite(assetID: String): Boolean { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.isFavorite") }
    suspend fun toggleFavorite(assetID: String) { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.toggleFavorite") }
    fun favoriteDescriptors(): List<MkAssetDescriptor> { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.favoriteDescriptors") }
    fun recentDescriptors(): List<MkAssetDescriptor> { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.recentDescriptors") }
    fun isLocked(descriptor: MkAssetDescriptor): Boolean { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.isLocked") }
    suspend fun select(descriptor: MkAssetDescriptor, position: MkPoint? = null, canvasSize: MkSize? = null): PlacementOutcome { throw MkNotYetPorted("mk-assets.MkAssetBrowserModel.select") }
    sealed class PlacementOutcome {
        data class Placed(val arg0: MkAssetInstantiator.Placement) : PlacementOutcome()
        data class PlacedPattern(val arg0: MkPatternInstantiator.Placement) : PlacementOutcome()
        data class PremiumRequired(val capability: MkPremiumCapability, val assetID: String, val nameAr: String) : PlacementOutcome()
    }
}

