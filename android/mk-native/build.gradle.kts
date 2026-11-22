// android/mk-native/build.gradle.kts
//
// Work item 1.1 — Gradle *configuration* only (ANDROID_SPINE.md §2
// D-303/D-304/D-315, §3.2). No module dependency edges — every text/glyph
// module depends on `:mk-native` (mk-color, mk-fonts, mk-textengine,
// mk-render, mk-export per spine §3.2), never the reverse.
//
// `CMakeLists.txt`, `third_party/**` and every `src/**` file are Agent
// 1.2's exclusive ownership (ANDROID_TASK_PACKETS/BATCH-1.md). This file
// only wires the NDK/CMake toolchain pointer via the `mk.android.native`
// convention plugin (android/build-logic/convention). Until Agent 1.2's
// CMakeLists.txt lands, `externalNativeBuild` tasks for this module cannot
// succeed — expected and documented in android/docs/impl-log/BATCH-1.1.md,
// not a defect in this file.

plugins {
    id("mk.android.native")
}

android {
    namespace = "net.binjamshid.makhtoot.mk.nativebridge"
}

dependencies {
    // No project(...) dependencies (spine §3.2) — mk-native is the leaf of
    // the graph every shaping/outline/colour module depends on.
}
