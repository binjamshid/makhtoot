import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-02 packet §5 task 19. Writes the shared fixture library to
// `Tests/Fixtures/` as real `.makhtoot` packages (idempotent ، skips a
// fixture that already exists on disk, so repeated test runs don't
// regenerate). "generator script checked in" (task 19 accept) ، this file
// IS that script, invoked from test `setUp`/at the top of any test needing
// a fixture, rather than as a separate command-line tool, since a Swift
// script target would be extra `Package.swift` surface for the same
// result. Duplicated verbatim into `Tests/MKPersistenceTests/`.
enum FixtureGenerator {
    static func ensureAllFixtures() throws {
        try FileManager.default.createDirectory(at: MKFixtureLocator.fixturesDirectory, withIntermediateDirectories: true)
        try ensure(name: "fixture-100-nodes.makhtoot", title: "مشروع بـ ١٠٠ عنصر", scene: FixtureScenes.flatNodesScene(count: 100))
        try ensure(name: "fixture-5000-nodes.makhtoot", title: "مشروع بـ ٥٠٠٠ عنصر", scene: FixtureScenes.flatNodesScene(count: 5000))
        try ensure(name: "fixture-arabic-basic.makhtoot", title: "نص عربي أساسي", scene: FixtureScenes.arabicBasicScene())
        try ensure(name: "fixture-arranged-la.makhtoot", title: "تركيبة لا", scene: FixtureScenes.arrangedLaScene())
    }

    static func fixtureURL(_ name: String) -> URL {
        MKFixtureLocator.fixturesDirectory.appendingPathComponent(name)
    }

    private static func ensure(name: String, title: String, scene: MKScene) throws {
        let url = fixtureURL(name)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: title, canvas: scene.canvas
        )
        try package.writeScene(scene)
    }
}
