import Foundation

// WS-14 packet §5 task 1. `Codable; library manifest assets-manifest.json
// in module resources. AC: decode test.`
public enum MKAssetManifestCodec {
    public static func encode(_ descriptors: [MKAssetDescriptor]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(descriptors.sorted { $0.assetID < $1.assetID })
    }

    public static func decode(_ data: Data) throws -> [MKAssetDescriptor] {
        try JSONDecoder().decode([MKAssetDescriptor].self, from: data)
    }

    /// Loads `assets-manifest.json` from the module's resource bundle
    /// (`Bundle.module`, SPM-generated because `Package.swift` declares
    /// this file as a target resource). This is NOT what
    /// `MKAssetLibrary.standard`/the browser model use at runtime (that's
    /// the in-memory Swift generators, this file's header explains why) ،
    /// this loader exists so the checked-in manifest resource is real,
    /// decodable, bundle-loadable data, not a file nobody ever reads, and
    /// so `MKAssetManifestResourceTests` can prove it round-trips and
    /// matches the generated library.
    public static func loadBundledManifest() throws -> [MKAssetDescriptor] {
        guard let url = Bundle.module.url(forResource: "assets-manifest", withExtension: "json") else {
            throw MKAssetManifestError.resourceNotFound("assets-manifest.json")
        }
        return try decode(Data(contentsOf: url))
    }

    public static func loadBundledProvenanceRecords() throws -> MKAssetProvenanceStore {
        guard let url = Bundle.module.url(forResource: "provenance-records", withExtension: "json") else {
            throw MKAssetManifestError.resourceNotFound("provenance-records.json")
        }
        return try MKAssetProvenanceCodec.decode(Data(contentsOf: url))
    }
}

public enum MKAssetManifestError: Error, Equatable {
    case resourceNotFound(String)
}

/// Dev-time regeneration utility: recomputes `assets-manifest.json` /
/// `provenance-records.json` from the current `MKAssetLibrary.standard` /
/// `MKAssetProvenanceLibrary` and overwrites the checked-in resource files
/// on disk via `#filePath`-relative resolution ، the same pattern
/// `MKFixtureLocator` (WS-02, `Tests/MKModelTests`/`Tests/
/// MKPersistenceTests`) already established for "a test-time tool writes a
/// real checked-in file." Run manually (`swift test --filter
/// regenerateManifestResources`, see `MKAssetManifestResourceTests`) after
/// changing ANY generator; the ordinary round-trip test then fails loudly
/// if someone changes a generator without regenerating, catching drift.
public enum MKAssetManifestGenerator {
    /// Resolves `Sources/MKAssets/Resources/` relative to THIS file's own
    /// location, mirroring `MKFixtureLocator`'s `#filePath`-walk-up
    /// approach (`Tests/MKModelTests/MKFixtureLocator.swift`) rather than
    /// depending on the current working directory.
    ///
    /// **No default-parameter `#filePath` here, deliberately.** Swift
    /// evaluates a `#filePath` DEFAULT ARGUMENT at the CALL SITE, not at
    /// this declaration ، a first-draft `sourceFile: String = #filePath`
    /// parameter resolved to whatever TEST FILE happened to call this
    /// function, not to this file's own location, silently pointing at the
    /// wrong directory for every caller outside this file (caught by
    /// `MKAssetProvenanceTests.sourcingRulesDocumentExistsAndIsComplete`
    /// failing with a path under `Tests/Resources/` instead of `Sources/
    /// MKAssets/Resources/`). `#filePath` used directly in the FUNCTION
    /// BODY (no parameter indirection) always captures the file it is
    /// LEXICALLY written in, regardless of caller ، the correct behavior
    /// here.
    public static func resourcesDirectory() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // MKAssetManifestCodec.swift → Library/
        url.deleteLastPathComponent() // Library/ → MKAssets/
        return url.appendingPathComponent("Resources", isDirectory: true)
    }

    @discardableResult
    public static func regenerate() throws -> (manifestURL: URL, provenanceURL: URL) {
        let dir = resourcesDirectory()
        let manifestURL = dir.appendingPathComponent("assets-manifest.json")
        let provenanceURL = dir.appendingPathComponent("provenance-records.json")
        try MKAssetManifestCodec.encode(MKAssetLibrary.standard.all).write(to: manifestURL, options: .atomic)
        try MKAssetProvenanceCodec.encode(.standard).write(to: provenanceURL, options: .atomic)
        return (manifestURL, provenanceURL)
    }
}
