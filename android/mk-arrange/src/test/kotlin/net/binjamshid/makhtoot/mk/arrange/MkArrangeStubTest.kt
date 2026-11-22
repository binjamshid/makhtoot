package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-arrange` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6).
 */
class MkArrangeStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        assertThrows(MkNotYetPorted::class.java) { MkArrangeInvariants.assertReshapeAllowed(MkArrangeNodeKind.Arranged) }
    }

    @Test
    fun `a representative data class round-trips via structural equality`() {
        val original = MkDecomposeOptions(fidelity = true)
        val copy = original.copy()
        assertEquals(original, copy)
    }
}
