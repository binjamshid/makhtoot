import Foundation
import CloudKit

/// Protocol abstracting the CloudKit public database operations needed by
/// `MKAnalyticsUploader`. Injected in production from
/// `CKContainer.default().publicCloudDatabase`; replaced in tests by a spy.
public protocol MKCloudKitPublicDatabase: Sendable {
    /// Save a batch. The implementation converts the batch to CKRecord
    /// fields internally. Called by the uploader once per consent+kill-
    /// switch check. Must throw on network/quota failure.
    func saveBatch(_ batch: MKFontUsageBatch) async throws

    /// Fetch the remote kill-switch record. Returns `nil` if the record
    /// does not exist yet (treated as "enabled" per T5 offline behavior).
    /// Throws only on non-"not found" errors.
    func fetchAnalyticsConfig() async throws -> MKAnalyticsConfigValue?
}

// MARK: - Remote config value

/// The decoded value of the `MKAnalyticsConfig` CloudKit record (T5 / D-207
/// layer 2). A single Boolean field `analyticsEnabled`.
public struct MKAnalyticsConfigValue: Sendable {
    public let analyticsEnabled: Bool
    public init(analyticsEnabled: Bool) {
        self.analyticsEnabled = analyticsEnabled
    }
}

// MARK: - Real CloudKit implementation

/// Production conformer wrapping `CKContainer.default().publicCloudDatabase`.
/// All CloudKit record type names and field names are constants here ، the
/// single source of truth for the schema (T3/WS-12-A3 ADR).
public actor MKLiveCloudKitPublicDatabase: MKCloudKitPublicDatabase {

    private let database: CKDatabase

    public init(database: CKDatabase = CKContainer.default().publicCloudDatabase) {
        self.database = database
    }

    public func saveBatch(_ batch: MKFontUsageBatch) async throws {
        let recordID = CKRecord.ID(recordName: batch.batchID)
        let record = CKRecord(recordType: MKFontUsageBatch.recordType, recordID: recordID)
        let fields = try batch.toCKFieldDict()
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        // Non-Sendable CKRecord is created and used entirely within this
        // actor's isolated context; no crossing of isolation boundaries.
        _ = try await database.save(record)
    }

    public func fetchAnalyticsConfig() async throws -> MKAnalyticsConfigValue? {
        let recordID = CKRecord.ID(recordName: "config")
        do {
            let record = try await database.record(for: recordID)
            let enabled = record["analyticsEnabled"] as? Bool ?? true
            return MKAnalyticsConfigValue(analyticsEnabled: enabled)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Record doesn't exist yet ، treat as enabled (T5 offline behavior).
            return nil
        }
    }
}
