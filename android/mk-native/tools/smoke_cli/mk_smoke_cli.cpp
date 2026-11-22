// mk_smoke_cli.cpp — work item 1.2 out-of-band verification tool.
//
// NOT part of the Gradle-built deliverable (mknative shared lib) and not
// wired into CMakeLists.txt — this is a standalone executable, built and run
// directly against the vendored, cross-compiled harfbuzz/freetype/lcms2
// static libraries under build/<abi>/, so the actual G1 evidence ("loads a
// font, shapes a string, returns plausible glyphs") can be gathered
// on-device/on-emulator per ABI without depending on Agent 1.1's Gradle
// wiring from a concurrent work item or a full instrumented-test
// harness. It duplicates the exact HarfBuzz/FreeType call sequence used by
// src/main/cpp/mk_shaping.cpp and mk_outline.cpp (same hb-ot-font funcs,
// same 26.6 fixed-point scale convention) — see BATCH-1.2.md for why this
// exists alongside the JNI-boundary Kotlin smoke test in
// src/test/kotlin/.../MkNativeShapingSmokeTest.kt, which exercises the JNI
// entry points themselves but needs Gradle + an instrumented-test
// environment to actually run.
//
// Test cases below are transcribed directly from android/fixtures/shaping/
// (the Core Text golden output from work item 0.2) — see the case table.
#include <hb.h>
#include <hb-ot.h>
#include <hb-subset.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H
#include <lcms2.h>

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>
#include <fstream>

namespace {

int gFailures = 0;

std::vector<uint8_t> readFile(const std::string &path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return {};
    return std::vector<uint8_t>((std::istreambuf_iterator<char>(f)),
                                 std::istreambuf_iterator<char>());
}

// Class-A shaping-delta tolerance (ANDROID_SPINE.md §12): position delta
// <= 0.5px at the fixture's rendered scale, or <= 1/64 em, whichever is
// larger. Fixtures below are all fontPointSize 36, so 1/64 em = 0.5625px;
// use the larger of the two, matching the register's own wording.
bool withinTolerance(double a, double b, double emPx) {
    double delta = std::fabs(a - b);
    double tol = std::max(0.5, emPx / 64.0);
    return delta <= tol;
}

struct ShapeExpectation {
    const char *label;
    std::string fontPath;
    std::vector<uint16_t> utf16;
    std::vector<uint32_t> expectGlyphs;
    std::vector<double> expectXAdvance; // one per glyph
    float fontSizePx;
};

// Verbatim from android/fixtures/shaping/{cairo,almarai,scheherazade-new,vazirmatn}/F-1.json
// ("Mandatory lam-alif ligature, isolated" — U+0644 U+0627) and
// android/fixtures/shaping/cairo/F-11.json ("Full-alphabet joining sweep").
std::vector<ShapeExpectation> testCases(const std::string &fontsRoot) {
    std::vector<ShapeExpectation> cases;

    cases.push_back({
        "cairo/F-1 (lam-alif ligature)",
        fontsRoot + "/Cairo/Cairo[slnt,wght].ttf",
        {0x0644, 0x0627},
        {460},
        {21.708},
        36.0f,
    });
    cases.push_back({
        "almarai/F-1 (lam-alif ligature)",
        fontsRoot + "/Almarai/Almarai-Regular.ttf",
        {0x0644, 0x0627},
        {577},
        {23.976},
        36.0f,
    });
    cases.push_back({
        "scheherazade-new/F-1 (lam-alif ligature)",
        fontsRoot + "/ScheherazadeNew/ScheherazadeNew-Regular.ttf",
        {0x0644, 0x0627},
        {930},
        {23.16796875},
        36.0f,
    });
    cases.push_back({
        "vazirmatn/F-1 (lam-alif ligature)",
        fontsRoot + "/Vazirmatn/Vazirmatn[wght].ttf",
        {0x0644, 0x0627},
        {1301},
        {19.40625},
        36.0f,
    });
    // hex codepoints transcribed from F-11.json's cluster list (35 chars,
    // one glyph per input char — a joining sweep has no ligatures).
    cases.push_back({
        "cairo/F-11 (full-alphabet joining sweep)",
        fontsRoot + "/Cairo/Cairo[slnt,wght].ttf",
        {0x0623, 0x0628, 0x062c, 0x062f, 0x0020, 0x0647, 0x0648, 0x0632, 0x0020,
         0x062d, 0x0637, 0x064a, 0x0020, 0x0643, 0x0644, 0x0645, 0x0646, 0x0020,
         0x0633, 0x0639, 0x0641, 0x0635, 0x0020, 0x0642, 0x0631, 0x0634, 0x062a,
         0x0020, 0x062b, 0x062e, 0x0630, 0x0020, 0x0636, 0x0638, 0x063a},
        {}, {}, 36.0f,
    });
    cases.back().expectGlyphs = {
        366, 359, 352, 666, 326, 321, 300, 666, 294, 344, 330, 386, 666, 346, 371,
        363, 340, 666, 410, 407, 403, 392, 666, 444, 355, 318, 666, 331, 438, 420,
        666, 324, 307, 286, 269,
    };
    cases.back().expectXAdvance = {
        21.744, 25.919999999999998, 26.999999999999996, 7.919999999999999,
        18.971999999999998, 20.988, 8.1, 7.919999999999999, 27.755999999999997,
        27.395999999999997, 10.043999999999999, 21.276, 7.919999999999999,
        42.839999999999996, 21.996, 22.067999999999998, 27.395999999999997,
        7.919999999999999, 23.58, 22.895999999999997, 8.459999999999999,
        21.816, 7.919999999999999, 31.067999999999998, 25.919999999999998,
        19.548, 7.919999999999999, 9.324, 19.548, 28.08, 7.919999999999999,
        18.971999999999998, 20.988, 8.1, 8.459999999999999,
    };

    return cases;
}

bool runShapeCase(const ShapeExpectation &tc) {
    printf("-- %s --\n", tc.label);
    std::vector<uint8_t> bytes = readFile(tc.fontPath);
    if (bytes.empty()) {
        printf("   FAIL: could not read font %s\n", tc.fontPath.c_str());
        return false;
    }

    hb_blob_t *blob = hb_blob_create(reinterpret_cast<const char *>(bytes.data()),
                                      static_cast<unsigned>(bytes.size()),
                                      HB_MEMORY_MODE_READONLY, nullptr, nullptr);
    hb_face_t *face = hb_face_create(blob, 0);
    hb_font_t *font = hb_font_create(face);
    hb_ot_font_set_funcs(font);
    int scale = static_cast<int>(tc.fontSizePx * 64.0f);
    hb_font_set_scale(font, scale, scale);

    hb_buffer_t *buffer = hb_buffer_create();
    hb_buffer_add_utf16(buffer, tc.utf16.data(), static_cast<int>(tc.utf16.size()), 0,
                         static_cast<int>(tc.utf16.size()));
    hb_buffer_set_cluster_level(buffer, HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
    hb_buffer_set_direction(buffer, HB_DIRECTION_RTL);
    hb_buffer_set_script(buffer, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buffer, hb_language_from_string("ar", -1));
    hb_buffer_guess_segment_properties(buffer);

    hb_shape(font, buffer, nullptr, 0);

    unsigned glyphCount = 0;
    hb_glyph_info_t *infos = hb_buffer_get_glyph_infos(buffer, &glyphCount);
    hb_glyph_position_t *positions = hb_buffer_get_glyph_positions(buffer, &glyphCount);

    bool ok = true;
    if (glyphCount != tc.expectGlyphs.size()) {
        printf("   FAIL: glyph count %u != expected %zu\n", glyphCount,
               tc.expectGlyphs.size());
        ok = false;
    } else {
        for (unsigned i = 0; i < glyphCount; i++) {
            uint32_t got = infos[i].codepoint;
            uint32_t want = tc.expectGlyphs[i];
            double gotAdvance = static_cast<double>(positions[i].x_advance) / 64.0;
            double wantAdvance = tc.expectXAdvance[i];
            bool glyphOk = got == want;
            bool advanceOk = withinTolerance(gotAdvance, wantAdvance, tc.fontSizePx);
            if (!glyphOk || !advanceOk) {
                printf("   glyph[%u]: got=%u want=%u  advance got=%.4f want=%.4f  %s%s\n", i,
                       got, want, gotAdvance, wantAdvance, glyphOk ? "" : "GLYPH-MISMATCH ",
                       advanceOk ? "" : "ADVANCE-OUT-OF-TOLERANCE");
                ok = false;
            }
        }
    }
    printf("   %s (%u glyphs)\n", ok ? "PASS" : "FAIL", glyphCount);

    // Outline extraction smoke check (D-303 FreeType half): every glyph this
    // case shaped must decompose to at least one contour without crashing.
    FT_Library ftLib = nullptr;
    if (FT_Init_FreeType(&ftLib) == 0) {
        FT_Face ftFace = nullptr;
        if (FT_New_Memory_Face(ftLib, bytes.data(), static_cast<FT_Long>(bytes.size()), 0,
                                &ftFace) == 0) {
            FT_Set_Pixel_Sizes(ftFace, 0, static_cast<FT_UInt>(tc.fontSizePx));
            for (unsigned i = 0; i < glyphCount; i++) {
                if (FT_Load_Glyph(ftFace, infos[i].codepoint,
                                   FT_LOAD_NO_BITMAP | FT_LOAD_NO_HINTING) != 0) {
                    printf("   FAIL: FT_Load_Glyph failed for glyph %u\n", infos[i].codepoint);
                    ok = false;
                    continue;
                }
                if (ftFace->glyph->format == FT_GLYPH_FORMAT_OUTLINE &&
                    ftFace->glyph->outline.n_points == 0 && infos[i].codepoint != 666 /* space */) {
                    printf("   FAIL: empty outline for non-space glyph %u\n", infos[i].codepoint);
                    ok = false;
                }
            }
            FT_Done_Face(ftFace);
        } else {
            printf("   FAIL: FT_New_Memory_Face failed\n");
            ok = false;
        }
        FT_Done_FreeType(ftLib);
    } else {
        printf("   FAIL: FT_Init_FreeType failed\n");
        ok = false;
    }

    hb_buffer_destroy(buffer);
    hb_font_destroy(font);
    hb_face_destroy(face);
    hb_blob_destroy(blob);

    if (!ok) gFailures++;
    return ok;
}

// hb-subset smoke check: subsetting the lam-alif case's font to exactly the
// two codepoints it uses must succeed and produce a strictly smaller,
// non-empty sfnt blob.
bool runSubsetCase(const std::string &fontsRoot) {
    printf("-- hb-subset (cairo, subset to U+0644 U+0627) --\n");
    std::string path = fontsRoot + "/Cairo/Cairo[slnt,wght].ttf";
    std::vector<uint8_t> bytes = readFile(path);
    if (bytes.empty()) {
        printf("   FAIL: could not read %s\n", path.c_str());
        gFailures++;
        return false;
    }
    hb_blob_t *blob = hb_blob_create(reinterpret_cast<const char *>(bytes.data()),
                                      static_cast<unsigned>(bytes.size()),
                                      HB_MEMORY_MODE_READONLY, nullptr, nullptr);
    hb_face_t *face = hb_face_create(blob, 0);
    hb_subset_input_t *input = hb_subset_input_create_or_fail();
    hb_set_t *unicodes = hb_subset_input_unicode_set(input);
    hb_set_add(unicodes, 0x0644);
    hb_set_add(unicodes, 0x0627);
    hb_face_t *subsetFace = hb_subset_or_fail(face, input);

    bool ok = subsetFace != nullptr;
    if (ok) {
        hb_blob_t *subsetBlob = hb_face_reference_blob(subsetFace);
        unsigned length = 0;
        hb_blob_get_data(subsetBlob, &length);
        ok = length > 0 && length < bytes.size();
        printf("   original=%zu bytes, subset=%u bytes  %s\n", bytes.size(), length,
               ok ? "PASS" : "FAIL");
        hb_blob_destroy(subsetBlob);
        hb_face_destroy(subsetFace);
    } else {
        printf("   FAIL: hb_subset_or_fail returned null\n");
    }
    hb_subset_input_destroy(input);
    hb_face_destroy(face);
    hb_blob_destroy(blob);
    if (!ok) gFailures++;
    return ok;
}

// lcms2 smoke check: synthesize an sRGB profile in-process and round-trip a
// colour through an sRGB->sRGB transform (identity up to floating-point/LUT
// quantization noise) — proves the vendored lcms2 executes correctly on
// this ABI. The real synthetic-generic-CMYK profile is a later batch's
// concern (ANDROID_SPINE.md §2 D-315 platform-substitution table: 2.3/5.7b);
// this facade's job is the transform primitive.
bool runColorCase() {
    printf("-- lcms2 (sRGB->sRGB identity transform) --\n");
    cmsHPROFILE srgb = cmsCreate_sRGBProfile();
    if (srgb == nullptr) {
        printf("   FAIL: cmsCreate_sRGBProfile returned null\n");
        gFailures++;
        return false;
    }
    cmsHTRANSFORM transform = cmsCreateTransform(srgb, TYPE_RGB_FLT, srgb, TYPE_RGB_FLT,
                                                  INTENT_RELATIVE_COLORIMETRIC, 0);
    bool ok = transform != nullptr;
    if (ok) {
        float src[3] = {0.5f, 0.25f, 0.75f};
        float dst[3] = {0, 0, 0};
        cmsDoTransform(transform, src, dst, 1);
        for (int i = 0; i < 3; i++) {
            if (std::fabs(src[i] - dst[i]) > 0.01f) ok = false;
        }
        printf("   src=(%.4f,%.4f,%.4f) dst=(%.4f,%.4f,%.4f)  %s\n", src[0], src[1], src[2],
               dst[0], dst[1], dst[2], ok ? "PASS" : "FAIL");
        cmsDeleteTransform(transform);
    } else {
        printf("   FAIL: cmsCreateTransform returned null\n");
    }
    cmsCloseProfile(srgb);
    if (!ok) gFailures++;
    return ok;
}

} // namespace

int main(int argc, char **argv) {
    std::string fontsRoot = argc > 1 ? argv[1] : "/data/local/tmp/mk_fonts";
    printf("mk_smoke_cli: fontsRoot=%s\n", fontsRoot.c_str());

    for (const auto &tc : testCases(fontsRoot)) {
        runShapeCase(tc);
    }
    runSubsetCase(fontsRoot);
    runColorCase();

    printf("==== %s (%d failing case%s) ====\n", gFailures == 0 ? "ALL PASS" : "FAILURES",
           gFailures, gFailures == 1 ? "" : "s");
    return gFailures == 0 ? 0 : 1;
}
