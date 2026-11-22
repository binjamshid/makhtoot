import Foundation

/// T11 ، `catalog-manifest-v1.json` schema: the premium catalog's static
/// JSON manifest (D-121). Decoding is tolerant of unknown top-level/entry
/// keys (forward compatibility ، `JSONDecoder` already ignores unknown
/// keys by default for `Decodable` structs, so no special handling is
/// needed there) and hard-fails when an entry is missing `licenseRecord`
/// (T11 AC) ، a manifest entry with no embedded license evidence is a
/// contract violation, not a soft/default-to-empty case.
public struct MKCatalogManifest: Sendable, Codable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var fonts: [MKCatalogManifestEntry]

    public init(schemaVersion: Int, generatedAt: String, fonts: [MKCatalogManifestEntry]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.fonts = fonts
    }
}

public struct MKCatalogManifestFace: Sendable, Codable, Hashable {
    public var postScriptName: String
    public var styleName: String
    public var weight: Int
    public var isVariable: Bool

    public init(postScriptName: String, styleName: String, weight: Int, isVariable: Bool) {
        self.postScriptName = postScriptName
        self.styleName = styleName
        self.weight = weight
        self.isVariable = isVariable
    }
}

public struct MKCatalogManifestEntry: Sendable, Codable {
    public var fontID: MKFontID
    public var family: String
    public var faces: [MKCatalogManifestFace]
    public var categories: [MKFontCategory]
    public var tags: [String]
    public var fileURL: URL
    public var fileSHA256: String
    public var fileSizeBytes: Int
    public var licenseRecord: MKLicenseRecord
    public var minAppVersion: String
    public var previewImageURL: URL?

    public init(
        fontID: MKFontID, family: String, faces: [MKCatalogManifestFace], categories: [MKFontCategory],
        tags: [String], fileURL: URL, fileSHA256: String, fileSizeBytes: Int, licenseRecord: MKLicenseRecord,
        minAppVersion: String, previewImageURL: URL? = nil
    ) {
        self.fontID = fontID
        self.family = family
        self.faces = faces
        self.categories = categories
        self.tags = tags
        self.fileURL = fileURL
        self.fileSHA256 = fileSHA256
        self.fileSizeBytes = fileSizeBytes
        self.licenseRecord = licenseRecord
        self.minAppVersion = minAppVersion
        self.previewImageURL = previewImageURL
    }
}

public enum MKCatalogManifestDecodingError: Swift.Error, Sendable, Equatable {
    case missingLicenseRecord(fontID: String)
    case malformed(String)
    case unsupportedSchemaVersion(Int)
}

public enum MKCatalogManifestDecoder {
    /// Decodes and validates a manifest payload. `licenseRecord` absence is
    /// caught at a lower level automatically (it's non-optional in
    /// `MKCatalogManifestEntry`, so `JSONDecoder` itself throws a
    /// `DecodingError.keyNotFound` for a missing key) ، this wrapper
    /// re-surfaces that specific failure as the documented
    /// `.missingLicenseRecord` case by inspecting the entry dictionaries
    /// directly before the strongly-typed decode, so the AC's "logged
    /// error" naming a `fontID` is possible even though the strongly-typed
    /// path would otherwise just throw a generic `DecodingError`.
    public static func decode(_ data: Data) throws -> MKCatalogManifest {
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fontsRaw = raw["fonts"] as? [[String: Any]] else {
            throw MKCatalogManifestDecodingError.malformed("top-level `fonts` array missing")
        }
        for entry in fontsRaw {
            let fontID = entry["fontID"] as? String ?? "<unknown>"
            guard entry["licenseRecord"] != nil else {
                throw MKCatalogManifestDecodingError.missingLicenseRecord(fontID: fontID)
            }
        }
        let manifest = try JSONDecoder().decode(MKCatalogManifest.self, from: data)
        guard manifest.schemaVersion == 1 else {
            throw MKCatalogManifestDecodingError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        return manifest
    }
}
