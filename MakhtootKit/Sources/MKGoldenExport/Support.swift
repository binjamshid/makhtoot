// Work item 0.2 (android/, ANDROID_TASK_PACKETS/BATCH-0.md §"Batch 0 ·
// Agent 0.2 — Golden-fixture exporter (Swift)"). Shared plumbing for every
// category exporter in this target: deterministic paths, deterministic JSON
// writing, the bundled-font catalog, and the canonical Arabic corpus
// (PRD.md "Canonical Arabic test fixtures", F-1..F-12).
//
// **Determinism discipline (G0, ANDROID_SPINE.md §6/§10).** Two runs of this
// executable must produce a byte-identical `android/fixtures/` tree, except
// JPEG (see `android/fixtures/DETERMINISM_EXCLUSIONS.json`). PDFs are local
// samples outside the fixture tree. To hold that invariant
// against MakhtootKit's own source types, this file's `writeJSON` helper
// ALWAYS uses `.sortedKeys` (stable regardless of Swift's dictionary
// iteration order) and this target NEVER encodes a raw `MKID<Tag>` (backed
// by a randomly-generated `UUID` at `init()`, see `MKFoundation/MKID.swift`)
// or a `Date` (e.g. `MKSourceTextBackup.createdAt`) into any golden file.
// Every place a source type carries one of those, the category exporter
// substitutes a deterministic, array-position-derived ordinal instead (see
// each `*Export.swift` file's own header note for its specific mapping).
// This is a documented interpretation, not a silent omission — recorded
// again in `android/docs/impl-log/BATCH-0.2.md`.

import CoreGraphics
import CoreText
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

// MARK: - Repository paths (resolved from #filePath, never CWD-dependent —
// this executable must produce identical output whether invoked as
// `swift run MKGoldenExport` from `MakhtootKit/` or from anywhere else).

enum RepoPaths {
    /// `.../makhtoot/MakhtootKit/Sources/MKGoldenExport/Support.swift`
    /// → walk up 3 path components to `MakhtootKit/`, 1 more to the repo
    /// root.
    static let makhtootKitRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Support.swift
            .deletingLastPathComponent()   // MKGoldenExport
            .deletingLastPathComponent()   // Sources
    }()

    static let repoRoot: URL = makhtootKitRoot.deletingLastPathComponent()

    static let fixturesRoot: URL = repoRoot.appendingPathComponent("android/fixtures")

    static let testFixturesDir: URL = makhtootKitRoot.appendingPathComponent("Tests/Fixtures")

    static let fontsRoot: URL = makhtootKitRoot.appendingPathComponent("Sources/MKFonts/Resources/Fonts")

    /// Creates `dir` (and intermediates) if missing. Never removes an
    /// existing tree first — category exporters are responsible for
    /// overwriting every file they own on each run so a second run is a
    /// true byte-for-byte re-derivation, not an accumulation.
    static func ensure(_ dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

// MARK: - Deterministic JSON

enum GoldenJSON {
    /// `.sortedKeys`: stable key order regardless of Swift's own keyed-
    /// container iteration order. `.prettyPrinted` is included for
    /// human/diff readability — `JSONEncoder`'s pretty-printed output is
    /// itself deterministic for a fixed input (whitespace is derived
    /// mechanically from nesting depth, not from any iteration-order-
    /// sensitive process), so this does not reintroduce non-determinism.
    /// No `Date`/`UUID` value may ever reach this encoder — see this
    /// file's header.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }()

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        RepoPaths.ensure(url.deletingLastPathComponent())
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - The 4 canonical `Tests/Fixtures/*.makhtoot` scenes (shared by the
// `arrange` and `scenecodec` category exporters).

let fixtureNames = ["fixture-arabic-basic", "fixture-arranged-la", "fixture-100-nodes", "fixture-5000-nodes"]

// MARK: - Canonical Arabic corpus (PRD.md "Canonical Arabic test fixtures")

struct CorpusFixture: Sendable {
    let id: String
    let string: String
    let note: String
}

enum Corpus {
    /// Verbatim from `PRD.md`'s F-1..F-12 table (the canonical fixture set
    /// every flow/edge-case doc cross-references; the packet's task 2
    /// instruction is to build the shaping corpus from exactly this
    /// section).
    static let fixtures: [CorpusFixture] = [
        CorpusFixture(id: "F-1", string: "لا", note: "Mandatory lam-alif ligature, isolated"),
        CorpusFixture(id: "F-2", string: "الله", note: "Word-ligature candidate, multi-glyph cluster behavior"),
        CorpusFixture(id: "F-3", string: "محمّد", note: "Shadda on a medial base inside a joined word"),
        CorpusFixture(id: "F-4", string: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", note: "Full tashkeel, multiple marks per base"),
        CorpusFixture(id: "F-5", string: "مرحبا Hello ١٢٣ 123", note: "Mixed bidi: RTL base, embedded LTR run, Arabic-Indic + European digits"),
        CorpusFixture(id: "F-6a", string: "حِسّ", note: "Shadda + kasra ordering, multiple marks on one base"),
        CorpusFixture(id: "F-6b", string: "مُدَرِّسَة", note: "Shadda + kasra ordering, multiple marks on one base"),
        CorpusFixture(id: "F-7a", string: "سلام", note: "Lam-alif ligature inside a joined word"),
        CorpusFixture(id: "F-7b", string: "الإسلام", note: "Lam-alif ligature inside a joined word, hamza-on-alif"),
        CorpusFixture(id: "F-8", string: "ًٌٍَُِّْ", note: "Tashkeel-only input, no base letters (dotted-circle fallback)"),
        CorpusFixture(id: "F-9", string: "محمــــد", note: "Kashida/tatweel U+0640 as a real, shapeable glyph"),
        CorpusFixture(id: "F-10", string: "مخطوط عربي جميل", note: "Path-text fixture, three words"),
        CorpusFixture(id: "F-11", string: "أبجد هوز حطي كلمن سعفص قرشت ثخذ ضظغ", note: "Full-alphabet joining sweep"),
        CorpusFixture(id: "F-12", string: "ما شاء الله ١٤٤٧هـ", note: "Ligatures + digits + heh-marker mixed content"),
    ]
}

// MARK: - Bundled font catalog (45 families, one representative face each)

struct FontFamilyFixture: Sendable {
    let familyID: String       // lower-kebab, derived from the directory name
    let familyDir: String      // Resources/Fonts/<familyDir>
    let fileName: String
}

enum FontCatalog {
    /// Enumerates every family directory under `Resources/Fonts/` (skipping
    /// marker files `_PROHIBITED.md`/`EXCLUDED_FONTS.md`, which are not
    /// families), picking one representative face per family: the file
    /// whose name contains "Regular" if one exists, else the
    /// alphabetically-first `.ttf`/`.otf` in that directory (deterministic
    /// either way — no reliance on filesystem enumeration order).
    static func discoverFamilies() -> [FontFamilyFixture] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: RepoPaths.fontsRoot, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        var families: [FontFamilyFixture] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let dirName = entry.lastPathComponent
            guard let files = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil) else { continue }
            let fontFiles = files
                .map(\.lastPathComponent)
                .filter { $0.hasSuffix(".ttf") || $0.hasSuffix(".otf") }
                .sorted()
            guard !fontFiles.isEmpty else { continue }
            let chosen = fontFiles.first { $0.contains("Regular") } ?? fontFiles[0]
            families.append(FontFamilyFixture(
                familyID: familyID(from: dirName), familyDir: dirName, fileName: chosen))
        }
        return families
    }

    /// `NotoNastaliqUrdu` → `noto-nastaliq-urdu` (kebab-case, matching the
    /// `fontID`/catalog-id spelling convention used elsewhere in this repo,
    /// e.g. `PerFontArrangeFidelitySweepTests.FontFixture.fontID`).
    private static func familyID(from dirName: String) -> String {
        var result = ""
        for (i, ch) in dirName.enumerated() {
            if ch.isUppercase, i > 0 { result += "-" }
            result += ch.lowercased()
        }
        return result
    }

    /// Registers `fixture`'s font file by URL (process-wide, matching the
    /// existing `PerFontArrangeFidelitySweepTests.registerAndResolvePostScriptName`
    /// pattern this exporter reuses verbatim) and resolves its REAL
    /// PostScript name — several bundled families are variable fonts whose
    /// PostScript name does not match the filename stem.
    static func registerAndResolvePostScriptName(_ fixture: FontFamilyFixture) -> String? {
        let url = RepoPaths.fontsRoot.appendingPathComponent(fixture.familyDir).appendingPathComponent(fixture.fileName)
        var registerErr: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registerErr)
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first
        else { return nil }
        let font = CTFontCreateWithFontDescriptor(first, 0, nil)
        return CTFontCopyPostScriptName(font) as String
    }
}

/// Resolves every handle to the ONE registered PostScript name this fixture
/// provider was built for — same shape as
/// `PerFontArrangeFidelitySweepTests.NamedFontProvider` (Tests/MKArrangeTests),
/// duplicated here because this executable target cannot `@testable import`
/// a sibling test target's helper.
struct NamedFontProvider: MKFontProviding {
    let postScriptName: String
    func resolve(_ handle: MKFontHandle) -> CTFont {
        CTFontCreateWithName(postScriptName as CFString, handle.pointSize, nil)
    }
}

// MARK: - Cluster-id / node-id determinism helpers
//
// `MKClusterID`/`MKNodeID` (`MKID<Tag>`) default to a freshly-random `UUID`
// at construction (`MKFoundation/MKID.swift`). `MKShapingEngine`'s cluster
// builder and `MKArrange.ArrangeDeriver`'s freshly-derived glyph/mark/
// ligature nodes both mint new ids on every call, so the SAME logical
// fixture shaped/derived twice (once per golden-export run) gets two
// DIFFERENT sets of raw id values — a direct violation of G0's byte-
// identical-second-run requirement if serialized verbatim. Every category
// exporter that touches these types builds one of the ordinal maps below
// (keyed by the id's own *position* in a deterministic array, never by its
// UUID value) and serializes the ordinal, never the raw id.

func clusterOrdinalMap(_ line: MKShapedLine) -> [MKClusterID: Int] {
    var map: [MKClusterID: Int] = [:]
    for (i, cluster) in line.clusterMap.clusters.enumerated() { map[cluster.id] = i }
    return map
}

func clusterOrdinalMap(_ paragraph: MKShapedParagraph) -> [MKClusterID: Int] {
    var map: [MKClusterID: Int] = [:]
    var i = 0
    for line in paragraph.lines {
        for cluster in line.clusterMap.clusters {
            map[cluster.id] = i
            i += 1
        }
    }
    return map
}

func nodeOrdinalMap(_ composition: ArrangedComposition) -> [MKNodeID: Int] {
    Dictionary(uniqueKeysWithValues: composition.nodes.enumerated().map { ($1.id, $0) })
}
