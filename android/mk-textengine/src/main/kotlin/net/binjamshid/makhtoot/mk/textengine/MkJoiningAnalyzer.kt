package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningState

/**
 * One analyzed letter: its position, scalar, and computed joining state
 * (`MKModel.MKJoiningState` ، the exact type `MKGlyphNode.joining` stores,
 * so WS-04's derivation consumes this without conversion). Ports
 * `Sources/MKTextEngine/JoiningAnalyzer.swift`.
 */
data class MkLetterJoining(
    /** UTF-16 index of the letter's first code unit in the source string. */
    var utf16Index: Int,
    var scalar: Int,
    var state: MkJoiningState,
)

/**
 * WS-03 packet §5 task 10: per-letter joining analysis. Walks the source
 * string's scalars in logical order, skipping transparent codepoints
 * (combining marks and non-ZWJ/ZWNJ format controls, which "do not break
 * joining"), and computes each letter's current `MkJoiningForm` from its
 * effective neighbors ، ZWJ (join-causing) extends joins, ZWNJ
 * (non-joining) breaks them, exactly per Unicode ArabicShaping semantics.
 *
 * Rules (UCD joining model, right side = toward the logically-previous
 * letter in RTL):
 * - `joinsPrevious(L)` ⇔ `JT(L) ∈ {D, R}` and `JT(prev) ∈ {D, C}`.
 * - `joinsNext(L)` ⇔ `JT(L) = D` and `JT(next) ∈ {D, R, C}`.
 * - Form: (joinsPrev, joinsNext) → (F,F) isolated · (T,F) final · (F,T)
 *   initial · (T,T) medial.
 *
 * This computes the form Core Text *should* have chosen (ARCHITECTURE
 * §4.6) ، used to label glyphs in the Arrange inspector, seed the D-107
 * form picker, and cross-check harvested glyphs in debug.
 */
object MkJoiningAnalyzer {
    /**
     * Analyzes every letter (D or R joining type) in [text]. Join-causing,
     * non-joining, transparent, and non-Arabic scalars produce no entry
     * (they are context, not letters with contextual forms). Tatweel
     * (U+0640, join-causing) is context ، «مـحـمـد»'s letters keep their
     * joined forms *through* the tatweel (packet §6 kashida note).
     */
    fun analyze(text: String): List<MkLetterJoining> =
        throw MkNotYetPorted("MkJoiningAnalyzer.analyze")
}
