import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 12 ، the "Test target AssetProvenanceAudit" the
// packet names explicitly (implemented as a `@Suite` inside `MKAssetsTests`
// rather than a separate SPM test target ، this codebase's test-target
// grain is one target per module, per `Package.swift`'s own precedent;
// `AssetProvenanceAudit` below is the literal audit surface, callable
// standalone from any future tooling too). Accept criteria: "fails if any
// manifest asset lacks provenance; any derivedVerified lacks a captured
// license file; any provenance notes mention forbidden sources; category
// outside the locked five; premium flags missing. Mirrors WS-09 T20
// pattern. AC: audit green; tamper test fails correctly."
public enum AssetProvenanceAudit {
    public enum Finding: Equatable, CustomStringConvertible {
        case missingProvenance(assetID: String)
        case derivedWithoutCapturedLicenseFile(assetID: String, path: String)
        case forbiddenSourceMentioned(assetID: String)
        case categoryOutsideLockedFive(assetID: String)

        public var description: String {
            switch self {
            case .missingProvenance(let id): return "missing provenance: \(id)"
            case .derivedWithoutCapturedLicenseFile(let id, let path): return "derivedVerified \(id) has no captured license file at \(path)"
            case .forbiddenSourceMentioned(let id): return "forbidden source marker in provenance notes: \(id)"
            case .categoryOutsideLockedFive(let id): return "category outside the locked five: \(id)"
            }
        }
    }

    /// Runs the full audit over `descriptors` against `store`. Returns an
    /// empty array iff every check passes ، the audit is GREEN.
    public static func run(descriptors: [MKAssetDescriptor], store: MKAssetProvenanceStore, resourcesDirectory: URL) -> [Finding] {
        var findings: [Finding] = []
        let lockedCategories = Set(MKAssetCategory.allCases)

        for descriptor in descriptors {
            guard !lockedCategories.isEmpty else { continue } // structurally always true; keeps the check explicit
            if !MKAssetCategory.allCases.contains(descriptor.category) {
                findings.append(.categoryOutsideLockedFive(assetID: descriptor.assetID))
            }
            guard let record = store.provenance(for: descriptor.assetID) else {
                findings.append(.missingProvenance(assetID: descriptor.assetID))
                continue
            }
            if MKAssetForbiddenSourceMarkers.containsForbiddenMarker(record.notes) {
                findings.append(.forbiddenSourceMentioned(assetID: descriptor.assetID))
            }
            if case .derivedVerified(_, _, let licenseFilePath, _) = record.origin {
                let fileURL = resourcesDirectory.appendingPathComponent(licenseFilePath)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    findings.append(.derivedWithoutCapturedLicenseFile(assetID: descriptor.assetID, path: licenseFilePath))
                }
            }
        }
        return findings
    }
}

@Suite("AssetProvenanceAudit (T12)")
struct AssetProvenanceAuditTests {
    @Test func auditIsGreenForTheShippedLibrary() {
        let findings = AssetProvenanceAudit.run(
            descriptors: MKAssetLibrary.standard.all, store: .standard, resourcesDirectory: MKAssetManifestGenerator.resourcesDirectory()
        )
        #expect(findings.isEmpty, "\(findings.map(\.description))")
    }

    @Test func zeroAssetsWithoutProvenance() {
        let store = MKAssetProvenanceStore.standard
        let missing = MKAssetLibrary.standard.all.filter { store.provenance(for: $0.assetID) == nil }
        #expect(missing.isEmpty)
    }

    @Test func zeroForbiddenSourceMentionsAnywhereInTheLibrary() {
        for record in MKAssetProvenanceStore.standard.allRecords {
            #expect(!MKAssetForbiddenSourceMarkers.containsForbiddenMarker(record.notes), "\(record.assetID)")
        }
    }

    @Test func everyAssetHasThePremiumFlagStructurallyPresent() {
        // `isPremium` is a non-optional `Bool` on `MKAssetDescriptor` ، a
        // "missing premium flag" is a COMPILE error, not a runtime state.
        // This test documents that guarantee rather than re-checking
        // something the type system already enforces.
        for descriptor in MKAssetLibrary.standard.all {
            let flagIsBoolean: Bool = descriptor.isPremium
            _ = flagIsBoolean
        }
    }

    // MARK: - Tamper tests (the audit must FAIL correctly on bad input)

    @Test func tamperMissingProvenanceRecordIsCaught() {
        var store = MKAssetProvenanceStore.standard
        // Rebuild a store with one asset's record removed.
        var records = Dictionary(uniqueKeysWithValues: store.allRecords.map { ($0.assetID, $0) })
        let victim = MKAssetLibrary.standard.all.first!.assetID
        records.removeValue(forKey: victim)
        store = MKAssetProvenanceStore(records: records)

        let findings = AssetProvenanceAudit.run(descriptors: MKAssetLibrary.standard.all, store: store, resourcesDirectory: MKAssetManifestGenerator.resourcesDirectory())
        #expect(findings.contains(.missingProvenance(assetID: victim)))
    }

    @Test func tamperForbiddenSourceMentionIsCaught() {
        let victim = MKAssetLibrary.standard.all.first!
        let tampered = MKAssetProvenance(assetID: victim.assetID, origin: .originalWork(author: "x", date: "2026-01-01"), verifiedBy: "x", notes: "traced from Freepik")
        var records = Dictionary(uniqueKeysWithValues: MKAssetProvenanceStore.standard.allRecords.map { ($0.assetID, $0) })
        records[victim.assetID] = tampered
        let store = MKAssetProvenanceStore(records: records)

        let findings = AssetProvenanceAudit.run(descriptors: MKAssetLibrary.standard.all, store: store, resourcesDirectory: MKAssetManifestGenerator.resourcesDirectory())
        #expect(findings.contains(.forbiddenSourceMentioned(assetID: victim.assetID)))
    }

    @Test func tamperDerivedVerifiedWithoutCapturedLicenseFileIsCaught() {
        let victim = MKAssetLibrary.standard.all.first!
        let tampered = MKAssetProvenance(
            assetID: victim.assetID,
            origin: .derivedVerified(sourceURL: "https://example.com", sourceLicense: "CC0-1.0", licenseFilePath: "Resources/Licenses/does-not-exist.txt", transformationNote: "n/a"),
            verifiedBy: "x", notes: "hypothetical tamper test"
        )
        var records = Dictionary(uniqueKeysWithValues: MKAssetProvenanceStore.standard.allRecords.map { ($0.assetID, $0) })
        records[victim.assetID] = tampered
        let store = MKAssetProvenanceStore(records: records)

        let findings = AssetProvenanceAudit.run(descriptors: MKAssetLibrary.standard.all, store: store, resourcesDirectory: MKAssetManifestGenerator.resourcesDirectory())
        #expect(findings.contains { if case .derivedWithoutCapturedLicenseFile(let id, _) = $0 { return id == victim.assetID } else { return false } })
    }
}
