package net.binjamshid.makhtoot.mk.textengine

// Ports `Sources/MKTextEngine/CursiveAttachment.swift` — WS-16
// (`docs/impl-log/WS-16-cursive.md`, ADR WS16-A2). D-222 step 8 found GPOS
// LookupType 3 (cursive attachment) on base glyphs in 5 held-out fonts
// (Amiri, Amiri Quran, Aref Ruqaa, Rakkas, Qahiri) and asked whether D-105's
// mark-capture model needs a "cursive-pair structure" before those fonts can
// ship. The Swift file's answer is an empirically-minimal one: a per-glyph
// provenance FLAG (`MkShapedRun.cursiveAttached`, `MkShapedModels.kt`), not
// a full anchor-delta structure — the shaped positions already encode the
// answer (D-105), so no geometry needs recomputing. The only real gap this
// flag exists to make identifiable: D-107's ZWJ-synthetic-context reshape
// technique (used by MKArrange's join-break/restore and ligature-decompose
// paths) cannot reproduce a CONTEXTUAL cursive-variant glyph a real
// neighbor letter would have triggered, since ZWJ isn't a real letter.
//
// This file has NO public Swift declarations to port under this batch's
// "only public Swift declarations need porting" rule (stub mechanism
// rule 5; `ANDROID_SPINE.md` §3.3/§4): `MKCursiveCoverageCache`
// (`final class ... : @unchecked Sendable`), `MKGPOSCursiveParser`
// (`enum`), and the big-endian table reader `BEReader` (`private struct`)
// are all internal/private in Swift — none carries the `public` modifier,
// so none produces a Kotlin declaration here.
//
// The real implementation lands in Batch 3.3 per
// `ANDROID_TASK_PACKETS/BATCH-3.md` ("CursiveAttachment.swift → 254 LOC →
// `MkCursiveCoverageCache.kt` + `MkGposCursiveParser.kt`") as
// internal-visibility types backing the one WS-16/D-222 provenance flag
// this file exists to compute, reading `hb_face_reference_table(face,
// HB_TAG('G','P','O','S'))` (via `:mk-native`) in place of
// `CTFontCopyTable`. No `MkNotYetPorted` throw-stubs are needed at this
// path because nothing declared here is called from outside this module.
