import Testing
import CoreGraphics
import Foundation
@testable import MKColor

// WS-08 packet §5 task 1 accept: "round-trip tests; P3 is display-only,
// never stored."
@Suite struct MKColorSpecTests {
    @Test func roundTripsComponentsThroughCGColorExtendedSRGB() {
        let spec = MKColorSpec(r: 0.25, g: 0.5, b: 0.75, a: 0.9)
        let cg = spec.cgColor()
        let comps = cg.components ?? []
        #expect(comps.count == 4)
        #expect(abs(Double(comps[0]) - 0.25) < 1e-9)
        #expect(abs(Double(comps[1]) - 0.5) < 1e-9)
        #expect(abs(Double(comps[2]) - 0.75) < 1e-9)
        #expect(abs(Double(comps[3]) - 0.9) < 1e-9)
    }

    @Test func preservesOutOfGamutExtendedComponentsVerbatim() {
        // D-117: "components may exceed [0,1] from a P3-aware picker" ، the
        // spec must NOT clamp on construction or on `cgColor()`.
        let spec = MKColorSpec(r: 1.2, g: -0.1, b: 0.5)
        #expect(spec.r == 1.2)
        #expect(spec.g == -0.1)
        let cg = spec.cgColor()
        let comps = cg.components ?? []
        #expect(abs(Double(comps[0]) - 1.2) < 1e-9)
        #expect(abs(Double(comps[1]) - (-0.1)) < 1e-9)
    }

    @Test func clampedSRGBFormIsAlwaysUnitRange() {
        let spec = MKColorSpec(r: 1.5, g: -0.5, b: 0.5, a: 2.0)
        let cg = spec.cgColorClampedSRGB()
        let comps = cg.components ?? []
        #expect(comps[0] == 1)
        #expect(comps[1] == 0)
        #expect(comps[2] == 0.5)
        #expect(comps[3] == 1)
    }

    @Test func displayP3ConversionUsesADistinctColorSpaceFromExtendedSRGB() {
        let spec = MKColorSpec(r: 0.4, g: 0.4, b: 0.4)
        let srgb = spec.cgColor()
        let p3 = spec.cgColorDisplayP3()
        #expect(srgb.colorSpace?.name != p3.colorSpace?.name)
        // Components are stored verbatim regardless of the tagged space ،
        // display-P3 is a TAG on the same numeric triple, never a document
        // conversion (D-117: "P3 is display-only, never stored").
        #expect((p3.components ?? [])[0] == 0.4)
    }

    @Test func blackWhiteClearConstantsHaveExpectedComponents() {
        #expect(MKColorSpec.black.r == 0 && MKColorSpec.black.a == 1)
        #expect(MKColorSpec.white.r == 1 && MKColorSpec.white.a == 1)
        #expect(MKColorSpec.clear.a == 0)
    }

    @Test func hashableAndCodableRoundTrip() throws {
        let spec = MKColorSpec(r: 0.1, g: 0.2, b: 0.3, a: 0.4, swatch: "ink")
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(MKColorSpec.self, from: data)
        #expect(decoded == spec)
        #expect(decoded.hashValue == spec.hashValue)
    }
}
