# First design example

[`first-design.makhtoot`](first-design.makhtoot) contains a single editable word, `مُحَمَّدٌ`, on a square canvas. The word is ready for the Arrange Mode step of the tutorial once the project is open. Keep `manifest.json` and `scene.json` together inside the `.makhtoot` directory.

The sample targets the iPhone and iPad version 1 directory reader. The iOS app handles packages delivered through its system document-open route and reuses the local project when the same project ID is already registered. This sample was checked against the format and bundled font data. Opening it on a device remains unverified. Android project import and ZIP interchange are still planned. [iOS document-open route](../Makhtoot/AppShell/Navigation/RootShellView.swift) · [Document format](../docs/document-format.md)

For an authorized public release under the [repository license](../LICENSE), the project includes this example under the same terms. It adapts the project’s [basic live-text fixture](../MakhtootKit/Tests/Fixtures/fixture-arabic-basic.makhtoot) and uses the word from the [shaping test corpus](../MakhtootKit/Tests/MKTextEngineTests/Fixtures.swift). The two JSON files reference Amiri Regular and contain no embedded fonts, artwork, or color profiles. The bundled Amiri font software is separately licensed under the SIL Open Font License 1.1. [Amiri license](../MakhtootKit/Sources/MKFonts/Resources/Fonts/Amiri/LICENSE-OFL.txt)

The [Arrange Mode illustration](arrange-fatha.png) uses the same word and bundled Amiri Regular. HarfBuzz shaped the word once. The second rendering raises only the fatha on ح, highlighted in both panels. This schematic shows the edit independently of the iOS UI. The PNG contains rendered pixels and the package references the font by name.
