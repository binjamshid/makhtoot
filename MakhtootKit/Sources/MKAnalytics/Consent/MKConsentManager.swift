import Foundation
import MKFoundation

/// Manages the analytics consent record ، the authoritative source for
/// whether `MKAnalyticsService` may collect or upload data. T1.
///
/// Thread-safe actor. Persistence: JSON file in the app's Application
/// Support directory (`MKAnalytics/consent.json`).
///
/// ## Version-bump re-consent
/// If the consent record on disk was written for a previous
/// `consentVersion`, `load()` DOWNGRADES its status to `.neverAsked`,
/// persists the downgrade, and returns the downgraded record ، the user
/// must re-grant consent for the updated disclosure. `MKAnalyticsService`
/// re-checks `isConsentGranted` before every counter increment and every
/// upload attempt.
public actor MKConsentManager {

    // MARK: State

    private(set) var record: MKConsentRecord
    private let storeURL: URL

    // MARK: Init

    public init(storeURL: URL) {
        self.storeURL = storeURL
        self.record = MKConsentRecord()  // default: neverAsked
    }

    /// Factory: use the production Application Support path.
    public static func production() -> MKConsentManager {
        let dir = MKAnalyticsStorage.analyticsDirectory()
        let url = dir.appendingPathComponent("consent.json")
        return MKConsentManager(storeURL: url)
    }

    // MARK: Load

    /// Load the consent record from disk. Must be called once at startup.
    /// Applies version-bump downgrade logic if needed.
    public func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            // First launch ، write the default neverAsked record.
            try? save(record)
            return
        }
        do {
            let data = try Data(contentsOf: storeURL)
            var loaded = try JSONDecoder().decode(MKConsentRecord.self, from: data)
            // Version-bump downgrade: if stored version < current, force re-consent.
            if loaded.consentVersion < MKConsentRecord.currentConsentVersion {
                loaded.status = .neverAsked
                loaded.consentVersion = MKConsentRecord.currentConsentVersion
                loaded.disclosureTextHash = ""
                try? save(loaded)
            }
            record = loaded
        } catch {
            MKLog.analytics.error("MKConsentManager: failed to load consent record: \(error, privacy: .public)")
            record = MKConsentRecord()
        }
    }

    // MARK: Public API

    /// `true` iff the user has granted consent for the current version.
    public var isConsentGranted: Bool {
        record.status.isGranted
    }

    /// Grant consent. Stores `consentVersion`, date, and hash of the
    /// disclosure text the user confirmed. T1 AC.
    public func grant(disclosureText: String) throws {
        let hash = MKConsentRecord.hash(disclosureText: disclosureText)
        record = MKConsentRecord(
            consentVersion: MKConsentRecord.currentConsentVersion,
            status: .granted(date: Date()),
            disclosureTextHash: hash
        )
        try save(record)
        MKLog.analytics.info("MKConsentManager: consent granted v\(MKConsentRecord.currentConsentVersion, privacy: .public)")
    }

    /// Revoke consent. Wipes local counters + pending batches (data
    /// minimization, T1/D-125). T1 AC.
    public func revoke(counterStore: MKUsageCounterStore) async throws {
        record = MKConsentRecord(
            consentVersion: MKConsentRecord.currentConsentVersion,
            status: .revoked(date: Date()),
            disclosureTextHash: ""
        )
        try save(record)
        await counterStore.wipeAll()
        MKLog.analytics.info("MKConsentManager: consent revoked; counters wiped")
    }

    // MARK: Private

    private func save(_ rec: MKConsentRecord) throws {
        let dir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(rec)
        try data.write(to: storeURL, options: .atomicWrite)
    }
}

