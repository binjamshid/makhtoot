import Testing
import Foundation
@testable import MKAnalytics

// MARK: - T3: Payload allowlist test (WS-12-A3 ADR enforcement gate)
//
// THIS TEST IS THE TECHNICAL ENFORCEMENT MECHANISM for D-125's prohibition
// list. Adding ANY new field to `MKFontUsageBatch.toCKFieldDict()` will
// fail this test ، that is intentional. The test must pass before any new
// field is considered acceptable for upload.
//
// Fields explicitly absent from the payload:
// - user record references
// - device model
// - locale
// - vendor IDs
// - any timestamp finer than week

@Suite("MKFontUsageBatch payload allowlist ، T3")
struct MKPayloadAllowlistTests {

    private static let expectedAllowedKeys: Set<String> = ["batchID", "week", "appVersion", "entries"]

    @Test("Payload contains ONLY whitelisted keys")
    func payloadContainsOnlyAllowedKeys() throws {
        let entries = [
            MKFontUsageBatch.Entry(fontID: "amiri", bucket: .high),
            MKFontUsageBatch.Entry(fontID: "noto-naskh-arabic", bucket: .medium),
        ]
        let batch = MKFontUsageBatch(week: "2026-W29", appVersion: "1.0", entries: entries)
        let keys = try batch.serializedPayloadKeys()
        // D-125 enforcement: any new field added to the upload payload
        // will be caught here. Do not bypass this test without explicit
        // approval (WS-12-A3 ADR).
        #expect(keys == Self.expectedAllowedKeys)
    }

    @Test("Payload contains no user record reference")
    func noUserRecordReference() throws {
        let batch = MKFontUsageBatch(week: "2026-W29", appVersion: "1.0", entries: [])
        let dict = try batch.toCKFieldDict()
        let prohibited = ["userRecordID", "userID", "deviceID", "vendorID", "locale", "deviceModel"]
        for key in prohibited {
            #expect(dict[key] == nil, "Prohibited field '\(key)' found in upload payload ، D-125 violation")
        }
    }

    @Test("batchID is a UUID string (ephemeral, random)")
    func batchIDIsRandomUUID() throws {
        let batch1 = MKFontUsageBatch(week: "2026-W29", appVersion: "1.0", entries: [])
        let batch2 = MKFontUsageBatch(week: "2026-W29", appVersion: "1.0", entries: [])
        let dict1 = try batch1.toCKFieldDict()
        let dict2 = try batch2.toCKFieldDict()
        let id1 = dict1["batchID"] as? String ?? ""
        let id2 = dict2["batchID"] as? String ?? ""
        #expect(UUID(uuidString: id1) != nil, "batchID must be a valid UUID string")
        #expect(id1 != id2, "batchID must be random and unique across batch instances")
    }

    @Test("week field is ISO week format only (no finer timestamp)")
    func weekIsISOWeekOnly() throws {
        let week = "2026-W29"
        let batch = MKFontUsageBatch(week: week, appVersion: "1.0", entries: [])
        let dict = try batch.toCKFieldDict()
        let weekValue = dict["week"] as? String ?? ""
        #expect(weekValue == week)
        // Must NOT contain a full ISO8601 date or time.
        #expect(!weekValue.contains("T"), "week must not contain time component")
        #expect(!weekValue.contains("-0"), "week must not contain day component like '-01'")
        // Simple format check: YYYY-WWW
        let parts = weekValue.split(separator: "-")
        #expect(parts.count == 2)
        #expect(parts[1].hasPrefix("W"))
    }

    @Test("appVersion is major.minor only")
    func appVersionIsMajorMinor() throws {
        let batch = MKFontUsageBatch(week: "2026-W29", appVersion: "1.2", entries: [])
        let dict = try batch.toCKFieldDict()
        let version = dict["appVersion"] as? String ?? ""
        #expect(version == "1.2")
        let parts = version.split(separator: ".")
        #expect(parts.count == 2, "appVersion must be major.minor only (no build/patch)")
    }

    @Test("entries encodes fontID + bucket only (no raw count)")
    func entriesEncodesOnlyFontIDAndBucket() throws {
        let entries = [MKFontUsageBatch.Entry(fontID: "amiri", bucket: .high)]
        let batch = MKFontUsageBatch(week: "2026-W29", appVersion: "1.0", entries: entries)
        let dict = try batch.toCKFieldDict()
        let entriesString = dict["entries"] as? String ?? ""
        let entriesData = Data(entriesString.utf8)
        let decoded = try JSONDecoder().decode([[String: String]].self, from: entriesData)
        #expect(decoded.count == 1)
        let entry = decoded[0]
        #expect(entry["fontID"] == "amiri")
        #expect(entry["bucket"] == "10-24")
        #expect(entry["count"] == nil, "Raw count must never appear in the upload payload (D-125)")
    }
}
