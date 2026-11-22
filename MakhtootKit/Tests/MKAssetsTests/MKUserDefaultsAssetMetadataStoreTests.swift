import Foundation
import Testing
@testable import MKAssets

// Persistence proof for the real `MKAssetMetadataStoring` conformer ، every
// test here points an ISOLATED `UserDefaults(suiteName:)` at a fresh suite
// (not `.standard`, which would leak state across test runs/the app itself)
// and tears it down with `removePersistentDomain(forName:)`, mirroring this
// repo's existing isolated-suite test pattern for other `UserDefaults`-backed
// state.
//
// Stores are constructed with a suite NAME (`String?`, `Sendable`), not a
// `UserDefaults` instance ، `UserDefaults` isn't `Sendable`, so handing one
// to the actor's `init` from this nonisolated test context would be a
// cross-isolation send under Swift 6 complete concurrency. Passing the name
// and letting the actor construct its own `UserDefaults` internally keeps
// every send across the boundary `Sendable`. Teardown still needs a local
// `UserDefaults(suiteName:)` to call `removePersistentDomain(forName:)` on ،
// that local instance is created and used only within this nonisolated
// scope and never crosses into the actor, so it is fine.
@Suite("MKUserDefaultsAssetMetadataStore")
struct MKUserDefaultsAssetMetadataStoreTests {
    /// Builds a fresh suite name for one test ، unique per call so parallel
    /// test execution can't collide.
    private func makeIsolatedSuiteName(name: String) -> String {
        "net.binjamshid.makhtoot.tests.\(name).\(UUID().uuidString)"
    }

    @Test func favoriteSetAndUnsetRoundTripsAcrossAFreshStoreInstance() async {
        let suiteName = makeIsolatedSuiteName(name: "favorites")
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let store = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        #expect(await store.isFavorite(assetID: "shape.star-8") == false)

        await store.setFavorite(assetID: "shape.star-8", isFavorite: true)
        #expect(await store.isFavorite(assetID: "shape.star-8"))

        // The actual persistence proof: a BRAND NEW store instance pointed
        // at the SAME suite sees the favorite without any in-process state
        // being shared ، only the underlying `UserDefaults` suite carries it
        // across.
        let reopened = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        #expect(await reopened.isFavorite(assetID: "shape.star-8"))
        #expect(await reopened.favoriteAssetIDs() == ["shape.star-8"])

        await reopened.setFavorite(assetID: "shape.star-8", isFavorite: false)
        #expect(await reopened.isFavorite(assetID: "shape.star-8") == false)

        let reopenedAgain = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        #expect(await reopenedAgain.isFavorite(assetID: "shape.star-8") == false)
        #expect(await reopenedAgain.favoriteAssetIDs().isEmpty)
    }

    @Test func recentsPersistMostRecentFirstAcrossAFreshStoreInstance() async {
        let suiteName = makeIsolatedSuiteName(name: "recentsOrder")
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let store = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        await store.recordUsed(assetID: "shape.rectangle")
        await store.recordUsed(assetID: "shape.ellipse")

        let reopened = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        let recents = await reopened.recentAssetIDs()
        #expect(recents == ["shape.ellipse", "shape.rectangle"])
    }

    @Test func recordUsedDedupesByRemovingExistingOccurrenceAndReinsertingAtFront() async {
        let suiteName = makeIsolatedSuiteName(name: "recentsDedupe")
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let store = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        await store.recordUsed(assetID: "a")
        await store.recordUsed(assetID: "b")
        await store.recordUsed(assetID: "c")
        #expect(await store.recentAssetIDs() == ["c", "b", "a"])

        // Re-using "a" moves it to the front without duplicating it.
        await store.recordUsed(assetID: "a")
        let recents = await store.recentAssetIDs()
        #expect(recents == ["a", "c", "b"])
        #expect(recents.count == 3)

        // Dedupe result survives a fresh store instance too, not just the
        // in-memory one.
        let reopened = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        let reopenedRecents = await reopened.recentAssetIDs()
        #expect(reopenedRecents == ["a", "c", "b"])
    }

    @Test func recentsAreCappedAtTwelveMostRecentFirst() async {
        let suiteName = makeIsolatedSuiteName(name: "recentsCap")
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let store = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        for i in 0..<13 {
            await store.recordUsed(assetID: "asset-\(i)")
        }
        let recents = await store.recentAssetIDs()
        #expect(recents.count == 12)
        // Most recently recorded (asset-12) is first.
        #expect(recents.first == "asset-12")
        // The very first recorded (asset-0, now evicted past the cap) is gone.
        #expect(!recents.contains("asset-0"))

        // Cap survives a fresh store instance too, not just the in-memory one.
        let reopened = MKUserDefaultsAssetMetadataStore(suiteName: suiteName)
        let reopenedRecents = await reopened.recentAssetIDs()
        #expect(reopenedRecents.count == 12)
        #expect(reopenedRecents.first == "asset-12")
    }
}
