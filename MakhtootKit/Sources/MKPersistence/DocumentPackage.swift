import Foundation
import MKFoundation
import MKModel

// WS-02 packet §5 task 7. The `.makhtoot` file-package document: create/
// read/write `manifest.json`, `scene.json`, `assets/`, `backups/`,
// `thumbnail.png`, `journal.mkj` ، direct-FS, no `FileWrapper` (task 7:
// "`.makhtoot` `FileWrapper`-free direct-FS package"). Every write goes
// through `MKAtomicIO.write` (write-temp + `replaceItemAt`, INV-7).

/// Small, fast-open metadata (§13.2). Forward-tolerant: unknown JSON keys
/// decode-ignore automatically (synthesized `Decodable`).
public struct MKManifest: Codable, Sendable, Equatable {
    public var manifestVersion: Int
    public var projectID: MKProjectID
    public var schemaVersion: Int
    public var title: String
    public var canvas: MKCanvasSpec
    public var createdAt: Date
    public var modifiedAt: Date
    /// Relative filename within the package, e.g. `"thumbnail.png"`; `nil`
    /// until a first render produces one (WS-07's `SnapshotRenderer`).
    public var thumbnail: String?
    /// Digest of the current `assets/` index contents ، cheap "did assets
    /// change" check without opening `scene.json` (populated by
    /// `MKAssetStore`).
    public var assetIndexDigest: String?
    /// D-119 gating marker, recomputed on save.
    public var premiumContentPresent: Bool

    public init(
        projectID: MKProjectID,
        schemaVersion: Int,
        title: String,
        canvas: MKCanvasSpec,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        thumbnail: String? = nil,
        assetIndexDigest: String? = nil,
        premiumContentPresent: Bool = false
    ) {
        self.manifestVersion = 1
        self.projectID = projectID
        self.schemaVersion = schemaVersion
        self.title = title
        self.canvas = canvas
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.thumbnail = thumbnail
        self.assetIndexDigest = assetIndexDigest
        self.premiumContentPresent = premiumContentPresent
    }
}

/// One `.makhtoot` package on disk (§13.1 layout). Read/write primitives
/// only ، save ORDERING (assets → scene → manifest → journal-truncate,
/// §13.5) is orchestrated by `AutosaveController`, not this type, since
/// ordering is an autosave-strategy concern (incremental vs. full) rather
/// than a package-layout concern.
public struct DocumentPackage: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public var manifestURL: URL { rootURL.appendingPathComponent("manifest.json") }
    public var sceneURL: URL { rootURL.appendingPathComponent("scene.json") }
    public var journalURL: URL { rootURL.appendingPathComponent("journal.mkj") }
    public var assetsDirURL: URL { rootURL.appendingPathComponent("assets", isDirectory: true) }
    public var backupsDirURL: URL { rootURL.appendingPathComponent("backups", isDirectory: true) }
    public var thumbnailURL: URL { rootURL.appendingPathComponent("thumbnail.png") }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: rootURL.path)
    }

    /// Creates a brand-new package on disk: directory + initial
    /// `manifest.json`/`scene.json`. `journal.mkj` is intentionally NOT
    /// created here ، its absence means "no unflushed changes" (§13.1:
    /// "absent/empty after clean flush"), and `CommandJournal` creates it
    /// lazily on first append.
    @discardableResult
    public static func create(
        at rootURL: URL,
        projectID: MKProjectID,
        title: String,
        canvas: MKCanvasSpec,
        schemaVersion: Int = MKSceneSchema.currentVersion
    ) throws -> DocumentPackage {
        let package = DocumentPackage(rootURL: rootURL)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: package.assetsDirURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: package.backupsDirURL, withIntermediateDirectories: true)

        let scene = MKScene(schemaVersion: schemaVersion, canvas: canvas)
        try package.writeScene(scene)

        let manifest = MKManifest(projectID: projectID, schemaVersion: schemaVersion, title: title, canvas: canvas)
        try package.writeManifest(manifest)
        return package
    }

    public func readManifest() throws -> MKManifest {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw MKPersistenceError.documentPackageNotFound(manifestURL)
        }
        let data = try Data(contentsOf: manifestURL)
        do {
            let decoder = JSONDecoder()
            // Must mirror `writeManifest`'s `.iso8601` date strategy
            // exactly ، the default `.deferredToDate` strategy expects a
            // numeric `timeIntervalSinceReferenceDate`, which fails to
            // parse the ISO-8601 strings `writeManifest` actually writes.
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(MKManifest.self, from: data)
        } catch {
            throw MKPersistenceError.malformedManifest(String(describing: error))
        }
    }

    public func writeManifest(_ manifest: MKManifest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        try MKAtomicIO.write(data, to: manifestURL)
    }

    public func readScene() throws -> MKScene {
        guard FileManager.default.fileExists(atPath: sceneURL.path) else {
            throw MKPersistenceError.documentPackageNotFound(sceneURL)
        }
        let data = try Data(contentsOf: sceneURL)
        return try MKSceneCodec.decode(data)
    }

    public func writeScene(_ scene: MKScene) throws {
        let data = try MKSceneCodec.encode(scene)
        try MKAtomicIO.write(data, to: sceneURL)
    }

    public func writeThumbnail(_ pngData: Data) throws {
        try MKAtomicIO.write(pngData, to: thumbnailURL)
    }
}
