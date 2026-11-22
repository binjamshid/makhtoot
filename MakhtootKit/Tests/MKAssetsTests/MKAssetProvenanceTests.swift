import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 2 accept criteria: "rules doc complete; provenance
// schema tested; audit hook defined."
@Suite("MKAssetProvenance (T2)")
struct MKAssetProvenanceTests {
    @Test func originalWorkProvenanceRoundTripsThroughJSON() throws {
        let record = MKAssetProvenance(
            assetID: "shape.rectangle", origin: .originalWork(author: "test", date: "2026-07-18"), verifiedBy: "test", notes: "unit test note"
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(MKAssetProvenance.self, from: data)
        #expect(decoded == record)
    }

    @Test func derivedVerifiedProvenanceRoundTripsThroughJSON() throws {
        let record = MKAssetProvenance(
            assetID: "hypothetical.derived",
            origin: .derivedVerified(sourceURL: "https://example.com", sourceLicense: "CC0-1.0", licenseFilePath: "Resources/Licenses/example.txt", transformationNote: "simplified path"),
            verifiedBy: "test", notes: "hypothetical only ، no shipped asset uses this case"
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(MKAssetProvenance.self, from: data)
        #expect(decoded == record)
    }

    @Test func forbiddenSourceMarkerDetectionCatchesKnownMarkers() {
        #expect(MKAssetForbiddenSourceMarkers.containsForbiddenMarker("traced from a free vector site"))
        #expect(MKAssetForbiddenSourceMarkers.containsForbiddenMarker("Downloaded from Freepik"))
        #expect(!MKAssetForbiddenSourceMarkers.containsForbiddenMarker("original vector geometry authored procedurally for Makhtoot"))
    }

    @Test func sourcingRulesDocumentExistsAndIsComplete() throws {
        let url = MKAssetManifestGenerator.resourcesDirectory().appendingPathComponent("ASSET_SOURCING_RULES.md")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("Forbidden sources"))
        #expect(text.contains("provenance record"))
        #expect(text.contains("D-215"))
    }

    @Test func everyLibraryAssetHasAMatchingProvenanceRecord() {
        let store = MKAssetProvenanceStore.standard
        for descriptor in MKAssetLibrary.standard.all {
            #expect(store.provenance(for: descriptor.assetID) != nil, "\(descriptor.assetID) missing provenance")
        }
        #expect(store.count == MKAssetLibrary.standard.all.count)
    }
}
