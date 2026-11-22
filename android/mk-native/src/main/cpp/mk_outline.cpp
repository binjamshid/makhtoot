// mk_outline.cpp — FreeType glyph outline extraction (D-303's "FreeType for
// outlines" half), the Android replacement for
// `CTFontCreatePathForGlyph`/`GlyphPathProvider.swift`. FT_Outline_Decompose
// flattens quadratic/cubic contours into the verb/point stream Kotlin
// reassembles into a path — no shaping policy here either, this is pure
// outline geometry extraction for a glyph id HarfBuzz already produced.
#include "mk_native.h"
#include FT_OUTLINE_H

namespace {

FT_Face mkFaceForBlob(MkBlobHandle *handle, int faceIndex) {
    if (handle->ftFace != nullptr && handle->cachedFaceIndex == faceIndex) {
        return handle->ftFace;
    }
    if (handle->ftFace != nullptr) {
        FT_Done_Face(handle->ftFace);
        handle->ftFace = nullptr;
    }
    unsigned length = 0;
    const char *data = hb_blob_get_data(handle->hbBlob, &length);
    if (data == nullptr || length == 0) return nullptr;

    FT_Face face = nullptr;
    FT_Error error = FT_New_Memory_Face(handle->ftLibrary,
                                         reinterpret_cast<const FT_Byte *>(data),
                                         static_cast<FT_Long>(length),
                                         faceIndex, &face);
    if (error != 0 || face == nullptr) return nullptr;

    handle->ftFace = face;
    handle->cachedFaceIndex = faceIndex;
    return face;
}

int mkMoveTo(const FT_Vector *to, void *user) {
    auto *path = static_cast<MkOutlinePath *>(user);
    path->verbs.push_back(0);
    path->points.push_back(static_cast<float>(to->x) / 64.0f);
    path->points.push_back(static_cast<float>(to->y) / 64.0f);
    return 0;
}

int mkLineTo(const FT_Vector *to, void *user) {
    auto *path = static_cast<MkOutlinePath *>(user);
    path->verbs.push_back(1);
    path->points.push_back(static_cast<float>(to->x) / 64.0f);
    path->points.push_back(static_cast<float>(to->y) / 64.0f);
    return 0;
}

int mkConicTo(const FT_Vector *control, const FT_Vector *to, void *user) {
    auto *path = static_cast<MkOutlinePath *>(user);
    path->verbs.push_back(2);
    path->points.push_back(static_cast<float>(control->x) / 64.0f);
    path->points.push_back(static_cast<float>(control->y) / 64.0f);
    path->points.push_back(static_cast<float>(to->x) / 64.0f);
    path->points.push_back(static_cast<float>(to->y) / 64.0f);
    return 0;
}

int mkCubicTo(const FT_Vector *c1, const FT_Vector *c2, const FT_Vector *to, void *user) {
    auto *path = static_cast<MkOutlinePath *>(user);
    path->verbs.push_back(3);
    path->points.push_back(static_cast<float>(c1->x) / 64.0f);
    path->points.push_back(static_cast<float>(c1->y) / 64.0f);
    path->points.push_back(static_cast<float>(c2->x) / 64.0f);
    path->points.push_back(static_cast<float>(c2->y) / 64.0f);
    path->points.push_back(static_cast<float>(to->x) / 64.0f);
    path->points.push_back(static_cast<float>(to->y) / 64.0f);
    return 0;
}

} // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeGlyphOutline(
        JNIEnv *, jclass, jlong blobHandlePtr, jint faceIndex, jint glyphId, jfloat fontSizePx) {
    if (blobHandlePtr == 0) return 0;
    auto *blobHandle = reinterpret_cast<MkBlobHandle *>(blobHandlePtr);
    FT_Face face = mkFaceForBlob(blobHandle, faceIndex);
    if (face == nullptr) return 0;

    FT_UInt pixelSize = static_cast<FT_UInt>(fontSizePx + 0.5f);
    if (pixelSize == 0) pixelSize = 1;
    if (FT_Set_Pixel_Sizes(face, 0, pixelSize) != 0) return 0;

    if (FT_Load_Glyph(face, static_cast<FT_UInt>(glyphId),
                       FT_LOAD_NO_BITMAP | FT_LOAD_NO_HINTING) != 0) {
        return 0;
    }
    if (face->glyph->format != FT_GLYPH_FORMAT_OUTLINE) {
        // Bitmap-only glyph (e.g. an emoji-style COLR/CBDT font not in the
        // v1 bundled catalog) — no vector outline to report. Not a Class-B
        // shaping delta (D-325 §12): this is an outline-extraction result,
        // not a shape() result, so it stays out of the shaping-delta
        // register entirely.
        return 0;
    }

    auto *path = new MkOutlinePath();
    path->advance = static_cast<float>(face->glyph->advance.x) / 64.0f;

    FT_Outline_Funcs funcs{};
    funcs.move_to = mkMoveTo;
    funcs.line_to = mkLineTo;
    funcs.conic_to = mkConicTo;
    funcs.cubic_to = mkCubicTo;
    funcs.shift = 0;
    funcs.delta = 0;

    FT_Outline_Decompose(&face->glyph->outline, &funcs, path);
    if (!path->verbs.empty()) {
        path->verbs.push_back(4); // close
    }

    return reinterpret_cast<jlong>(path);
}

JNIEXPORT jintArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeOutlineVerbs(
        JNIEnv *env, jclass, jlong pathPtr) {
    if (pathPtr == 0) return nullptr;
    auto *path = reinterpret_cast<MkOutlinePath *>(pathPtr);
    jintArray out = env->NewIntArray(static_cast<jsize>(path->verbs.size()));
    if (out != nullptr && !path->verbs.empty()) {
        env->SetIntArrayRegion(out, 0, static_cast<jsize>(path->verbs.size()),
                                path->verbs.data());
    }
    return out;
}

JNIEXPORT jfloatArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeOutlinePoints(
        JNIEnv *env, jclass, jlong pathPtr) {
    if (pathPtr == 0) return nullptr;
    auto *path = reinterpret_cast<MkOutlinePath *>(pathPtr);
    jfloatArray out = env->NewFloatArray(static_cast<jsize>(path->points.size()));
    if (out != nullptr && !path->points.empty()) {
        env->SetFloatArrayRegion(out, 0, static_cast<jsize>(path->points.size()),
                                  path->points.data());
    }
    return out;
}

JNIEXPORT jfloat JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeOutlineAdvance(
        JNIEnv *, jclass, jlong pathPtr) {
    if (pathPtr == 0) return 0.0f;
    return reinterpret_cast<MkOutlinePath *>(pathPtr)->advance;
}

JNIEXPORT void JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeOutlineDestroy(
        JNIEnv *, jclass, jlong pathPtr) {
    if (pathPtr == 0) return;
    delete reinterpret_cast<MkOutlinePath *>(pathPtr);
}

} // extern "C"
