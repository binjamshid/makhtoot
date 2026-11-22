import CoreText
import Foundation
import Testing
@testable import MKFonts

/// T10 AC: Amiri reports `supportsQuranicMarks == true`; a Latin-only
/// fixture font reports Arabic coverage 0%.
@Suite("MKCoverageAnalyzer ، T10")
struct CoverageAnalysisTests {
    @Test func amiriSupportsQuranicMarksAndTashkeel() throws {
        let index = BundledFontIndex()
        let loaded = try index.loadAll()
        let amiri = try #require(loaded.first { $0.record.fontID == "amiri" })
        let face = try #require(amiri.record.faces.first)
        // Resolve directly from the on-disk file URL rather than by
        // PostScript name via `CTFontCreateWithName`. Name-based lookup
        // only succeeds if some *other* code path already registered
        // Amiri into the process (`CTFontManagerRegisterFontURLs`) before
        // this test ran; `CTFontCreateWithName` never errors on a miss, it
        // silently falls back to a substitute system font, so an
        // unregistered name lookup here would quietly report 0% Arabic
        // coverage instead of failing loudly ، a hidden dependency on
        // global test-execution order (`swift test`'s ordering isn't
        // guaranteed across suites, and no prior test in this suite calls
        // `MKFontRegistry.loadBundled()`). Building the `CTFont` straight
        // from `face.fileURL` makes this test hermetic: it exercises the
        // real Amiri binary regardless of what has or hasn't been
        // registered process-wide by other tests.
        let font = try Self.ctFont(fromFileURL: face.fileURL, size: 24)
        let report = MKCoverageAnalyzer().analyze(font)
        #expect(report.supportsQuranicMarks)
        #expect(report.supportsTashkeel)
        let arabicRange = try #require(report.ranges.first { $0.rangeName == "arabic" })
        #expect(arabicRange.percentage > 50)
    }

    @Test func latinOnlySystemFontReportsZeroArabicCoverage() {
        // Helvetica/Times ship no Arabic glyphs at all ، a reliable
        // "Latin-only fixture" without needing to bundle a synthetic font.
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        let report = MKCoverageAnalyzer().analyze(font)
        let arabicRange = report.ranges.first { $0.rangeName == "arabic" }
        #expect((arabicRange?.percentage ?? 0) == 0)
        #expect(!report.supportsTashkeel)
        #expect(!report.supportsQuranicMarks)
    }

    @Test func reportIsCachedOnRegistry() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let first = await registry.coverageReport(for: "amiri")
        let second = await registry.coverageReport(for: "amiri")
        #expect(first != nil)
        #expect(first == second)
    }

    private enum FixtureError: Error { case noDescriptor(URL) }

    /// Builds a `CTFont` directly from a bundled font file's on-disk URL ،
    /// no process-wide registration required (`CTFontManagerRegisterFontURLs`
    /// is never called), so this is safe to use regardless of what any
    /// other test in the process has or hasn't registered.
    /// `CTFontManagerCreateFontDescriptorsFromURL` reads the file's own
    /// sfnt tables to build the descriptor, so the resulting `CTFont` is
    /// the real bundled binary, not a substitute.
    private static func ctFont(fromFileURL url: URL, size: CGFloat) throws -> CTFont {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first else {
            throw FixtureError.noDescriptor(url)
        }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
}
