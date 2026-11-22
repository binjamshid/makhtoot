import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import Observation

// WS-14 packet §5 task 9. `MKAssetBrowserModel` ، sections by category,
// search, favorites, premium badge state, recents, and the placement API.
// `@Observable` (Swift Observation, available at this package's
// `.iOS(.v18)`/`.macOS(.v14)` platform floor) so WS-13's SwiftUI panel can
// bind directly, per the task's "@Observable-friendly" requirement.
//
// **Paywall-routing note (task 9: "→ `.premiumRequired` routes paywall
// context `.premiumFeatureTap(.premiumAsset)`").** `PaywallContext`/
// `PremiumFeature`/`MKRoute` are APP-TARGET types
// (`Makhtoot/AppShell/Navigation/MKRoute.swift`, owned by WS-13) ، `MKAssets`
// cannot import the app target (wrong dependency direction; also outside
// this run's fence). `select(_:)` below signals "premium required" using
// the shared, already-cross-module `MKFoundation.MKPremiumCapability
// .premiumAssets` enum case instead (the same vocabulary
// `MKEntitlementProviding.isEntitled(_:)` already uses everywhere else in
// the app). WS-13's integration is then a one-line addition to its own
// `PremiumFeature` enum:
//
//     // Makhtoot/AppShell/Navigation/MKRoute.swift, PremiumFeature:
//     case premiumAsset
//
// …and a one-line mapping at the call site
// (`nav.presentPaywall(.premiumFeatureTap(.premiumAsset))` when `select(_:)`
// returns `.premiumRequired`), mirroring the existing `.customCanvas` call
// site in `ProjectBrowserView.swift` exactly.
@MainActor
@Observable
public final class MKAssetBrowserModel {
    public private(set) var searchQuery: String = ""
    public private(set) var favoriteAssetIDs: Set<String> = []
    public private(set) var recentAssetIDs: [String] = []

    private let library: MKAssetLibrary
    private let metadataStore: any MKAssetMetadataStoring
    private let entitlement: any MKEntitlementProviding
    private let instantiator = MKAssetInstantiator()
    private let patternInstantiator = MKPatternInstantiator()

    public init(
        library: MKAssetLibrary = .standard,
        metadataStore: any MKAssetMetadataStoring = MKInMemoryAssetMetadataStore(),
        entitlement: any MKEntitlementProviding = StubEntitlementResolver()
    ) {
        self.library = library
        self.metadataStore = metadataStore
        self.entitlement = entitlement
    }

    /// Loads favorites/recents from `metadataStore` ، call once at panel
    /// appearance (async because the metadata store is an actor / future
    /// disk-backed store).
    public func loadMetadata() async {
        favoriteAssetIDs = await metadataStore.favoriteAssetIDs()
        recentAssetIDs = await metadataStore.recentAssetIDs()
    }

    public func setSearchQuery(_ query: String) {
        searchQuery = query
    }

    // MARK: - Sections / search

    /// Categories in browser-grid order (`MKAssetCategory.browserOrder`),
    /// each with its (search-filtered) descriptors ، the "sections by
    /// category (Arabic titles)" the task asks for.
    public func sections() -> [(category: MKAssetCategory, assets: [MKAssetDescriptor])] {
        MKAssetCategory.browserOrder.map { ($0, descriptors(in: $0)) }
    }

    public func descriptors(in category: MKAssetCategory) -> [MKAssetDescriptor] {
        let base = library.descriptors(in: category)
        guard !searchQuery.isEmpty else { return base }
        return base.filter { MKAssetSearchNormalizer.matches(query: searchQuery, nameAr: $0.nameAr, tags: $0.tags) }
    }

    // MARK: - Favorites

    public func isFavorite(_ assetID: String) -> Bool {
        favoriteAssetIDs.contains(assetID)
    }

    public func toggleFavorite(_ assetID: String) async {
        let newValue = !favoriteAssetIDs.contains(assetID)
        await metadataStore.setFavorite(assetID: assetID, isFavorite: newValue)
        favoriteAssetIDs = await metadataStore.favoriteAssetIDs()
    }

    public func favoriteDescriptors() -> [MKAssetDescriptor] {
        library.all.filter { favoriteAssetIDs.contains($0.assetID) }
    }

    // MARK: - Recents

    /// Last-used descriptors, most-recent-first (task 9: "recently-used
    /// list (last 12, persisted metadata)"). Ids the store no longer
    /// resolves to a known asset (e.g. a future library edit) are skipped
    /// rather than crashing.
    public func recentDescriptors() -> [MKAssetDescriptor] {
        recentAssetIDs.compactMap { library.descriptor(assetID: $0) }
    }

    // MARK: - Premium badge state

    /// Whether `descriptor` should show a lock badge for the CURRENT
    /// entitlement state (task 9: "premium badge state (from entitlement
    /// stream ، lock badge when free)"). Free-flagged assets are never
    /// locked regardless of entitlement.
    public func isLocked(_ descriptor: MKAssetDescriptor) -> Bool {
        descriptor.isPremium && !entitlement.isEntitled(.premiumAssets)
    }

    // MARK: - Placement

    public enum PlacementOutcome: Sendable {
        case placed(MKAssetInstantiator.Placement)
        case placedPattern(MKPatternInstantiator.Placement)
        /// Free entitlement blocked a premium asset ، the paywall-routing
        /// note at this file's header explains why this carries
        /// `MKPremiumCapability` rather than an app-target paywall type.
        case premiumRequired(capability: MKPremiumCapability, assetID: String, nameAr: String)
    }

    /// Places `descriptor` ، the browser's single entry point (task 9:
    /// "Placement API: `select(asset:) -> MKNode` via instantiator +
    /// premium gate check"). Records asset usage (recents) only on an
    /// ACTUAL placement, never on a blocked attempt. `canvasSize` is only
    /// consulted for `.patternBackgrounds` (tiling extent); other
    /// categories ignore it.
    @discardableResult
    public func select(_ descriptor: MKAssetDescriptor, at position: CGPoint = .zero, canvasSize: CGSize = CGSize(width: 1080, height: 1080)) async -> PlacementOutcome {
        guard entitlement.isEntitled(.premiumAssets) || !descriptor.isPremium else {
            return .premiumRequired(capability: .premiumAssets, assetID: descriptor.assetID, nameAr: descriptor.nameAr)
        }
        await metadataStore.recordUsed(assetID: descriptor.assetID)
        recentAssetIDs = await metadataStore.recentAssetIDs()

        if descriptor.category == .patternBackgrounds {
            guard let fill = library.patternFill(assetID: descriptor.assetID) else {
                // Structurally impossible for any library-sourced descriptor
                // (`MKAssetLibrary.standard` always pairs the two) ، falls
                // back to the gate rather than trapping, matching this
                // codebase's "degrade, don't crash on missing data" posture
                // (e.g. `MKPathData.cgPath(at:)`'s malformed-stream handling).
                return .premiumRequired(capability: .premiumAssets, assetID: descriptor.assetID, nameAr: descriptor.nameAr)
            }
            return .placedPattern(patternInstantiator.placeBackground(descriptor, fill: fill, canvasSize: canvasSize))
        }
        return .placed(instantiator.place(descriptor, at: position))
    }
}
