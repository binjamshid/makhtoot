import Foundation
import MKFoundation

// WS-02 packet §5 task 6. Migration protocol + registry. v1 has no real
// migrations (schemaVersion starts at 1, FOUNDATION §0) ، this ships the
// identity migration and the dispatch machinery so schema evolution is
// testable and has a proven seam from day one, per the task's accept
// criterion ("register identity and unit-test the dispatch path").

/// The current schema version this build of `MKModel` writes and can read
/// natively. `MKScene.init`'s default and `MKSceneCodec` both key off this.
public enum MKSceneSchema {
    public static let currentVersion = 1
}

/// One `v(n) → v(n+1)` pure JSON transform. Migrations operate on the
/// decoded-but-untyped JSON object graph (not `MKScene` directly) so a
/// migrator can be written before the *current* Swift type even exists ،
/// the standard forward-migration shape for schema evolution.
public protocol MKSceneMigrator: Sendable {
    /// The schema version this migrator's `migrate` expects as input.
    var fromVersion: Int { get }
    /// The schema version `migrate` produces.
    var toVersion: Int { get }
    /// Transforms a decoded `scene.json` JSON object (already unwrapped
    /// from the `{schemaVersion, scene}` envelope ، this receives just the
    /// `scene` sub-object) from `fromVersion`'s shape to `toVersion`'s.
    func migrate(_ sceneJSON: [String: Any]) throws -> [String: Any]
}

/// v1 → v1 no-op migrator. Exists purely so the registry/dispatch path has
/// at least one real entry to unit-test before any real migration is ever
/// needed (task 6 accept criterion).
public struct MKIdentityMigrator: MKSceneMigrator {
    public let fromVersion = MKSceneSchema.currentVersion
    public let toVersion = MKSceneSchema.currentVersion

    public init() {}

    public func migrate(_ sceneJSON: [String: Any]) throws -> [String: Any] {
        sceneJSON
    }
}

/// Ordered registry of migrators, dispatched by `fromVersion`. Decoding a
/// document at an older `schemaVersion` than `MKSceneSchema.currentVersion`
/// runs every migrator on the chain from the document's version up to
/// current, in order, before typed decode.
public struct MKSceneMigratorRegistry: Sendable {
    private var migratorsByFromVersion: [Int: any MKSceneMigrator]

    public init(migrators: [any MKSceneMigrator] = [MKIdentityMigrator()]) {
        var table: [Int: any MKSceneMigrator] = [:]
        for migrator in migrators { table[migrator.fromVersion] = migrator }
        self.migratorsByFromVersion = table
    }

    /// The registry every production caller should use: identity migration
    /// for v1, extended by later workstreams registering `v(n)→v(n+1)`
    /// steps as new schema versions ship.
    public static let standard = MKSceneMigratorRegistry()

    /// Runs the full migration chain from `fromVersion` to
    /// `MKSceneSchema.currentVersion`, applying one migrator step at a
    /// time. Throws `MKModelError.migrationPathMissing` if any step in the
    /// chain has no registered migrator (a decode-time programmer error ،
    /// every shipped older version must have a path forward).
    public func migrate(_ sceneJSON: [String: Any], fromVersion: Int) throws -> [String: Any] {
        var version = fromVersion
        var json = sceneJSON
        while version < MKSceneSchema.currentVersion {
            guard let migrator = migratorsByFromVersion[version] else {
                throw MKModelError.migrationPathMissing(fromVersion: version)
            }
            json = try migrator.migrate(json)
            version = migrator.toVersion
        }
        return json
    }
}
