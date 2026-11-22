import Foundation
import MKModel

// WS-02 packet §5 task 8. Content-addressed `assets/` store:
// `storeAsset(data:kind:) -> MKAssetRef`, `assetData(for:)`, refcount sweep
// on save that gives unreferenced assets one grace save-cycle in
// `backups/orphans/` before deletion (undo safety ، an undo that
// re-references a just-orphaned asset should still find its bytes).

/// S-2 defense in depth: thrown by `MKAssetStore.assetURL(for:)` when a
/// ref's `digest`/`ext` ، constructed directly via `MKAssetRef`'s plain
/// memberwise initializer, bypassing `init(from:)`'s decode-time
/// validation ، would resolve outside `assetsDirURL`.
public enum MKAssetPathError: Error, Sendable, Equatable {
    case pathEscapesAssetsDirectory(URL)
}

/// Per-open-package content-addressed asset store (§13.3). An actor: asset
/// I/O runs off the main thread, and `storeAsset`/`sweepOrphans` must not
/// race each other (a sweep concurrent with a store-in-progress could
/// delete bytes a save is about to reference).
public actor MKAssetStore {
    private let package: DocumentPackage

    public init(package: DocumentPackage) {
        self.package = package
    }

    /// S-2 defense in depth: `MKAssetRef.init(from:)` already rejects any
    /// `digest`/`ext` that could form a traversal path at DECODE time, but
    /// a ref can also reach here constructed directly via the plain
    /// memberwise `init(digest:ext:)` (bypassing that validation). Assert
    /// the built URL still resolves inside `assetsDirURL` before handing
    /// it back ، `appendingPathComponent` does not itself normalize `..`.
    private func assetURL(for ref: MKAssetRef) throws -> URL {
        let url = package.assetsDirURL.appendingPathComponent("sha256-\(ref.digest).\(ref.ext)")
        // S8-4: containment is checked component-wise, not with a string
        // `hasPrefix` on the standardized path ، a plain prefix test is
        // defeated by a sibling directory sharing the prefix
        // (`<pkg>/assets-evil/x` hasPrefix `<pkg>/assets` is true).
        // `pathComponents` can only match on whole components, so the
        // sibling-prefix case cannot pass.
        let candidateComponents = url.standardizedFileURL.pathComponents
        let assetsDirComponents = package.assetsDirURL.standardizedFileURL.pathComponents
        guard candidateComponents.starts(with: assetsDirComponents) else {
            throw MKAssetPathError.pathEscapesAssetsDirectory(url)
        }
        return url
    }

    /// Stores `data`, deduping by SHA-256 digest ، importing the same
    /// bytes twice (even under a different original filename) writes the
    /// file once (task 8 accept: "same bytes stored twice dedupe to one
    /// file").
    @discardableResult
    public func storeAsset(data: Data, ext: String) throws -> MKAssetRef {
        let digest = MKContentHash.sha256Hex(data)
        let ref = MKAssetRef(digest: digest, ext: ext)
        let url = try assetURL(for: ref)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: package.assetsDirURL, withIntermediateDirectories: true)
            // S-6: same `.completeUnlessOpen` file-protection posture as
            // every other document write (`MKAtomicIO.write`) ، user
            // images/assets get the same stronger-than-default protection
            // as scene/manifest data.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        }
        return ref
    }

    public func assetData(for ref: MKAssetRef) throws -> Data {
        let url = try assetURL(for: ref)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MKPersistenceError.documentPackageNotFound(url)
        }
        return try Data(contentsOf: url)
    }

    public func hasAsset(_ ref: MKAssetRef) -> Bool {
        guard let url = try? assetURL(for: ref) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Diagnostics for tests (P-7): counts sweeps that actually touched
    /// the filesystem, as opposed to the early-return skip below. Same
    /// "expose a counter so a test can assert without racing the
    /// filesystem" pattern `AutosaveController.fullSaveCount` already
    /// uses.
    public private(set) var sweepExecutionCount = 0

    /// Refcount sweep, run on save (task 8): any asset file not referenced
    /// by `referencedBy` is moved to `backups/orphans/`; any file already
    /// in `backups/orphans/` from the PRIOR sweep cycle (i.e. unreferenced
    /// for two consecutive sweeps) is permanently deleted first. This
    /// gives every orphaned asset exactly one full save-cycle of grace
    /// before it's gone ، long enough for an in-flight undo to still
    /// resolve it, short enough that deleted-node assets don't accumulate
    /// forever.
    ///
    /// P-7: this used to unconditionally `removeItem`+recreate
    /// `backups/orphans/` and re-enumerate the whole `assets/` directory
    /// on EVERY save cycle, even when nothing about the referenced-asset
    /// set had changed. `MKManifest.assetIndexDigest` (declared, never
    /// previously written ، `DocumentPackage.swift:27`) now persists a
    /// digest of the referenced-filename set across saves; when the newly
    /// computed digest matches the persisted one AND there is nothing
    /// left over in `backups/orphans/` from a prior cycle to finalize,
    /// there is nothing this sweep could possibly do, so it returns
    /// immediately.
    ///
    /// The second half of that condition matters for correctness, not
    /// just performance: the one-cycle-grace deletion is driven by "was
    /// this file still unreferenced on the NEXT sweep", not by "did the
    /// referenced set change again in between" ، a long steady-state run
    /// with a stable referenced set (e.g. editing text with no image
    /// changes) must still finalize (permanently delete) an orphan that
    /// entered its grace period earlier, or that file would never be
    /// reclaimed. Skipping ONLY on "digest unchanged" without also
    /// checking for pending orphans would leak every orphaned asset
    /// forever the moment the referenced set stops changing ، see this
    /// agent's final report for the concrete trace (`orphanSweepGives
    /// OneGraceCycleBeforeDeletion` in `AssetStoreTests.swift`, an
    /// existing test predating this fix, is what surfaced this).
    ///
    /// When the sweep does run, only the directory's CURRENT contents
    /// (the prior cycle's orphans) are deleted before it's repopulated ،
    /// no `removeItem` on the directory itself, narrowing the window
    /// during which a concurrent read could observe a missing directory.
    public func sweepOrphans(referencedBy referencedRefs: Set<MKAssetRef>) throws {
        let fm = FileManager.default
        let orphansDir = package.backupsDirURL.appendingPathComponent("orphans", isDirectory: true)

        let referencedFilenames = Set(referencedRefs.map { "sha256-\($0.digest).\($0.ext)" })
        let newDigest = Self.assetIndexDigest(forReferencedFilenames: referencedFilenames)
        let priorOrphans = (try? fm.contentsOfDirectory(at: orphansDir, includingPropertiesForKeys: nil)) ?? []

        let manifest = try? package.readManifest()
        if manifest?.assetIndexDigest == newDigest, priorOrphans.isEmpty {
            return
        }
        sweepExecutionCount += 1

        try fm.createDirectory(at: orphansDir, withIntermediateDirectories: true)
        for file in priorOrphans {
            try? fm.removeItem(at: file)
        }

        if fm.fileExists(atPath: package.assetsDirURL.path) {
            let files = try fm.contentsOfDirectory(at: package.assetsDirURL, includingPropertiesForKeys: nil)
            for file in files where !referencedFilenames.contains(file.lastPathComponent) {
                try fm.moveItem(at: file, to: orphansDir.appendingPathComponent(file.lastPathComponent))
            }
        }

        if var updatedManifest = manifest {
            updatedManifest.assetIndexDigest = newDigest
            try? package.writeManifest(updatedManifest)
        }
    }

    private static func assetIndexDigest(forReferencedFilenames filenames: Set<String>) -> String {
        MKContentHash.sha256Hex(Data(filenames.sorted().joined(separator: "\n").utf8))
    }

    /// Lists filenames currently sitting in the one-cycle orphan grace
    /// area ، test/diagnostic hook.
    public func orphanedFilenames() throws -> [String] {
        let orphansDir = package.backupsDirURL.appendingPathComponent("orphans", isDirectory: true)
        guard FileManager.default.fileExists(atPath: orphansDir.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: orphansDir.path)
    }
}
