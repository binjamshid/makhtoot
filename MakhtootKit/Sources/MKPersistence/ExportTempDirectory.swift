import Foundation

/// S-5 (AUDIT_2026-07-28.md): every share-export write
/// (JPEG/PNG/SVG/PDF-vector/PDF-raster) used to land in the bare
/// `FileManager.default.temporaryDirectory` root
/// (`makhtoot_export_<UUID>.{jpg,png,svg,pdf}`) and was never deleted ،
/// a user iterating on a design (the expected workflow: export, tweak,
/// export again) accumulated one full-resolution copy per attempt,
/// forever. This type gives every export write a single, dedicated
/// subdirectory of the temp root instead, so the whole set can be purged
/// in one call rather than tracked file-by-file.
///
/// Mirrors `MKPersistenceProjectLibrary`'s own named-tmp-subdirectory
/// pattern (`Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary
/// .swift:52`, a sibling `appSupportURL`-scoped `"Makhtoot"` subdirectory)
/// at the `MKPersistence` layer instead: `EditorViewModel` (the app
/// target) is this type's only production caller today, passing
/// `directoryURL` as `MKExportCoordinator.export(...)`'s
/// `destinationDirectory:` argument for every one of its five
/// share-export methods, and calling `purge()` once when an editor
/// session opens (a stand-in for "once at app launch" — see this file's
/// own `EXECUTION_PLAN_2026-07-28.md` Wave 1 · Agent 1.1 "Do" step 4: "call
/// site inside `EditorViewModel` init or a hook it exposes ، do not touch
/// launch code outside this file's scope" — `ExportTempDirectory.swift`
/// itself has no launch-code fence to respect, `EditorViewModel.swift`'s
/// does) and again at editor close.
public struct ExportTempDirectory: Sendable {
    /// The app has exactly one system temp directory; every export writer
    /// wants the SAME dedicated subdirectory within it, so a shared value
    /// (not a singleton class — this type is a stateless `URL` deriver,
    /// nothing to share beyond the computed path itself) is the right
    /// shape, mirroring `MKExportPresetCatalog.standard`'s own
    /// shared-default convention.
    public static let shared = ExportTempDirectory()

    private let systemTemporaryDirectory: URL

    /// `systemTemporaryDirectory` is injectable (defaulting to the real
    /// system temp dir) purely so tests can point this at an isolated
    /// throwaway root instead of sharing the one real temp directory every
    /// other test in the process also writes into.
    public init(systemTemporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        self.systemTemporaryDirectory = systemTemporaryDirectory
    }

    /// `tmp/MKExports/` ، created on disk if it doesn't already exist.
    /// Every access re-asserts the directory exists (a cheap no-op `stat`
    /// when it already does), so a caller can safely read this even right
    /// after an intervening `purge()` without re-deriving anything itself.
    public var directoryURL: URL {
        let url = systemTemporaryDirectory.appendingPathComponent("MKExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A fresh, uniquely-named file URL inside `directoryURL` with the
    /// given extension (no leading dot), for a caller that writes the file
    /// itself rather than going through `MKExportCoordinator`'s own
    /// `destinationDirectory:`-based naming.
    public func urlForExport(ext: String) -> URL {
        directoryURL
            .appendingPathComponent("makhtoot_export_\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    /// Deletes `directoryURL` and everything in it. Safe to call even when
    /// nothing was ever written, or when nothing is left to delete ، a
    /// missing directory is not an error.
    public func purge() {
        try? FileManager.default.removeItem(at: systemTemporaryDirectory.appendingPathComponent("MKExports", isDirectory: true))
    }
}
