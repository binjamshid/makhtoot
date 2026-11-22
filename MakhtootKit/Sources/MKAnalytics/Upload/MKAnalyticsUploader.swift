import Foundation
import MKFoundation

/// Uploads closed-week font-usage batches to the CloudKit public database.
/// T4 / T5 / T17.
///
/// ## Upload cadence (T4)
/// Opportunistic ، checked on launch / foreground. Uploads a given week's
/// batch only if:
/// 1. `MKConsentManager.isConsentGranted` is `true` (re-checked immediately
///    before every upload attempt).
/// 2. `MKFeatureFlags.analyticsEnabled` is `true` (layer-3 kill switch, T5).
/// 3. The remote `MKAnalyticsConfig` record is enabled or has never been
///    fetched (layer-2 kill switch, T5/D-207/DF-2).
/// 4. At least 7 days (1 closed week) have passed since the last successful
///    upload (`lastUploadDate`).
///
/// ## Kill switch behavior (T5 / D-207)
/// - Local consent OFF → immediate stop, no network call.
/// - `MKFeatureFlags.analyticsEnabled = false` → compile/runtime inertness.
/// - Remote CloudKit record `MKAnalyticsConfig.analyticsEnabled = false` →
///   upload suppressed; cached value used offline. Default: enabled if record
///   never fetched (T5 offline-with-no-prior-fetch AC).
///
/// ## Batch retry retention (T4 / DF-7)
/// On failure, the batch can be retried on subsequent upload attempts only
/// while the underlying raw counters still exist. Once `MKUsageCounterStore`
/// prunes a week's counters at the 8-week boundary, that week's batch is
/// silently dropped. This keeps retry retention bounded by (and never
/// exceeding) the raw-counter retention window.
public actor MKAnalyticsUploader {

    // MARK: Dependencies

    private let consentManager: MKConsentManager
    private let counterStore: MKUsageCounterStore
    private let database: any MKCloudKitPublicDatabase
    private let featureFlags: MKFeatureFlags

    // MARK: State

    /// Date of the last successful upload attempt. Persisted as a JSON file.
    private var lastUploadDate: Date?
    private let lastUploadURL: URL

    /// Last-known value of the remote kill-switch record (layer 2).
    /// `nil` = record never fetched (default to enabled).
    private var cachedRemoteEnabled: Bool?

    // MARK: Init

    public init(
        consentManager: MKConsentManager,
        counterStore: MKUsageCounterStore,
        database: any MKCloudKitPublicDatabase,
        featureFlags: MKFeatureFlags = .default,
        lastUploadURL: URL
    ) {
        self.consentManager = consentManager
        self.counterStore = counterStore
        self.database = database
        self.featureFlags = featureFlags
        self.lastUploadURL = lastUploadURL
        self.lastUploadDate = MKAnalyticsUploader.loadLastUploadDate(url: lastUploadURL)
    }

    public static func production(
        consentManager: MKConsentManager,
        counterStore: MKUsageCounterStore,
        database: any MKCloudKitPublicDatabase = MKLiveCloudKitPublicDatabase()
    ) -> MKAnalyticsUploader {
        let dir = MKAnalyticsStorage.analyticsDirectory()
        let url = dir.appendingPathComponent("last-upload.json")
        return MKAnalyticsUploader(
            consentManager: consentManager,
            counterStore: counterStore,
            database: database,
            lastUploadURL: url
        )
    }

    // MARK: Upload entry point

    /// Run upload cycle: check gates, fetch remote kill switch, upload all
    /// closed weeks. Called opportunistically at launch / app-foreground.
    public func runUploadCycle() async {
        // Layer 3: compile/runtime flag (supplementary, T5).
        guard featureFlags.analyticsEnabled else {
            MKLog.analytics.debug("MKAnalyticsUploader: feature flag off ، skipping")
            return
        }
        // Layer 1: local consent (T5).
        guard await consentManager.isConsentGranted else {
            MKLog.analytics.debug("MKAnalyticsUploader: consent not granted ، skipping")
            return
        }
        // Cadence: at least 7 days since last successful upload.
        if let last = lastUploadDate, Date().timeIntervalSince(last) < 7 * 86_400 {
            MKLog.analytics.debug("MKAnalyticsUploader: upload not due yet")
            return
        }
        // Layer 2: remote kill switch (T5/D-207).
        do {
            if let config = try await database.fetchAnalyticsConfig() {
                cachedRemoteEnabled = config.analyticsEnabled
            }
            // If fetchAnalyticsConfig() returns nil (record not found),
            // cachedRemoteEnabled stays nil → defaults to enabled (T5 AC).
        } catch {
            MKLog.analytics.error("MKAnalyticsUploader: kill-switch fetch error: \(error, privacy: .public)")
            // Use cached value; don't block on transient error.
        }
        // If we have an explicitly cached `false`, block upload.
        if cachedRemoteEnabled == false {
            MKLog.analytics.info("MKAnalyticsUploader: remote kill switch off ، skipping")
            return
        }

        // Prune expired counters before building batches.
        await counterStore.pruneOldEntries()

        // Build one batch per closed week.
        let entries = await counterStore.closedWeekEntries()
        guard !entries.isEmpty else { return }

        // Group by week.
        var byWeek: [String: [(fontID: String, count: Int)]] = [:]
        for entry in entries {
            byWeek[entry.week, default: []].append((fontID: entry.fontID, count: entry.count))
        }

        let appVersion = MKAppVersion.majorMinor
        var anySuccess = false

        for (week, fontCounts) in byWeek {
            let batchEntries = fontCounts.map { fc in
                MKFontUsageBatch.Entry(fontID: fc.fontID, bucket: MKFontUsageBucket.bucket(for: fc.count))
            }
            let batch = MKFontUsageBatch(week: week, appVersion: appVersion, entries: batchEntries)
            do {
                try await database.saveBatch(batch)
                await counterStore.deleteEntries(for: week)
                anySuccess = true
                MKLog.analytics.info("MKAnalyticsUploader: uploaded week \(week, privacy: .public)")
            } catch {
                // Silent failure (T17: analytics must never nag the user).
                MKLog.analytics.error("MKAnalyticsUploader: upload failed for \(week, privacy: .public): \(error, privacy: .public)")
            }
        }

        if anySuccess {
            lastUploadDate = Date()
            saveLastUploadDate()
        }
    }

    // MARK: Persistence of last-upload date

    private func saveLastUploadDate() {
        guard let date = lastUploadDate else { return }
        if let data = try? JSONEncoder().encode(date) {
            try? data.write(to: lastUploadURL, options: .atomicWrite)
        }
    }

    private static func loadLastUploadDate(url: URL) -> Date? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Date.self, from: data)
    }
}

// MARK: - Storage directory helper

public enum MKAnalyticsStorage {
    /// Returns the analytics subdirectory in Application Support,
    /// creating it if needed.
    public static func analyticsDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("MKAnalytics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
