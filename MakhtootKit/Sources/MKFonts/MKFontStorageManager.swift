import Foundation
import MKFoundation
import MKPersistence

/// T18 ، deletion & storage management for premium-downloaded and
/// user-imported fonts. Bundled fonts are never deletable (they ship
/// inside the app bundle; there is nothing on a writable volume to free).
public actor MKFontStorageManager {
    private let registry: MKFontRegistry
    private let catalogStore: MKFontCatalogStore?

    public init(registry: MKFontRegistry, catalogStore: MKFontCatalogStore? = nil) {
        self.registry = registry
        self.catalogStore = catalogStore
    }

    public enum DeletionOutcome: Sendable, Equatable {
        case deleted
        case deletedWithProjectReferenceWarning(String)
        case notFound
        case refusedBundled
    }

    /// Removes the on-disk file(s) + unregisters + updates catalog state
    /// to `notDownloaded`/removed. Re-download/re-import afterward works
    /// (AC) because the catalog entry itself is not deleted ، only its
    /// `downloadState`/registration.
    @discardableResult
    public func delete(_ fontID: MKFontID, referencingProjectTitles: [String] = []) async -> DeletionOutcome {
        guard let record = await registry.record(for: fontID) else { return .notFound }
        guard record.origin != .bundled else { return .refusedBundled }

        for face in record.faces {
            try? FileManager.default.removeItem(at: face.fileURL)
        }
        try? await registry.remove(fontID)
        if let catalogStore {
            try? await catalogStore.setDownloadState(.notDownloaded, fontID: fontID)
        }

        if !referencingProjectTitles.isEmpty {
            // Latin gloss: this font is used in N project(s); the text
            // will keep its last appearance, but re-editing needs the
            // font again.
            // N8-2: project titles may carry Latin-script runs ، FSI/PDI-
            // isolate each title individually (not the joined string) so
            // the Arabic-comma separators between titles keep the list's
            // RTL order regardless of each title's own script.
            let names = referencingProjectTitles
                .map { MKRTLUtilities.isolated($0) }
                .joined(separator: "، ")
            return .deletedWithProjectReferenceWarning(
                "هذا الخط مستخدم في مشاريع: \(names) ، سيحتفظ النص بمظهره الأخير، لكن التعديل عليه يتطلب الخط مجددًا."
            )
        }
        return .deleted
    }
}
