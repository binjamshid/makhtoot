// Machine-readable determinism-exclusion manifest for `Scripts/android/gate.sh`
// (ANDROID_SPINE.md §6 G0 / §4 ground rule). G0 requires `android/fixtures/**` to regenerate
// byte-identically on a second run for deterministic formats. This list
// records the exclusion in a format `gate.sh` can parse. PDFs are generated
// separately for local use, outside `android/fixtures/`.
//
// Why JPEG is excluded:
// - JPEG (`android/fixtures/export/*.jpg`): `MKRasterEncoders.writeJPEG`
//   goes through ImageIO's JPEG encoder, which is not documented or
//   guaranteed to produce bit-identical output across process invocations
//   (encoder internals — e.g. Huffman table construction, multi-threaded
//   DCT — are an implementation detail Apple does not contract as stable).
//   Empirically verified byte-identical or not by this run's own double-run
//   diff — see `android/docs/impl-log/BATCH-0.2.md` for the literal result.
import Foundation

enum DeterminismManifest {
    struct Entry: Encodable {
        var category: String
        var pathGlob: String
        var reason: String
        var deterministic: Bool
    }

    struct Manifest: Encodable {
        var generator: String = "swift run MKGoldenExport"
        var frozenCategoryList: [String] = [
            "shaping", "joining", "ligature", "marks", "arrange", "pathtext",
            "scenecodec", "render", "export", "canvas", "assets",
        ]
        var note: String = "Every category not listed in `nonDeterministicExclusions` below regenerates byte-identically on a second `swift run MKGoldenExport` — recorded in the BATCH-0.2 implementation log. gate.sh should diff every fixture file EXCEPT one whose path matches a `pathGlob` entry below."
        var nonDeterministicExclusions: [Entry]
    }

    /// The exclusion list itself. `pathGlob` is relative to
    /// `android/fixtures/`.
    static let exclusions: [Entry] = [
        Entry(category: "export", pathGlob: "export/*.jpg", reason: "ImageIO JPEG encoder is not contractually bit-stable across process invocations.", deterministic: false),
    ]

    static func write() throws {
        let manifest = Manifest(nonDeterministicExclusions: exclusions)
        try GoldenJSON.write(manifest, to: RepoPaths.fixturesRoot.appendingPathComponent("DETERMINISM_EXCLUSIONS.json"))
    }
}
