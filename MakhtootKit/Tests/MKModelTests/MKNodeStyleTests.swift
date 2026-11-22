import Foundation
import Testing
@testable import MKModel

/// WS-02 packet §5 task 1 accept criterion: JSON round-trip; unknown-key
/// tolerance (decode ignores unknown fields).
@Suite("MKNodeStyle (MKFill/MKStroke/MKShadow/MKStyle)")
struct MKNodeStyleTests {
    @Test func solidFillRoundTripsThroughJSON() throws {
        let style = MKStyle(
            fill: .solid(MKSolidColor(r: 0.5, g: 0.25, b: 0.1, a: 1, swatch: "ink")),
            stroke: MKStroke(color: .black, width: 2, join: .round, cap: .square),
            shadow: MKShadow(color: .black, blur: 4, offset: CGSize(width: 1, height: 2))
        )
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(MKStyle.self, from: data)
        #expect(decoded == style)
    }

    @Test func noneFillRoundTrips() throws {
        let style = MKStyle(fill: .none)
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(MKStyle.self, from: data)
        #expect(decoded == style)
    }

    @Test func decodeIgnoresUnknownFields() throws {
        // Round-trip a real value first (rather than hand-authoring JSON
        // that has to match `MKFill`'s exact synthesized enum-with-payload
        // encoding shape) so this test only asserts what it's actually
        // meant to: that FUTURE, unrecognized keys injected alongside the
        // real ones don't break decode.
        let original = MKStyle(fill: .solid(.black))
        var object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(original)) as! [String: Any]
        object["futureField"] = "ignored"
        object["nested"] = ["x": 1]
        let mutatedData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(MKStyle.self, from: mutatedData)
        #expect(decoded == original)
    }

    @Test func colorComponentsMayExceedZeroToOneRange() throws {
        // D-117: P3-picker-sourced components are preserved verbatim, not clamped.
        let color = MKSolidColor(r: 1.2, g: -0.1, b: 0.5)
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(MKSolidColor.self, from: data)
        #expect(decoded.r == 1.2)
        #expect(decoded.g == -0.1)
    }
}
