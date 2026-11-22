package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm

/**
 * Unicode joining types for cursive-script shaping analysis (WS-03 packet
 * §5 task 10: "look up joining type ... from a bundled table (derived from
 * Unicode ArabicShaping semantics ، encode the table in Swift, cite UCD in
 * comments, no runtime file)"). Ports
 * `Sources/MKTextEngine/JoiningTypeTable.swift`.
 *
 * Source: Unicode Character Database, `ArabicShaping.txt` (UCD 15/16 ، the
 * Arabic-block assignments are stable across recent versions). Categories
 * (UAX #9 / UCD terminology):
 * - [Dual] Dual_Joining ، joins on both sides (ب ت ث ج ح خ س ش …).
 * - [RightJoining] Right_Joining ، joins only to the preceding letter (ا د
 *   ذ ر ز و …).
 * - [JoinCausing] Join_Causing ، makes neighbors join without joining
 *   itself visually (U+0640 TATWEEL, U+200D ZWJ).
 * - [NonJoining] Non_Joining ، never joins (U+0621 ء, U+200C ZWNJ, …).
 * - [Transparent] Transparent ، invisible to joining (combining marks Mn/Me
 *   and most Cf format controls other than ZWJ/ZWNJ).
 */
enum class MkJoiningType {
    Dual,
    RightJoining,
    JoinCausing,
    NonJoining,
    Transparent,
}

object MkJoiningTypeTable {
    /**
     * The joining type of [scalar] (a Unicode scalar value). Marks (Mn/Me
     * per `MkMarkClassifier`) and format controls other than ZWJ/ZWNJ are
     * `Transparent`; anything not otherwise listed is `NonJoining` ، the UCD
     * default for unlisted codepoints. The full UCD range tables (private
     * in Swift, not part of this module's public API) live alongside this
     * function in the ported implementation.
     */
    fun joiningType(scalar: Int): MkJoiningType =
        throw MkNotYetPorted("MkJoiningTypeTable.joiningType")

    /**
     * The set of contextual forms a letter of this joining type can
     * actually realize (T-TXT-6's "form selector metadata": right-joining
     * letters expose only {isolated, final}). Non-joining and non-letter
     * types expose only {isolated}.
     */
    fun validForms(scalar: Int): Set<MkJoiningForm> =
        throw MkNotYetPorted("MkJoiningTypeTable.validForms")
}
