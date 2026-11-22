import Foundation
import Testing
@testable import MKModel

/// WS-02 packet §5 task 6 accept criteria: v1 decode; unknown-newer
/// rejection; migrator dispatch.
@Suite("Scene schema / migration")
struct SceneSchemaTests {
    @Test func v1SceneEncodesAndDecodesThroughTheEnvelope() throws {
        let scene = FixtureScenes.flatNodesScene(count: 3)
        let data = try MKSceneCodec.encode(scene)

        let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(envelope?["schemaVersion"] as? Int == 1)
        #expect(envelope?["scene"] != nil)

        let decoded = try MKSceneCodec.decode(data)
        #expect(decoded == scene)
    }

    @Test func decodingANewerSchemaVersionThrowsSchemaTooNew() throws {
        let scene = FixtureScenes.flatNodesScene(count: 1)
        var envelope = try JSONSerialization.jsonObject(with: try MKSceneCodec.encode(scene)) as! [String: Any]
        envelope["schemaVersion"] = MKSceneSchema.currentVersion + 1
        let futureData = try JSONSerialization.data(withJSONObject: envelope)

        #expect(throws: MKModelError.self) {
            _ = try MKSceneCodec.decode(futureData)
        }

        do {
            _ = try MKSceneCodec.decode(futureData)
            Issue.record("expected schemaTooNew")
        } catch let error as MKModelError {
            guard case .schemaTooNew(let found, let supported) = error else {
                Issue.record("expected .schemaTooNew, got \(error)")
                return
            }
            #expect(found == MKSceneSchema.currentVersion + 1)
            #expect(supported == MKSceneSchema.currentVersion)
            #expect(error.arabicUserMessage == "هذا المشروع أُنشئ بإصدار أحدث من مخطوط")
        }
    }

    @Test func migratorRegistryDispatchesIdentityMigrationForCurrentVersion() throws {
        let registry = MKSceneMigratorRegistry(migrators: [MKIdentityMigrator()])
        let sceneJSON: [String: Any] = ["schemaVersion": 1, "canvas": ["size": ["width": 100, "height": 100]], "nodes": []]
        let migrated = try registry.migrate(sceneJSON, fromVersion: MKSceneSchema.currentVersion)
        #expect(migrated["schemaVersion"] as? Int == 1)
    }

    @Test func migrationPathMissingThrowsForAnUnregisteredOlderVersion() {
        let emptyRegistry = MKSceneMigratorRegistry(migrators: [])
        #expect(throws: MKModelError.self) {
            _ = try emptyRegistry.migrate([:], fromVersion: 0)
        }
    }

    @Test func malformedEnvelopeIsRejected() {
        #expect(throws: MKModelError.self) {
            _ = try MKSceneCodec.decode(Data("not json".utf8))
        }
        #expect(throws: MKModelError.self) {
            _ = try MKSceneCodec.decode(Data("{}".utf8))
        }
    }
}
