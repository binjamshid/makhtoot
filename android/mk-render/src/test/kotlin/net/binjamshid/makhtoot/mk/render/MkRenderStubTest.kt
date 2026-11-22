package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkBackgroundNode
import net.binjamshid.makhtoot.mk.model.MkNode
import net.binjamshid.makhtoot.mk.model.MkNodeCore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-render` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6).
 */
class MkRenderStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        val node = MkNode.Background(MkBackgroundNode(core = MkNodeCore(name = "background")))
        assertThrows(MkNotYetPorted::class.java) { MkContentHash.hash(node = node, scaleBucket = 1.0) }
    }

    @Test
    fun `a representative data class round-trips via structural equality`() {
        val original = MkBitmapCacheKey(nodeContentHash = "abc123", scaleBucket = 1.0)
        val copy = original.copy()
        assertEquals(original, copy)
    }
}
