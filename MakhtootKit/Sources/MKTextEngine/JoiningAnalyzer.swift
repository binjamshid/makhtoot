import Foundation
import MKModel

/// One analyzed letter: its position, scalar, and computed joining state
/// (`MKModel.MKJoiningState` ، the exact type `MKGlyphNode.joining`
/// stores, so WS-04's derivation consumes this without conversion).
public struct MKLetterJoining: Hashable, Sendable {
    /// UTF-16 index of the letter's first code unit in the source string.
    public var utf16Index: Int
    public var scalar: UInt32
    public var state: MKJoiningState

    public init(utf16Index: Int, scalar: UInt32, state: MKJoiningState) {
        self.utf16Index = utf16Index
        self.scalar = scalar
        self.state = state
    }
}

/// WS-03 packet §5 task 10: per-letter joining analysis. Walks the source
/// string's scalars in logical order, skipping transparent codepoints
/// (combining marks and non-ZWJ/ZWNJ format controls, which "do not break
/// joining"), and computes each letter's current `MKJoiningForm` from its
/// effective neighbors ، ZWJ (join-causing) extends joins, ZWNJ
/// (non-joining) breaks them, exactly per Unicode ArabicShaping semantics.
///
/// Rules (UCD joining model, right side = toward the logically-previous
/// letter in RTL):
/// - `joinsPrevious(L)` ⇔ `JT(L) ∈ {D, R}` and `JT(prev) ∈ {D, C}`.
/// - `joinsNext(L)`     ⇔ `JT(L) = D` and `JT(next) ∈ {D, R, C}`.
/// - Form: (joinsPrev, joinsNext) → (F,F) isolated · (T,F) final ·
///   (F,T) initial · (T,T) medial.
///
/// This computes the form Core Text *should* have chosen (ARCHITECTURE
/// §4.6) ، used to label glyphs in the Arrange inspector, seed the D-107
/// form picker, and cross-check harvested glyphs in debug.
public enum MKJoiningAnalyzer {
    /// Analyzes every letter (D or R joining type) in `text`. Join-causing,
    /// non-joining, transparent, and non-Arabic scalars produce no entry
    /// (they are context, not letters with contextual forms). Tatweel
    /// (U+0640, join-causing) is context ، «مـحـمـد»'s letters keep their
    /// joined forms *through* the tatweel (packet §6 kashida note).
    public static func analyze(text: String) -> [MKLetterJoining] {
        // Effective (non-transparent) scalar sequence with UTF-16 offsets.
        var effective: [(scalar: Unicode.Scalar, type: MKJoiningType, utf16Index: Int)] = []
        var utf16Offset = 0
        for scalar in text.unicodeScalars {
            let type = MKJoiningTypeTable.joiningType(of: scalar)
            if type != .transparent {
                effective.append((scalar, type, utf16Offset))
            }
            utf16Offset += UTF16.width(scalar)
        }

        var results: [MKLetterJoining] = []
        for (i, entry) in effective.enumerated() {
            guard entry.type == .dual || entry.type == .rightJoining else { continue }

            let prevType = i > 0 ? effective[i - 1].type : nil
            let nextType = i + 1 < effective.count ? effective[i + 1].type : nil

            let joinsPrevious = (prevType == .dual || prevType == .joinCausing)
            let joinsNext = entry.type == .dual
                && (nextType == .dual || nextType == .rightJoining || nextType == .joinCausing)

            let form: MKJoiningForm
            switch (joinsPrevious, joinsNext) {
            case (false, false): form = .isolated
            case (true, false): form = .final
            case (false, true): form = .initial
            case (true, true): form = .medial
            }

            results.append(MKLetterJoining(
                utf16Index: entry.utf16Index,
                scalar: entry.scalar.value,
                state: MKJoiningState(form: form, joinsPrevious: joinsPrevious, joinsNext: joinsNext)))
        }
        return results
    }
}
