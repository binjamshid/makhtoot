package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-pathtext` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6).
 *
 * Note: `mk-pathtext`'s data types are deliberately plain (non-`@Serializable`)
 * data classes, mirroring the Swift source's own "Codable-free runtime
 * type" design for this module (`PathGlyphPlacement.swift`'s file header) —
 * so the serialization half of this smoke test uses `MkPathGlyphUserOffset`
 * encoded manually via a locally-declared serializable mirror is
 * unnecessary; instead this test exercises the one `@Serializable`-free
 * round-trip this module's own design calls for: plain `data class`
 * `equals`/`copy` structural equality, still a real, working, ported
 * behavior (not a stub) per the same "data classes are real" rule as every
 * other module.
 */
class MkPathTextStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        val model = MkBezierPathModel(anchors = listOf(MkPathAnchor(point = MkPoint.zero)))
        assertThrows(MkNotYetPorted::class.java) { model.bezierPathData() }
    }

    @Test
    fun `a representative data class round-trips via structural equality (this module's types are deliberately non-Serializable)`() {
        val original = MkPathGlyphUserOffset(offset = MkPoint(1.0, 2.0), rotation = 0.25)
        val copy = original.copy()
        assertEquals(original, copy)
    }
}
