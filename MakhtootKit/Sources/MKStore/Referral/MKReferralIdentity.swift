#if MAKHTOOT_REFERRAL_ENABLED
import Foundation

/// Stable per-install identity backing this device's own referral code
/// (D-327, activating D-124/T14).
///
/// `MKReferralCodeGenerator.code(installUUID:salt:)` is deterministic, so a
/// stable code requires a stable `installUUID`. Nothing in the tree provided
/// one before D-327 — the generator was never called from app code — so this
/// type owns it: a UUID minted once and persisted to the same Keychain
/// service as the referral ledger (`MKSecureStoreKeys.referralLedgerKeychainService`).
///
/// Kept deliberately separate from `MKReferralLedgerRecord` rather than added
/// as a field on it: the ledger's `Codable` shape is covered by existing tests
/// and is written on every redemption, and a stable identity has a different
/// lifetime (write-once) from a mutable ledger (write-often).
///
/// Not synchronizable, for the same reason `MKReferralLedger` isn't: a
/// per-install identity that followed the user across devices would defeat
/// the cap it exists to enforce. A user who reinstalls gets a new code — an
/// accepted D-212 weakness (self-referral is already possible with two
/// devices; reinstall is not a new hole).
public actor MKReferralIdentity {
    /// Salt is a build-time constant, not a secret: it only separates this
    /// app's code space from any other use of the same generator. The
    /// generator hashes `installUUID + salt`, and `installUUID` is the
    /// unpredictable part.
    static let salt = "net.binjamshid.makhtoot.referral.v1"

    private static let installUUIDKey = "referral.installUUID"

    private let store: any MKKeyValueStoring

    public init(
        store: any MKKeyValueStoring = MKKeychainStore(
            service: MKSecureStoreKeys.referralLedgerKeychainService
        )
    ) {
        self.store = store
    }

    /// This device's referral code, e.g. `MK-ABCD2345`. Mints and persists
    /// the backing UUID on first call; every later call returns the same
    /// string.
    public func myCode() -> String {
        MKReferralCodeGenerator.code(installUUID: installUUID(), salt: Self.salt)
    }

    private func installUUID() -> String {
        if let data = store.read(Self.installUUIDKey),
           let existing = String(data: data, encoding: .utf8),
           !existing.isEmpty {
            return existing
        }
        let minted = UUID().uuidString
        store.write(Self.installUUIDKey, value: Data(minted.utf8))
        return minted
    }
}
#endif
