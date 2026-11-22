import Foundation
import MKFoundation

// MARK: - Batch payload (T3, WS-12-A3 ADR)

/// One analytics upload batch ، the only CloudKit record type `MKAnalytics`
/// writes to the public database.
///
/// ## Field allowlist (D-125 / T3 / WS-12-A3)
/// The serialized payload MUST contain ONLY these keys:
/// - `batchID`    ، random UUID generated per upload, never stored after
///                  success, never reused.
/// - `week`       ، ISO week string ("2026-W29"), no finer timestamps.
/// - `appVersion` ، major.minor only (e.g. "1.0"), no build/patch.
/// - `entries`    ، JSON array of `{fontID, bucket}` dicts.
///
/// Explicitly ABSENT: user record links, device model, locale, vendor IDs,
/// timestamps finer than week. The `MKPayloadAllowlistTests` test suite
/// asserts the serialized dictionary contains NO key outside this list ،
/// any addition will fail that test (intentional enforcement gate, T3 AC).
public struct MKFontUsageBatch: Encodable, Sendable {

    /// CloudKit record type name. Used in the uploader to create CKRecords.
    public static let recordType = "MKFontUsageBatch"

    /// Whitelisted top-level field names (T3 AC enforcement).
    public static let allowedPayloadKeys: Set<String> = ["batchID", "week", "appVersion", "entries"]

    public let batchID: String       // random UUID string
    public let week: String          // ISO week e.g. "2026-W29"
    public let appVersion: String    // major.minor only e.g. "1.0"
    public let entries: [Entry]

    /// Single per-font entry. Raw count is NEVER included ، only the bucket.
    public struct Entry: Codable, Sendable {
        public let fontID: String
        public let bucket: MKFontUsageBucket

        public init(fontID: String, bucket: MKFontUsageBucket) {
            self.fontID = fontID
            self.bucket = bucket
        }
    }

    public init(week: String, appVersion: String, entries: [Entry]) {
        self.batchID = UUID().uuidString   // ephemeral, never reused
        self.week = week
        self.appVersion = appVersion
        self.entries = entries
    }

    // MARK: Serialization

    /// Encode to the JSON `[String: Any]` dict that maps to CloudKit field
    /// values. The `entries` array is encoded as a JSON string asset field.
    public func toCKFieldDict() throws -> [String: Any] {
        let entriesData = try JSONEncoder().encode(entries)
        let entriesString = String(data: entriesData, encoding: .utf8) ?? "[]"
        return [
            "batchID": batchID,
            "week": week,
            "appVersion": appVersion,
            "entries": entriesString,
        ]
    }

    /// Serialized payload keys ، used in `MKPayloadAllowlistTests` to assert
    /// no extra keys exist.
    public func serializedPayloadKeys() throws -> Set<String> {
        let dict = try toCKFieldDict()
        return Set(dict.keys)
    }
}

// MARK: - App version helper

public enum MKAppVersion {
    /// Returns "major.minor" from CFBundleShortVersionString.
    /// Falls back to "1.0" if unresolvable.
    public static var majorMinor: String {
        guard let full = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "1.0"
        }
        let parts = full.split(separator: ".")
        if parts.count >= 2 {
            return "\(parts[0]).\(parts[1])"
        }
        return full
    }
}
