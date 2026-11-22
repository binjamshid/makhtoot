# The `.makhtoot` document format

On iPhone and iPad, a `.makhtoot` project is a directory package containing one editable canvas. iOS registers `net.binjamshid.makhtoot.project` as the document type. The app’s import handler registers an external package in the project library and opens the existing local project if its ID is already registered. [Package implementation](../MakhtootKit/Sources/MKPersistence/DocumentPackage.swift) · [iOS document type](../Makhtoot/Config/Info.plist) · [Project import](../Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift)

## Package contents

| Member | Contents |
| --- | --- |
| `manifest.json` | Project ID, title, canvas size, ISO 8601 timestamps, `manifestVersion`, `schemaVersion`, and fields for the thumbnail, asset digest, and premium content. |
| `scene.json` | The saved scene in a `{"schemaVersion":1,"scene":{…}}` envelope. The scene carries its own `schemaVersion`, a canvas, a background, and ordered nodes. |
| `assets/` | Referenced project assets. The [asset store](../MakhtootKit/Sources/MKPersistence/AssetStore.swift) uses names of the form `sha256-<digest>.<ext>`. |
| `thumbnail.png` | Optional preview. |
| `journal.mkj` and `backups/` | Local recovery data. The journal records commands pending a completed save. Recovery can replay the journal and write a rescue snapshot. [Autosave](../MakhtootKit/Sources/MKPersistence/AutosaveController.swift) · [Crash recovery](../MakhtootKit/Sources/MKPersistence/CrashRecovery.swift) |

Scene nodes are encoded as objects with `kind` and `payload`. Live Text and Path Text keep editable source text, style, and font references. Arranged nodes carry visual-order children with geometry and provenance, including stored outlines where available, and a Source Text Backup. Live text rendering depends on the receiving system’s font resolution. The arranged canvas drawer paints persisted outlines. [Node encoding](../MakhtootKit/Sources/MKModel/MKNode.swift) · [Font references](../MakhtootKit/Sources/MKModel/MKFontRef.swift) · [Arranged composition](../MakhtootKit/Sources/MKModel/Arranged/ArrangedComposition.swift)

## Versioning and compatibility

- **Current writer.** New packages use `manifestVersion` 1 and scene `schemaVersion` 1. iOS reads the outer scene version before decoding the typed scene. A higher version throws `schemaTooNew`. Older versions need a registered migration chain, and the standard registry currently contains only the version 1 identity migration. [Scene codec](../MakhtootKit/Sources/MKModel/Schema/SceneCodec.swift) · [Migrator registry](../MakhtootKit/Sources/MKModel/Schema/MKSceneMigrator.swift)
- **Older version 1 files.** A matching version number alone cannot guarantee decoding. The two text fixtures below lack `isBold`, `isItalic`, `isUnderline`, and `isStrikethrough`, which the current `MKTextStyle` decoder requires. The parity fixture generator supplies those values before decoding. The regular package reader decodes through the scene codec directly. [Text style](../MakhtootKit/Sources/MKModel/MKTextStyle.swift) · [Fixture loader](../MakhtootKit/Sources/MKGoldenExport/FixtureSceneLoader.swift)
- **Android and ZIP exchange.** D-309 specifies a future ZIP interchange path. The iOS import path reads a directory package. Android’s scene codec, package reader and writer, and project import are stubs. Editable project exchange between platforms is unavailable in the current source. [Decision log](../DECISIONS_LOG.md) · [Android scene codec](../android/mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/schema/MkSceneCodec.kt) · [Android package API](../android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkDocumentPackage.kt) · [Android project library](../android/app/src/main/kotlin/net/binjamshid/makhtoot/persistence/MkPersistenceProjectLibrary.kt)

## Fixtures for inspecting the format

| Fixture | What to inspect |
| --- | --- |
| Basic Arabic | The [manifest](../MakhtootKit/Tests/Fixtures/fixture-arabic-basic.makhtoot/manifest.json) and [scene](../MakhtootKit/Tests/Fixtures/fixture-arabic-basic.makhtoot/scene.json) show one Live Text object on a 1080 × 1080 canvas. |
| Arranged lam–alef | The [manifest](../MakhtootKit/Tests/Fixtures/fixture-arranged-la.makhtoot/manifest.json) and [scene](../MakhtootKit/Tests/Fixtures/fixture-arranged-la.makhtoot/scene.json) show a Ligature Group and its retained source. |
| Many shapes | The [100-node package](../MakhtootKit/Tests/Fixtures/fixture-100-nodes.makhtoot) and [5,000-node package](../MakhtootKit/Tests/Fixtures/fixture-5000-nodes.makhtoot) show larger scene trees made up of shapes. |

Use the JSON files as format examples. The [regenerated scene goldens](../android/fixtures/scenecodec) and [expected migration outcomes](../android/fixtures/scenecodec/migration-behavior.json) are reference data for the Android codec port. Swift tests cover the [scene envelope](../MakhtootKit/Tests/MKModelTests/SceneSchemaTests.swift) and [package round trip](../MakhtootKit/Tests/MKPersistenceTests/DocumentPackageTests.swift).
