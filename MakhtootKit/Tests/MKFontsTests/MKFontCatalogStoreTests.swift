import Foundation
import MKPersistence
import Testing
@testable import MKFonts

/// T6 AC: favorites toggle persists across relaunch (simulated by
/// reopening a store over the same on-disk container).
@Suite("MKFontCatalogStore ، T6")
struct MKFontCatalogStoreTests {
    private func makeStore() throws -> (MKFontCatalogStore, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-fonts-catalog-tests-\(UUID().uuidString).store")
        let container = try MetadataStore.makeContainer(at: storeURL)
        return (MKFontCatalogStore(modelContainer: container), storeURL)
    }

    @Test func upsertThenFavoriteTogglePersistsAcrossReopen() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        try await store.upsertCatalogEntry(
            fontID: "amiri", displayNameAr: "أميري", postScriptName: "Amiri-Regular",
            category: .naskh, origin: .bundled
        )
        try await store.setFavorite(true, fontID: "amiri")

        let entries = try await store.allEntries()
        #expect(entries.first { $0.fontID == "amiri" }?.isFavorite == true)

        // Simulate relaunch: reopen the container.
        let reopenedContainer = try MetadataStore.makeContainer(at: url)
        let reopenedStore = MKFontCatalogStore(modelContainer: reopenedContainer)
        let reopenedEntries = try await reopenedStore.allEntries()
        #expect(reopenedEntries.first { $0.fontID == "amiri" }?.isFavorite == true)
    }

    @Test func downloadStateTransitionsPersist() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        try await store.upsertCatalogEntry(
            fontID: "premium-font", displayNameAr: "خط مميز", postScriptName: "Premium-Regular",
            category: .modernDisplay, origin: .premiumDownloaded, downloadState: .notDownloaded
        )
        try await store.setDownloadState(.downloaded, fontID: "premium-font", localPath: "/tmp/x.ttf")
        let entries = try await store.allEntries()
        #expect(entries.first { $0.fontID == "premium-font" }?.downloadState == MKFontCatalogStore.DownloadStateValue.downloaded.rawValue)
    }

    @Test func lockingByTierAffectsOnlyMatchingTiers() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        try await store.upsertCatalogEntry(fontID: "bundled-a", displayNameAr: "أ", postScriptName: "A", category: .naskh, origin: .bundled)
        try await store.upsertCatalogEntry(fontID: "premium-b", displayNameAr: "ب", postScriptName: "B", category: .naskh, origin: .premiumDownloaded)

        try await store.setLocked(true, tiers: [MKFontOrigin.premiumDownloaded.rawValue, MKFontOrigin.userImported.rawValue])
        let entries = try await store.allEntries()
        #expect(entries.first { $0.fontID == "bundled-a" }?.lockedByExpiry == false)
        #expect(entries.first { $0.fontID == "premium-b" }?.lockedByExpiry == true)
    }

    @Test func removeEntryDeletesFavoriteToo() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        try await store.upsertCatalogEntry(fontID: "x", displayNameAr: "س", postScriptName: "X", category: .kufi, origin: .userImported)
        try await store.setFavorite(true, fontID: "x")
        try await store.removeEntry(fontID: "x")
        let entries = try await store.allEntries()
        #expect(!entries.contains { $0.fontID == "x" })
    }
}
