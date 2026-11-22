import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKTextEngine

/// T-TXT-3 (TEST_MATRIX.md §5) + WS-03 packet §5 task 7: bidi run map
/// preservation and per-glyph global visual indices.
@Suite struct BidiMapTests {

    @Test func arabicAndLatinDigitsSplitIntoDistinctRunsWithCorrectLevels() {
        let line = Fixtures.shape(Fixtures.mixedWesternDigits)   // "عام 2026"
        let bidi = line.bidiMap
        #expect(bidi.baseDirection == .rightToLeft)
        #expect(!bidi.runs.isEmpty)

        // Every run's isRTL flag must be internally consistent with its
        // derived level (RTL ⇒ level 1; LTR-in-RTL-paragraph ⇒ level 2).
        for run in bidi.runs {
            if run.isRTL {
                #expect(run.level == 1)
            } else {
                #expect(run.level == 2)
            }
        }

        // At least one run is flagged RTL (the Arabic word) and at least
        // one is flagged LTR (the Western digits) ، mirrors T-TXT-3's
        // "Arabic runs flagged RTL, Latin run LTR."
        #expect(bidi.runs.contains { $0.isRTL })
        #expect(bidi.runs.contains { !$0.isRTL })
    }

    @Test func visualRunOrderMatchesCTLineRunOrder() {
        let line = Fixtures.shape(Fixtures.mixedWesternDigits)
        // visualOrdinal must be a strict 0..<n permutation matching array index.
        for (index, run) in line.bidiMap.runs.enumerated() {
            #expect(run.visualOrdinal == index)
        }
        // Concatenating runs by string range (sorted by logical start)
        // reproduces the full source string span with no gaps/overlaps ،
        // T-TXT-3's "concatenating runs by string range reproduces the
        // source string exactly."
        let sourceLength = Fixtures.mixedWesternDigits.utf16.count
        let sortedRanges = line.bidiMap.runs.map(\.utf16Range).sorted { $0.lowerBound < $1.lowerBound }
        var cursor = 0
        for range in sortedRanges {
            #expect(range.lowerBound == cursor)
            cursor = range.upperBound
        }
        #expect(cursor == sourceLength)
    }

    @Test func glyphVisualIndicesAreAPermutation() {
        // Packet task 7: "assign each glyph a global visualIndex
        // left→right across the line" ، must be a permutation of
        // 0..<glyphCount, covering every glyph address.
        for source in [Fixtures.mixedWesternDigits, Fixtures.laIlahaIllaAllah, Fixtures.brandMixed, Fixtures.muhammadTashkeel] {
            let line = Fixtures.shape(source)
            let indices = line.bidiMap.glyphVisualIndex.values.sorted()
            #expect(indices == Array(0..<line.glyphCount), "visual indices must be a 0..<n permutation for «\(source)»")
            for (runIndex, run) in line.runs.enumerated() {
                for glyphIndex in run.glyphs.indices {
                    #expect(line.bidiMap.glyphVisualIndex[MKGlyphAddress(run: runIndex, glyph: glyphIndex)] != nil)
                }
            }
        }
    }

    @Test func arabicIndicDigitsFixtureCapturesFaithfullyWithNoCrash() {
        // §6 "mixed bidi": «عام ٢٠٢٦ ميلادي» ، Arabic-Indic digits. This
        // engine makes no claim about which run Core Text assigns them to
        // (documented finding, docs/impl-log/WS-03.md: on this host/font
        // Core Text splits Arabic-Indic digits into their own non-RTL run,
        // contrary to ARCHITECTURE §8.3's illustrative phrasing) ، D-109
        // only requires faithful capture of whatever Core Text decided.
        let line = Fixtures.shape(Fixtures.mixedArabicIndicDigits)
        #expect(!line.bidiMap.runs.isEmpty)
        for run in line.bidiMap.runs {
            #expect(run.level == (run.isRTL ? 1 : 2))
        }
        let sourceLength = Fixtures.mixedArabicIndicDigits.utf16.count
        let sortedRanges = line.bidiMap.runs.map(\.utf16Range).sorted { $0.lowerBound < $1.lowerBound }
        var cursor = 0
        for range in sortedRanges {
            #expect(range.lowerBound == cursor)
            cursor = range.upperBound
        }
        #expect(cursor == sourceLength)
    }

    @Test func pureArabicTextIsAllLevelOne() {
        let line = Fixtures.shape(Fixtures.laIlahaIllaAllah)
        #expect(line.bidiMap.runs.allSatisfy { $0.isRTL && $0.level == 1 })
    }

    @Test func leftToRightBaseDirectionYieldsLevelZeroForLTRRuns() {
        let line = Fixtures.shape("Makhtoot", direction: .leftToRight)
        #expect(line.bidiMap.baseDirection == .leftToRight)
        #expect(line.bidiMap.runs.allSatisfy { !$0.isRTL && $0.level == 0 })
    }

    @Test func rightToLeftOverrideForcesRTLOnLatinText() {
        // The forced-direction attribute (kCTWritingDirection + override)
        // must make even pure-Latin text shape as RTL runs.
        let line = Fixtures.shape("abc", direction: .rightToLeftOverride)
        #expect(line.bidiMap.baseDirection == .rightToLeftOverride)
        #expect(!line.runs.isEmpty)
        #expect(line.runs.allSatisfy { $0.isRTL }, "override direction must force RTL run status on Latin text")
    }

    @Test func brandMixedFixtureStaysStructurallyConsistent() {
        // §6: "Makhtoot مخطوط" ، Latin brand name embedded in Arabic.
        let line = Fixtures.shape(Fixtures.brandMixed)
        #expect(line.bidiMap.runs.contains { $0.isRTL })
        #expect(line.bidiMap.runs.contains { !$0.isRTL })
        for (index, run) in line.bidiMap.runs.enumerated() {
            #expect(run.visualOrdinal == index)
        }
    }
}
