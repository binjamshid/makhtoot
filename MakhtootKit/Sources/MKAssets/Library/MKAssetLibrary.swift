import Foundation

// WS-14 packet §5 tasks 1/4–8. `MKAssetLibrary` ، the aggregated v1 asset
// set (basic shapes + ornaments + frames + calligraphic elements + pattern
// backgrounds), built once, in-memory, from the five generators. This is
// the RUNTIME source of truth (`MKAssetBrowserModel`, `MKAssetInstantiator`
// read from here directly) ، Swift construction is essentially free
// (no I/O, no JSON parsing of ~57 small structs), which is what keeps the
// packet's §7 gate 5 "browser first-open <100 ms model build" trivially
// true. `Resources/assets-manifest.json` (see `MKAssetManifestCodec`) is a
// periodically-regenerated, checked-in Codable SNAPSHOT of this exact data
// ، the T1-mandated on-disk manifest artifact, verified to match this
// runtime library byte-for-structure by
// `MKAssetManifestResourceTests.checkedInManifestMatchesGeneratedLibrary`.
public struct MKAssetLibrary: Sendable {
    public let all: [MKAssetDescriptor]
    /// Companion pattern-fill data (tile/repeat/colors) for every
    /// `.patternBackgrounds` descriptor, keyed by `assetID` ، see
    /// `MKPatternTileGenerator`'s file header for why this is a separate,
    /// joined table rather than a field on `MKAssetDescriptor` itself.
    public let patternFills: [String: MKPatternFill]

    public init(all: [MKAssetDescriptor], patternFills: [String: MKPatternFill]) {
        self.all = all
        self.patternFills = patternFills
    }

    public func descriptor(assetID: String) -> MKAssetDescriptor? {
        all.first { $0.assetID == assetID }
    }

    public func descriptors(in category: MKAssetCategory) -> [MKAssetDescriptor] {
        all.filter { $0.category == category }
    }

    public func patternFill(assetID: String) -> MKPatternFill? {
        patternFills[assetID]
    }

    /// The full v1 bundled library (task 4–8's generators). Built once at
    /// first access (`static let`), reused for the process lifetime.
    public static let standard: MKAssetLibrary = {
        let shapes = MKBasicShapeGenerator.makeAll()
        let ornaments = MKOrnamentGenerator.makeAll()
        let frames = MKFrameGenerator.makeAll()
        let calligraphic = MKCalligraphicGenerator.makeAll()
        let patternPairs = MKPatternTileGenerator.makeAll()

        var all = shapes + ornaments + frames + calligraphic
        var fills: [String: MKPatternFill] = [:]
        for pair in patternPairs {
            all.append(pair.descriptor)
            fills[pair.descriptor.assetID] = pair.fill
        }
        return MKAssetLibrary(all: all, patternFills: fills)
    }()
}
