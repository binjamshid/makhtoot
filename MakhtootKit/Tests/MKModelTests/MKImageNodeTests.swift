import Foundation
import Testing
@testable import MKModel

/// Legacy-payload back-compat fix (MASTER-PLAN-HANDOVER.md §6 item 7,
/// exact same bug class as §2.5's `MKBackgroundContent.fit` finding):
/// `MKImageNode.isPhotoBackgroundUse` is a non-optional `Bool` on a struct
/// that PREVIOUSLY relied on synthesized `Decodable`. Synthesis only
/// auto-defaults `Optional` properties, not non-optional ones ، any
/// `scene.json` written before this field existed would fail the WHOLE
/// document with `keyNotFound("isPhotoBackgroundUse")`. `MKImageNode` now
/// has a hand-written `init(from:)`/`encode(to:)` (`MKNode.swift`) that
/// decodes the key via `decodeIfPresent(Bool.self, forKey:) ?? false`
/// (absence means `false`: a legacy document predating the field cannot
/// have been a photo-background use) while still encoding it
/// unconditionally going forward.
///
/// The legacy literal below is HAND-AUTHORED, not derived by encoding the
/// current type and stripping a key ، per §2.5's rule, a strip-based test
/// only proves this type's own encoder/decoder agree with each other, not
/// that a real pre-existing `scene.json` (which never had this key) still
/// decodes. Every other property (`core`, `asset`, `kind`) reproduces the
/// synthesized shape those unrelated types have always had (unchanged by
/// this fix): `MKNodeCore.style.stroke`/`.shadow` are `Optional` and so are
/// simply absent (synthesized `Decodable` already defaults those), and
/// `MKStyle.fill`'s no-associated-value `.none` case is STILL a keyed
/// container under synthesized enum `Codable` (`{"none": {}}`), not a bare
/// string ، confirmed against a real on-disk fixture
/// (`Tests/Fixtures/fixture-100-nodes.makhtoot/scene.json`'s
/// `background.core.style`), same "even a no-payload case gets wrapped"
/// rule `MKBackgroundContentTests.swift` documents for payload-carrying
/// cases (there under `_0`). `CGPoint`/`CGSize` (`MKNodeCore.transform
/// .position`/`.scale`) also encode via an UNKEYED container on Apple
/// platforms (`[0, 0]` / `[1, 1]`), not `{"x":…,"y":…}` / `{"width":…,
/// "height":…}` ، likewise confirmed against that same real fixture.
@Suite("MKImageNode Codable (legacy isPhotoBackgroundUse back-compat)")
struct MKImageNodeTests {
    @Test func legacyPayloadWithNoIsPhotoBackgroundUseKeyDecodesToFalse() throws {
        // Hand-authored: the real pre-field shape of a persisted
        // `MKImageNode` ، no "isPhotoBackgroundUse" key exists at all.
        let legacyJSON = """
        {
            "core": {
                "id": "8F14E45F-CEEA-467E-BD9C-6DF9C7B0C6B0",
                "name": "صورة",
                "transform": {
                    "position": [0, 0],
                    "rotation": 0,
                    "scale": [1, 1]
                },
                "zOrder": 0,
                "opacity": 1,
                "style": {"fill": {"none": {}}},
                "isLocked": false,
                "isHidden": false
            },
            "asset": {"digest": "deadbeef", "ext": "jpg"},
            "kind": "raster"
        }
        """
        let decoded = try JSONDecoder().decode(MKImageNode.self, from: Data(legacyJSON.utf8))

        #expect(decoded.asset == MKAssetRef(digest: "deadbeef", ext: "jpg"))
        #expect(decoded.kind == .raster)
        #expect(decoded.isPhotoBackgroundUse == false)
        #expect(decoded.core.name == "صورة")
    }

    @Test func payloadWithIsPhotoBackgroundUseTrueRoundTripsPreservingTrue() throws {
        // Same shape as the legacy literal above, but WITH the key present
        // and set to `true` ، asserts a modern document's `true` value
        // survives decode, and that re-encoding still writes the key
        // unconditionally (round-trip stability going forward).
        let modernJSON = """
        {
            "core": {
                "id": "8F14E45F-CEEA-467E-BD9C-6DF9C7B0C6B0",
                "name": "صورة",
                "transform": {
                    "position": [0, 0],
                    "rotation": 0,
                    "scale": [1, 1]
                },
                "zOrder": 0,
                "opacity": 1,
                "style": {"fill": {"none": {}}},
                "isLocked": false,
                "isHidden": false
            },
            "asset": {"digest": "cafebabe", "ext": "png"},
            "kind": "raster",
            "isPhotoBackgroundUse": true
        }
        """
        let decoded = try JSONDecoder().decode(MKImageNode.self, from: Data(modernJSON.utf8))
        #expect(decoded.isPhotoBackgroundUse == true)

        let reencoded = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode(MKImageNode.self, from: reencoded)
        #expect(redecoded == decoded)
        #expect(redecoded.isPhotoBackgroundUse == true)

        // Made structurally explicit (not just via round-trip equality) so
        // an accidental future `encodeIfPresent`/conditional-omit regression
        // fails loudly here: the key must always be written.
        let object = try #require(try JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        #expect(object["isPhotoBackgroundUse"] as? Bool == true)
    }
}
