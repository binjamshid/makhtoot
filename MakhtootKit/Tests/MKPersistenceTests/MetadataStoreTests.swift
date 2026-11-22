import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 14 accept criteria: schema instantiates; CRUD
/// tests; assert no property holds scene data. Task 15 accept: search test
/// ، query "مخطوط" matches record named "مَخْطُوطٌ"; query "علي" matches
/// "على".
@Suite("MetadataStore")
struct MetadataStoreTests {
    private func makeStore() throws -> (MetadataStore, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-metadata-tests-\(UUID().uuidString).store")
        let container = try MetadataStore.makeContainer(at: storeURL)
        return (MetadataStore(modelContainer: container), storeURL)
    }

    @Test func schemaInstantiatesAndProjectCRUDWorks() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let projectID = UUID()
        let created = try await store.addProject(
            projectID: projectID, title: "مشروعي", canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        #expect(created.title == "مشروعي")

        try await store.rename(projectID: projectID, to: "اسم جديد")
        let fetched = try await store.project(id: projectID)
        #expect(fetched?.title == "اسم جديد")

        let list = try await store.listProjects()
        #expect(list.contains { $0.projectID == projectID })

        try await store.deleteProject(id: projectID)
        #expect(try await store.project(id: projectID) == nil)
    }

    @Test func projectSummaryNeverCarriesSceneShapedData() async throws {
        // Structural assertion: `MKProjectSummary`'s field list contains
        // only metadata ، this test enumerates every stored property and
        // fails if a future edit ever adds anything named/shaped like
        // scene content, which is the closest a compiled test gets to
        // "assert no property holds scene data" for a fixed-shape struct.
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let projectID = UUID()
        let summary = try await store.addProject(
            projectID: projectID, title: "ت", canvas: MKCanvasSpec(size: CGSize(width: 1, height: 1)),
            packageRelativePath: "Projects/x.makhtoot"
        )
        let mirror = Mirror(reflecting: summary)
        let allowedLabels: Set<String> = [
            "projectID", "title", "folderID", "createdAt", "modifiedAt", "canvasWidth", "canvasHeight",
            "thumbnailPath", "searchText", "premiumContentPresent", "packageRelativePath", "syncState",
            "lastSyncedChangeTag", "isOrphaned",
        ]
        for child in mirror.children {
            guard let label = child.label else { continue }
            #expect(allowedLabels.contains(label), "unexpected MKProjectSummary field '\(label)'")
        }
    }

    @Test func folderCRUDAndProjectMoveWorks() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let folder = try await store.createFolder(name: "مجلد")
        let projectID = UUID()
        _ = try await store.addProject(
            projectID: projectID, title: "ت", canvas: MKCanvasSpec(size: CGSize(width: 1, height: 1)),
            packageRelativePath: "Projects/x.makhtoot", folderID: folder.folderID
        )
        let inFolder = try await store.listProjects(folderID: folder.folderID)
        #expect(inFolder.count == 1)

        try await store.deleteFolder(id: folder.folderID)
        let afterDelete = try await store.project(id: projectID)
        #expect(afterDelete?.folderID == nil) // moved to "no folder", not deleted
    }

    @Test func duplicateProjectDeepCopiesPackageWithNisakhaSuffix() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let documentsRoot = FileManager.default.temporaryDirectory.appendingPathComponent("mk-dup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: documentsRoot) }

        let projectID = UUID()
        let relativePath = "Projects/\(projectID.uuidString).makhtoot"
        let packageURL = documentsRoot.appendingPathComponent(relativePath)
        _ = try DocumentPackage.create(
            at: packageURL, projectID: MKProjectID(rawValue: projectID), title: "الأصل",
            canvas: MKCanvasSpec(size: CGSize(width: 50, height: 50))
        )
        _ = try await store.addProject(
            projectID: projectID, title: "الأصل", canvas: MKCanvasSpec(size: CGSize(width: 50, height: 50)),
            packageRelativePath: relativePath
        )

        let duplicate = try await store.duplicateProject(id: projectID, documentsRootURL: documentsRoot)
        #expect(duplicate.title == "الأصل نسخة")
        #expect(duplicate.projectID != projectID)

        let duplicatedPackage = DocumentPackage(rootURL: documentsRoot.appendingPathComponent(duplicate.packageRelativePath))
        #expect(duplicatedPackage.exists)
        #expect(try duplicatedPackage.readManifest().projectID.rawValue == duplicate.projectID)
    }

    @Test func searchMatchesTashkeelAndHamzaVariants() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await store.addProject(
            projectID: UUID(), title: "مَخْطُوطٌ", canvas: MKCanvasSpec(size: CGSize(width: 1, height: 1)),
            packageRelativePath: "Projects/a.makhtoot"
        )
        _ = try await store.addProject(
            projectID: UUID(), title: "على الطريق", canvas: MKCanvasSpec(size: CGSize(width: 1, height: 1)),
            packageRelativePath: "Projects/b.makhtoot"
        )

        let matchesMakhtoot = try await store.search("مخطوط")
        #expect(matchesMakhtoot.contains { $0.title == "مَخْطُوطٌ" })

        let matchesAli = try await store.search("علي")
        #expect(matchesAli.contains { $0.title == "على الطريق" })
    }

    @Test func exportHistoryRecordsAndLists() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let projectID = UUID()
        _ = try await store.recordExport(projectID: projectID, format: "png", pixelWidth: 1080, pixelHeight: 1080)
        _ = try await store.recordExport(projectID: projectID, format: "pdf", pixelWidth: 2480, pixelHeight: 3508)

        let history = try await store.exportHistory(projectID: projectID)
        #expect(history.count == 2)
        #expect(history.allSatisfy { $0.projectID == projectID })
    }
}
