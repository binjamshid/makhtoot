import Testing
import CoreGraphics
import Foundation
import MKModel
@testable import MKTextEngine

/// WS-03 packet §5 task 13: the cached actor facade + bundled analyzers +
/// the D-115 pre-gate perf check.
@Suite struct ShapingServiceTests {

    @Test func repeatShapeHitsTheCache() async {
        let service = MKShapingService()
        let request = MKShapingRequest(string: Fixtures.laIlahaIllaAllah, style: Fixtures.style())

        let first = await service.shape(request)
        let second = await service.shape(request)
        #expect(first == second)

        let counters = await service.cacheCounters()
        #expect(counters.misses == 1)
        #expect(counters.hits == 1)
    }

    @Test func differentRequestsMissSeparately() async {
        let service = MKShapingService()
        _ = await service.shape(MKShapingRequest(string: "به", style: Fixtures.style()))
        _ = await service.shape(MKShapingRequest(string: "به", style: Fixtures.style(size: 48)))
        let counters = await service.cacheCounters()
        #expect(counters.misses == 2, "a different point size is a different cache key (full-request hash, §4.7)")
    }

    @Test func invalidateCacheForcesReshape() async {
        let service = MKShapingService()
        let request = MKShapingRequest(string: "به", style: Fixtures.style())
        _ = await service.shape(request)
        await service.invalidateCache()
        _ = await service.shape(request)
        let counters = await service.cacheCounters()
        #expect(counters.misses == 2)
        #expect(counters.hits == 0)
    }

    @Test func captureResultBundlesAllAnalyzers() async {
        let service = MKShapingService()
        let request = MKShapingRequest(string: Fixtures.muhammadTashkeel, style: Fixtures.style())
        let result = await service.captureResult(request)

        #expect(result.paragraph.lines.count == 1)
        #expect(result.lineAnalyses.count == 1)
        guard let analysis = result.lineAnalyses.first else { return }

        // مُحَمَّدٌ: 5 marks, 4 letters (م ح م د), no ligatures.
        #expect(analysis.marks.count == 5)
        #expect(analysis.joining.count == 4)
        #expect(analysis.joining.map(\.state.form) == [.initial, .medial, .medial, .final])
        #expect(analysis.ligatures.isEmpty)
    }

    @Test func captureResultJoiningSpansLinesInAbsoluteIndices() async {
        let service = MKShapingService()
        let request = MKShapingRequest(
            string: "بسم الله الرحمن الرحيم وعلى آله وصحبه أجمعين",
            style: Fixtures.style(size: 24),
            frame: .widthConstrained(width: 120))
        let result = await service.captureResult(request)
        #expect(result.paragraph.lines.count >= 2)
        #expect(result.lineAnalyses.count == result.paragraph.lines.count)

        // Every joining entry lands in its own line's source range
        // (absolute full-string indices, same space as the cluster maps).
        for (line, analysis) in zip(result.paragraph.lines, result.lineAnalyses) {
            for letter in analysis.joining {
                #expect(line.sourceRange.contains(letter.utf16Index))
            }
        }
    }

    @Test func ligaturesAppearInCaptureResult() async {
        let service = MKShapingService()
        let result = await service.captureResult(
            MKShapingRequest(string: Fixtures.laIlahaIllaAllah, style: Fixtures.style()))
        let allLigatures = result.lineAnalyses.flatMap(\.ligatures)
        #expect(allLigatures.contains { $0.kind == .required })
    }

    @Test func singleLineCaptureIsFarUnderTheFiftyMillisecondTypingEchoBudget() async {
        // SIMULATOR-INDICATIVE ، D-115 pre-gate: single-line reshape must
        // be far under the 50 ms typing-echo budget (packet's own tighter
        // target: <5 ms on simulator). This number is measured on the
        // swift-test host (Xcode Simulator or macOS host process running
        // `swift test`, never real device hardware) and stands in for the
        // real D-115 device budget ، see docs/impl-log/WS-07-p14.md's
        // "T-PRF budget sweep vs D-115" section. Warm-up call first: the first CoreText call in a
        // fresh process pays one-time font-loading cost (~85 ms observed
        // on the iOS Simulator destination with coverage instrumentation)
        // that is not steady-state typing-echo latency ، the thing D-115
        // budgets (docs/impl-log/WS-03.md). The measured call goes through
        // the SERVICE with a cache-missing request so the timed path is
        // shape + capture + signpost, not a cache hit.
        let service = MKShapingService()
        let text = String(String(repeating: "الخط العربي الجميل ", count: 4).prefix(60))
        _ = await service.shape(MKShapingRequest(string: text, style: Fixtures.style(size: 35)))   // warm-up

        let request = MKShapingRequest(string: text, style: Fixtures.style(size: 36))
        let clock = ContinuousClock()
        let start = clock.now
        _ = await service.shape(request)
        let elapsed = clock.now - start
        #expect(elapsed < .milliseconds(50))

        let counters = await service.cacheCounters()
        #expect(counters.misses == 2, "the timed call must have been a real shape, not a cache hit")
    }
}
