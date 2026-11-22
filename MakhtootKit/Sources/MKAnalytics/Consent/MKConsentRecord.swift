import Foundation
import CryptoKit

/// Persisted consent record ، stored as JSON in the app's Application
/// Support directory by `MKConsentManager`.
///
/// ## Versioning (T1)
/// When `consentVersion` in a loaded record is less than
/// `MKConsentRecord.currentConsentVersion`, the record's status is
/// DOWNGRADED to `.neverAsked` on load ، the user must re-consent to the
/// updated disclosure text. The `disclosureTextHash` records which exact
/// disclosure the user consented to, so future audits can verify the
/// claim.
///
/// ## Deviation note (WS-12 §5)
/// FOUNDATION D-112 nominates "consent records" as SwiftData metadata.
/// Implementing this as a SwiftData `@Model` inside `MKAnalytics` would
/// require registering the model in `MKPersistence`'s shared
/// `ModelContainer` ، a circular dependency risk (MKAnalytics →
/// MKPersistence, but MKPersistence would then need to know about
/// MKAnalytics model types at compile time). Instead, `MKConsentRecord` is
/// a plain `Codable` struct persisted as a JSON file, achieving equivalent
/// durability with zero coupling. Logged as WS-12 deviation #2.
public struct MKConsentRecord: Codable, Sendable {

    /// The monotonically-increasing version of the disclosure text the
    /// user consented to. Current version is 1. A future change to the
    /// disclosure increments this constant and triggers re-consent.
    public static let currentConsentVersion: Int = 1

    /// The consent version this record was written for.
    public var consentVersion: Int

    /// Whether the user has granted, revoked, or never been asked.
    public var status: MKConsentStatus

    /// SHA-256 hex hash of the disclosure text the user saw when granting
    /// consent. Recorded for audit; checked on version bump.
    public var disclosureTextHash: String

    public init(
        consentVersion: Int = currentConsentVersion,
        status: MKConsentStatus = .neverAsked,
        disclosureTextHash: String = ""
    ) {
        self.consentVersion = consentVersion
        self.status = status
        self.disclosureTextHash = disclosureTextHash
    }
}

// MARK: - Disclosure text hashing

extension MKConsentRecord {
    /// Compute the SHA-256 hex digest of the given Arabic disclosure text.
    /// Stored in `disclosureTextHash` at grant time.
    public static func hash(disclosureText: String) -> String {
        let data = Data(disclosureText.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
