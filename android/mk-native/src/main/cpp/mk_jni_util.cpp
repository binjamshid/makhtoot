// mk_jni_util.cpp — small JNI array <-> native buffer helpers shared by the
// other translation units in this facade. work item 1.2.
#include "mk_native.h"
#include <cstring>

jbyteArray mkBytesToJavaArray(JNIEnv *env, const uint8_t *data, size_t len) {
    jbyteArray array = env->NewByteArray(static_cast<jsize>(len));
    if (array == nullptr) return nullptr;
    if (len > 0) {
        env->SetByteArrayRegion(array, 0, static_cast<jsize>(len),
                                 reinterpret_cast<const jbyte *>(data));
    }
    return array;
}

std::vector<uint8_t> mkJavaArrayToBytes(JNIEnv *env, jbyteArray array) {
    if (array == nullptr) return {};
    jsize len = env->GetArrayLength(array);
    std::vector<uint8_t> out(static_cast<size_t>(len));
    if (len > 0) {
        env->GetByteArrayRegion(array, 0, len, reinterpret_cast<jbyte *>(out.data()));
    }
    return out;
}
