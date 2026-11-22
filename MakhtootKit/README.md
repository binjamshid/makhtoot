# MakhtootKit

MakhtootKit is the local Swift package for Makhtoot (مخطوط). It supplies the Arabic text engine, document and rendering code, and other feature modules used by the iPhone and iPad app. The package declares iOS 18 and macOS 14. The macOS target supports local development and tests. [Package manifest](Package.swift) · [App build guide](../docs/BUILD.md)

## Build and test

From the repository root on a Mac with a Swift 6 toolchain, build the package and run one shaping suite.

```sh
swift build --package-path MakhtootKit
swift test --package-path MakhtootKit --filter ShapingEngineSmokeTests
```

Choose a suite in `Tests/` that matches the change. For iOS package tests, open the package in Xcode, select the `MakhtootKit-Package` scheme, and choose an iOS simulator. The app's own UI tests run from `Makhtoot.xcodeproj` under the `Makhtoot` scheme. [Shaping smoke tests](Tests/MKTextEngineTests/ShapingEngineSmokeTests.swift) · [App and package checks](../docs/BUILD.md#iphone-and-ipad)

## Find the code

| Path | Contents |
| --- | --- |
| [`Sources/MKTextEngine`](Sources/MKTextEngine), [`Sources/MKArrange`](Sources/MKArrange), [`Sources/MKPathText`](Sources/MKPathText) | Core Text shaping capture, Arrange Mode, and text placement along paths. |
| [`Sources/MKModel`](Sources/MKModel), [`Sources/MKPersistence`](Sources/MKPersistence) | Scene types, document packages, autosave, and undo. |
| [`Sources/MKCanvas`](Sources/MKCanvas), [`Sources/MKRender`](Sources/MKRender), [`Sources/MKExport`](Sources/MKExport) | Canvas interaction, drawing, and file export. |
| [`Tests`](Tests), [`Tests/Fixtures`](Tests/Fixtures) | Package test suites and shared document fixtures. |

The [package manifest](Package.swift) defines the available targets and their dependencies. See the [module map](../FOUNDATION.md#2-module-map-targets-inside-makhtootkit) for responsibilities and the [module contracts](CONTRACTS.md) for interfaces between them.

## Arabic text and UI

Keep user-facing text Arabic and right-to-left. Give new UI-facing Arabic strings a Latin gloss in a comment on first use. Use ordinary Arabic letters and combining marks in samples and fixtures so the engine exercises shaping from logical text. Keep presentation-form codepoints out of samples and test input. [RTL utilities](Sources/MKFoundation/RTL/MKRTLUtilities.swift) · [Architecture invariants](../docs/INVARIANTS.md)

## Traceability

The package supports the brief's Arabic text, Arrange Mode, canvas, projects, fonts, and export requirements. [Platform and module decisions](../FOUNDATION.md) · [Test matrix](../TEST_MATRIX.md)
