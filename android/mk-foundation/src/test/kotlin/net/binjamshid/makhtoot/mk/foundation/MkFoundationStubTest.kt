package net.binjamshid.makhtoot.mk.foundation

import kotlinx.serialization.json.Json
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-foundation` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6). Not behavioral
 * coverage — real coverage lands with the Batch 2 implementation at the same
 * file paths.
 */
class MkFoundationStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        val transform = MkTransform2D()
        assertThrows(MkNotYetPorted::class.java) { transform.inverted() }
    }

    @Test
    fun `a representative data class round-trips through kotlinx serialization`() {
        val original = MkTransform2D(position = MkPoint(1.0, 2.0), rotation = 0.5, scale = MkSize(2.0, 3.0))
        val encoded = Json.encodeToString(MkTransform2D.serializer(), original)
        val decoded = Json.decodeFromString(MkTransform2D.serializer(), encoded)
        assertEquals(original, decoded)
    }
}
