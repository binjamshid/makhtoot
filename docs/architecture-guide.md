# Makhtoot architecture

The iPhone and iPad editor lives in `Makhtoot/` and uses the local Swift package [`MakhtootKit`](../MakhtootKit/Package.swift). The editor changes a document through commands. The canvas and exporters consume snapshots of its single-canvas scene. Start at [EditorViewModel](../Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift), [MakhtootDocument](../MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift), and [MKScene](../MakhtootKit/Sources/MKModel/MKScene.swift).

## From Arabic text to output

1. **Shape.** A Live Text object holds the source string and its text style. `MKShapingEngine` builds attributed text and uses Core Text to capture glyphs, positions, advances, source indices, and bidirectional runs. `MKShapingService` caches results and supplies the cluster, joining, and mark analysis needed by Arrange Mode. A Path Text object adds an editable Bézier path. `PathLayoutEngine` places shaped text by distance along that path. [Shaping engine](../MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift) · [Shaping capture](../MakhtootKit/Sources/MKTextEngine/ShapingService.swift) · [Path layout](../MakhtootKit/Sources/MKPathText/PathLayoutEngine.swift)
2. **Arrange.** Entering Arrange Mode freezes the shaped placement into Glyph Nodes, Mark Nodes, and Ligature Groups. Children retain outlines and provenance. Attached marks start with the offsets captured from shaping and follow their base by default. The Source Text Backup keeps the original string and text style, plus the path for a Path Text object. Reverting rebuilds a live object from that backup and discards manual arrangement edits. [Arrange deriver](../MakhtootKit/Sources/MKArrange/ArrangeDeriver.swift) · [Revert service](../MakhtootKit/Sources/MKArrange/RevertService.swift) · [Mark and glyph transforms](../MakhtootKit/Sources/MKRender/Geometry/ArrangedGeometry.swift)
3. **Paint and export.** `MKSceneRenderer` walks the scene in paint order using Core Graphics. Its Live Text and Path Text drawers call the shaping engine. Its arranged drawer paints stored outlines using the same geometry helpers used for arranged hit testing. `MKExportCoordinator` dispatches JPEG, PNG, SVG, and distinct PDF variants. Raster export uses the scene renderer. SVG has a dedicated serializer that uses the arranged geometry helpers. [Scene renderer](../MakhtootKit/Sources/MKRender/SceneRenderer.swift) · [Arranged drawer](../MakhtootKit/Sources/MKRender/Drawers/ArrangedDrawer.swift) · [Export coordinator](../MakhtootKit/Sources/MKExport/ExportCoordinator.swift) · [SVG serializer](../MakhtootKit/Sources/MKExport/SVGSerializer.swift)

## Android port

The [Gradle modules](../android/settings.gradle.kts) mirror the Swift package boundaries. The native bridge has HarfBuzz shaping and FreeType outline extraction. The Kotlin editor pipeline is scaffolded at the shaping, path layout, arrangement, scene rendering, and export entry points below. Those calls throw `MkNotYetPorted`. The port plan and parity matrix describe the intended behavior and acceptance gates. [HarfBuzz bridge](../android/mk-native/src/main/cpp/mk_shaping.cpp) · [FreeType bridge](../android/mk-native/src/main/cpp/mk_outline.cpp) · [Android port plan](../ANDROID_SPINE.md) · [Parity matrix](../android/PARITY_MATRIX.md)

| Stage | Kotlin entry point |
| --- | --- |
| Shape | [MkShapingService](../android/mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkShapingService.kt) |
| Place on a path | [MkPathLayoutEngine](../android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutEngine.kt) |
| Arrange | [MkArrangeDeriver](../android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeDeriver.kt) |
| Paint | [MkSceneRenderer](../android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkSceneRenderer.kt) |
| Export | [MkExportCoordinator](../android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportCoordinator.kt) |

## Where to check a change

- For glyph substitutions, joining, tashkeel, or mixed-direction text, start with the [shaping tests](../MakhtootKit/Tests/MKTextEngineTests) and the [Android shaping goldens](../android/fixtures/shaping). The Android parity decision D-325 treats dropped marks, broken ligatures, changed glyph IDs, and changed joining forms as gate failures. [Test matrix](../TEST_MATRIX.md) · [Decision log](../DECISIONS_LOG.md)
- For changes in appearance when entering Arrange Mode, start with the [derivation fidelity tests](../MakhtootKit/Tests/MKArrangeTests/DerivationFidelityTests.swift) and [arranged geometry tests](../MakhtootKit/Tests/MKRenderTests/ArrangedGeometryTests.swift). The architecture invariants describe what must survive shaping, arrangement, and paint. [Architecture invariants](../ARCHITECTURE.md#14-architecture-invariants-verified-in-test_matrix) · [Module contracts](../MakhtootKit/CONTRACTS.md)
- For save, reopen, or interchange, see the [document format and fixtures](document-format.md). For CMYK export details, see the [print PDF decision](adr/0001-cmyk-print-pdf-color-pipeline.md) and [current exporter](../MakhtootKit/Sources/MKExport/PDFPrintCMYKExporter.swift).
