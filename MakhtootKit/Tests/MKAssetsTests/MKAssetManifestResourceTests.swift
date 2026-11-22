import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 1: "Codable; library manifest assets-manifest.json
// in module resources. AC: decode test." See `MKAssetLibrary.swift`'s file
// header for why the CHECKED-IN resource is a periodically-regenerated
// snapshot of the runtime-generated library, not the runtime source of
// truth itself.
@Suite("assets-manifest.json / provenance-records.json bundled resources")
struct MKAssetManifestResourceTests {
    /// Regenerates BOTH checked-in resource files from the current
    /// generators. Run this manually (`swift test --filter
    /// regenerateManifestResources`) after changing ANY generator, then
    /// commit the updated `Resources/*.json` files ، `Bundle.module`'s
    /// contents are a build-time SNAPSHOT (SPM copies resources into the
    /// build product), so the OTHER tests in this file read whatever was
    /// on disk at the last `swift build`, not a live re-generation. This
    /// test is intentionally the one place in the suite that WRITES
    /// (rather than only reads) ، every other test file in
    /// `MKAssetsTests` is read-only.
    @Test func regenerateManifestResources() throws {
        let (manifestURL, provenanceURL) = try MKAssetManifestGenerator.regenerate()
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
        #expect(FileManager.default.fileExists(atPath: provenanceURL.path))
    }

    @Test func bundledManifestDecodesAndMatchesTheGeneratedLibraryStructurally() throws {
        let bundled = try MKAssetManifestCodec.loadBundledManifest()
        let generated = MKAssetLibrary.standard.all
        #expect(bundled.count == generated.count)
        let bundledIDs = Set(bundled.map(\.assetID))
        let generatedIDs = Set(generated.map(\.assetID))
        #expect(bundledIDs == generatedIDs, "bundled assets-manifest.json is out of sync with the generators ، run regenerateManifestResources and commit the result")

        let bundledByID = Dictionary(uniqueKeysWithValues: bundled.map { ($0.assetID, $0) })
        for asset in generated {
            #expect(bundledByID[asset.assetID] == asset, "\(asset.assetID) drifted from the checked-in manifest")
        }
    }

    @Test func bundledProvenanceRecordsDecodeAndCoverEveryManifestAsset() throws {
        let store = try MKAssetManifestCodec.loadBundledProvenanceRecords()
        let manifest = try MKAssetManifestCodec.loadBundledManifest()
        for asset in manifest {
            #expect(store.provenance(for: asset.assetID) != nil, "\(asset.assetID) missing from bundled provenance-records.json")
        }
    }

    @Test func bundledManifestPayloadSizeIsUnderTheTwoMegabyteBudget() throws {
        // Packet §7 gate 1: "total bundled asset payload <2 MB."
        guard let url = Bundle.module.url(forResource: "assets-manifest", withExtension: "json") else {
            Issue.record("assets-manifest.json not found in Bundle.module")
            return
        }
        let manifestSize = try Data(contentsOf: url).count
        var provenanceSize = 0
        if let provenanceURL = Bundle.module.url(forResource: "provenance-records", withExtension: "json") {
            provenanceSize = try Data(contentsOf: provenanceURL).count
        }
        let total = manifestSize + provenanceSize
        #expect(total < 2_000_000, "bundled asset payload is \(total) bytes, over the 2 MB budget")
    }

    @Test func everyOrnamentAssetJSONIsUnderTheThirtyKilobyteTarget() throws {
        // Packet §3 task 3: "ornament paths target <30 KB JSON each."
        for ornament in MKOrnamentGenerator.makeAll() {
            let data = try JSONEncoder().encode(ornament)
            #expect(data.count < 30_000, "\(ornament.assetID) is \(data.count) bytes")
        }
    }
}
