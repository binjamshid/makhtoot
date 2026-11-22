import Foundation

// WS-02 packet §5 task 19. Resolves `MakhtootKit/Tests/Fixtures/` relative
// to THIS source file's on-disk location (`#filePath`) rather than via SPM
// `resources:` ، a `resources:` path may not escape its own target
// directory (`Tests/MKModelTests/…`), but `Tests/Fixtures/` is a sibling of
// both `MKModelTests/` and `MKPersistenceTests/`, not nested inside either
// (matching the packet's literal deliverable path). This file is
// duplicated verbatim into `Tests/MKPersistenceTests/` ، see that copy's
// header for why, and `Package.swift`'s comment on both `.testTarget`
// declarations.
enum MKFixtureLocator {
    static var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // .../Tests/MKModelTests/
            .deletingLastPathComponent() // .../Tests/
            .appendingPathComponent("Fixtures", isDirectory: true)
    }
}
