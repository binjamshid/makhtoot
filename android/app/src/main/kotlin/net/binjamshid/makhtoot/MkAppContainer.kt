package net.binjamshid.makhtoot

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.analytics.service.MkAnalyticsService
import net.binjamshid.makhtoot.mk.assets.browser.MkAssetBrowserModel
import net.binjamshid.makhtoot.mk.assets.rendering.MkAssetThumbnailRenderer
import net.binjamshid.makhtoot.mk.fonts.MkFontImporter
import net.binjamshid.makhtoot.mk.fonts.MkFontRegistry
import net.binjamshid.makhtoot.mk.foundation.MkFeatureFlags
import net.binjamshid.makhtoot.mk.foundation.MkFontUsageRecording
import net.binjamshid.makhtoot.mk.foundation.MkNoOpFontUsageRecorder
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkDocumentStoring
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkInMemoryDocumentStore
import net.binjamshid.makhtoot.mk.store.MkEntitlementResolver
import net.binjamshid.makhtoot.mk.store.MkProductCatalog
import net.binjamshid.makhtoot.mk.store.MkPurchaseController
import net.binjamshid.makhtoot.mk.store.trial.MkTrialManager
import net.binjamshid.makhtoot.mk.sync.engine.MkSyncEngineController
import net.binjamshid.makhtoot.mk.sync.status.MkSyncStatusPublisher
import net.binjamshid.makhtoot.persistence.MkPersistenceProjectLibrary
import net.binjamshid.makhtoot.stubs.MkProjectLibraryProviding
import net.binjamshid.makhtoot.stubs.MkStaticSyncStatusPublisher
import net.binjamshid.makhtoot.stubs.MkSyncStatusProviding

class MkAppContainer(
    val documentStore: MkDocumentStoring = MkInMemoryDocumentStore(),
    val projectLibrary: MkProjectLibraryProviding = MkPersistenceProjectLibrary(),
    val entitlementProvider: MkEntitlementProviding,
    val syncStatusProvider: MkSyncStatusProviding = MkStaticSyncStatusPublisher(),
    val analyticsRecorder: MkFontUsageRecording = MkNoOpFontUsageRecorder(),
    val productCatalog: MkProductCatalog = MkProductCatalog(),
    val trialManager: MkTrialManager = MkTrialManager(),
    val entitlementResolver: MkEntitlementResolver,
    val purchaseController: MkPurchaseController,
    val fontRegistry: MkFontRegistry = MkFontRegistry(),
    val fontProvider: MkFontProviding,
    val fontImporter: MkFontImporter,
    val featureFlags: MkFeatureFlags? = null,
    val analyticsService: MkAnalyticsService,
    val syncStatusPublisher: MkSyncStatusPublisher,
    var syncEngineController: MkSyncEngineController? = null,
    val assetBrowserModel: MkAssetBrowserModel,
    val assetThumbnailRenderer: MkAssetThumbnailRenderer,
    val service: MkAnalyticsService.production = MkAnalyticsService.production(),
    val resolver: Any? = null,
    val registrar: Any? = null
)

