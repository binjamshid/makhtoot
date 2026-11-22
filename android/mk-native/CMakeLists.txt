# android/mk-native/CMakeLists.txt — Batch 1 · Agent 1.2 (D-303/D-304/D-315/D-316)
#
# Builds the vendored HarfBuzz(+hb-subset)/FreeType/lcms2 third-party trees
# and links them into one shared object, libmknative.so — "one JNI facade"
# per the packet. Never write a shaper (D-303): this file and
# src/main/cpp/**  only wire up the libraries and the thin JNI bridge; all
# shaping/joining/ligature/mark POLICY lives in Kotlin (Batch 3+).
#
# Ownership: this file, third_party/**, src/main/cpp/** and src/main/kotlin/**
# under mk-native are Agent 1.2's exclusively (ANDROID_TASK_PACKETS/BATCH-1.md
# Batch 1 · Agent 1.2). android/mk-native/build.gradle.kts is Agent 1.1's —
# never edited here; any Gradle wiring this file needs is recorded in
# android/docs/impl-log/BATCH-1.2.md and android/docs/CONTRACT_CHANGES.md
# (ground rule 5, ANDROID_SPINE.md §4/§11).
#
# --- Vendored library pins (D-304 third-party carve-out). Licence
# characterization for all three libraries is VERIFY-AT-SUBMISSION
# (ANDROID_SPINE.md §9) until an actual App/Play submission review — do not
# read the labels below as a settled legal conclusion. ---
#   harfbuzz  tag 14.2.1     commit 56feae4035bdd48f62ba2b8d8c16232d4d89b3a4  vendored 2026-07-31  licence label: "Old MIT" (VERIFY-AT-SUBMISSION)
#   freetype  tag VER-2-14-3 commit 0a0221a1347e2f1e07c395263540026e9a0aa7c7  vendored 2026-07-31  licence label: FTL, elected over the GPLv2 dual-licence option (VERIFY-AT-SUBMISSION)
#   lcms2     tag lcms2.19.1 commit 21c582a594fe5279f90c0b93437c398f93bf62b0  vendored 2026-07-31  licence label: MIT — core src/ only; plugins/fast_float and
#             plugins/threaded are GPL-3.0 and MUST stay excluded from every build (LCMS2_WITH_FASTFLOAT / LCMS2_WITH_THREADED_PLUGIN forced OFF below) (VERIFY-AT-SUBMISSION)
#
# NDK note: this machine has NDK 28.2.13676358 installed; D-300 specifies
# r27. Built and verified against r28 instead (recorded as a deviation in
# BATCH-1.2.md, not silently assumed r27-compatible) — nothing in this file
# depends on an r27-vs-r28 ABI difference; nothing here needed a 32-bit-ABI
# behavior that r28 dropped.

cmake_minimum_required(VERSION 3.22.1)
project(mknative LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---------------------------------------------------------------------------
# FreeType — self-contained build. Every optional external dependency is
# disabled so cross-compiling for four Android ABIs never depends on
# find_package() resolving a system zlib/png/bzip2/brotli that may or may not
# exist in the NDK sysroot; freetype's bundled minimal zlib is used instead.
# FT_DISABLE_HARFBUZZ=ON because this facade never links FreeType against
# HarfBuzz (or vice versa, HB_HAVE_FREETYPE below) — HarfBuzz shapes via
# hb-ot-font directly from the font blob (D-303); FreeType only extracts
# outlines. Keeping the two libraries independent avoids a circular
# HarfBuzz<->FreeType build dependency entirely.
set(FT_DISABLE_ZLIB ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
set(FT_ENABLE_ERROR_STRINGS OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/freetype freetype-build EXCLUDE_FROM_ALL)

# ---------------------------------------------------------------------------
# HarfBuzz + hb-subset. HB_HAVE_FREETYPE stays OFF (see above). Every other
# optional backend (cairo/glib/graphite2/ICU/introspection) is OFF: ICU BiDi
# (D-303) is consumed via android.icu on the JVM side, never linked into this
# native facade.
set(HB_HAVE_FREETYPE OFF CACHE BOOL "" FORCE)
set(HB_HAVE_CAIRO OFF CACHE BOOL "" FORCE)
set(HB_HAVE_GRAPHITE2 OFF CACHE BOOL "" FORCE)
set(HB_HAVE_GLIB OFF CACHE BOOL "" FORCE)
set(HB_HAVE_ICU OFF CACHE BOOL "" FORCE)
set(HB_HAVE_GOBJECT OFF CACHE BOOL "" FORCE)
set(HB_HAVE_INTROSPECTION OFF CACHE BOOL "" FORCE)
set(HB_BUILD_UTILS OFF CACHE BOOL "" FORCE)
set(HB_BUILD_SUBSET ON CACHE BOOL "" FORCE)
set(HB_BUILD_RASTER OFF CACHE BOOL "" FORCE)
set(HB_BUILD_VECTOR OFF CACHE BOOL "" FORCE)
set(HB_BUILD_GPU OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/harfbuzz harfbuzz-build EXCLUDE_FROM_ALL)

# ---------------------------------------------------------------------------
# lcms2 — static, MIT-core only. The two GPL-3.0 plugins (fast_float,
# threaded) are force-OFF so no GPL-3.0 code ever enters the vendored tree's
# build output; only lcms2/src/** (MIT, per lcms2/LICENSE) is compiled.
set(LCMS2_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(LCMS2_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(LCMS2_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LCMS2_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LCMS2_WITH_FASTFLOAT OFF CACHE BOOL "" FORCE)
set(LCMS2_WITH_THREADED_PLUGIN OFF CACHE BOOL "" FORCE)
set(LCMS2_WITH_JPEG OFF CACHE BOOL "" FORCE)
set(LCMS2_WITH_TIFF OFF CACHE BOOL "" FORCE)
set(LCMS2_WITH_ZLIB OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/lcms2 lcms2-build EXCLUDE_FROM_ALL)

# ---------------------------------------------------------------------------
# mk_native — the single JNI facade (D-303/D-304/D-315/D-316). Thin bridge
# only: shaping buffer setup + one hb_shape() call (mk_shaping.cpp), outline
# decomposition (mk_outline.cpp), subsetting (mk_subset.cpp), ICC transform
# (mk_color.cpp), blob/font-table lifetime + the AssetManager-fd path
# (mk_blob.cpp).
add_library(mknative SHARED
    src/main/cpp/mk_jni_util.cpp
    src/main/cpp/mk_blob.cpp
    src/main/cpp/mk_shaping.cpp
    src/main/cpp/mk_outline.cpp
    src/main/cpp/mk_subset.cpp
    src/main/cpp/mk_color.cpp
)

target_include_directories(mknative PRIVATE
    src/main/cpp
    third_party/lcms2/include
)

target_link_libraries(mknative PRIVATE
    harfbuzz
    harfbuzz-subset
    freetype
    lcms2
    log
    android
)

# Android.mk-style stripped release size hygiene; harmless for the Debug
# config this batch's smoke test builds against.
set_target_properties(mknative PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)
