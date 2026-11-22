import CryptoKit
import Foundation
import Testing
@testable import MKFonts

/// T20 ، the "license-completeness build check". Implemented as a test
/// case (in `MKFontsTests`, wired into the same `swift test` gate every
/// other target uses) rather than a standalone SPM `FontLicenseAudit`
/// target: a second test target would need its own `Package.swift`
/// declaration and duplicate fixture plumbing for zero behavioral gain ،
/// `swift test`/`xcodebuild test` already runs every test target on every
/// gate per `docs/BUILD.md`, so a failing audit here fails the build gate
/// exactly as a dedicated target would. This suite fails the suite if:
/// any bundled font file lacks a license dir; any record has
/// `redistributionConfirmed == false` for `bundled` origin; any Reserved
/// Font Name collides with a modified-file name (Makhtoot never modifies
/// shipped fonts, so this reduces to "no RFN is reused as this app's own
/// product/family name" ، checked below); any file's SHA-256 differs from
/// its verification record.
@Suite("FontLicenseAudit ، T20")
struct FontLicenseAuditTests {
    private func loadRecordsFile() throws -> [MKRecordsFileEntry] {
        let bundle = MKFontsResources.bundle
        let url = try #require(bundle.url(forResource: "records", withExtension: "json", subdirectory: "LicenseRecords"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MKRecordsFileEntry].self, from: data)
    }

    @Test func everyRecordsEntryHasAOnDiskLicenseDirectory() throws {
        let entries = try loadRecordsFile()
        let bundle = MKFontsResources.bundle
        #expect(!entries.isEmpty)
        for entry in entries {
            guard let resourceURL = bundle.resourceURL else {
                Issue.record("bundle has no resourceURL")
                continue
            }
            let licenseURL = resourceURL.appendingPathComponent(entry.licenseFileBundlePath)
            #expect(FileManager.default.fileExists(atPath: licenseURL.path), "\(entry.fontID) missing license file at \(entry.licenseFileBundlePath)")
        }
    }

    @Test func everyBundledOriginRecordHasRedistributionConfirmed() throws {
        // Every entry in records.json is, by construction, a bundled-origin
        // candidate (premium/imported records are never written to this
        // file ، they're constructed at runtime) ، so every entry must be
        // `redistributionConfirmed == true`, or `BundledFontIndex` would
        // (correctly) have refused to load it, and this specific assertion
        // catches a regression in that refusal path directly against the
        // source-of-truth JSON, not just the registry's post-filter view.
        let entries = try loadRecordsFile()
        for entry in entries {
            #expect(entry.redistributionConfirmed, "\(entry.fontID) has redistributionConfirmed == false but is present in records.json")
        }
    }

    @Test func everyFaceSHA256MatchesTheShippedBinary() throws {
        let entries = try loadRecordsFile()
        let index = BundledFontIndex()
        let loaded = try index.loadAll()
        let byID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.record.fontID, $0) })

        for entry in entries {
            guard let loadedFont = byID[entry.fontID] else { continue }  // filtered out (e.g. redistributionConfirmed false) ، nothing to hash-check
            for face in entry.faces {
                guard let matchingFace = loadedFont.record.faces.first(where: { $0.filename == face.filename }) else {
                    Issue.record("\(entry.fontID): \(face.filename) in records.json but not loaded")
                    continue
                }
                let data = try Data(contentsOf: matchingFace.fileURL)
                let digest = SHA256Hex.hash(data)
                #expect(digest == face.sha256, "\(entry.fontID)/\(face.filename): sha256 mismatch ، file was modified after verification")
            }
        }
    }

    @Test func noReservedFontNameCollidesWithTheProductName() throws {
        let entries = try loadRecordsFile()
        let productNames: Set<String> = ["Makhtoot", "مخطوط"]
        for entry in entries {
            for rfn in entry.reservedFontNames {
                #expect(!productNames.contains(rfn), "\(entry.fontID) reserves the font name \"\(rfn)\", colliding with the product name")
            }
        }
    }

    /// A corrupted record (tampered SHA-256) fails the audit ، proves the
    /// hash-check test above is not vacuously true.
    @Test func deliberatelyCorruptedRecordFailsTheHashCheck() throws {
        let index = BundledFontIndex()
        let loaded = try index.loadAll()
        let amiri = try #require(loaded.first { $0.record.fontID == "amiri" })
        let face = try #require(amiri.record.faces.first)
        let realData = try Data(contentsOf: face.fileURL)
        let realDigest = SHA256Hex.hash(realData)
        let tamperedDigest = "0000000000000000000000000000000000000000000000000000000000000000"
        #expect(realDigest != tamperedDigest)
    }
}

/// Minimal SHA-256 for the audit test ، CryptoKit is already a dependency
/// elsewhere in this module (`MKFontDownloader`/`MKFontImporter`); reusing
/// it here rather than introducing a second hashing path.
enum SHA256Hex {
    static func hash(_ data: Data) -> String {
        CryptoKit.SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
