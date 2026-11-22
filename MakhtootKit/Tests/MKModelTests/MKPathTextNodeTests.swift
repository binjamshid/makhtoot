import CoreGraphics
import Foundation
import Testing
@testable import MKModel

/// WS-05 gap 2 accept criteria (`Sources/MKPathText/README.md`'s "Known
/// schema gap" section / `CONTRACTS.md`'s WS-05 "Known schema gap"
/// section): `MKPathTextNode.glyphOffsets` round-trips through JSON, and an
/// old, pre-this-change `scene.json` payload with no `glyphOffsets` key at
/// all still decodes successfully with an empty dictionary ، same
/// additive/no-schema-bump contract `Arranged/GlyphNode.swift`'s
/// `MKProvenance.cursiveAttached` already established (see
/// `SceneSchemaTests.swift` for the sibling schema-version test suite).
@Suite("MKPathTextNode.glyphOffsets (WS-05 gap 2)")
struct MKPathTextNodeTests {
    static func makeNode(glyphOffsets: [MKPathGlyphOffsetKey: MKPathGlyphOffset] = [:]) -> MKPathTextNode {
        MKPathTextNode(
            core: MKNodeCore(name: "مسار"),
            text: MKSourceText(string: "سلام"),
            style: .default,
            path: MKBezierPathData(segments: [
                MKBezierSegment(start: .zero, c1: .zero, c2: CGPoint(x: 500, y: 0), end: CGPoint(x: 500, y: 0)),
            ], isClosed: false),
            layout: MKPathLayoutOptions(),
            glyphOffsets: glyphOffsets
        )
    }

    @Test func glyphOffsetsRoundTripThroughJSON() throws {
        let key = MKPathGlyphOffsetKey(codepoints: [0x0633, 0x0644], occurrenceOrdinal: 1)
        let offset = MKPathGlyphOffset(offset: CGPoint(x: 3.5, y: -2), rotation: 0.25)
        let node = Self.makeNode(glyphOffsets: [key: offset])

        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(MKPathTextNode.self, from: data)

        #expect(decoded == node)
        #expect(decoded.glyphOffsets[key] == offset)
    }

    @Test func oldDocumentWithNoGlyphOffsetsKeyDecodesToEmptyDictionary() throws {
        // Simulates a `scene.json` written before this field existed:
        // encode a node, then strip the `glyphOffsets` key entirely before
        // decoding, rather than hand-authoring the whole node's JSON shape.
        let node = Self.makeNode()
        var object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(node)) as! [String: Any]
        #expect(object["glyphOffsets"] != nil)
        object.removeValue(forKey: "glyphOffsets")
        let oldData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(MKPathTextNode.self, from: oldData)
        #expect(decoded.glyphOffsets == [:])
        #expect(decoded.text.string == node.text.string)
    }
}
