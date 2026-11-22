// mk_color.cpp — lcms2 ICC transform facade (D-315). Replaces
// `CGColorSpace(iccData:)`. The JNI facade exposes the transform
// primitive only, given two ICC profile byte blobs and an intent; the
// actual synthetic-generic-CMYK profile bytes (FDA-03) are a later Batch
// 2.3/5.7b concern per ANDROID_SPINE.md's platform-substitution table — this
// facade does not bake in any particular CMYK profile. `nativeCreateSrgbProfile`
// is provided so the working-space profile (extended sRGB, D-315) never has
// to be bundled as an asset: lcms2 can synthesize it in-process.
#include "mk_native.h"
#include <lcms2.h>
#include <vector>

extern "C" {

JNIEXPORT jbyteArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeCreateSrgbProfile(
        JNIEnv *env, jclass) {
    cmsHPROFILE profile = cmsCreate_sRGBProfile();
    if (profile == nullptr) return nullptr;

    cmsUInt32Number size = 0;
    cmsSaveProfileToMem(profile, nullptr, &size);
    std::vector<uint8_t> buffer(size);
    jbyteArray result = nullptr;
    if (size > 0 && cmsSaveProfileToMem(profile, buffer.data(), &size)) {
        result = mkBytesToJavaArray(env, buffer.data(), size);
    }
    cmsCloseProfile(profile);
    return result;
}

JNIEXPORT jfloatArray JNICALL
Java_net_binjamshid_makhtoot_mk_nativebridge_MkNative_nativeIccTransform(
        JNIEnv *env, jclass, jbyteArray inputProfileBytes, jbyteArray outputProfileBytes,
        jfloatArray srcValues, jint intent) {
    std::vector<uint8_t> inBytes = mkJavaArrayToBytes(env, inputProfileBytes);
    std::vector<uint8_t> outBytes = mkJavaArrayToBytes(env, outputProfileBytes);
    if (inBytes.empty() || outBytes.empty()) return nullptr;

    cmsHPROFILE inProfile = cmsOpenProfileFromMem(inBytes.data(),
                                                   static_cast<cmsUInt32Number>(inBytes.size()));
    cmsHPROFILE outProfile = cmsOpenProfileFromMem(outBytes.data(),
                                                    static_cast<cmsUInt32Number>(outBytes.size()));
    if (inProfile == nullptr || outProfile == nullptr) {
        if (inProfile != nullptr) cmsCloseProfile(inProfile);
        if (outProfile != nullptr) cmsCloseProfile(outProfile);
        return nullptr;
    }

    auto formatFor = [](cmsHPROFILE p) -> cmsUInt32Number {
        switch (cmsGetColorSpace(p)) {
            case cmsSigRgbData: return TYPE_RGB_FLT;
            case cmsSigCmykData: return TYPE_CMYK_FLT;
            case cmsSigGrayData: return TYPE_GRAY_FLT;
            case cmsSigLabData: return TYPE_Lab_FLT;
            case cmsSigXYZData: return TYPE_XYZ_FLT;
            default: return TYPE_RGB_FLT;
        }
    };
    cmsUInt32Number inFormat = formatFor(inProfile);
    cmsUInt32Number outFormat = formatFor(outProfile);

    // Relative colorimetric (D-315) is the caller's expected default; the
    // intent is still passed through explicitly rather than hard-coded so a
    // later batch can exercise perceptual/saturation intents if ever needed.
    cmsHTRANSFORM transform = cmsCreateTransform(inProfile, inFormat, outProfile, outFormat,
                                                  static_cast<cmsUInt32Number>(intent), 0);
    cmsCloseProfile(inProfile);
    cmsCloseProfile(outProfile);
    if (transform == nullptr) return nullptr;

    jsize srcLen = env->GetArrayLength(srcValues);
    std::vector<float> src(static_cast<size_t>(srcLen));
    if (srcLen > 0) env->GetFloatArrayRegion(srcValues, 0, srcLen, src.data());

    unsigned inChannels = T_CHANNELS(inFormat);
    unsigned outChannels = T_CHANNELS(outFormat);
    unsigned pixelCount = inChannels > 0 ? static_cast<unsigned>(srcLen) / inChannels : 0;
    std::vector<float> dst(static_cast<size_t>(pixelCount) * outChannels);

    if (pixelCount > 0) {
        cmsDoTransform(transform, src.data(), dst.data(), pixelCount);
    }
    cmsDeleteTransform(transform);

    jfloatArray result = env->NewFloatArray(static_cast<jsize>(dst.size()));
    if (result != nullptr && !dst.empty()) {
        env->SetFloatArrayRegion(result, 0, static_cast<jsize>(dst.size()), dst.data());
    }
    return result;
}

} // extern "C"
