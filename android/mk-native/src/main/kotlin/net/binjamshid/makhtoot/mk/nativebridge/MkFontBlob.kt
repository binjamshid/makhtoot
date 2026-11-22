package net.binjamshid.makhtoot.mk.nativebridge

import android.content.res.AssetManager
import java.io.Closeable

/**
 * A loaded font's native lifetime (D-303/D-316) — the Kotlin-side owner of
 * the `hb_blob_t`/`FT_Library`/`FT_Face` handle bundle
 * `mk_native.h`'s `MkBlobHandle` wraps on the C++ side.
 *
 * **Ownership contract.** Exactly one [close] call per instance, always —
 * every [MkShaper], [MkGlyphOutliner], [MkFontSubsetter] call that takes an
 * `MkFontBlob` borrows the handle for the duration of that call only; none
 * of them retain it past return. Use Kotlin's `.use { }` (this class
 * implements [Closeable]) rather than a manual `try`/`finally` wherever
 * possible, exactly as the class's own tests do.
 *
 * Two loading paths (D-316):
 *  - [fromAsset] — bundled fonts under `assets/fonts` (recursively), no
 *    extraction to disk, no OS-level font registration (`CTFontManagerRegisterFontURLs`
 *    has no Android analogue and needs none here).
 *  - [fromBytes] — SAF-imported user fonts already read into memory, and
 *    host-side/unit-test loading where no [AssetManager] exists.
 */
public class MkFontBlob private constructor(@Volatile private var handle: Long) : Closeable {

    private fun liveHandle(): Long {
        val current = handle
        check(current != 0L) { "MkFontBlob used after close()" }
        return current
    }

    /** Number of faces in this font's `sfnt` collection (usually 1; TTC fonts may have more). */
    public fun faceCount(): Int = MkNative.nativeBlobFaceCount(liveHandle())

    /** `hb_face_reference_table` — `null` if [faceIndex] has no such table. */
    public fun getTable(faceIndex: Int, tag: String): ByteArray? =
        MkNative.nativeGetTable(liveHandle(), faceIndex, tag)

    internal fun rawHandle(): Long = liveHandle()

    /** Idempotent — a second [close] call is a documented no-op, per the [Closeable] contract. */
    override fun close() {
        val current = handle
        if (current != 0L) {
            handle = 0L
            MkNative.nativeBlobDestroy(current)
        }
    }

    public companion object {
        public fun fromBytes(bytes: ByteArray): MkFontBlob {
            val handle = MkNative.nativeBlobCreate(bytes)
            check(handle != 0L) { "MkNative.nativeBlobCreate failed — malformed font bytes?" }
            return MkFontBlob(handle)
        }

        /** [path] is relative to `assets/`, e.g. `fonts/Cairo/Cairo[slnt,wght].ttf`. */
        public fun fromAsset(assetManager: AssetManager, path: String): MkFontBlob {
            val handle = MkNative.nativeBlobCreateFromAsset(assetManager, path)
            check(handle != 0L) { "MkNative.nativeBlobCreateFromAsset failed for asset: $path" }
            return MkFontBlob(handle)
        }
    }
}
