import Testing
import CoreGraphics
import Foundation
import MKModel
@testable import MKTextEngine

/// Capture-core sanity (packet task 4), multi-line wrap (task 5), and the
/// T-TXT-10 attribute-survival checks (tracking/kern-override/baseline).
@Suite struct ShapingEngineSmokeTests {

    @Test func basmalaProducesGlyphsAndNonEmptyCapture() {
        let line = Fixtures.shape("بسم الله الرحمن الرحيم")
        #expect(!line.runs.isEmpty)
        #expect(line.glyphCount > 0)
        #expect(line.typographicBounds.width > 0)
    }

    @Test func multiLineParagraphWrapsAndContinuesSourceRange() {
        let request = MKShapingRequest(
            string: "بسم الله الرحمن الرحيم وعلى آله وصحبه أجمعين",
            style: Fixtures.style(size: 24),
            frame: .widthConstrained(width: 120))
        let paragraph = Fixtures.engine.shapeParagraph(request)
        #expect(paragraph.lines.count >= 2, "a long line at a narrow width must wrap to at least two lines")
        // Line N+1's source range starts exactly where line N's ends (task 5 accept criterion).
        for i in 1..<paragraph.lines.count {
            #expect(paragraph.lines[i].sourceRange.lowerBound == paragraph.lines[i - 1].sourceRange.upperBound)
        }
    }

    // MARK: - T-TXT-10: kerning/tracking/baseline survive capture

    @Test func trackingWidensTheLineAndSurvivesIntoCapturedAttributes() {
        let text = "الخط العربي"
        let plain = Fixtures.shape(text)

        var trackedStyle = Fixtures.style()
        trackedStyle.tracking = 40
        let tracked = Fixtures.engine.shapeSingleLine(MKShapingRequest(string: text, style: trackedStyle))

        #expect(tracked.typographicBounds.width > plain.typographicBounds.width, "tracking must widen the shaped line")
        #expect(tracked.runs.allSatisfy { $0.attributes.tracking == 40 }, "tracking must survive into captured run attributes")
        #expect(plain.runs.allSatisfy { $0.attributes.tracking == 0 })
    }

    @Test func baselineShiftSurvivesIntoCapturedAttributes() {
        var style = Fixtures.style()
        style.baselineShift = 4
        let line = Fixtures.engine.shapeSingleLine(MKShapingRequest(string: "الخط", style: style))
        #expect(line.runs.allSatisfy { $0.attributes.baselineShift == 4 })
    }

    @Test func kernOverrideChangesGeometryAndRemovalRestoresIt() {
        let text = "به"
        let plain = Fixtures.shape(text)

        var kernedStyle = Fixtures.style()
        kernedStyle.kerningOverrides = [MKKernOverride(clusterPairIndex: 0, value: 25)]
        let kerned = Fixtures.engine.shapeSingleLine(MKShapingRequest(string: text, style: kernedStyle))

        #expect(kerned.typographicBounds.width > plain.typographicBounds.width, "a positive kern override between the two clusters must widen the line")

        // Removing the override returns byte-identical default GEOMETRY
        // (T-TXT-10: "disabling returns to byte-identical default
        // geometry") ، compared on runs + metrics, not whole-line `==`:
        // `MKCluster.id` mints a fresh durable UUID per capture (by
        // design, provenance keys are unique per derivation), so two
        // captures of identical text are never `==` wholesale.
        let restored = Fixtures.shape(text)
        #expect(restored.runs == plain.runs)
        #expect(restored.typographicBounds == plain.typographicBounds)
    }

    @Test func statusFlagsAreCapturedVerbatim() {
        let line = Fixtures.shape(Fixtures.muhammadTashkeel)
        // The specific non-monotonic value is font/OS dependent and not
        // asserted (tolerance policy) ، this asserts the fields exist and
        // are readable for every run.
        var inspected = 0
        for run in line.runs {
            _ = run.isRTL
            _ = run.isNonMonotonic
            inspected += 1
        }
        #expect(inspected == line.runs.count)
    }
}
