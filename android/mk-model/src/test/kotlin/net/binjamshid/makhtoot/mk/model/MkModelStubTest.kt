package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.json.Json
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Minimal compile/smoke test for the `:mk-model` contract stubs
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, task 6).
 */
class MkModelStubTest {
    @Test
    fun `a representative stubbed function throws MkNotYetPorted`() {
        val scene = MkScene(
            canvas = MkCanvasSpec(size = MkSize(1080.0, 1080.0)),
            background = MkBackgroundNode(core = MkNodeCore(name = "background")),
        )
        assertThrows(MkNotYetPorted::class.java) { scene.node(net.binjamshid.makhtoot.mk.foundation.MkNodeId()) }
    }

    @Test
    fun `a representative data class round-trips through kotlinx serialization`() {
        val original = MkTextStyle(pointSize = 48.0, isBold = true)
        val encoded = Json.encodeToString(MkTextStyle.serializer(), original)
        val decoded = Json.decodeFromString(MkTextStyle.serializer(), encoded)
        assertEquals(original, decoded)
    }
}
