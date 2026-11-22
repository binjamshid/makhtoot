// mk_blob.cpp — font blob lifetime (create/destroy) + the D-316
// AssetManager-fd -> hb_blob_t path ("no extraction to disk, no OS-level
// font registration needed"). work item 1.2.
//
// Two loading paths:
//   nativeBlobCreate(bytes)              — JVM byte[] (SAF-imported fonts,
//                                           host-side/unit-test loading with
//                                           no AssetManager available).
//   nativeBlobCreateFromAsset(mgr, path) — bundled fonts under
//                                           assets/fonts/** (D-316). Tries a
//                                           true fd+mmap zero-copy path via
//                                           AAsset_openFileDescriptor64 first
//                                           (works when the asset is stored
//                                           uncompressed in the APK, which is
//                                           Agent 1.1's aaptOptions.noCompress
//                                           concern for *.ttf); falls back to
//                                           AAsset_getBuffer (still no disk
//                                           write, just not fd-shareable) if
//                                           the asset was compressed.
#include "mk_native.h"
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cstdlib>

namespace {

struct MmapRegion {
    void *addr;
    size_t length;
};

void mkDestroyMmapBlob(void *userData) {
    auto *region = static_cast<MmapRegion *>(userData);
    if (region != nullptr) {
        if (region->addr != nullptr && region->addr != MAP_FAILED) {
            munmap(region->addr, region->length);
        }
        delete region;
    }
}

void mkDestroyAssetBlob(void *userData) {
    auto *asset = static_cast<AAsset *>(userData);
    if (asset != nullptr) {
        AAsset_close(asset);
    }
}

// Frees the copy made by nativeBlobCreate (see below) once HarfBuzz is done
// with the blob.
void mkDestroyOwnedCopy(void *userData) {
    free(userData);
}

} // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeBlobCreate(
        JNIEnv *env, jclass, jbyteArray bytes) {
    if (bytes == nullptr) return 0;
    jsize len = env->GetArrayLength(bytes);
    if (len <= 0) return 0;

    // hb_blob_create needs bytes that outlive the hb_blob_t; take an owned
    // copy since the JVM byte[] is not guaranteed to stay pinned/alive.
    auto *copy = static_cast<uint8_t *>(malloc(static_cast<size_t>(len)));
    if (copy == nullptr) return 0;
    env->GetByteArrayRegion(bytes, 0, len, reinterpret_cast<jbyte *>(copy));

    auto *handle = new MkBlobHandle();
    handle->hbBlob = hb_blob_create(reinterpret_cast<const char *>(copy),
                                     static_cast<unsigned>(len),
                                     HB_MEMORY_MODE_READONLY, copy, mkDestroyOwnedCopy);
    if (handle->hbBlob == nullptr) {
        free(copy);
        delete handle;
        return 0;
    }
    if (FT_Init_FreeType(&handle->ftLibrary) != 0) {
        hb_blob_destroy(handle->hbBlob);
        delete handle;
        return 0;
    }
    return reinterpret_cast<jlong>(handle);
}

JNIEXPORT jlong JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeBlobCreateFromAsset(
        JNIEnv *env, jclass, jobject assetManager, jstring path) {
    AAssetManager *mgr = AAssetManager_fromJava(env, assetManager);
    if (mgr == nullptr) return 0;

    const char *pathChars = env->GetStringUTFChars(path, nullptr);
    AAsset *asset = AAssetManager_open(mgr, pathChars, AASSET_MODE_UNKNOWN);
    env->ReleaseStringUTFChars(path, pathChars);
    if (asset == nullptr) return 0;

    hb_blob_t *hbBlob = nullptr;

    off64_t start = 0, length = 0;
    int fd = AAsset_openFileDescriptor64(asset, &start, &length);
    if (fd >= 0 && length > 0) {
        void *mapped = mmap(nullptr, static_cast<size_t>(length), PROT_READ, MAP_PRIVATE, fd,
                             start);
        close(fd);
        if (mapped != MAP_FAILED) {
            auto *region = new MmapRegion{mapped, static_cast<size_t>(length)};
            hbBlob = hb_blob_create(static_cast<const char *>(mapped),
                                     static_cast<unsigned>(length), HB_MEMORY_MODE_READONLY,
                                     region, mkDestroyMmapBlob);
        }
        AAsset_close(asset);
    } else {
        // Asset is compressed in the APK (fd sharing impossible for a
        // compressed entry) — fall back to the buffer path. Still zero disk
        // writes; just not fd-shareable. AAsset stays alive as the blob's
        // user_data and is closed when the blob is destroyed.
        const void *buf = AAsset_getBuffer(asset);
        off64_t len2 = AAsset_getLength64(asset);
        if (buf != nullptr && len2 > 0) {
            hbBlob = hb_blob_create(static_cast<const char *>(buf), static_cast<unsigned>(len2),
                                     HB_MEMORY_MODE_READONLY, asset, mkDestroyAssetBlob);
        } else {
            AAsset_close(asset);
        }
    }

    if (hbBlob == nullptr) return 0;

    auto *handle = new MkBlobHandle();
    handle->hbBlob = hbBlob;
    if (FT_Init_FreeType(&handle->ftLibrary) != 0) {
        hb_blob_destroy(handle->hbBlob);
        delete handle;
        return 0;
    }
    return reinterpret_cast<jlong>(handle);
}

JNIEXPORT void JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeBlobDestroy(
        JNIEnv *, jclass, jlong handlePtr) {
    if (handlePtr == 0) return;
    auto *handle = reinterpret_cast<MkBlobHandle *>(handlePtr);
    if (handle->ftFace != nullptr) FT_Done_Face(handle->ftFace);
    if (handle->ftLibrary != nullptr) FT_Done_FreeType(handle->ftLibrary);
    if (handle->hbBlob != nullptr) hb_blob_destroy(handle->hbBlob);
    delete handle;
}

JNIEXPORT jint JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeBlobFaceCount(
        JNIEnv *, jclass, jlong handlePtr) {
    if (handlePtr == 0) return 0;
    auto *handle = reinterpret_cast<MkBlobHandle *>(handlePtr);
    hb_face_t *face = hb_face_create(handle->hbBlob, 0);
    unsigned count = hb_face_count(handle->hbBlob);
    hb_face_destroy(face);
    return static_cast<jint>(count);
}

JNIEXPORT jbyteArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeGetTable(
        JNIEnv *env, jclass, jlong handlePtr, jint faceIndex, jstring tag) {
    if (handlePtr == 0) return nullptr;
    auto *handle = reinterpret_cast<MkBlobHandle *>(handlePtr);
    hb_face_t *face = hb_face_create(handle->hbBlob, static_cast<unsigned>(faceIndex));
    const char *tagChars = env->GetStringUTFChars(tag, nullptr);
    hb_tag_t hbTag = hb_tag_from_string(tagChars, -1);
    env->ReleaseStringUTFChars(tag, tagChars);

    hb_blob_t *tableBlob = hb_face_reference_table(face, hbTag);
    unsigned length = 0;
    const char *data = hb_blob_get_data(tableBlob, &length);
    jbyteArray result = nullptr;
    if (data != nullptr && length > 0) {
        result = mkBytesToJavaArray(env, reinterpret_cast<const uint8_t *>(data), length);
    }
    hb_blob_destroy(tableBlob);
    hb_face_destroy(face);
    return result;
}

} // extern "C"
