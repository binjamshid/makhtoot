import MKFoundation

/// WS-13 packet §3 stub ، superseded by WS-12's `MKFoundation.MKFontUsageRecording`
/// (the protocol moved from this local stub to `MKFoundation` in WS-12 T16).
/// `MKFoundation.MKNoOpFontUsageRecorder` is the canonical no-op; this file
/// is kept only so the Xcode group and pbxproj reference remain valid.
/// AppContainer now uses `MKNoOpFontUsageRecorder` from MKFoundation.

// NOTE: The local `protocol MKFontUsageRecording` and `struct NoOpAnalyticsRecorder`
// declarations previously here have been removed. The authoritative types are:
//   - Protocol: MKFoundation.MKFontUsageRecording (func recordFontUsed(_:) async)
//   - No-op stub: MKFoundation.MKNoOpFontUsageRecorder
//   - Real impl: MKAnalytics.MKAnalyticsService (WS-12)
