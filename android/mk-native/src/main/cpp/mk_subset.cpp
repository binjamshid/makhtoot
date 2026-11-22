// mk_subset.cpp — hb-subset facade (D-303/D-304). Feeds Batch 5.7b's
// in-house PDF writer (D-314): a PDF that embeds live Arabic text needs a
// Type0/CIDFontType2 subset containing only the glyphs actually used, not
// the full bundled font. The JNI facade only exposes the subsetting primitive;
// the CID-mapping/Type0-embedding policy is 5.7b's, not this facade's.
#include "mk_native.h"
#include <hb-subset.h>

extern "C" {

JNIEXPORT jbyteArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeSubset(
        JNIEnv *env, jclass, jlong blobHandlePtr, jint faceIndex, jintArray unicodes) {
    if (blobHandlePtr == 0) return nullptr;
    auto *handle = reinterpret_cast<MkBlobHandle *>(blobHandlePtr);

    hb_face_t *face = hb_face_create(handle->hbBlob, static_cast<unsigned>(faceIndex));
    hb_subset_input_t *input = hb_subset_input_create_or_fail();
    if (input == nullptr) {
        hb_face_destroy(face);
        return nullptr;
    }

    hb_set_t *unicodeSet = hb_subset_input_unicode_set(input);
    jsize count = env->GetArrayLength(unicodes);
    jint *elements = env->GetIntArrayElements(unicodes, nullptr);
    for (jsize i = 0; i < count; i++) {
        hb_set_add(unicodeSet, static_cast<hb_codepoint_t>(elements[i]));
    }
    env->ReleaseIntArrayElements(unicodes, elements, JNI_ABORT);

    hb_face_t *subsetFace = hb_subset_or_fail(face, input);
    hb_subset_input_destroy(input);
    hb_face_destroy(face);
    if (subsetFace == nullptr) return nullptr;

    hb_blob_t *subsetBlob = hb_face_reference_blob(subsetFace);
    unsigned length = 0;
    const char *data = hb_blob_get_data(subsetBlob, &length);
    jbyteArray result = nullptr;
    if (data != nullptr && length > 0) {
        result = mkBytesToJavaArray(env, reinterpret_cast<const uint8_t *>(data), length);
    }
    hb_blob_destroy(subsetBlob);
    hb_face_destroy(subsetFace);
    return result;
}

} // extern "C"
