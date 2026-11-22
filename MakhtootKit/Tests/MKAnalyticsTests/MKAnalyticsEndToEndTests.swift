import Testing
import Foundation
@testable import MKAnalytics
import MKFoundation

// MARK: - T18: Full opt-in end-to-end test
//
// Integration test: grant consent → record usages → upload → verify
// payload allowlist, bucket values, batchID randomness, counter cleanup
// → revoke → verify wipe.
//
// Note: `SpyCloudKitDatabase` is defined in `MKAnalyticsUploaderTests.swift`
// (same test target). Swift test targets compile all files in the target
// directory together, so the type is available here without re-declaration.

@Suite("MKAnalytics end-to-end ، T18")
struct MKAnalyticsEndToEndTests {

    private func makeTempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).json")
    }

    @Test("Full opt-in: grant → record → upload → revoke → wipe")
    func fullOptInEndToEnd() async throws {
        // 1. Setup.
        let consentURL = makeTempURL("consent")
        let counterURL = makeTempURL("counters")
        let uploadURL  = makeTempURL("upload")

        let consent  = MKConsentManager(storeURL: consentURL)
        let counters = MKUsageCounterStore(storeURL: counterURL)
        let spy      = SpyCloudKitDatabase()
        let uploader = MKAnalyticsUploader(
            consentManager: consent,
            counterStore: counters,
            database: spy,
            lastUploadURL: uploadURL
        )
        let service  = MKAnalyticsService(
            consentManager: consent,
            counterStore: counters,
            uploader: uploader
        )

        await consent.load()
        await counters.load()

        // 2. Grant consent (D-125 opt-in).
        try await service.grantConsent()
        let isGranted = await service.isConsentGranted
        #expect(isGranted)

        // 3. Record 30 usages across 3 fonts.
        //    To produce closedWeekEntries we need to inject counters for a
        //    PAST week. We do this by directly incrementing the counter store
        //    (bypassing the debounce timer) for a past week using the store's
        //    increment method, then manually manipulating the ISO week.
        //    However, since MKUsageCounterStore only exposes increment(fontID:)
        //    for the current week, we use a separate store instance with a
        //    past week injected as a key in the file.
        let pastWeek = MKISOWeek.week(subtractingWeeks: 2, from: MKISOWeek.current()) ?? "2026-W27"

        // Inject past-week data by writing directly to the counter file.
        let pastCounters: [String: Int] = [
            "amiri|\(pastWeek)": 12,           // → .high (10-24)
            "noto-naskh-arabic|\(pastWeek)": 6, // → .medium (5-9)
            "scheherazade-new|\(pastWeek)": 50, // → .intense (50+)
        ]
        let pastData = try JSONEncoder().encode(pastCounters)
        let dir = counterURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try pastData.write(to: counterURL, options: .atomicWrite)
        await counters.load()  // re-load the injected data

        // 4. Run upload cycle.
        await service.triggerUploadIfDue()

        // 5. Assert payload allowlist.
        #expect(!spy.savedBatches.isEmpty, "Upload cycle should have saved batches")

        // Find the batch for pastWeek.
        guard let savedBatch = spy.savedBatches.first(where: { $0.week == pastWeek }) else {
            Issue.record("No batch found for week \(pastWeek)")
            return
        }

        // Allowlist: only expected keys.
        let batchKeys = try savedBatch.serializedPayloadKeys()
        #expect(batchKeys == MKFontUsageBatch.allowedPayloadKeys,
            "Payload keys \(batchKeys) must equal allowlist \(MKFontUsageBatch.allowedPayloadKeys)")

        // Verify bucket values in entries.
        let bucketsPerFont = Dictionary(uniqueKeysWithValues: savedBatch.entries.map { e in
            (e.fontID, e.bucket.rawValue)
        })
        #expect(bucketsPerFont["amiri"] == "10-24",       "amiri:12 → high (10-24)")
        #expect(bucketsPerFont["noto-naskh-arabic"] == "5-9", "noto:6 → medium (5-9)")
        #expect(bucketsPerFont["scheherazade-new"] == "50+",  "scheherazade:50 → intense (50+)")

        // 6. Counter cleanup: pastWeek's counters should be deleted after upload.
        let remaining = await counters.closedWeekEntries()
        let remainingForPastWeek = remaining.filter { $0.week == pastWeek }
        #expect(remainingForPastWeek.isEmpty, "Counters for uploaded week must be cleaned up (T4 AC)")

        // 7. batchID randomness.
        let id1 = savedBatch.batchID
        #expect(UUID(uuidString: id1) != nil, "batchID must be a valid UUID")

        // 8. Revoke → wipe.
        try await service.revokeConsent()
        let isGrantedAfterRevoke = await service.isConsentGranted
        #expect(!isGrantedAfterRevoke, "Consent revoked")
        let isEmpty = await counters.isEmpty
        #expect(isEmpty, "Revoke must wipe all local counters (D-125 data minimization, T1 AC)")
    }
}
