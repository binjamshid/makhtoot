package net.binjamshid.makhtoot.mk.nativebridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure-Kotlin contract tests for the safe wrapper layer's data types — no
 * native call, so these run (and must pass) on every JVM, unlike
 * [MkNativeShapingSmokeTest]'s self-skipping native-boundary cases.
 */
class MkNativeBridgeContractTest {

    @Test
    fun `MkShapeDirection native values match the JNI facade's IntDef`() {
        assertEquals(0, MkShapeDirection.LTR.nativeValue)
        assertEquals(1, MkShapeDirection.RTL.nativeValue)
    }

    @Test
    fun `MkOutlineVerb round-trips through its native value`() {
        for (verb in MkOutlineVerb.entries) {
            assertEquals(verb, MkOutlineVerb.fromNativeValue(verb.nativeValue))
        }
    }

    @Test
    fun `MkOutlineVerb point counts match FT_Outline_Decompose callback arity`() {
        assertEquals(1, MkOutlineVerb.MOVE_TO.pointCount)
        assertEquals(1, MkOutlineVerb.LINE_TO.pointCount)
        assertEquals(2, MkOutlineVerb.QUAD_TO.pointCount)
        assertEquals(3, MkOutlineVerb.CUBIC_TO.pointCount)
        assertEquals(0, MkOutlineVerb.CLOSE.pointCount)
    }

    @Test
    fun `MkShapedGlyphs structural equality is content-based, not reference-based`() {
        val a = MkShapedGlyphs(
            glyphIds = intArrayOf(460),
            clusters = intArrayOf(0),
            xAdvances = floatArrayOf(21.708f),
            yAdvances = floatArrayOf(0f),
            xOffsets = floatArrayOf(0f),
            yOffsets = floatArrayOf(0f),
            isRtl = true,
        )
        val b = MkShapedGlyphs(
            glyphIds = intArrayOf(460),
            clusters = intArrayOf(0),
            xAdvances = floatArrayOf(21.708f),
            yAdvances = floatArrayOf(0f),
            xOffsets = floatArrayOf(0f),
            yOffsets = floatArrayOf(0f),
            isRtl = true,
        )
        assertEquals(a, b)
        assertEquals(a.hashCode(), b.hashCode())
        assertEquals(1, a.glyphCount)

        val c = b.copy(glyphIds = intArrayOf(461))
        assertNotEquals(a, c)
    }

    @Test
    fun `MkGlyphOutline structural equality is content-based`() {
        val a = MkGlyphOutline(
            verbs = intArrayOf(0, 1, 4),
            points = floatArrayOf(0f, 0f, 10f, 0f),
            advance = 21.7f,
        )
        val b = MkGlyphOutline(
            verbs = intArrayOf(0, 1, 4),
            points = floatArrayOf(0f, 0f, 10f, 0f),
            advance = 21.7f,
        )
        assertTrue(a == b)
        assertEquals(a.hashCode(), b.hashCode())
    }

    @Test
    fun `MkRenderingIntent native values match the ICC spec numbering lcms2 also uses`() {
        assertEquals(0, MkRenderingIntent.PERCEPTUAL.nativeValue)
        assertEquals(1, MkRenderingIntent.RELATIVE_COLORIMETRIC.nativeValue)
        assertEquals(2, MkRenderingIntent.SATURATION.nativeValue)
        assertEquals(3, MkRenderingIntent.ABSOLUTE_COLORIMETRIC.nativeValue)
    }
}
