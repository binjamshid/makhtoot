package net.binjamshid.makhtoot.mk.foundation.rtl

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * RTL / Arabic-script helpers shared by every module that touches text
 * direction, digit display, or layout mirroring. Ports
 * `Sources/MKFoundation/RTL/MKRTLUtilities.swift`.
 *
 * Detection-only note (D-103): Unicode *presentation-form* ranges
 * (U+FB50-FDFF, U+FE70-FEFF) are recognized here strictly for already-composed
 * presentation-form text encountered externally (e.g. pasted from another
 * app). MakhtootKit itself never *produces* presentation-form codepoints for
 * rendering — shaping always goes through HarfBuzz on Android (D-303).
 */
object MkRtlUtilities {
    /** Whether [scalar] (a single Unicode code point) falls in any recognized Arabic-script range. */
    fun isRTLCharacter(scalar: Int): Boolean = throw MkNotYetPorted("MkRtlUtilities.isRTLCharacter")

    /** Convenience overload for a single Kotlin `Char`. */
    fun isRTLCharacter(character: Char): Boolean = throw MkNotYetPorted("MkRtlUtilities.isRTLCharacter")

    /** Ports `BaseDirection`. */
    enum class BaseDirection {
        RightToLeft,
        LeftToRight,

        /** No strongly-directional character was found. */
        Neutral,
    }

    /** A lightweight first-strong-character heuristic for [string]'s base direction. */
    fun baseDirection(of: String): BaseDirection = throw MkNotYetPorted("MkRtlUtilities.baseDirection")

    /**
     * Ports the `#if canImport(UIKit)`-gated `semanticContentAttribute(for:)`.
     * [MkSemanticContentAttribute] is a local placeholder for
     * `UISemanticContentAttribute`, which has no Android equivalent — retained
     * per the "port every public symbol" mandate (`ANDROID_TASK_PACKETS/BATCH-1.md`
     * Agent 1.3 Mission) even though no Android call site is expected to need it.
     */
    fun semanticContentAttribute(direction: BaseDirection): MkSemanticContentAttribute =
        throw MkNotYetPorted("MkRtlUtilities.semanticContentAttribute")

    /** Converts every Latin digit `0`-`9` in [string] to its Arabic-Indic equivalent. */
    fun toArabicIndicDigits(string: String): String = throw MkNotYetPorted("MkRtlUtilities.toArabicIndicDigits")

    /** Converts every Arabic-Indic digit in [string] to its Latin equivalent. */
    fun toLatinDigits(string: String): String = throw MkNotYetPorted("MkRtlUtilities.toLatinDigits")

    /** Whether every digit character in [string] (if any) is Arabic-Indic, Latin, or absent. */
    fun hasConsistentDigitSystem(string: String): Boolean =
        throw MkNotYetPorted("MkRtlUtilities.hasConsistentDigitSystem")
}

/**
 * Local placeholder substitute for `UISemanticContentAttribute` (no Android
 * equivalent). See [MkRtlUtilities.semanticContentAttribute].
 */
enum class MkSemanticContentAttribute {
    ForceRightToLeft,
    ForceLeftToRight,
    Unspecified,
}
