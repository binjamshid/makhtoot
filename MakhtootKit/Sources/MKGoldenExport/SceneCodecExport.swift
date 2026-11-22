// Work item 0.2 — category (g): scene-codec round trips. For each of
// the 4 canonical `Tests/Fixtures/*.makhtoot` scenes: decode (via the
// tolerant `FixtureSceneLoader`, see that file's header for the pre-
// existing fixture/schema-drift finding), then re-encode through the real
// `MKSceneCodec.encode`, and write the re-encoded bytes as the byte-golden
// — this is the literal `scene.json` payload a Kotlin `MkSceneCodec` must
// reproduce byte-for-byte for the same decoded `MKScene` value.
//
// Migration coverage: `MKSceneMigratorRegistry` currently ships only
// `MKIdentityMigrator` (`Sources/MKModel/Schema/MKSceneMigrator.swift`) —
// there is no non-trivial migration case in the shipped codebase yet
// (`schemaVersion` has never been bumped past 1). This is not an omission
// on this agent's part: it is the honest, current state of the migrator
// registry, confirmed by reading the file. What IS exported: the identity-
// migration behavior itself (`migrate(_:fromVersion:)` at the current
// version is a no-op) and the two documented error paths
// (`SceneSchemaTests.swift`'s own coverage: decoding a FUTURE schema
// version throws, and an empty migrator registry throws) — reproduced here
// as golden `outcome` records so a Kotlin port has the same three
// documented behaviors to match, not just the happy path.
//
// Output: `android/fixtures/scenecodec/<fixture-name>.json` (re-encoded
// scene bytes) + `android/fixtures/scenecodec/migration-behavior.json`
// (the migrator-registry outcome records).

import Foundation
import MKModel

struct MigrationOutcomeDTO: Encodable {
    var caseID: String
    var note: String
    var fromVersion: Int
    var outcome: String   // "success" | "threw"
    var errorDescription: String?
}

func exportSceneCodec() throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("scenecodec")
    var count = 0

    // (1) Round trip every canonical fixture scene: decode (tolerant) →
    // re-encode with the REAL codec → write those bytes verbatim. This is
    // deterministic because `JSONEncoder`'s per-value output for a fixed
    // Swift value follows declaration order, not any run-to-run-variable
    // process, even without `.sortedKeys` (confirmed by this run's own
    // double-run diff — see the impl log).
    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)
        let reencoded = try MKSceneCodec.encode(scene)
        let url = categoryRoot.appendingPathComponent("\(fixtureName).json")
        RepoPaths.ensure(url.deletingLastPathComponent())
        try reencoded.write(to: url, options: .atomic)
        count += 1
    }

    // (2) Migrator-registry behavior (identity-only, per this file's header
    // note).
    var outcomes: [MigrationOutcomeDTO] = []

    // (a) Identity migration at the current schema version is a no-op
    // success.
    do {
        let registry = MKSceneMigratorRegistry(migrators: [MKIdentityMigrator()])
        let scene = try FixtureSceneLoader.loadScene(named: "fixture-arabic-basic")
        let encoded = try MKSceneCodec.encode(scene)
        let obj = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]
        let sceneJSON = obj["scene"] as? [String: Any] ?? [:]
        _ = try registry.migrate(sceneJSON, fromVersion: MKSceneSchema.currentVersion)
        outcomes.append(MigrationOutcomeDTO(caseID: "identity-at-current-version", note: "MKIdentityMigrator at MKSceneSchema.currentVersion is a documented no-op success.", fromVersion: MKSceneSchema.currentVersion, outcome: "success", errorDescription: nil))
    } catch {
        outcomes.append(MigrationOutcomeDTO(caseID: "identity-at-current-version", note: "unexpected throw", fromVersion: MKSceneSchema.currentVersion, outcome: "threw", errorDescription: String(describing: error)))
    }

    // (b) Empty migrator registry throws (SceneSchemaTests' own coverage,
    // reproduced here as a golden expectation).
    do {
        let emptyRegistry = MKSceneMigratorRegistry(migrators: [])
        _ = try emptyRegistry.migrate([:], fromVersion: 0)
        outcomes.append(MigrationOutcomeDTO(caseID: "empty-registry-no-path", note: "expected a throw, got success — flag as unexpected", fromVersion: 0, outcome: "success", errorDescription: nil))
    } catch {
        outcomes.append(MigrationOutcomeDTO(caseID: "empty-registry-no-path", note: "An empty migrator registry has no path from schemaVersion 0 to current and must throw.", fromVersion: 0, outcome: "threw", errorDescription: String(describing: error)))
    }

    // (c) Decoding a scene claiming a FUTURE schema version throws.
    do {
        let scene = try FixtureSceneLoader.loadScene(named: "fixture-arabic-basic")
        var envelopeObj = try JSONSerialization.jsonObject(with: try MKSceneCodec.encode(scene)) as! [String: Any]
        let futureVersion = MKSceneSchema.currentVersion + 1000
        envelopeObj["schemaVersion"] = futureVersion
        let futureData = try JSONSerialization.data(withJSONObject: envelopeObj)
        _ = try MKSceneCodec.decode(futureData)
        outcomes.append(MigrationOutcomeDTO(caseID: "future-schema-version-rejected", note: "expected a throw, got success — flag as unexpected", fromVersion: futureVersion, outcome: "success", errorDescription: nil))
    } catch {
        outcomes.append(MigrationOutcomeDTO(caseID: "future-schema-version-rejected", note: "MKSceneCodec.decode must reject a schemaVersion newer than MKSceneSchema.currentVersion.", fromVersion: MKSceneSchema.currentVersion + 1000, outcome: "threw", errorDescription: String(describing: error)))
    }

    try GoldenJSON.write(outcomes, to: categoryRoot.appendingPathComponent("migration-behavior.json"))
    count += 1

    print("[scenecodec] wrote \(count) files (\(fixtureNames.count) round-trip byte-goldens + 1 migration-behavior manifest with \(outcomes.count) outcomes)")
}
