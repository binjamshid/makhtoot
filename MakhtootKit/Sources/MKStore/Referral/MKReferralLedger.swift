#if MAKHTOOT_REFERRAL_ENABLED
import Foundation

/// Keychain-persisted record of codes redeemed against me + extensions
/// granted (T14). Not synchronizable ، same reasoning as
/// `MKTrialRecord`/`MKSecureStore`: referral abuse-cap state is a single-
/// device concern here (v1 has no server to reconcile it across devices;
/// documented weakness, same honesty posture as the trial's own residuals).
struct MKReferralLedgerRecord: Codable, Sendable {
    var redeemedCodes: Set<String> = []
    var extensionsGranted: Int = 0
}

/// Referrer-side ledger + anti-abuse enforcement (T14). An `actor`: every
/// redemption attempt is serialized so the cap can't be raced.
public actor MKReferralLedger {
    /// D-124 abuse cap: max 4 × 7-day extensions = 28 days total.
    public static let maxExtensions = 4

    /// Design constant (T14): a trial that has been `.expired` for more
    /// than this many days is not revived by a referral extension ، the
    /// mechanic rewards active/recently-lapsed users, not a dormant
    /// install resurrected purely to farm invite codes.
    public static let maxExpiredRevivalWindowDays: Double = 30

    private let store: any MKKeyValueStoring
    private let trialManager: MKTrialManager
    private let key = MKSecureStoreKeys.referralLedgerKey

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
    private let decoder = JSONDecoder()

    public init(
        store: any MKKeyValueStoring = MKKeychainStore(service: MKSecureStoreKeys.referralLedgerKeychainService),
        trialManager: MKTrialManager
    ) {
        self.store = store
        self.trialManager = trialManager
    }

    private func readRecord() -> MKReferralLedgerRecord {
        guard let data = store.read(key), let record = try? decoder.decode(MKReferralLedgerRecord.self, from: data) else {
            return MKReferralLedgerRecord()
        }
        return record
    }

    private func writeRecord(_ record: MKReferralLedgerRecord) {
        guard let data = try? encoder.encode(record) else { return }
        store.write(key, value: data)
    }

    public func extensionsGranted() -> Int {
        readRecord().extensionsGranted
    }

    public func hasRedeemed(_ code: String) -> Bool {
        readRecord().redeemedCodes.contains(code)
    }

    /// Records a redemption and grants a +7-day trial extension if the
    /// code is new, the cap hasn't been reached, and the trial isn't a
    /// dormant-too-long revival attempt. Returns `false` only when the
    /// code was already redeemed (T14 AC: "one redemption per unique
    /// code") ، a redemption that's new but past the cap or the revival
    /// window still records the code (so it can't be replayed later) but
    /// grants no extension.
    @discardableResult
    public func recordRedemption(code: String) async -> Bool {
        var record = readRecord()
        guard !record.redeemedCodes.contains(code) else { return false }
        record.redeemedCodes.insert(code)
        if record.extensionsGranted < Self.maxExtensions, await isEligibleForExtension() {
            let extended = await trialManager.extend(by: 7, source: .referral)
            if extended {
                record.extensionsGranted += 1
            }
        }
        writeRecord(record)
        return true
    }

    private func isEligibleForExtension() async -> Bool {
        let state = await trialManager.peek()
        switch state {
        case .active:
            return true
        case .expired:
            let record = await trialManager.currentRecord()
            let totalDays = Double(MKTrialManager.trialDays + record.extensionDays)
            let expiryDate = record.firstLaunchAt.addingTimeInterval(totalDays * 86_400)
            let daysSinceExpiry = Date().timeIntervalSince(expiryDate) / 86_400
            return daysSinceExpiry <= Self.maxExpiredRevivalWindowDays
        }
    }
}
#endif
