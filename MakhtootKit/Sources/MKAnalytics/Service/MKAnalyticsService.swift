import Foundation
import MKFoundation

/// The main analytics service ، the real conformer of `MKFontUsageRecording`
/// (MKFoundation). T16 / D-125.
///
/// ## Concurrency model
/// All mutable state is isolated inside the `MKAnalyticsService` actor.
/// `recordFontUsed(_:)` is `async` so callers can call it without blocking
/// any UI thread, and the consent check + debounce happen actor-isolatedly.
///
/// ## Debounce (T16 AC)
/// Identical consecutive fontID values within 5 seconds are collapsed to
/// one counter increment ، prevents a rapid picker-scroll from producing a
/// cascade of events for the same font.
///
/// ## Consent gate (D-125)
/// `recordFontUsed` is a strict no-op if consent is not granted ، no
/// buffering, no deferred emit.
public actor MKAnalyticsService: MKFontUsageRecording {

    // MARK: Dependencies

    let consentManager: MKConsentManager
    let counterStore: MKUsageCounterStore
    let uploader: MKAnalyticsUploader
    private let featureFlags: MKFeatureFlags

    // MARK: Debounce state

    private var lastRecordedFontID: String?
    private var lastRecordedAt: Date?
    private let debounceInterval: TimeInterval = 5.0

    // MARK: Init

    public init(
        consentManager: MKConsentManager,
        counterStore: MKUsageCounterStore,
        uploader: MKAnalyticsUploader,
        featureFlags: MKFeatureFlags = .default
    ) {
        self.consentManager = consentManager
        self.counterStore = counterStore
        self.uploader = uploader
        self.featureFlags = featureFlags
    }

    /// Convenience factory for production use.
    public static func production(
        database: any MKCloudKitPublicDatabase = MKLiveCloudKitPublicDatabase()
    ) -> MKAnalyticsService {
        let consent = MKConsentManager.production()
        let counters = MKUsageCounterStore.production()
        let uploader = MKAnalyticsUploader.production(
            consentManager: consent,
            counterStore: counters,
            database: database
        )
        return MKAnalyticsService(consentManager: consent, counterStore: counters, uploader: uploader)
    }

    // MARK: Bootstrap

    /// Load persisted state. Call once at app launch.
    public func bootstrap() async {
        await consentManager.load()
        await counterStore.load()
    }

    // MARK: MKFontUsageRecording

    /// Record that `fontID` was applied to a text object.
    /// No-op if consent is not granted or if debounce window is active
    /// for this fontID. T16 AC / D-125.
    public func recordFontUsed(_ fontID: String) async {
        guard featureFlags.analyticsEnabled else { return }
        guard await consentManager.isConsentGranted else { return }

        // Debounce: same fontID within 5 s → skip.
        let now = Date()
        if fontID == lastRecordedFontID,
           let last = lastRecordedAt,
           now.timeIntervalSince(last) < debounceInterval {
            return
        }
        lastRecordedFontID = fontID
        lastRecordedAt = now

        await counterStore.increment(fontID: fontID)
    }

    // MARK: Grant / Revoke

    public func grantConsent() async throws {
        try await consentManager.grant(disclosureText: MKDisclosureContent.v1)
    }

    public func revokeConsent() async throws {
        try await consentManager.revoke(counterStore: counterStore)
    }

    // MARK: Upload

    /// Trigger an opportunistic upload cycle. Typically called on
    /// app launch / foreground transition.
    public func triggerUploadIfDue() async {
        await uploader.runUploadCycle()
    }

    // MARK: Status helpers (for Privacy section UI)

    /// ISO week of the most-recently-touched counter entry, or `nil` if
    /// no entries exist yet.
    public var lastRecordedWeek: String? {
        get async {
            let entries = await counterStore.closedWeekEntries()
            return entries.map(\.week).sorted().last
        }
    }

    public var isConsentGranted: Bool {
        get async { await consentManager.isConsentGranted }
    }
}
