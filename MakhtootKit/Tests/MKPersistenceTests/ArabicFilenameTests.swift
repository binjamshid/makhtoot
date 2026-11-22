import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §6 Arabic-correctness notes: "File/folder names typed by
/// users may be Arabic ، ensure package paths and bookmarks handle Arabic
/// filenames + NFC/NFD variance (APFS): test project named 'مشروعي
/// الأول'."
@Suite("Arabic filenames (T-ARABIC-M-PERSIST)")
struct ArabicFilenameTests {
    @Test func arabicNamedProjectPackageCreatesReadsAndWritesCorrectly() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mk-arabic-name-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let title = "مشروعي الأول"
        // The package DIRECTORY itself uses the project's UUID (§13.1:
        // `Documents/Projects/<projectUUID>.makhtoot`) ، Arabic content
        // lives in `manifest.json`'s `title` field, not the filesystem
        // path, so this test exercises Arabic content round-tripping
        // through the same atomic-write path every other write uses.
        let projectID = MKProjectID()
        let url = root.appendingPathComponent("\(projectID.rawValue.uuidString).makhtoot")
        let package = try DocumentPackage.create(at: url, projectID: projectID, title: title, canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)))

        let manifest = try package.readManifest()
        #expect(manifest.title == title)
        #expect(manifest.title.unicodeScalars.elementsEqual(title.unicodeScalars))
    }

    @Test func arabicFolderNameWithNFCAndNFDVariantsBothResolve() throws {
        // "مشروعي الأول" typed via different input methods can normalize to
        // NFC or NFD Unicode forms; both must be handled ، APFS is
        // Unicode-normalization-insensitive-by-default (case/diacritic
        // preserving) but Swift `String`'s `==` is already
        // normalization-aware (canonical equivalence), which this asserts
        // explicitly since it's the property the rest of this module's
        // Arabic-filename handling relies on.
        let nfc = "مشروعي الأول".precomposedStringWithCanonicalMapping
        let nfd = "مشروعي الأول".decomposedStringWithCanonicalMapping
        #expect(nfc == nfd) // String equality is canonical-equivalence-aware

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mk-nfc-nfd-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let projectID = MKProjectID()
        let url = root.appendingPathComponent("\(projectID.rawValue.uuidString).makhtoot")
        let package = try DocumentPackage.create(at: url, projectID: projectID, title: nfd, canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10)))
        #expect(try package.readManifest().title == nfc)
    }

    @Test func searchTextIndexesArabicFolderAndProjectNames() async throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-arabic-search-tests-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let container = try MetadataStore.makeContainer(at: storeURL)
        let store = MetadataStore(modelContainer: container)

        let projectID = UUID()
        _ = try await store.addProject(
            projectID: projectID, title: "مشروعي الأول",
            canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        let results = try await store.search("مشروعي")
        #expect(results.contains { $0.projectID == projectID })
    }
}
