import Foundation

// T13 ، Large-project handling thresholds. These are advisory constants ،
// NOT feature caps. Sync still attempts regardless of project size (BRIEF:
// "no artificial premium caps on canvas/project size"). Exceeding a threshold
// only changes the published per-project status (advisory annotation).

/// Advisory tunables for `MKSync`. Values are chosen to balance UX
/// (progress visibility) with CloudKit's practical per-request limits.
/// None of these prevent a project from syncing.
public enum MKSyncTunables {
    // MARK: - Size advisories (T13)

    /// Single-asset advisory threshold: 50 MB.
    /// Assets above this size still upload; the project's status gains an
    /// advisory annotation rendered by WS-13's browser badge.
    public static let singleAssetAdvisoryBytes: Int = 50 * 1_024 * 1_024

    /// Total-project advisory cap: 200 MB (sum of all asset payloads).
    /// Projects above this threshold publish a status advisory; sync still
    /// runs. Not a hard cap (BRIEF §19/D-101 compliance).
    public static let totalProjectAdvisoryBytes: Int = 200 * 1_024 * 1_024

    // MARK: - Debounce (T4)

    /// Minimum quiet period after the last local change before the project
    /// is queued for upload. Prevents rapid autosave from thrashing uploads
    /// (T4: "10 rapid saves produce 1 upload; debounce 5 s quiet period").
    public static let uploadDebounceInterval: Duration = .seconds(5)

    // MARK: - Retry backoff (T10)

    /// Initial retry delay after a transient error.
    public static let initialRetryBackoff: Duration = .seconds(5)

    /// Maximum retry backoff, regardless of exponential growth.
    public static let maxRetryBackoff: Duration = .seconds(3_600) // 1 hour

    /// Jitter fraction: up to ±20 % added to the backoff interval.
    public static let retryJitterFraction: Double = 0.2

    // MARK: - Schema (T14)

    /// The highest `schemaVersion` this build of the app can apply.
    /// Records with `schemaVersion > supportedSchemaVersion` are quarantined:
    /// not applied locally AND not overwritten upstream (T14).
    public static let supportedSchemaVersion: Int64 = 1

    // MARK: - Batch limits

    /// Maximum number of `CKRecord` changes in a single
    /// `CKSyncEngine.RecordZoneChangeBatch`. CloudKit's own limit is 400;
    /// we stay well under for headroom.
    public static let maxRecordsPerBatch: Int = 200

    // MARK: - Helpers

    /// Whether `byteCount` exceeds the single-asset advisory threshold.
    public static func isAssetTooLarge(_ byteCount: Int) -> Bool {
        byteCount > singleAssetAdvisoryBytes
    }

    /// Whether `byteCount` exceeds the total-project advisory threshold.
    public static func isProjectTooLarge(_ byteCount: Int) -> Bool {
        byteCount > totalProjectAdvisoryBytes
    }

    /// Computes the next backoff interval with exponential growth + jitter.
    /// - Parameters:
    ///   - attempt: Zero-based attempt count.
    ///   - base: Base interval in seconds. Defaults to `initialRetryBackoff`.
    /// - Returns: Seconds to wait, capped at `maxRetryBackoff`.
    public static func backoffInterval(attempt: Int, base: Double = 5) -> Duration {
        let raw = base * pow(2.0, Double(attempt))
        let jitter = raw * Double.random(in: -retryJitterFraction...retryJitterFraction)
        let clamped = min(raw + jitter, Double(maxRetryBackoff.components.seconds))
        return .seconds(clamped)
    }
}
