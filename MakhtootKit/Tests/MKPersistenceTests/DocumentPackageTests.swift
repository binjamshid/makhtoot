import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 7 accept criterion: kill-during-write test ،
/// simulate a crash between temp write and rename; reopening yields the
/// previous intact version.
@Suite("DocumentPackage")
struct DocumentPackageTests {
    private func makeTempPackageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-doc-pkg-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("test.makhtoot")
    }

    @Test func createReadWriteRoundTrip() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let canvas = MKCanvasSpec(size: CGSize(width: 800, height: 600))
        let package = try DocumentPackage.create(at: url, projectID: MKProjectID(), title: "مشروع تجريبي", canvas: canvas)

        var manifest = try package.readManifest()
        #expect(manifest.title == "مشروع تجريبي")
        #expect(manifest.schemaVersion == MKSceneSchema.currentVersion)

        let scene = FixtureScenes.flatNodesScene(count: 3)
        try package.writeScene(scene)
        let readBack = try package.readScene()
        #expect(readBack == scene)

        manifest.title = "اسم جديد"
        try package.writeManifest(manifest)
        #expect(try package.readManifest().title == "اسم جديد")
    }

    @Test func killDuringWriteLeavesThePreviousIntactVersion() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let canvas = MKCanvasSpec(size: CGSize(width: 400, height: 400))
        let package = try DocumentPackage.create(at: url, projectID: MKProjectID(), title: "v1", canvas: canvas)
        let originalScene = try package.readScene()

        // Simulate a crash BETWEEN the temp write and the atomic rename:
        // write a `.tmp-*` sibling directly (bypassing `writeScene`'s
        // rename step entirely) and never replace `scene.json`.
        let newerScene = FixtureScenes.flatNodesScene(count: 7)
        let tmpURL = url.appendingPathComponent(".tmp-\(UUID().uuidString)")
        try MKSceneCodec.encode(newerScene).write(to: tmpURL)

        // "Reopening" (reading scene.json fresh) must yield the untouched
        // previous version ، the stray temp file is not scene.json.
        let reopened = try package.readScene()
        #expect(reopened == originalScene)
        #expect(reopened != newerScene)

        // The stray temp file must still exist (proving we truly never
        // reached the rename step) and must not have been picked up.
        #expect(FileManager.default.fileExists(atPath: tmpURL.path))
    }

    @Test func atomicWriteReplacesContentCompletelyOnSuccess() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: "t", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )
        let scene2 = FixtureScenes.flatNodesScene(count: 2)
        try package.writeScene(scene2)
        #expect(try package.readScene() == scene2)

        // No stray `.tmp-*` files should remain after a successful write.
        let entries = try FileManager.default.contentsOfDirectory(atPath: url.path)
        #expect(entries.contains { $0.hasPrefix(".tmp-") } == false)
    }
}
