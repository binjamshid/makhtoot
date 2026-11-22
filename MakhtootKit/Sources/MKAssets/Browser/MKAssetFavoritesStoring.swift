import Foundation

// WS-14 packet §3 upstream deps: "MKPersistence (WS-02): favorites +
// browser metadata. Stub: in-memory favorites until integrated." Mirrors
// the `MKEntitlementProviding`/`MKFontProviding` stub-protocol pattern
// `CONTRACTS.md` documents for every other cross-workstream seam: code
// against the PROTOCOL, swap the concrete stub for a real
// `MKPersistence`-backed conformer later with zero call-site changes.
public protocol MKAssetMetadataStoring: Sendable {
    func isFavorite(assetID: String) async -> Bool
    func setFavorite(assetID: String, isFavorite: Bool) async
    func favoriteAssetIDs() async -> Set<String>

    /// Most-recently-used asset ids, most recent first, capped at 12
    /// (task 9: "recently-used list (last 12, persisted metadata)").
    func recentAssetIDs() async -> [String]
    func recordUsed(assetID: String) async
}

/// In-memory conformer ، the stub this packet's §3 explicitly calls for.
/// `MKPersistence`'s real, disk-backed store is the eventual replacement
/// (out of this run's fence); every call site in `MKAssetBrowserModel`
/// codes against `MKAssetMetadataStoring` only, so that swap needs no
/// call-site change.
public actor MKInMemoryAssetMetadataStore: MKAssetMetadataStoring {
    private var favorites: Set<String> = []
    private var recents: [String] = [] // most recent first

    public init() {}

    public func isFavorite(assetID: String) async -> Bool {
        favorites.contains(assetID)
    }

    public func setFavorite(assetID: String, isFavorite: Bool) async {
        if isFavorite {
            favorites.insert(assetID)
        } else {
            favorites.remove(assetID)
        }
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
        if recents.count > 12 {
            recents.removeLast(recents.count - 12)
        }
    }
}
