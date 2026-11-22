package net.binjamshid.makhtoot.mk.fonts

// Ports MKFontsCTFontSendable.swift, whose entire content is
// `extension CTFont: @retroactive @unchecked Sendable {}` — a retroactive
// Sendable conformance that lets Swift 6's strict-concurrency checker
// treat the CoreText opaque type `CTFont` as safe to pass across actor
// isolation boundaries. Kotlin coroutines have no equivalent
// compile-time "is this type safe to share across threads" checker for
// arbitrary classes, so there is no annotation, supertype, or symbol to
// port here — this file is intentionally content-free (mirrors the
// naming rule's file-with-nothing-to-port precedent, documented rather
// than silently omitted, `ANDROID_SPINE.md` §3.3).
