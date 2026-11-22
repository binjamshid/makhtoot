import Foundation
import MKModel

// WS-02 packet §5 task 17. Scans `Documents/Projects/` for `.makhtoot`
// packages and reconciles with the SwiftData index: adds records for
// packages missing from the index, marks index records orphaned when their
// package no longer exists on disk. The SwiftData index is a CACHE, not
// the source of truth (task 17 accept: "deleting the SwiftData store and
// relaunching rebuilds the full project list").

public enum LaunchReconciler {
    /// Runs one full reconciliation pass. Safe to call on every launch ،
    /// idempotent (an already-indexed package is left untouched; an
    /// already-orphaned record whose package reappears is un-orphaned).
    public static func reconcile(store: MetadataStore, projectsRootURL: URL) async throws {
        let fm = FileManager.default
        let existingRecords = try await store.listProjects()
        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.projectID, $0) })

        guard fm.fileExists(atPath: projectsRootURL.path) else {
            // No projects directory at all yet ، everything indexed is
            // orphaned (covers "index survived a full Documents wipe").
            for record in existingRecords {
                try await store.markOrphaned(projectID: record.projectID, orphaned: true)
            }
            return
        }

        let entries = (try? fm.contentsOfDirectory(at: projectsRootURL, includingPropertiesForKeys: nil)) ?? []
        let packageURLs = entries.filter { $0.pathExtension == "makhtoot" }
        var seenIDs: Set<UUID> = []

        for url in packageURLs {
            let package = DocumentPackage(rootURL: url)
            guard let manifest = try? package.readManifest() else { continue }
            let id = manifest.projectID.rawValue
            seenIDs.insert(id)
            let relativePath = "Projects/\(url.lastPathComponent)"

            if let existing = recordsByID[id] {
                if existing.isOrphaned {
                    try await store.markOrphaned(projectID: id, orphaned: false)
                }
                continue
            }

            let scene = try? package.readScene()
            let searchText = scene.map { SearchTextExtractor.extract(scene: $0, title: manifest.title) }
                ?? SearchNormalizer.normalize(manifest.title)

            let newSummary = try await store.addProject(
                projectID: id, title: manifest.title, canvas: manifest.canvas,
                packageRelativePath: relativePath, searchText: searchText,
                premiumContentPresent: manifest.premiumContentPresent
            )
            recordsByID[id] = newSummary
        }

        for record in existingRecords where !seenIDs.contains(record.projectID) {
            try await store.markOrphaned(projectID: record.projectID, orphaned: true)
        }
    }
}
