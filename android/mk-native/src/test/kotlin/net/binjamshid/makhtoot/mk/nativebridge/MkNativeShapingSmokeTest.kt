package net.binjamshid.makhtoot.mk.nativebridge

import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assume
import org.junit.Test

/**
 * Batch 1 · Agent 1.2's `:mk-native` smoke test (`ANDROID_SPINE.md` §6 G1),
 * compared against the Core Text golden fixtures from work item 0.2 under
 * `android/fixtures/shaping` (recursively).
 *
 * **Why this test self-skips on a plain JVM unit test run.** `:mk-native`'s
 * production artefact is `libmknative.so`, cross-compiled for Android target
 * triples (arm64-v8a/armeabi-v7a/x86_64/x86, `mk-native/CMakeLists.txt`).
 * `./gradlew :mk-native:testDebugUnitTest` runs on the **host** JVM (macOS,
 * in this repo's CI/dev environment) — there is no Android-ABI `.so` for the
 * host to load, so [MkNative]'s `System.loadLibrary("mknative")` throws
 * `UnsatisfiedLinkError` here by construction, not by a bug in this test or
 * the facade. This is caught and turned into `Assume.assumeNoException`
 * (JUnit's documented mechanism for "this environment cannot exercise this
 * check" — reported as **skipped**, never as a false pass or a false fail).
 *
 * The real, actually-executed proof that this facade loads a font, shapes
 * Arabic text and returns the exact glyph ids Core Text produced — run via
 * `adb shell` against a booted arm64-v8a emulator/device (and, ABI
 * permitting, x86_64) — is `android/mk-native/tools/smoke_cli/mk_smoke_cli.cpp`,
 * a standalone native harness duplicating this same test-case table so the
 * two can be diffed by eye. See `android/docs/impl-log/BATCH-1.2.md` for
 * the actual pass/fail transcript per ABI. Once a later batch wires an
 * instrumented-test (`androidTest`) environment for this module (this
 * agent may not edit `build.gradle.kts` to add one — `CONTRACT_CHANGES.md`),
 * this same case table should be promoted there so it runs for real on
 * every CI-exercised device instead of self-skipping.
 */
class MkNativeShapingSmokeTest {

    private fun tryLoadNative(): Boolean {
        return try {
            // Touching MkNative's companion triggers its `init` block
            // (System.loadLibrary). A no-op call is enough to force it.
            MkNative.nativeBlobDestroy(0L)
            true
        } catch (e: UnsatisfiedLinkError) {
            false
        } catch (e: ExceptionInInitializerError) {
            false
        } catch (e: NoClassDefFoundError) {
            false
        }
    }

    /** Repo-relative font lookup that tolerates AGP's per-module test working directory. */
    private fun findFont(relativeFromRepoRoot: String): File? {
        var dir = File(System.getProperty("user.dir") ?: ".").absoluteFile
        repeat(6) {
            val candidate = File(dir, relativeFromRepoRoot)
            if (candidate.exists()) return candidate
            dir = dir.parentFile ?: return null
        }
        return null
    }

    // Verbatim from android/fixtures/shaping/{cairo,almarai}/F-1.json
    // ("Mandatory lam-alif ligature, isolated" — U+0644 U+0627).
    @Test
    fun `cairo lam-alif ligature matches Core Text golden glyph id`() {
        Assume.assumeTrue(
            "libmknative.so is an Android-ABI binary; not loadable on the host JVM " +
                "unit-test runner (see class KDoc) — verified instead via mk_smoke_cli on-device",
            tryLoadNative(),
        )
        val fontFile = findFont(
            "MakhtootKit/Sources/MKFonts/Resources/Fonts/Cairo/Cairo[slnt,wght].ttf",
        )
        Assume.assumeTrue("Cairo font file not found relative to test working dir", fontFile != null)

        MkFontBlob.fromBytes(fontFile!!.readBytes()).use { blob ->
            val shaped = MkShaper(blob).shape(
                text = "لا",
                script = "Arab",
                language = "ar",
                direction = MkShapeDirection.RTL,
                fontSizePx = 36f,
            )
            assertArrayEquals(intArrayOf(460), shaped.glyphIds)
            assertEquals(21.708, shaped.xAdvances[0].toDouble(), 0.56)
        }
    }

    // Verbatim from android/fixtures/shaping/almarai/F-1.json — a static
    // (non-variable) font, included alongside the Cairo case above because
    // Batch 1.2's own on-device run found the two variable-font cases
    // (cairo, vazirmatn) diverge on advance width while every static-font
    // case matches exactly — see BATCH-1.2.md's shaping observation.
    @Test
    fun `almarai lam-alif ligature matches Core Text golden glyph id`() {
        Assume.assumeTrue(
            "libmknative.so is an Android-ABI binary; not loadable on the host JVM " +
                "unit-test runner (see class KDoc) — verified instead via mk_smoke_cli on-device",
            tryLoadNative(),
        )
        val fontFile = findFont(
            "MakhtootKit/Sources/MKFonts/Resources/Fonts/Almarai/Almarai-Regular.ttf",
        )
        Assume.assumeTrue("Almarai font file not found relative to test working dir", fontFile != null)

        MkFontBlob.fromBytes(fontFile!!.readBytes()).use { blob ->
            val shaped = MkShaper(blob).shape(
                text = "لا",
                script = "Arab",
                language = "ar",
                direction = MkShapeDirection.RTL,
                fontSizePx = 36f,
            )
            assertArrayEquals(intArrayOf(577), shaped.glyphIds)
            assertEquals(23.976, shaped.xAdvances[0].toDouble(), 0.56)
        }
    }
}
