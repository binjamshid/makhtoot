import Foundation
#if canImport(Security)
import Security
#endif

/// Narrow key-value storage seam so `MKTrialManager`/`MKReferralLedger`
/// (T6/T14) can be driven by a real Keychain in production and an
/// in-memory fake in tests, without either depending on `Security`
/// directly. Kept inside `MKStore` (not `MKFoundation`) per the packet's
/// own upstream note: "Keychain/iCloud-KVS access wrapped in `MKSecureStore`
/// utilities inside MKStore (kept out of MKFoundation to keep it
/// dependency-free)."
public protocol MKKeyValueStoring: Sendable {
    func read(_ key: String) -> Data?
    func write(_ key: String, value: Data)
    func delete(_ key: String)
}

/// Real Keychain-backed store (ARCHITECTURE §19.2): `kSecClassGenericPassword`,
/// caller-supplied `service`, `kSecAttrAccessibleAfterFirstUnlock` (D-123:
/// survives app deletion/reinstall on-device), explicitly
/// `kSecAttrSynchronizable = false` (cross-device sync is handled
/// explicitly by the iCloud KVS mirror instead ، never implicitly via
/// Keychain iCloud sync, so the two propagation paths stay distinguishable
/// for the merge-rule tests).
public struct MKKeychainStore: MKKeyValueStoring {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    #if canImport(Security)
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func read(_ key: String) -> Data? {
        var query = baseQuery(account: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    public func write(_ key: String, value: Data) {
        var query = baseQuery(account: key)
        query[kSecReturnData as String] = false
        var checkStatus: AnyObject?
        let exists = SecItemCopyMatching(query as CFDictionary, &checkStatus) == errSecSuccess
        if exists {
            let update: [String: Any] = [kSecValueData as String: value]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            var attributes = baseQuery(account: key)
            attributes[kSecValueData as String] = value
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            attributes[kSecAttrSynchronizable as String] = false
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    public func delete(_ key: String) {
        SecItemDelete(baseQuery(account: key) as CFDictionary)
    }
    #else
    public func read(_ key: String) -> Data? { nil }
    public func write(_ key: String, value: Data) {}
    public func delete(_ key: String) {}
    #endif
}

/// In-memory fake conforming to `MKKeyValueStoring` ، the standard test
/// double for both the Keychain-facing and KVS-facing seams (they share
/// the same protocol shape; only persistence semantics differ, which tests
/// don't need to exercise since real Keychain/KVS access is unavailable/
/// unreliable in a `swift test` sandbox ، T6/T14 AC "unit tests with
/// injected clock" implies injected storage too).
public final class MKInMemoryKeyValueStore: MKKeyValueStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init(seed: [String: Data] = [:]) {
        storage = seed
    }

    public func read(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    public func write(_ key: String, value: Data) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
    }

    public func delete(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}

/// Well-known service/key constants (T6/T14 ، keeps every call site
/// spelling the same strings instead of re-typing literals).
public enum MKSecureStoreKeys {
    public static let trialKeychainService = "net.binjamshid.makhtoot.trial"
    public static let trialRecordKey = "trial.record"
    public static let trialKVSKey = "trial.record"
    public static let referralLedgerKeychainService = "net.binjamshid.makhtoot.referral"
    public static let referralLedgerKey = "referral.ledger"
}
