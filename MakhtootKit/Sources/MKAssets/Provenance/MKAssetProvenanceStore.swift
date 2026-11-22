import Foundation

// WS-14 packet §5 task 2/12. `MKAssetProvenanceStore` ، the runtime lookup
// surface + the `Resources/provenance-records.json` Codable snapshot (task
// 2 deliverable: "provenance records store").
public struct MKAssetProvenanceStore: Sendable {
    private let records: [String: MKAssetProvenance]

    public init(records: [String: MKAssetProvenance]) {
        self.records = records
    }

    public func provenance(for assetID: String) -> MKAssetProvenance? {
        records[assetID]
    }

    public var allRecords: [MKAssetProvenance] { Array(records.values) }
    public var count: Int { records.count }

    /// The store built from `MKAssetLibrary.standard`'s full asset list ،
    /// what `MKAssetInstantiator`/`AssetProvenanceAudit` use at runtime.
    public static let standard = MKAssetProvenanceStore(records: MKAssetProvenanceLibrary.standard(for: MKAssetLibrary.standard.all))
}

/// One `[String: MKAssetProvenance]` entry, sorted-key-array Codable shape
/// (a JSON *array* of `{assetID, origin, verifiedBy, notes}` objects rather
/// than a JSON object keyed by id ، arrays are stable to diff/sort, and
/// every entry is self-labeled by its own `assetID` field already, so the
/// array form carries no less information). Mirrors how
/// `assets-manifest.json` is also a plain array (`MKAssetManifestCodec`).
public enum MKAssetProvenanceCodec {
    public static func encode(_ store: MKAssetProvenanceStore) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sorted = store.allRecords.sorted { $0.assetID < $1.assetID }
        return try encoder.encode(sorted)
    }

    public static func decode(_ data: Data) throws -> MKAssetProvenanceStore {
        let decoder = JSONDecoder()
        let records = try decoder.decode([MKAssetProvenance].self, from: data)
        return MKAssetProvenanceStore(records: Dictionary(uniqueKeysWithValues: records.map { ($0.assetID, $0) }))
    }
}
