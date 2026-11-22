import Foundation

/// iCloud KVS mirror (ARCHITECTURE §19.2 "Storage 2"). Conforms to the same
/// `MKKeyValueStoring` seam as `MKKeychainStore` ، `MKTrialManager` treats
/// both stores symmetrically for the merge rule (T6: "earliest timestamp
/// wins across the two stores and across devices").
///
/// `NSUbiquitousKeyValueStore` requires the app target's iCloud (Key-Value
/// storage) entitlement to actually propagate across devices; without it,
/// reads/writes still succeed locally (silently degrading to a per-device
/// store), which matches D-123's documented honesty-limit ("KVS unavailable
/// ، Keychain alone suffices; per-device anchors may diverge").
public struct MKUbiquitousStore: MKKeyValueStoring, @unchecked Sendable {
    private let store: NSUbiquitousKeyValueStore

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    public func read(_ key: String) -> Data? {
        store.data(forKey: key)
    }

    public func write(_ key: String, value: Data) {
        store.set(value, forKey: key)
        store.synchronize()
    }

    public func delete(_ key: String) {
        store.removeObject(forKey: key)
        store.synchronize()
    }

    /// A push channel for `NSUbiquitousKeyValueStore.didChangeExternallyNotification`
    /// (T6 AC "KVS-earlier-date wins test"; also T-SK-16's cross-device
    /// reconciliation). `MKTrialManager` re-runs its merge whenever this
    /// fires.
    public func changeNotifications() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let box = ObserverBox()
            box.token = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: nil
            ) { _ in
                continuation.yield(())
            }
            continuation.onTermination = { _ in
                box.removeIfNeeded()
            }
        }
    }
}

/// `NSObjectProtocol` observer tokens aren't `Sendable`; this box lets the
/// `onTermination` closure (itself `@Sendable`) release the token safely
/// without the compiler needing the token type itself to be `Sendable`.
private final class ObserverBox: @unchecked Sendable {
    var token: NSObjectProtocol?
    func removeIfNeeded() {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
