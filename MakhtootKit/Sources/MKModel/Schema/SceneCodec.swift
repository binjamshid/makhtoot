import Foundation
import MKFoundation

// WS-02 packet §5 task 6. `scene.json` codec: envelope
// `{schemaVersion: 1, scene: …}`, migration dispatch, and the
// newer-than-current rejection path.

/// `MKModel`'s error taxonomy (follows the `MKError` pattern established by
/// `MKFoundation`/`MKIOError` ، WS-01, `MKError.swift`). Reserves the
/// `"model"` error-code prefix.
public enum MKModelError: MKError {
    /// هذا المشروع أُنشئ بإصدار أحدث من مخطوط (Latin gloss: this project
    /// was created with a newer version of Makhtoot). Thrown when
    /// `scene.json`'s `schemaVersion` exceeds `MKSceneSchema.currentVersion`
    /// ، never attempt to guess-decode a newer, unknown shape.
    case schemaTooNew(found: Int, supported: Int)
    /// No registered `MKSceneMigrator` covers a step in the migration
    /// chain from an older on-disk `schemaVersion` up to current ، a
    /// programmer/registry-configuration error, not a user-facing one.
    case migrationPathMissing(fromVersion: Int)
    /// The decoded JSON envelope is missing the required `schemaVersion`
    /// or `scene` keys, or `scene.json` is not valid JSON at all.
    case malformedEnvelope(underlyingDescription: String)

    public var errorCode: String {
        switch self {
        case .schemaTooNew: return "model.schema-too-new"
        case .migrationPathMissing: return "model.migration-path-missing"
        case .malformedEnvelope: return "model.malformed-envelope"
        }
    }

    public var arabicUserMessage: String? {
        switch self {
        case .schemaTooNew:
            return "هذا المشروع أُنشئ بإصدار أحدث من مخطوط"
        case .migrationPathMissing, .malformedEnvelope:
            // Internal/registry errors ، no polished user-facing string
            // exists yet; a caller surfacing this to a user should map it
            // to a generic "تعذّر فتح المشروع" (could not open project)
            // string at the app layer instead of showing this directly.
            return nil
        }
    }

    public var underlying: (any Swift.Error)? { nil }
}

/// The on-disk envelope wrapping a scene: `{"schemaVersion": 1, "scene": {…}}`
/// (task 6). Kept as a thin `Codable` struct separate from `MKScene` itself
/// so the envelope's `schemaVersion` can be read *before* attempting a
/// typed decode of `scene` (needed to detect "newer than supported" and to
/// pick a migration starting point without first successfully decoding the
/// (possibly incompatible) payload).
public struct MKSceneEnvelope: Codable {
    public var schemaVersion: Int
    public var scene: MKScene

    public init(scene: MKScene) {
        self.schemaVersion = scene.schemaVersion
        self.scene = scene
    }
}

/// Encodes/decodes `scene.json`, applying migration + the
/// newer-than-supported rejection path (task 6).
public enum MKSceneCodec {
    /// Encodes `scene` as the `{schemaVersion, scene}` envelope.
    public static func encode(_ scene: MKScene) throws -> Data {
        let envelope = MKSceneEnvelope(scene: scene)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    /// Decodes `data` as a `scene.json` envelope:
    /// 1. Reads `schemaVersion` from the raw JSON object first (before any
    ///    typed decode of `scene`).
    /// 2. If `schemaVersion > MKSceneSchema.currentVersion`, throws
    ///    `MKModelError.schemaTooNew` immediately ، never attempts to
    ///    decode a payload shape this build doesn't understand.
    /// 3. If `schemaVersion < MKSceneSchema.currentVersion`, runs the
    ///    `registry` migration chain over the raw JSON `scene` object,
    ///    then re-serializes and decodes the migrated JSON as `MKScene`.
    /// 4. If `schemaVersion == MKSceneSchema.currentVersion`, decodes
    ///    `scene` directly as `MKScene`.
    public static func decode(_ data: Data, registry: MKSceneMigratorRegistry = .standard) throws -> MKScene {
        let rawObject: [String: Any]
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MKModelError.malformedEnvelope(underlyingDescription: "top-level JSON is not an object")
            }
            rawObject = object
        } catch let error as MKModelError {
            throw error
        } catch {
            throw MKModelError.malformedEnvelope(underlyingDescription: String(describing: error))
        }

        guard let schemaVersion = rawObject["schemaVersion"] as? Int else {
            throw MKModelError.malformedEnvelope(underlyingDescription: "missing integer 'schemaVersion'")
        }
        guard let sceneJSON = rawObject["scene"] as? [String: Any] else {
            throw MKModelError.malformedEnvelope(underlyingDescription: "missing object 'scene'")
        }

        if schemaVersion > MKSceneSchema.currentVersion {
            throw MKModelError.schemaTooNew(found: schemaVersion, supported: MKSceneSchema.currentVersion)
        }

        let migratedJSON: [String: Any]
        if schemaVersion < MKSceneSchema.currentVersion {
            migratedJSON = try registry.migrate(sceneJSON, fromVersion: schemaVersion)
        } else {
            migratedJSON = sceneJSON
        }

        let migratedData = try JSONSerialization.data(withJSONObject: migratedJSON)
        return try JSONDecoder().decode(MKScene.self, from: migratedData)
    }
}
