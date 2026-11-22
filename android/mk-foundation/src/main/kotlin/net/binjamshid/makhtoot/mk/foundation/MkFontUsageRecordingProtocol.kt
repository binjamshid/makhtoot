package net.binjamshid.makhtoot.mk.foundation

/**
 * Interface seam allowing `MkAnalytics` to receive font-usage events from the
 * app shell/editor without creating an upward `mk-foundation` <- `mk-analytics`
 * dependency. Ports `Sources/MKFoundation/MKFontUsageRecordingProtocol.swift`.
 *
 * `fontID` is `String` (matching `MKFonts.MKFontID`, itself a plain
 * `typealias` to `String` on the Swift side) to avoid an
 * `mk-foundation` <- `mk-fonts` import cycle.
 */
interface MkFontUsageRecording {
    /**
     * Record that the given font was applied to a text object. No-ops if the
     * user has not granted analytics consent. Debounces identical consecutive
     * calls within 5s.
     */
    suspend fun recordFontUsed(fontID: String)
}

/**
 * No-op stub for use before analytics consent is granted, in previews, or in
 * tests that do not require analytics behavior. `mk-analytics` ships the real
 * conformer.
 */
class MkNoOpFontUsageRecorder : MkFontUsageRecording {
    override suspend fun recordFontUsed(fontID: String) {
        // Intentional no-op — matches the Swift original's empty body exactly
        // (this is real, working behavior, not a stub: "no-op" is the spec).
    }
}
