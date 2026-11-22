import Foundation

/// Error types for the MKAnalytics module. T17: all errors are silent
/// (no user-facing alerts from analytics paths ، enforced by the test
/// suite asserting the UI stream emits nothing on failure).
public enum MKAnalyticsError: Error, Sendable {
    /// Consent record could not be written to disk.
    case consentPersistenceFailure(underlying: Error)
    /// Counter store could not be written to disk.
    case counterPersistenceFailure(underlying: Error)
    /// CloudKit upload failed (network, quota, throttle).
    case uploadFailure(underlying: Error)
    /// Remote kill-switch record fetch failed.
    case killSwitchFetchFailure(underlying: Error)
}
