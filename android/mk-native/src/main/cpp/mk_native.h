// mk_native.h — work item 1.2 (D-303/D-304/D-315/D-316)
//
// Shared internal types for the single JNI facade `libmknative.so`. This
// header is private to the native side; the Kotlin surface only sees the
// `external fun` declarations in
// mk-native/src/main/kotlin/net/binjamshid/makhtoot/mk/nativebridge/MkNative.kt.
//
// Every long-lived native object (font blob, shape result, outline path) is
// handed to Kotlin as an opaque `Long` handle allocated with `new` and freed
// exactly once by an explicit `*Destroy` call from the Kotlin `Closeable`
// wrapper layer (MkNativeHandles.kt). No handle is ever implicitly
// collected — see that file's KDoc for the ownership contract per handle
// type.
//
// D-303: HarfBuzz `hb_shape` (GSUB/GPOS) + FreeType (outlines) + ICU BiDi
// (platform, JVM side only — never linked into this native facade). No
// shaping *policy* lives here (D-303 "never write a shaper") — this file
// and its .cpp units are a thin bridge: buffer setup, the one `hb_shape`
// call, and verbatim result extraction, mirroring
// MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift's capture core.
#pragma once

#include <jni.h>
#include <hb.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <vector>
#include <cstdint>

// ---------------------------------------------------------------------------
// Blob handle: an hb_blob_t wrapping either asset-manager-mapped memory
// (D-316: AAssetManager_open + fd, no extraction to disk) or a JVM byte[]
// copy (used for SAF-imported fonts and for host-side/test loading where no
// AssetManager is available). One FT_Face is created per face index on
// demand and cached, since FreeType/HarfBuzz face objects are cheap to
// re-derive from the blob but shaping/outline calls need one repeatedly.
struct MkBlobHandle {
    hb_blob_t *hbBlob = nullptr;      // owns the bytes (immutable, ref-counted)
    FT_Library ftLibrary = nullptr;   // one per blob, simplest correct lifetime
    FT_Face ftFace = nullptr;         // lazily created, face index 0 only (v1 scope)
    int cachedFaceIndex = -1;
};

// ---------------------------------------------------------------------------
// Shape result handle: verbatim hb_shape() output, extracted eagerly into
// plain vectors so the hb_buffer_t itself can be destroyed immediately
// after nativeShape() returns (HarfBuzz buffers are not meant to be held
// across the JNI boundary).
struct MkShapeResult {
    std::vector<uint32_t> glyphIds;
    std::vector<uint32_t> clusters;
    std::vector<float> advances;   // interleaved x,y — length 2*glyphCount
    std::vector<float> offsets;    // interleaved x,y — length 2*glyphCount
    bool rtl = false;
};

// ---------------------------------------------------------------------------
// Outline path handle: FT_Outline decomposed into a flat verb/point stream.
// Verb encoding (matches mk-native/.../MkGlyphOutline.kt):
//   0 = moveTo(x,y)         1 point
//   1 = lineTo(x,y)         1 point
//   2 = quadTo(cx,cy,x,y)   2 points
//   3 = cubicTo(c1,c2,x,y)  3 points
//   4 = close               0 points
struct MkOutlinePath {
    std::vector<int32_t> verbs;
    std::vector<float> points; // flattened x,y pairs, in verb order
    float advance = 0.0f;
};

// ---------------------------------------------------------------------------
// Small helpers shared across translation units (mk_jni_util.cpp).
jbyteArray mkBytesToJavaArray(JNIEnv *env, const uint8_t *data, size_t len);
std::vector<uint8_t> mkJavaArrayToBytes(JNIEnv *env, jbyteArray array);
