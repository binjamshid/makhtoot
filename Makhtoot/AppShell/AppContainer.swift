import MKAnalytics
import MKAssets
import MKFonts
import MKFoundation
import MKSync
import Observation

/// Owns the editor, project library, and app-wide services.
@MainActor @Observable
final class AppContainer {
    let documentStore: any MKDocumentStoring
    let projectLibrary: any ProjectLibraryProviding
    let entitlementProvider: any MKEntitlementProviding
    let syncStatusProvider: any SyncStatusProviding
    let analyticsRecorder: any MKFontUsageRecording

    /// The real font registry (WS-09) ، bundled OFL catalog registered
    /// per-process at launch (D-122/D-219). `MKRegistryFontProvider`
    /// (`fontProvider`) is the `MKFontProviding` conformer every
    /// WS-03/WS-07 default-injection call site should receive once wired
    /// through, per `MakhtootKit/CONTRACTS.md`'s stub-to-real plan.
    let fontRegistry: MKFontRegistry
    let fontProvider: any MKFontProviding

    let fontImporter: MKFontImporter

    /// WS-12 T16: the real analytics service (MKAnalyticsService), held
    /// under its concrete type so Settings/Privacy UI can reach consent-
    /// management members (grant, revoke, status). `analyticsRecorder`
    /// above types it to the MKFontUsageRecording protocol for every
    /// existing downstream call site.
    let analyticsService: MKAnalyticsService

    /// WS-11: the real iCloud sync engine controller and its status publisher.
    let syncStatusPublisher: MKSyncStatusPublisher
    private(set) var syncEngineController: MKSyncEngineController?
    private let syncPreference: MKSyncPreference
    private(set) var isProjectSyncEnabled: Bool

    func setProjectSyncEnabled(_ enabled: Bool) {
        syncPreference.setEnabled(enabled)
        isProjectSyncEnabled = syncPreference.isEnabled
        Task { await syncEngineController?.refreshAvailability() }
    }

    /// P3.2: the real asset browser model (WS-14's bundled 57-asset/
    /// 5-category library), shared for the app's process lifetime so
    /// favorites/recents (currently in-memory, see swap-log note above)
    /// and the thumbnail cache both persist across sheet presentations.
    let assetBrowserModel: MKAssetBrowserModel
    let assetThumbnailRenderer: MKAssetThumbnailRenderer

    init(
        documentStore: any MKDocumentStoring = InMemoryDocumentStore(),
        projectLibrary: any ProjectLibraryProviding = MKPersistenceProjectLibrary(),
        syncStatusProvider: any SyncStatusProviding = StaticSyncStatusPublisher(),
        analyticsRecorder: any MKFontUsageRecording = MKNoOpFontUsageRecorder(),
        fontRegistry: MKFontRegistry = MKFontRegistry()
    ) {
        self.documentStore = documentStore
        self.projectLibrary = projectLibrary
        self.syncStatusPublisher = MKSyncStatusPublisher()
        self.syncStatusProvider = MKSyncStatusAdapter(publisher: syncStatusPublisher)
        let syncPreference = MKSyncPreference()
        self.syncPreference = syncPreference
        self.isProjectSyncEnabled = syncPreference.isEnabled
        self.syncEngineController = nil  // created asynchronously below
        self.fontRegistry = fontRegistry
        self.fontProvider = MKRegistryFontProvider()

        let service = MKAnalyticsService.production()
        self.analyticsService = service
        self.analyticsRecorder = service

        let access = MKUnrestrictedAppAccess()
        self.entitlementProvider = access
        self.fontImporter = MKFontImporter(registry: fontRegistry, entitlements: access)
        self.assetBrowserModel = MKAssetBrowserModel(
            metadataStore: MKUserDefaultsAssetMetadataStore(),
            entitlement: access
        )
        self.assetThumbnailRenderer = MKAssetThumbnailRenderer()

        let registrar = MKFontRegistrar(registry: fontRegistry)
        Task.detached(priority: .userInitiated) {
            await registrar.registerBundledFontsAtLaunch()
        }

        // WS-12 T16: bootstrap analytics service (load consent + counters
        // from disk). Also triggers an opportunistic upload cycle in case
        // a closed week is ready. Same "off main actor, don't block init"
        // pattern as the font registrar above.
        Task.detached(priority: .background) {
            await service.bootstrap()
            await service.triggerUploadIfDue()
        }

        Task { @MainActor [weak self, syncStatusPublisher, projectLibrary, access] in
            guard let library = projectLibrary as? MKPersistenceProjectLibrary else { return }
            guard let controller = await library.makeSyncEngineController(
                entitlementProvider: access,
                statusPublisher: syncStatusPublisher,
                preference: syncPreference
            ) else { return }
            self?.syncEngineController = controller
            await controller.refreshAvailability()
        }
    }
}
