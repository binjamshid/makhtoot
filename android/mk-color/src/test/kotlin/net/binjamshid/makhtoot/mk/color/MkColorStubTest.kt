package net.binjamshid.makhtoot.mk.color

import kotlinx.serialization.json.Json
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-color` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6).
 */
class MkColorStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        val color = MkColorSpec(r = 0.5, g = 0.5, b = 0.5)
        assertThrows(MkNotYetPorted::class.java) { color.cgColor() }
    }

    @Test
    fun `a representative data class round-trips through kotlinx serialization`() {
        val original = MkColorSpec(r = 0.1, g = 0.2, b = 0.3, a = 0.9, swatch = "brand-1")
        val encoded = Json.encodeToString(MkColorSpec.serializer(), original)
        val decoded = Json.decodeFromString(MkColorSpec.serializer(), encoded)
        assertEquals(original, decoded)
    }
}
