// Work item 0.2. Loads the 4 canonical `Tests/Fixtures/*.makhtoot`
// scenes for the `arrange` and `scenecodec` categories.
//
// **Discovered pre-existing drift (impl-log-worthy, not an MKGoldenExport
// bug):** the checked-in `Tests/Fixtures/*.makhtoot/scene.json` files
// predate `MKTextStyle` gaining its `isBold`/`isItalic`/`isUnderline`/
// `isStrikethrough` fields (`Sources/MKModel/MKTextStyle.swift`) — those
// four keys are simply ABSENT from every `style` object in all 4 checked-in
// files (verified directly: `python3 -c "json.load(...)"` on
// `fixture-arabic-basic.makhtoot/scene.json` shows a `style` object with
// `font`/`pointSize`/`kerningOverrides`/`tracking`/`baselineShift`/
// `lineHeightMultiple`/`ligatureSetting`/`baseDirection` and NOTHING else).
// `MKTextStyle`'s `Codable` conformance is the plain synthesized one (no
// custom `init(from:)` with `decodeIfPresent` defaults, unlike
// `MKProvenance.cursiveAttached`'s deliberately additive-safe custom
// decoder in `GlyphNode.swift`), so `MKSceneCodec.decode` throws
// `keyNotFound(isBold)` on every one of these 4 files as-is.
// `Tests/MKModelTests/FixtureGenerator.swift`'s own doc comment says this
// generator is "idempotent — skips a fixture that already exists on disk,
// so repeated test runs don't regenerate" — since these 4 `.makhtoot`
// directories are already checked into git, the generator never re-runs,
// so the drift is permanent until someone deletes and regenerates them.
// This agent's fence forbids touching `MakhtootKit/Tests/**` (read-only),
// so the fix lives here instead: `patchLegacyStyle` backfills exactly the
// 4 missing boolean fields (documented default `false` for all four,
// `MKTextStyle.init`'s own default) into every JSON object that already
// has `pointSize`+`font` (i.e., is structurally an `MKTextStyle`) but lacks
// them, before handing the bytes to `MKSceneCodec.decode`. Flagged again,
// prominently, in `android/docs/impl-log/BATCH-0.2.md` for whoever next
// owns `Tests/Fixtures/` regeneration.

import Foundation
import MKModel

enum FixtureSceneLoader {
    static func loadScene(named fixtureName: String) throws -> MKScene {
        let url = RepoPaths.testFixturesDir.appendingPathComponent("\(fixtureName).makhtoot/scene.json")
        let raw = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: raw)
        let patched = patchLegacyStyleFields(object)
        let patchedData = try JSONSerialization.data(withJSONObject: patched)
        return try MKSceneCodec.decode(patchedData)
    }

    /// Recursively walks any JSON value; wherever a dictionary looks like an
    /// `MKTextStyle` (`pointSize` + `font` present) and is missing
    /// `isBold`/`isItalic`/`isUnderline`/`isStrikethrough`, backfills those
    /// four keys with `false` — `MKTextStyle.init`'s own documented default
    /// for all four. Never touches a dictionary that already has the keys
    /// (a forward-compatible fixture is passed through byte-for-byte).
    static func patchLegacyStyleFields(_ value: Any) -> Any {
        if var dict = value as? [String: Any] {
            for (key, sub) in dict { dict[key] = patchLegacyStyleFields(sub) }
            if dict["pointSize"] != nil, dict["font"] != nil {
                for boolField in ["isBold", "isItalic", "isUnderline", "isStrikethrough"] where dict[boolField] == nil {
                    dict[boolField] = false
                }
            }
            return dict
        }
        if let array = value as? [Any] {
            return array.map(patchLegacyStyleFields)
        }
        return value
    }
}
