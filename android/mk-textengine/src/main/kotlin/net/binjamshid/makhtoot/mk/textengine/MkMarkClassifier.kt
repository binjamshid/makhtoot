package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.arranged.MkMarkClass

/**
 * D-105 mark identification tables and classifier. Ports
 * `Sources/MKTextEngine/MarkClassifier.swift`.
 *
 * The explicit ranges/sets below are plain literal data (not behavior), so
 * they are ported as real values, exactly as in the Swift source — only
 * [isMark]/[classify]/[isControlFormatter] (real logic/functions) are
 * throw-stubbed per the Batch 1 stub mechanism.
 */
object MkMarkClassifier {
    /** U+0610-061A: honorific/Qur'anic marks. */
    val honorifics: IntRange = 0x0610..0x061A

    /** U+064B-065F: harakat + extended harakat/hamza-mark block. */
    val harakatBlock: IntRange = 0x064B..0x065F

    /** U+0670: Arabic letter superscript alef. */
    const val superscriptAlef: Int = 0x0670

    /** U+06D6-06ED: Qur'anic annotation signs. Not every scalar in this range is a combining mark. */
    val quranicAnnotations: IntRange = 0x06D6..0x06ED

    /** Scalars inside [quranicAnnotations] that are **not** marks (verified empirically against Unicode categories). */
    val quranicNonMarkExceptions: Set<Int> = setOf(0x06DD, 0x06DE, 0x06E9)

    /** Zero-width joiners/formatting and bidi-control scalars — a cluster drawn entirely from this set is `.control`. */
    val controlFormatters: Set<Int> = setOf(
        0x200B, // ZERO WIDTH SPACE
        0x200C, // ZERO WIDTH NON-JOINER (ZWNJ)
        0x200D, // ZERO WIDTH JOINER (ZWJ)
        0x200E, // LEFT-TO-RIGHT MARK
        0x200F, // RIGHT-TO-LEFT MARK
        0x061C, // ARABIC LETTER MARK
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // LRE/RLE/PDF/LRO/RLO
        0x2066, 0x2067, 0x2068, 0x2069, // LRI/RLI/FSI/PDI
    )

    /** Whether [scalar] is a combining mark for D-105 purposes. */
    fun isMark(scalar: Int): Boolean = throw MkNotYetPorted("MkMarkClassifier.isMark")

    /** Classifies [scalar] into an [MkMarkClass], or `null` if it is not a mark. */
    fun classify(scalar: Int): MkMarkClass? = throw MkNotYetPorted("MkMarkClassifier.classify")

    /** Whether [scalar] is a ZWJ/ZWNJ/bidi-control formatting character (D-105 `.control` cluster kind). */
    fun isControlFormatter(scalar: Int): Boolean = throw MkNotYetPorted("MkMarkClassifier.isControlFormatter")
}
