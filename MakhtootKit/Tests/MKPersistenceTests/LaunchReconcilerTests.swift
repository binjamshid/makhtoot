import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 17 accept criterion: deleting the SwiftData store
/// and relaunching rebuilds the full project list.
@Suite("LaunchReconciler")
struct LaunchReconcilerTests {
    private func makeStore() throws -> (MetadataStore, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-reconciler-tests-\(UUID().uuidString).store")
        let container = try MetadataStore.makeContainer(at: storeURL)
        return (MetadataStore(modelContainer: container), storeURL)
    }

    @Test func reconcileAddsPackagesMissingFromTheIndex() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let projectsRoot = FileManager.default.temporaryDirectory.appendingPathComponent("mk-reconciler-projects-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: projectsRoot) }

        let projectID = MKProjectID()
        _ = try DocumentPackage.create(
            at: projectsRoot.appendingPathComponent("\(projectID.rawValue.uuidString).makhtoot"),
            projectID: projectID, title: "مشروع على القرص", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )

        #expect(try await store.listProjects().isEmpty)
        try await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRoot)

        let projects = try await store.listProjects()
        #expect(projects.count == 1)
        #expect(projects.first?.title == "مشروع على القرص")
    }

    @Test func deletingTheIndexAndRelaunchingRebuildsTheFullList() async throws {
        let projectsRoot = FileManager.default.temporaryDirectory.appendingPathComponent("mk-reconciler-rebuild-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: projectsRoot) }

        for i in 0..<3 {
            let projectID = MKProjectID()
            _ = try DocumentPackage.create(
                at: projectsRoot.appendingPathComponent("\(projectID.rawValue.uuidString).makhtoot"),
                projectID: projectID, title: "مشروع \(i)", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
            )
        }

        // First "launch": build the index from scratch.
        let (store1, storeURL1) = try makeStore()
        try await LaunchReconciler.reconcile(store: store1, projectsRootURL: projectsRoot)
        #expect(try await store1.listProjects().count == 3)

        // Simulate "deleting the SwiftData store": discard it, create a
        // BRAND NEW empty store, and reconcile against the same on-disk
        // packages again.
        try? FileManager.default.removeItem(at: storeURL1)
        let (store2, storeURL2) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL2) }
        try await LaunchReconciler.reconcile(store: store2, projectsRootURL: projectsRoot)

        #expect(try await store2.listProjects().count == 3)
    }

    @Test func packagesRemovedFromDiskAreMarkedOrphanedNotDeleted() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let projectsRoot = FileManager.default.temporaryDirectory.appendingPathComponent("mk-reconciler-orphan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: projectsRoot) }

        let projectID = MKProjectID()
        let packageURL = projectsRoot.appendingPathComponent("\(projectID.rawValue.uuidString).makhtoot")
        _ = try DocumentPackage.create(
            at: packageURL, projectID: projectID, title: "سيُحذف", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )
        try await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRoot)
        #expect(try await store.project(id: projectID.rawValue)?.isOrphaned == false)

        try FileManager.default.removeItem(at: packageURL)
        try await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRoot)

        let record = try await store.project(id: projectID.rawValue)
        #expect(record != nil) // still indexed, not deleted
        #expect(record?.isOrphaned == true)
    }

    /// S-7 (AUDIT_2026-07-28.md): `MKAtomicIO.write` used to stage its
    /// `.tmp-<UUID>` temp file inside the DESTINATION's own directory ،
    /// for every scene/manifest write, that directory IS the `.makhtoot`
    /// package itself, so a crash between the temp write and the atomic
    /// rename left a stray temp file inside a user-visible,
    /// Files.app-exposed, CloudKit-synced package (which S-3's sync packer
    /// would then upload). The fix moves the temp file to a sibling
    /// scratch directory outside every package
    /// (`MKFileLocations.atomicWriteScratchDirectory()`). This is
    /// `LaunchReconciler`'s own concern because it's the code that scans
    /// `Documents/Projects/` package-by-package on every launch ، a stray
    /// file inside one of those packages is exactly the kind of on-disk
    /// debris that reconciliation logic is closest to.
    @Test func reconcilingPackagesLeavesNoStrayTempFilesInsideAnyPackageDirectory() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let projectsRoot = FileManager.default.temporaryDirectory.appendingPathComponent("mk-reconciler-tmp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: projectsRoot) }

        var packageURLs: [URL] = []
        for i in 0..<3 {
            let projectID = MKProjectID()
            let packageURL = projectsRoot.appendingPathComponent("\(projectID.rawValue.uuidString).makhtoot")
            let package = try DocumentPackage.create(
                at: packageURL, projectID: projectID, title: "مشروع \(i)", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
            )
            // `writeScene`/`writeManifest` both route through
            // `MKAtomicIO.write` ، write each package a second time so this
            // test exercises the temp-file-then-replace path, not just the
            // initial `DocumentPackage.create`.
            try package.writeScene(FixtureScenes.flatNodesScene(count: 2))
            packageURLs.append(packageURL)
        }

        try await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRoot)
        #expect(try await store.listProjects().count == 3)

        for packageURL in packageURLs {
            let entries = try FileManager.default.contentsOfDirectory(atPath: packageURL.path)
            #expect(entries.contains { $0.hasPrefix(".tmp-") } == false, "stray temp file inside \(packageURL.lastPathComponent)")
        }
    }
}
