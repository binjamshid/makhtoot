package net.binjamshid.makhtoot.mk.model.arranged

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkTextStyle

/**
 * Reversible backup of the text object an Arranged Composition was derived
 * from — retained for the lifetime of the arranged node, and used to verify
 * it hasn't been silently mutated by arrange edits (INV-4). Ports
 * `Sources/MKModel/Arranged/SourceTextBackup.swift`.
 *
 * `createdAt`/`contentHash` are computed at construction time in Swift
 * (`contentHash` via a dependency-free FNV-1a digest) — real logic, so
 * [MkSourceTextBackup] models them as ordinary stored fields the caller
 * supplies (mirroring the constructor shape) rather than reproducing the
 * hash algorithm inline; [recomputedHash] is the throw-stubbed function that
 * will reproduce it once ported.
 */
@Serializable
data class MkSourceTextBackup(
    /** The exact source string at the moment of arrangement. */
    var sourceString: String,
    /** Full style state at arrangement time. */
    var style: MkTextStyle,
    /** Present iff the origin was a `pathText` node — the frozen path at arrangement time. */
    var pathData: MkBezierPathData? = null,
    /** Epoch-millis creation timestamp. */
    var createdAt: Long,
    /** SHA-256 (hex) over `sourceString + style` canonical encoding — INV-4 tamper/drift check. */
    var contentHash: String,
) {
    /** Recomputes the hash a decoded/mutated-in-place backup *should* have, for INV-4 verification. */
    fun recomputedHash(): String = throw MkNotYetPorted("MkSourceTextBackup.recomputedHash")
}
