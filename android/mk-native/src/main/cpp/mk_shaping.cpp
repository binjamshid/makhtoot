// mk_shaping.cpp — hb_shape() facade (D-303). This is the thin bridge:
// build an hb_buffer_t, run exactly one hb_shape() call, copy the result out
// verbatim. Shaping *policy* (ligature/mark/joining-form classification,
// ZWJ harvesting per D-107) is Kotlin's job in :mk-textengine (Batch 3),
// mirroring MKShapingEngine.swift's own separation between CTLine capture
// (this layer's analogue) and the classification that runs on the captured
// runs.
//
// Font funcs come from hb-ot-font (hb_ot_font_set_funcs), not hb-ft — this
// facade never links HarfBuzz against FreeType (HB_HAVE_FREETYPE=OFF in
// CMakeLists.txt). FreeType is used independently, only for glyph outline
// extraction (mk_outline.cpp). Positions/advances are produced in HarfBuzz's
// native 26.6 fixed-point scale (see scale-setup below) and converted to
// float pixels here so the Kotlin layer never has to know the fixed-point
// convention.
#include "mk_native.h"
#include <hb-ot.h>
#include <vector>
#include <string>

namespace {

// HarfBuzz scales position output by (raw_font_units / upem) * x_scale. We
// set x_scale/y_scale to fontSizePx * 64 (26.6 fixed point, the common
// FreeType/HarfBuzz convention) so integer-precision loss stays well below
// the Class-A shaping-delta tolerance (ANDROID_SPINE.md §12) even for large
// display sizes, then divide back to float pixels below.
constexpr int kFixedPointShift = 6; // 2^6 = 64

hb_direction_t mkDirection(jint direction) {
    // 0 = LTR, 1 = RTL — matches MkShapeDirection.kt's IntDef.
    return direction == 1 ? HB_DIRECTION_RTL : HB_DIRECTION_LTR;
}

} // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShape(
        JNIEnv *env, jclass, jlong blobHandlePtr, jint faceIndex, jstring text, jstring script,
        jstring language, jint direction, jstring features, jfloat fontSizePx) {
    if (blobHandlePtr == 0) return 0;
    auto *blobHandle = reinterpret_cast<MkBlobHandle *>(blobHandlePtr);

    hb_face_t *face = hb_face_create(blobHandle->hbBlob, static_cast<unsigned>(faceIndex));
    hb_font_t *font = hb_font_create(face);
    hb_ot_font_set_funcs(font);
    unsigned upem = hb_face_get_upem(face);
    int scale = static_cast<int>(fontSizePx * (1 << kFixedPointShift));
    hb_font_set_scale(font, scale, scale);
    (void) upem; // hb_font_set_scale already accounts for upem internally

    hb_buffer_t *buffer = hb_buffer_create();

    jsize textLen = env->GetStringLength(text);
    const jchar *textChars = env->GetStringChars(text, nullptr);
    hb_buffer_add_utf16(buffer, reinterpret_cast<const uint16_t *>(textChars),
                         textLen, 0, textLen);
    env->ReleaseStringChars(text, textChars);

    hb_buffer_set_cluster_level(buffer, HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
    hb_buffer_set_direction(buffer, mkDirection(direction));

    const char *scriptChars = env->GetStringUTFChars(script, nullptr);
    if (scriptChars[0] != '\0') {
        hb_buffer_set_script(buffer, hb_script_from_string(scriptChars, -1));
    }
    env->ReleaseStringUTFChars(script, scriptChars);

    const char *languageChars = env->GetStringUTFChars(language, nullptr);
    if (languageChars[0] != '\0') {
        hb_buffer_set_language(buffer, hb_language_from_string(languageChars, -1));
    }
    env->ReleaseStringUTFChars(language, languageChars);

    hb_buffer_guess_segment_properties(buffer);

    std::vector<hb_feature_t> hbFeatures;
    const char *featureChars = env->GetStringUTFChars(features, nullptr);
    if (featureChars[0] != '\0') {
        // Comma-separated hb_feature_t strings, e.g. "liga=1,calt=0".
        std::string all(featureChars);
        size_t start = 0;
        while (start < all.size()) {
            size_t comma = all.find(',', start);
            std::string token = all.substr(start, comma == std::string::npos
                                                    ? std::string::npos : comma - start);
            hb_feature_t feature;
            if (!token.empty() && hb_feature_from_string(token.c_str(),
                                                           static_cast<int>(token.size()),
                                                           &feature)) {
                hbFeatures.push_back(feature);
            }
            if (comma == std::string::npos) break;
            start = comma + 1;
        }
    }
    env->ReleaseStringUTFChars(features, featureChars);

    hb_shape(font, buffer, hbFeatures.empty() ? nullptr : hbFeatures.data(),
              static_cast<unsigned>(hbFeatures.size()));

    unsigned glyphCount = 0;
    hb_glyph_info_t *infos = hb_buffer_get_glyph_infos(buffer, &glyphCount);
    hb_glyph_position_t *positions = hb_buffer_get_glyph_positions(buffer, &glyphCount);

    auto *result = new MkShapeResult();
    result->rtl = hb_buffer_get_direction(buffer) == HB_DIRECTION_RTL;
    result->glyphIds.reserve(glyphCount);
    result->clusters.reserve(glyphCount);
    result->advances.reserve(glyphCount * 2u);
    result->offsets.reserve(glyphCount * 2u);

    const float toPixels = 1.0f / static_cast<float>(1 << kFixedPointShift);
    for (unsigned i = 0; i < glyphCount; i++) {
        result->glyphIds.push_back(infos[i].codepoint);
        result->clusters.push_back(infos[i].cluster);
        result->advances.push_back(static_cast<float>(positions[i].x_advance) * toPixels);
        result->advances.push_back(static_cast<float>(positions[i].y_advance) * toPixels);
        result->offsets.push_back(static_cast<float>(positions[i].x_offset) * toPixels);
        result->offsets.push_back(static_cast<float>(positions[i].y_offset) * toPixels);
    }

    hb_buffer_destroy(buffer);
    hb_font_destroy(font);
    hb_face_destroy(face);

    return reinterpret_cast<jlong>(result);
}

JNIEXPORT jint JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeGlyphCount(
        JNIEnv *, jclass, jlong resultPtr) {
    if (resultPtr == 0) return 0;
    return static_cast<jint>(reinterpret_cast<MkShapeResult *>(resultPtr)->glyphIds.size());
}

JNIEXPORT jintArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeGlyphIds(
        JNIEnv *env, jclass, jlong resultPtr) {
    if (resultPtr == 0) return nullptr;
    auto *result = reinterpret_cast<MkShapeResult *>(resultPtr);
    jintArray out = env->NewIntArray(static_cast<jsize>(result->glyphIds.size()));
    if (out != nullptr && !result->glyphIds.empty()) {
        env->SetIntArrayRegion(out, 0, static_cast<jsize>(result->glyphIds.size()),
                                reinterpret_cast<const jint *>(result->glyphIds.data()));
    }
    return out;
}

JNIEXPORT jintArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeClusters(
        JNIEnv *env, jclass, jlong resultPtr) {
    if (resultPtr == 0) return nullptr;
    auto *result = reinterpret_cast<MkShapeResult *>(resultPtr);
    jintArray out = env->NewIntArray(static_cast<jsize>(result->clusters.size()));
    if (out != nullptr && !result->clusters.empty()) {
        env->SetIntArrayRegion(out, 0, static_cast<jsize>(result->clusters.size()),
                                reinterpret_cast<const jint *>(result->clusters.data()));
    }
    return out;
}

JNIEXPORT jfloatArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeAdvances(
        JNIEnv *env, jclass, jlong resultPtr) {
    if (resultPtr == 0) return nullptr;
    auto *result = reinterpret_cast<MkShapeResult *>(resultPtr);
    jfloatArray out = env->NewFloatArray(static_cast<jsize>(result->advances.size()));
    if (out != nullptr && !result->advances.empty()) {
        env->SetFloatArrayRegion(out, 0, static_cast<jsize>(result->advances.size()),
                                  result->advances.data());
    }
    return out;
}

JNIEXPORT jfloatArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeOffsets(
        JNIEnv *env, jclass, jlong resultPtr) {
    if (resultPtr == 0) return nullptr;
    auto *result = reinterpret_cast<MkShapeResult *>(resultPtr);
    jfloatArray out = env->NewFloatArray(static_cast<jsize>(result->offsets.size()));
    if (out != nullptr && !result->offsets.empty()) {
        env->SetFloatArrayRegion(out, 0, static_cast<jsize>(result->offsets.size()),
                                  result->offsets.data());
    }
    return out;
}

JNIEXPORT jboolean JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeIsRtl(
        JNIEnv *, jclass, jlong resultPtr) {
    if (resultPtr == 0) return JNI_FALSE;
    return reinterpret_cast<MkShapeResult *>(resultPtr)->rtl ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeShapeDestroy(
        JNIEnv *, jclass, jlong resultPtr) {
    if (resultPtr == 0) return;
    delete reinterpret_cast<MkShapeResult *>(resultPtr);
}

} // extern "C"
