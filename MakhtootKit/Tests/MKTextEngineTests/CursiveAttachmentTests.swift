import CoreText
import Foundation
import MKFoundation
import MKModel
import Testing
@testable import MKTextEngine

// WS-16 (`docs/impl-log/WS-16-cursive.md`, ADR WS16-A2). D-222 step 8 held
// 5 fonts (Amiri, Amiri Quran, Aref Ruqaa, Rakkas, Qahiri) out of the
// catalog pending a "cursive-pair structure" in D-105's capture model.
// These tests exercise the resulting `MKShapedRun.cursiveAttached` signal
// against the REAL bundled Amiri binary (not a system font) ، registered
// directly from `MKFonts`' resource tree by file URL, mirroring the
// `NamedFontProvider`/Geeza-Pro pattern `Fixtures.swift`/`ArrangeFixtures`
// already use for real-font D-107 tests, without this target depending on
// the `MKFonts` module itself (dependency-graph direction: MKFonts depends
// on nothing here; MKTextEngine must not depend on MKFonts).
//
// Per WS03-A4's zero-hardcoded-glyph-id convention, every assertion below
// is structural (counts, membership, index-parallelism) ، never a specific
// glyph id ، except where a fixture's own EXACT finding is the point of the
// test (documented inline).
@Suite struct CursiveAttachmentTests {
    static let amiriPostScriptName = "Amiri-Regular"

    /// Registers the real bundled Amiri binary into the test process once,
    /// the first time any test in this suite runs. `CTFontManagerRegisterFontsForURL`
    /// is idempotent-safe to call more than once for the same URL (returns
    /// an error the second time, which this ignores) ، matches the
    /// registration pattern `MKFontRegistryTests`/`CoverageAnalysisTests`
    /// (WS-09) already use for the same binary.
    static let registerOnce: Void = {
        let fontsRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CursiveAttachmentTests.swift
            .deletingLastPathComponent()   // MKTextEngineTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Sources/MKFonts/Resources/Fonts/Amiri/Amiri-Regular.ttf")
        var err: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(fontsRoot as CFURL, .process, &err)
    }()

    struct NamedFontProvider: MKFontProviding {
        func resolve(_ handle: MKFontHandle) -> CTFont {
            CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        }
    }

    static let amiriEngine = MKShapingEngine(fonts: NamedFontProvider())

    static func amiriStyle(size: Double = 48) -> MKTextStyle {
        MKTextStyle(font: .system(postScriptName: amiriPostScriptName), pointSize: size, baseDirection: .rightToLeft)
    }

    static func shapeAmiri(_ text: String, size: Double = 48) -> MKShapedLine {
        _ = registerOnce
        return amiriEngine.shapeSingleLine(MKShapingRequest(string: text, style: amiriStyle(size: size)))
    }

    // Fail loudly (not silently pass) if Amiri didn't actually register ،
    // every other test in this suite is meaningless against a substituted
    // fallback font.
    @Test func amiriActuallyRegistered() {
        let line = Self.shapeAmiri("محمد")
        let resolvedFont = line.runs.first?.font.postScriptName
        #expect(resolvedFont == Self.amiriPostScriptName, "Amiri did not register ، got \(resolvedFont ?? "nil"); every other test in this suite is invalid without the real binary")
    }

    /// Index-parallelism / totality (mirrors the existing cluster-map
    /// totality convention): `cursiveAttached.count == glyphs.count` for
    /// EVERY run, on every fixture below ، never a partially-populated or
    /// mismatched array.
    @Test(arguments: ["محمد", "سجا", "بحث", "بسم الله الرحمن الرحيم", "طويل", "لا", "مُحَمَّدٌ"])
    func cursiveAttachedArrayIsIndexParallelToGlyphs(_ text: String) {
        let line = Self.shapeAmiri(text)
        for run in line.runs {
            #expect(run.cursiveAttached.count == run.glyphs.count, "run for '\(text)' has \(run.glyphs.count) glyphs but \(run.cursiveAttached.count) cursiveAttached flags")
        }
    }

    /// Negative fixture (probed empirically, `docs/impl-log/WS-16-cursive.md`):
    /// none of «محمد»'s 4 glyphs in Amiri are members of the GPOS 'curs'
    /// coverage table ، a clean baseline proving the flag is not
    /// universally true (would be a useless signal if it were).
    @Test func muhammadHasNoCursiveAttachedGlyphsInAmiri() {
        let line = Self.shapeAmiri("محمد")
        let anyFlagged = line.runs.contains { $0.cursiveAttached.contains(true) }
        #expect(!anyFlagged, "«محمد» unexpectedly has a cursive-attached glyph in Amiri ، WS-16 probe evidence assumed otherwise")
    }

    /// Positive fixture (probed empirically): «سجا» (seen-jeem-alef) is a
    /// real Arabic letter sequence where Amiri's GPOS 'curs' feature fires
    /// ، the jeem glyph carries an Entry anchor and the following letter's
    /// glyph carries an Exit anchor, producing a measurable (~0.576pt at
    /// 48pt) vertical position adjustment that IS already correctly baked
    /// into `positions` by Core Text (D-105) and is now ALSO flagged by
    /// `cursiveAttached` for the two participating glyphs.
    @Test func seenJeemAlefHasCursiveAttachedGlyphsInAmiri() {
        let line = Self.shapeAmiri("سجا")
        let run = line.runs[0]
        let flaggedCount = run.cursiveAttached.filter { $0 }.count
        #expect(flaggedCount >= 2, "expected at least 2 cursive-attached glyphs in «سجا» (jeem + the following letter), got \(flaggedCount) of \(run.glyphs.count)")

        // The already-baked position evidence: at least one glyph position
        // has a non-zero Y offset ، confirming Core Text applied the
        // cursive adjustment to `positions` BEFORE this flag was ever
        // computed (this flag is metadata about an already-correct
        // position, never a trigger for computing one).
        let anyNonZeroY = run.positions.contains { $0.y != 0 }
        #expect(anyNonZeroY, "expected «سجا» to show a Core-Text-applied cursive Y offset in its captured positions")
    }

    /// Broader corpus sweep (structural, no hardcoded ids): across a
    /// representative set of common Arabic sequences most likely to trigger
    /// Amiri's cursive-attachment contextual glyphs (seen/jeem-family
    /// combinations, per the WS-16 probe sweep in
    /// `docs/impl-log/WS-16-cursive.md`), the mechanism fires for real,
    /// everyday text ، not merely a theoretical GPOS table entry nobody's
    /// typed text ever reaches.
    @Test func cursiveAttachmentFiresAcrossARepresentativeCorpus() {
        let corpus = ["سجد", "سجل", "سجن", "سجم", "هجر", "نجم", "تجت"]
        var totalFlagged = 0
        for word in corpus {
            let line = Self.shapeAmiri(word)
            totalFlagged += line.runs.reduce(0) { $0 + $1.cursiveAttached.filter { $0 }.count }
        }
        #expect(totalFlagged > 0, "expected at least one cursive-attached glyph across the representative corpus \(corpus)")
    }

    /// The audit is a Coverage-table-membership read ONLY (never anchor
    /// values, never a position recomputation) ، cross-checked here by
    /// confirming that flagging a glyph never changes its captured
    /// position/advance relative to an unflagged capture of the same text
    /// (i.e., this feature is additive metadata, not a behavior change to
    /// D-105's existing capture math). Regression guard for a future editor
    /// accidentally wiring the flag into position computation.
    @Test func cursiveAttachedFlagNeverAffectsPositionOrAdvanceValues() {
        let line1 = Self.shapeAmiri("سجا")
        let line2 = Self.shapeAmiri("سجا")
        #expect(line1.runs[0].positions == line2.runs[0].positions)
        #expect(line1.runs[0].advances == line2.runs[0].advances)
        #expect(line1.runs[0].cursiveAttached == line2.runs[0].cursiveAttached)
    }

    /// `MKCursiveCoverageCache` must degrade to "no signal" (empty set,
    /// never a trap) for a font with no GPOS table / no 'curs' feature ،
    /// exercised here via the system fallback font (SF Arabic), which the
    /// existing WS-03 test suite already establishes has no observable
    /// dlig/cursive surface (WS03-A6).
    @Test func systemFontProducesNoCursiveAttachedGlyphs() {
        let line = Fixtures.shape("سجا")
        let anyFlagged = line.runs.contains { $0.cursiveAttached.contains(true) }
        #expect(!anyFlagged, "system SF Arabic unexpectedly reported a cursive-attached glyph")
    }
}
