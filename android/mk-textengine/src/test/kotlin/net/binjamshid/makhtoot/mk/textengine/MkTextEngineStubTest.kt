package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-textengine` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6).
 *
 * `mk-textengine`'s types are deliberately plain (non-`@Serializable`) data
 * classes, mirroring the shaped-output types' Swift shape (none of
 * `ShapedModels.swift`/etc. are `Codable` — they are runtime-only capture
 * results), so this test exercises structural equality (a real, working,
 * ported behavior on the data shapes) plus a representative stub throw.
 */
class MkTextEngineStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        assertThrows(MkNotYetPorted::class.java) { MkMarkClassifier.isMark(0x064B) }
    }

    @Test
    fun `a representative data class round-trips via structural equality`() {
        val original = MkGlyphAddress(run = 0, glyph = 3)
        val copy = original.copy()
        assertEquals(original, copy)
    }
}
