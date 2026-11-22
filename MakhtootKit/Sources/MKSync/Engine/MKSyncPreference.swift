import Foundation

/// The project-sync choice for this installation. StoreKit and iCloud
/// availability do not write this preference.
public final class MKSyncPreference: @unchecked Sendable {
    private static let key = "projectSyncEnabled"
    private let defaults: UserDefaults
    private let lock = NSLock()

    // A new opt-in gets its own revision, so an old operation cannot start
    // using consent from a subsequent off/on cycle.
    private var revision = UUID()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        enabledRevision != nil
    }

    public func setEnabled(_ enabled: Bool) {
        lock.withLock {
            guard defaults.bool(forKey: Self.key) != enabled else { return }
            revision = UUID()
            defaults.set(enabled, forKey: Self.key)
        }
    }

    var enabledRevision: UUID? {
        lock.withLock {
            defaults.bool(forKey: Self.key) ? revision : nil
        }
    }
}
