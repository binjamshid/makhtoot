import Foundation
import Testing
@testable import MKFonts

/// T11 AC: decode valid/malformed/unknown-key manifests; missing
/// `licenseRecord` is rejected with a logged (identifiable) error.
@Suite("CatalogManifest ، T11")
struct CatalogManifestTests {
    private func sampleManifestData() throws -> Data {
        let bundle = MKFontsResources.bundle
        let url = try #require(bundle.url(forResource: "manifest.sample", withExtension: "json", subdirectory: "PremiumCatalog"))
        return try Data(contentsOf: url)
    }

    @Test func decodesValidSampleManifest() throws {
        let data = try sampleManifestData()
        let manifest = try MKCatalogManifestDecoder.decode(data)
        #expect(manifest.schemaVersion == 1)
        #expect(!manifest.fonts.isEmpty)
        #expect(manifest.fonts[0].licenseRecord.licenseType == .ofl11)
    }

    @Test func toleratesUnknownTopLevelAndEntryKeys() throws {
        var raw = try JSONSerialization.jsonObject(with: sampleManifestData()) as! [String: Any]
        raw["unknownTopLevelKey"] = "ignore-me"
        var fonts = raw["fonts"] as! [[String: Any]]
        fonts[0]["unknownEntryKey"] = 12345
        raw["fonts"] = fonts
        let data = try JSONSerialization.data(withJSONObject: raw)
        let manifest = try MKCatalogManifestDecoder.decode(data)
        #expect(manifest.fonts.count == 1)
    }

    @Test func rejectsEntryMissingLicenseRecord() throws {
        var raw = try JSONSerialization.jsonObject(with: sampleManifestData()) as! [String: Any]
        var fonts = raw["fonts"] as! [[String: Any]]
        fonts[0].removeValue(forKey: "licenseRecord")
        raw["fonts"] = fonts
        let data = try JSONSerialization.data(withJSONObject: raw)
        #expect(throws: MKCatalogManifestDecodingError.self) {
            try MKCatalogManifestDecoder.decode(data)
        }
    }

    @Test func rejectsMalformedPayload() {
        let data = Data("{ not json".utf8)
        #expect(throws: (any Error).self) {
            try MKCatalogManifestDecoder.decode(data)
        }
    }

    @Test func rejectsUnsupportedSchemaVersion() throws {
        var raw = try JSONSerialization.jsonObject(with: sampleManifestData()) as! [String: Any]
        raw["schemaVersion"] = 99
        let data = try JSONSerialization.data(withJSONObject: raw)
        #expect(throws: MKCatalogManifestDecodingError.self) {
            try MKCatalogManifestDecoder.decode(data)
        }
    }
}
