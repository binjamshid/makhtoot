// Work item 0.2 — category (b): joining. Harvests ZWJ contextual
// joining forms per letter per family via the shipped `MKFormResolver`
// (D-107), reusing the shipped code rather than re-deriving joining-type
// lookup. Output: `android/fixtures/joining/<familyID>.json`.
//
// Outline geometry is intentionally OMITTED from this DTO (kept to
// glyphID/advance/form/coercion only): `MKResolvedForm.outline` is a
// `MKPathData` whose exact points are a per-font rendering detail already
// covered by the render/pathtext categories and the G4 render-tolerance
// gate (ANDROID_SPINE.md §12) — D-325's Class A/B/C shaping-delta
// classification cares about glyph id / form / mark presence / ligature
// composition, never sub-glyph outline geometry, so including full outlines
// here would bloat every fixture without adding anything the gate checks.
// Documented here per spine §9's "a tolerance/scoping choice an agent had
// to pick is always logged" rule (also restated in the impl log).

import CoreGraphics
import CoreText
import Foundation
import MKFoundation
import MKModel
import MKTextEngine

/// The Arabic letter block (U+0621–U+064A) minus combining marks
/// (`MKMarkClassifier.isMark`) — every codepoint UCD classifies as a
/// joining-relevant "letter" (dual/right/join-causing/non-joining), not
/// just the 28-letter core alphabet, so extended letters (hamza-on-yeh,
/// teh marbuta, etc.) are swept too.
private func joiningSweepLetters() -> [Unicode.Scalar] {
    (0x0621...0x064A).compactMap(Unicode.Scalar.init).filter { !MKMarkClassifier.isMark($0) }
}

struct ResolvedFormDTO: Encodable {
    var requestedForm: String
    var realizedForm: String
    var wasCoerced: Bool
    var glyphID: UInt16
    var advanceWidth: CGFloat
    var advanceHeight: CGFloat
    var hasOutline: Bool

    init(requested: MKJoiningForm, resolved: MKResolvedForm) {
        requestedForm = requested.rawValue
        realizedForm = resolved.form.rawValue
        wasCoerced = resolved.wasCoerced
        glyphID = resolved.glyphID
        advanceWidth = resolved.advance.width
        advanceHeight = resolved.advance.height
        hasOutline = resolved.outline != nil
    }
}

struct LetterJoiningDTO: Encodable {
    var scalar: UInt32
    var character: String
    var joiningType: String
    var forms: [ResolvedFormDTO]
}

struct FamilyJoiningDTO: Encodable {
    var familyID: String
    var familyDir: String
    var fontFile: String
    var postScriptName: String
    var letters: [LetterJoiningDTO]
}

func exportJoining() async throws {
    let families = FontCatalog.discoverFamilies()
    let letters = joiningSweepLetters()
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("joining")
    let allForms: [MKJoiningForm] = [.isolated, .initial, .medial, .final]

    var count = 0
    for family in families {
        guard let ps = FontCatalog.registerAndResolvePostScriptName(family) else {
            print("[joining] WARNING: could not resolve PostScript name for \(family.familyID) — skipped")
            continue
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let resolver = MKFormResolver(fonts: fonts)
        let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2)

        var letterDTOs: [LetterJoiningDTO] = []
        for letter in letters {
            var formDTOs: [ResolvedFormDTO] = []
            for requested in allForms {
                guard let resolved = await resolver.resolve(letter: letter, form: requested, style: style) else { continue }
                formDTOs.append(ResolvedFormDTO(requested: requested, resolved: resolved))
            }
            guard !formDTOs.isEmpty else { continue }
            letterDTOs.append(LetterJoiningDTO(
                scalar: letter.value, character: String(letter),
                joiningType: String(describing: MKJoiningTypeTable.joiningType(of: letter)), forms: formDTOs))
        }

        let dto = FamilyJoiningDTO(familyID: family.familyID, familyDir: family.familyDir, fontFile: family.fileName, postScriptName: ps, letters: letterDTOs)
        try GoldenJSON.write(dto, to: categoryRoot.appendingPathComponent("\(family.familyID).json"))
        count += 1
    }
    print("[joining] wrote \(count) family files (\(letters.count) letters swept per family)")
}
