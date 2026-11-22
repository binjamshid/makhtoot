import MKAnalytics
import MKAssets
import MKFonts
import MKFoundation
import MKStore
import MKSync
import Observation

/// The composition root (D-231, ARCHITECTURE.md §2.1): the single place in
/// the app target that knows about every stub-vs-real service swap. Every
/// view/view-model under `Makhtoot/AppShell` receives its dependencies
/// through this container (`@Environment(AppContainer.self)`) rather than
/// instantiating a stub type directly, so a later workstream's real
/// implementation is a one-line change here, exactly as WS-13 packet §3
/// promises ("the composition root is the ONLY place stubs are referenced").
///
/// ## Stub matrix (WS-13 packet §3 / §8 "document the current stub matrix
/// in `AppContainer.swift` header comments")
///
/// | Capability | Protocol seam | Conformer wired this slice | Real implementation | Owning packet |
/// |---|---|---|---|---|
/// | Document content bytes | `MKDocumentStoring` (`MKFoundation`, WS-01) | `InMemoryDocumentStore` (still stub ، the browser no longer reads through this seam at all, see swap log below) | `.makhtoot` file-package store (manifest/scene/assets/backups) | WS-02 `MKPersistence` |
/// | Project list/metadata | `ProjectLibraryProviding` (`Makhtoot/Stubs`) | **SWAPPED this session** → `MKPersistenceProjectLibrary` (`Makhtoot/AppShell/Persistence/`) | SwiftData metadata index (D-112) | WS-02 `MKPersistence` |
/// | Entitlement/premium state | `MKEntitlementProviding` (`MKFoundation`, WS-01) | **SWAPPED this session (WS-10 T16)** → real `MKEntitlementResolver` (StoreKit 2, D-113 precedence, `MKStore`) | `MKEntitlementResolver` (StoreKit 2, D-113 precedence) | WS-10 `MKStore` |
/// | Sync status badges | `SyncStatusProviding` (`Makhtoot/Stubs`) | `StaticSyncStatusPublisher` (always `.none`) | `MKSyncService` per-project status publisher | WS-11 `MKSync` |
/// | Font-usage analytics hook | `MKFontUsageRecording` (`Makhtoot/Stubs`) | `NoOpAnalyticsRecorder` | `MKAnalyticsService` (consent-gated, D-125) | WS-12 `MKAnalytics` |
/// | Font catalog / picker | `MKFontProviding` (`MKFoundation`, WS-01) | **SWAPPED this session** → real `MKFontRegistry` (15 in-catalog OFL fonts + 5 provisional GPOS-cursive-flagged fonts, see `docs/impl-log/WS-09.md`), exposed as `MKRegistryFontProvider` | `MKFontRegistry` (bundled catalog + premium downloads + user imports) | WS-09 `MKFonts` |
/// | Asset browser catalog | `MKAssetBrowserModel` (`MKAssets`, WS-14) | **SWAPPED this session (P3.2)** → real `MKAssetBrowserModel` (`assetBrowserModel`, `MKAssetLibrary.standard` ، 57 assets/5 categories), sharing this container's real `entitlementProvider` so `isLocked`/`select(_:)` gate on actual entitlement | `MKAssetLibrary` (already the real bundled catalog, not a stub) | WS-14 `MKAssets` |
/// | Canvas host | `MKCanvasHosting` (named in WS-13 packet §3) | *not yet wired* | UIKit canvas (`UIViewRepresentable`) | WS-06 `MKCanvas` |
/// | Export sheet | ، | *not yet wired* | `MKExportService` sheet (disabled formats until then) | WS-08 `MKExport` |
/// | Purchase/restore flow | ، | **SWAPPED this session (WS-10)** → real `MKPurchaseController` (`purchaseController`) | `MKPurchaseController` | WS-10 `MKStore` |
/// | Paywall content (PW-01…PW-10) | `MKTrialStarting` (named in WS-13 packet §3) | **SWAPPED this session (WS-10)** → `MKPaywallStateMachine` instances constructed per-context by `Paywall/PaywallView.swift` from this container's `purchaseController` | `MKPaywallStateMachine` rendering | WS-10 `MKStore` |
/// | Trial record (D-123) | ، | **SWAPPED this session (WS-10)** → real `MKTrialManager` (Keychain + iCloud KVS), held here as `trialManager` | `MKTrialController` (Keychain + iCloud KVS) | WS-10 `MKStore` |
///
/// ## Swap log
///
/// - **Asset favorites/recents persistence session:** `assetBrowserModel`'s
///   `metadataStore` swapped `MKInMemoryAssetMetadataStore` →
///   `MKUserDefaultsAssetMetadataStore` (`MKAssets/Browser/`, `.standard`
///   defaults). Favorites/recents are small UI-preference state (an id set
///   + a capped-at-12 ordered list), not document content, so
///   `UserDefaults` is the right weight class ، no `MKPersistence`
///   dependency was added to `MKAssets` (that edge stays forbidden per the
///   module graph), and document journalling/CloudKit sync are untouched.
///   `MKInMemoryAssetMetadataStore` remains `MKAssetBrowserModel`'s own
///   library default (kept for hermetic tests); this app-target
///   composition root is the only place the real store is injected.
///
/// - **P3.2 session (asset browser):** `assetBrowserModel` added ، real
///   `MKAssetBrowserModel(library: .standard, entitlement:
///   entitlementProvider)`, constructed AFTER `entitlementResolver` below
///   so it shares that exact resolver instance (same "don't let two
///   consumers drift on different resolver state" reasoning the WS-10
///   swap-log note already established for `purchaseController`).
///   `assetThumbnailRenderer` (`MKAssetThumbnailRenderer`, an actor with
///   its own internal LRU cache) is held here too so a thumbnail render
///   survives the asset browser sheet being dismissed/reopened within one
///   app session, rather than re-rendering from scratch every time
///   `MKAssetBrowserSheet` appears. `MKAssetBrowserModel`'s metadata store
///   is now the real `MKUserDefaultsAssetMetadataStore` (see swap log below)
///   ، favorites/recents survive a process restart.
///
/// - **WS-10 session (T16, stub retirement):** `entitlementProvider`'s
///   conformer swapped `AlwaysPremiumEntitlementStub` (now `#if
///   DEBUG`-gated, kept only for previews/manual QA, never referenced from
///   this `init`'s default anymore) → the real `MKEntitlementResolver`.
///   Three new properties: `productCatalog` (`MKProductCatalog`),
///   `trialManager` (`MKTrialManager`), `purchaseController`
///   (`MKPurchaseController`) ، all three constructed together in `init`
///   so they share the same catalog/resolver instances rather than each
///   defaulting independently (a naive per-parameter default-value
///   approach would have given the purchase controller and the exposed
///   `entitlementProvider` two DIFFERENT resolver instances with
///   divergent state, which would have been a real bug, not just an
///   accepted rough edge ، logged here so the next reader doesn't
///   "simplify" the shared-construction block back into per-parameter
///   defaults by accident). `init` stays synchronous per this file's own
///   established `<1 ms` rule: `MKEntitlementResolver.init` itself is
///   synchronous (it does a plain file read for the offline cache, not an
///   `async` StoreKit round trip ، see that type's own header), and the
///   transaction-listener start + first `resolve()` are kicked off in a
///   detached `Task`, same pattern `fontRegistry`'s registrar already
///   established just below. `PaywallPlaceholderView.swift` is replaced by
///   a real `PaywallView.swift` (WS-10 T10/PW-01…PW-10) that constructs an
///   `MKPaywallStateMachine` from `purchaseController` per `MKRoute`'s
///   `PaywallContext`.
///
/// - **WS-09 session:** `fontRegistry` added ، real `MKFontRegistry`
///   replacing the "not yet wired" font-catalog row. `init` kicks off
///   `MKFontRegistrar.registerBundledFontsAtLaunch()` in a detached `Task`
///   (off the main actor, per T5's own AC) rather than blocking `init`
///   (`init` must stay synchronous/`<1 ms`, same reasoning already
///   documented above for `MKPersistenceProjectLibrary`'s lazy bootstrap) ،
///   registration itself measures well under 150 ms for the whole bundled
///   set (`MKFontsTests.MKFontRegistryTests`), so by the time the project
///   browser/editor actually renders a font preview, registration has
///   virtually always already completed; nothing currently gates first
///   paint on it. `App/Debug/ShapingHarnessView.swift` (DEBUG-only) was
///   given a minimal, additive edit ، a font picker sourced from this
///   container's `fontRegistry`, defaulting to Amiri ، purely so the
///   packet's own gate ("app builds + boots with fonts registered and
///   «مرحبا» shapes in Amiri via the debug harness") is actually
///   demonstrable; no other WS-13-owned UI file was touched.
///
/// - **P1-COMPLETION session:** `ProjectLibraryProviding`'s
///   conformer swapped `InMemoryProjectLibrary` → `MKPersistenceProjectLibrary`
///   (packet T4-T8/T14/T16 ، real `.makhtoot` packages under
///   `Documents/Projects/`, WS-02's `MetadataStore` SwiftData index,
///   `LaunchReconciler` on bootstrap + foreground). `MKDocumentStoring`
///   (`documentStore`) is intentionally left wired to WS-01's
///   `InMemoryDocumentStore` stub still ، the browser/new-project/duplicate/
///   delete flows now go entirely through `MKPersistenceProjectLibrary`
///   (which talks to `DocumentPackage`/`MetadataStore` directly), so nothing
///   in this slice actually calls `documentStore` anymore. It is kept wired
///   (not deleted) only because `MKFilePackageDocumentStore`
///   (`MKPersistence`, the real `MKDocumentStoring` conformer) exists for
///   whichever future call site is still coded against the generic
///   protocol rather than `MKPersistenceProjectLibrary`/`MakhtootDocument`
///   directly (see WS-02's own note on why both shapes ship). Swapping this
///   one remaining row is a one-line change in `init` below whenever a real
///   call site needs it.
///
/// **Scope note (this slice):** the previous EARLY-SLICE session shipped the
/// navigation skeleton, project-browser UI shell against a stub store,
/// settings navigation stub, and this composition root. Rows still marked
/// "not yet wired" are WS-13 packet tasks (T10 paywall content, T11 editor
/// scene composition, T19 pre-export disclosure) explicitly deferred until
/// their upstream packets (WS-06/08/09/10/14) land. See
/// `docs/impl-log/WS-13.md` for both sessions' full logs.
@MainActor @Observable
final class AppContainer {
    let documentStore: any MKDocumentStoring
    let projectLibrary: any ProjectLibraryProviding
    let entitlementProvider: any MKEntitlementProviding
    let syncStatusProvider: any SyncStatusProviding
    let analyticsRecorder: any MKFontUsageRecording

    /// WS-10 T16: the real StoreKit 2 product catalog, trial manager, and
    /// entitlement resolver ، `entitlementProvider` above is this exact
    /// `entitlementResolver` instance (typed to the protocol for every
    /// existing downstream call site), kept here too under its concrete
    /// type so paywall/settings UI can reach resolver-only members
    /// (`states()`, `detail`) that aren't part of `MKEntitlementProviding`.
    let productCatalog: MKProductCatalog
    let trialManager: MKTrialManager
    let entitlementResolver: MKEntitlementResolver
    let purchaseController: MKPurchaseController

    /// The real font registry (WS-09) ، bundled OFL catalog registered
    /// per-process at launch (D-122/D-219). `MKRegistryFontProvider`
    /// (`fontProvider`) is the `MKFontProviding` conformer every
    /// WS-03/WS-07 default-injection call site should receive once wired
    /// through, per `MakhtootKit/CONTRACTS.md`'s stub-to-real plan.
    let fontRegistry: MKFontRegistry
    let fontProvider: any MKFontProviding

    /// P7.2 (§2.2 font import, Bug 18): the real `MKFontImporter` actor,
    /// sharing this container's `fontRegistry`/`entitlementProvider` so an
    /// import gates on the SAME live entitlement state every other premium
    /// surface in this container reads (same "share the instance, not just
    /// the protocol" reasoning already documented for `purchaseController`/
    /// `assetBrowserModel` above). Constructed after both, below.
    let fontImporter: MKFontImporter

    /// The process-wide flag table (MKFoundation, WS-01).
    let featureFlags: MKFeatureFlags

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
        guard !enabled || entitlementResolver.isEntitled(.cloudSync) else { return }
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
        productCatalog: MKProductCatalog = MKProductCatalog(),
        trialManager: MKTrialManager = MKTrialManager(),
        syncStatusProvider: any SyncStatusProviding = StaticSyncStatusPublisher(),
        analyticsRecorder: any MKFontUsageRecording = MKNoOpFontUsageRecorder(),
        fontRegistry: MKFontRegistry = MKFontRegistry(),
        featureFlags: MKFeatureFlags = .default
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
        self.featureFlags = featureFlags

        // WS-12 T16: real analytics service ، shared as both the concrete
        // `analyticsService` (for Settings consent UI) and the protocol-typed
        // `analyticsRecorder` (for the editor hook). The init parameter
        // `analyticsRecorder` is kept for test/preview injection (see
        // AppContainer stub matrix header), but in the production path the
        // real service is always used; pre-consent it is a pure no-op by design.
        let service = MKAnalyticsService.production()
        self.analyticsService = service
        self.analyticsRecorder = service

        // WS-10 T16 (stub retirement): `productCatalog`/`trialManager`/
        // `entitlementResolver`/`purchaseController` are constructed
        // together, in that order, so `entitlementProvider` and
        // `purchaseController` share the exact same resolver instance ،
        // see the swap-log note above for why that matters.
        self.productCatalog = productCatalog
        self.trialManager = trialManager
        let resolver = MKEntitlementResolver(catalog: productCatalog, trialManager: trialManager)
        self.entitlementResolver = resolver
        self.entitlementProvider = resolver
        self.purchaseController = MKPurchaseController(catalog: productCatalog, resolver: resolver)

        // P7.2: constructed AFTER `fontRegistry`/`resolver` so it shares
        // both live instances (same reasoning as `assetBrowserModel`'s own
        // note just below).
        self.fontImporter = MKFontImporter(registry: fontRegistry, entitlements: resolver)

        // P3.2: constructed AFTER `resolver`/`entitlementProvider` above so
        // `assetBrowserModel.isLocked(_:)`/`select(_:)` gate on the SAME
        // resolver instance every other entitlement-aware surface in this
        // container reads (see this file's swap-log note for why sharing
        // the instance matters, not just the protocol). `init` stays
        // synchronous/`<1 ms` ، `MKAssetLibrary.standard`/
        // `MKAssetBrowserModel.init` do no I/O (see `MKAssetLibrary.swift`'s
        // own "Swift construction is essentially free" doc comment).
        // `MKUserDefaultsAssetMetadataStore.init` only reads `UserDefaults`
        // (an already-in-memory-cached plist after first access, not a disk
        // round trip), so this stays within the same synchronous budget.
        self.assetBrowserModel = MKAssetBrowserModel(
            metadataStore: MKUserDefaultsAssetMetadataStore(),
            entitlement: resolver
        )
        self.assetThumbnailRenderer = MKAssetThumbnailRenderer()

        // T5 AC: registration off the main actor, not blocking `init`
        // (which must stay synchronous/`<1 ms`, see the swap-log note
        // above). `Task` inherits no actor here since `init` is not
        // actor-isolated, so this hops straight to `MKFontRegistry`'s own
        // actor executor.
        let registrar = MKFontRegistrar(registry: fontRegistry)
        Task.detached(priority: .userInitiated) {
            await registrar.registerBundledFontsAtLaunch()
        }

        // WS-10 T4/T5: start the long-lived `Transaction.updates` listener
        // and run the first resolution off the main actor, same
        // "don't block synchronous init" pattern as the font registrar
        // just above. Until this first `resolve()` completes, `state`
        // reads whatever `MKEntitlementResolver.init` loaded from its
        // on-disk cache (T5: `.free` on a genuinely first-ever launch,
        // the last-known state on every launch after that).
        Task.detached(priority: .userInitiated) {
            await resolver.startTransactionListener()
            await resolver.resolve()
        }

        // WS-12 T16: bootstrap analytics service (load consent + counters
        // from disk). Also triggers an opportunistic upload cycle in case
        // a closed week is ready. Same "off main actor, don't block init"
        // pattern as the font registrar and entitlement resolver above.
        Task.detached(priority: .background) {
            await service.bootstrap()
            await service.triggerUploadIfDue()
        }

        Task { @MainActor [weak self, syncStatusPublisher, projectLibrary, entitlementResolver] in
            guard let library = projectLibrary as? MKPersistenceProjectLibrary else { return }
            guard let controller = await library.makeSyncEngineController(
                entitlementProvider: entitlementResolver,
                statusPublisher: syncStatusPublisher,
                preference: syncPreference
            ) else { return }
            self?.syncEngineController = controller
            // The stream sends the initial state and future changes even
            // when Settings is closed.
            for await _ in await entitlementResolver.states() {
                guard self != nil else { break }
                Task { await controller.refreshAvailability() }
            }
        }
    }
}
