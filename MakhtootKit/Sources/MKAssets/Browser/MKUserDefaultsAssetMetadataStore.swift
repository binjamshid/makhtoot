import Foundation

// WS-14 packet §3's documented "stub protocol, real conformer later" swap
// (see `MKAssetFavoritesStoring.swift`'s header) ، but landing BEFORE any
// `MKPersistence` integration, per this run's fence: `MKAssets` must not
// gain a dependency on `MKPersistence` (`ARCHITECTURE.md`'s module graph is
// frozen for this slice, and `MKRender` must never reach `MKAssets`
// transitively through it either). Favorites/recents are small, UI-local
// preference state ، a set of ids plus a 12-element ordered list ، not
// document content, so they don't belong in `MakhtootDocument`'s
// manifest/scene/CloudKit journalling anyway; `UserDefaults` is the correct
// weight class for this data, matching the repo's own existing lightweight-
// preference pattern (`EditorTourModel`'s `MKEditorTourCompleted` flag,
// `MKColorFavouritesStore` in `FontSettingsSheet.swift`).
public actor MKUserDefaultsAssetMetadataStore: MKAssetMetadataStoring {
    /// Reverse-DNS-namespaced per this repo's established key convention
    /// (`net.binjamshid.makhtoot.<area>`, see `MKStoreIDs.swift`/`MKLog.swift`/
    /// `MKSyncSchema.swift`) rather than the shorter `"MK..."`/`"mk...."` ad
    /// hoc keys some UI-layer call sites use ، this type lives in
    /// `MKAssets`, a shared package (not an app-target-only view file), so
    /// it follows the package-wide namespacing rule to avoid any future key
    /// collision with another module's own `UserDefaults` usage.
    private static let favoritesKey = "net.binjamshid.makhtoot.assets.favorites"
    private static let recentsKey = "net.binjamshid.makhtoot.assets.recents"

    /// Recents are capped at 12 (task 9: "recently-used list (last 12,
    /// persisted metadata)") ، mirrors `MKInMemoryAssetMetadataStore`'s own
    /// cap exactly so the two conformers are behaviorally interchangeable.
    private static let recentsCap = 12

    private let defaults: UserDefaults

    /// Read-through in-memory mirrors of `defaults`' on-disk state. Kept so
    /// every read after the first doesn't re-decode from `UserDefaults`,
    /// while every WRITE still goes straight through to `defaults` ، the
    /// actual source of truth that must survive a process restart (the
    /// requirement this type exists to satisfy, unlike the in-memory stub).
    private var favorites: Set<String>
    private var recents: [String]

    /// The SUITE NAME is injectable (default `nil`, resolving to `.standard`)
    /// rather than a `UserDefaults` instance ، a `UserDefaults` instance is
    /// not `Sendable` and cannot cross into an actor's initializer under
    /// Swift 6 complete concurrency (any nonisolated caller, including test
    /// code, would be sending a non-`Sendable` value across an isolation
    /// boundary). `String?` IS `Sendable`, so passing the name and
    /// constructing the actual `UserDefaults` instance here, inside the
    /// actor, keeps the isolation boundary clean while still letting tests
    /// point an isolated instance at `UserDefaults(suiteName:)` and assert
    /// real persistence across a FRESH store instance without touching the
    /// process's actual standard defaults.
    public init(suiteName: String? = nil) {
        let defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.defaults = defaults
        self.favorites = Set(defaults.stringArray(forKey: Self.favoritesKey) ?? [])
        self.recents = defaults.stringArray(forKey: Self.recentsKey) ?? []
    }

    public func isFavorite(assetID: String) async -> Bool {
        favorites.contains(assetID)
    }

    public func setFavorite(assetID: String, isFavorite: Bool) async {
        if isFavorite {
            favorites.insert(assetID)
        } else {
            favorites.remove(assetID)
        }
        persistFavorites()
    }

    public func favoriteAssetIDs() async -> Set<String> {
        favorites
    }

    public func recentAssetIDs() async -> [String] {
        recents
    }

    public func recordUsed(assetID: String) async {
        recents.removeAll { $0 == assetID }
        recents.insert(assetID, at: 0)
        if recents.count > Self.recentsCap {
            recents.removeLast(recents.count - Self.recentsCap)
        }
        persistRecents()
    }

    // MARK: - Persistence

    /// `UserDefaults` cannot store `Set` directly (`propertyList`-eligible
    /// types only) ، converted to `[String]` at the boundary. Order among
    /// favorites is not meaningful (it's a set), so no ordering guarantee is
    /// needed here, unlike `recents`.
    private func persistFavorites() {
        defaults.set(Array(favorites), forKey: Self.favoritesKey)
    }

    private func persistRecents() {
        defaults.set(recents, forKey: Self.recentsKey)
    }
}
