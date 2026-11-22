import Testing
@testable import MKFoundation

/// WS-01 packet §5 task 9 originally asserted `referralProgram` defaults
/// false (D-124/Q78). **Inverted by D-327** (founder, 2026-08-07): FD-05 was
/// granted for iOS and the flag now defaults ON.
///
/// The assertion is inverted rather than deleted on purpose ، it still pins
/// the flag's default, so flipping it back to `false` (the documented D-327
/// kill switch) fails here and forces the change to be deliberate.
@Suite("MKFeatureFlags")
struct FeatureFlagTests {
    @Test func referralProgramDefaultsOnAfterFD05() {
        #expect(MKFeatureFlags.default.referralProgram == true)
        #expect(MKFeatureFlags().referralProgram == true)
    }

    @Test func v2ExtensionSeamsDefaultOff() {
        let flags = MKFeatureFlags.default
        #expect(flags.multiPageSeam == false)
        #expect(flags.metalRenderer == false)
    }
}
