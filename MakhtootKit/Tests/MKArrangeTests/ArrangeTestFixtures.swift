import CoreText
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

/// Shared test fixtures for `MKArrangeTests`. Mirrors the pattern
/// `MKTextEngineTests/Fixtures.swift` already established (per that file's
/// own doc comment, duplicated per test target rather than shared via a
/// resource-bundle indirection ، same "duplicated verbatim" convention
/// `MKFixtureLocator` uses elsewhere): D-107 form-harvest-dependent
/// fixtures (join break/restore, form selector, ligature decompose/
/// recompose) run against **Geeza Pro**, because the system SF font
/// ignores a leading ZWJ (WS03-A6, `docs/impl-log/WS-03.md`) ، Geeza Pro
/// (bundled on macOS AND iOS) implements the full joining feature set D-107
/// depends on. Plain-derivation/fidelity fixtures that don't need ZWJ
/// harvesting use `SystemFontStubProvider` (the P0 seam) since the
/// fidelity gate (task 3) only needs INTERNAL consistency between the live
/// and arranged render paths, not any particular font.
enum ArrangeFixtures {
    /// Test-side `MKFontProviding` conformer resolving a PostScript name
    /// literally ، same shape as `MKTextEngineTests.Fixtures
    /// .NamedFontProvider`. Production wiring never uses this type.
    struct NamedFontProvider: MKFontProviding {
        func resolve(_ handle: MKFontHandle) -> CTFont {
            CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        }
    }

    static let geezaProName = "GeezaPro"
    static let geezaFonts = NamedFontProvider()

    static func geezaStyle(size: Double = 36, lineHeight: Double = 1.2) -> MKTextStyle {
        MKTextStyle(font: .system(postScriptName: geezaProName), pointSize: size, lineHeightMultiple: lineHeight)
    }

    /// Amiri support (Run-3 P6 packet instruction: "harvest requires real
    /// Arabic fonts ، use Amiri/Geeza Pro in tests, both now bundled via
    /// MKFonts resources"). Registers the REAL bundled Amiri binary by file
    /// URL ، same pattern `WS16Fixtures.swift` already established for this
    /// exact font, duplicated here per this repo's "test targets don't
    /// import each other" convention (see `PixelDiff.swift`'s own header).
    static let amiriPostScriptName = "Amiri-Regular"

    private static var fontsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ArrangeTestFixtures.swift
            .deletingLastPathComponent()   // MKArrangeTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Sources/MKFonts/Resources/Fonts")
    }

    private static let amiriRegisterOnce: Void = {
        let url = fontsRoot.appendingPathComponent("Amiri/Amiri-Regular.ttf")
        var err: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
    }()

    static let amiriFonts = NamedFontProvider()

    static func amiriStyle(size: Double = 40, lineHeight: Double = 1.2) -> MKTextStyle {
        _ = amiriRegisterOnce
        return MKTextStyle(font: .system(postScriptName: amiriPostScriptName), pointSize: size, lineHeightMultiple: lineHeight)
    }

    static func systemStyle(size: Double = 36, lineHeight: Double = 1.2, direction: MKBaseDirection = .rightToLeft) -> MKTextStyle {
        MKTextStyle(font: .systemFallback, pointSize: size, lineHeightMultiple: lineHeight, baseDirection: direction)
    }

    /// Captures `text` via `MKShapingService` (the real WS-03 facade
    /// `ArrangeDeriver` consumes in production) against `fonts`/`style`.
    static func capture(_ text: String, style: MKTextStyle, fonts: any MKFontProviding = SystemFontStubProvider()) async -> MKShapingCaptureResult {
        let service = MKShapingService(fonts: fonts)
        return await service.captureResult(MKShapingRequest(string: text, style: style))
    }

    static func captureWrapped(_ text: String, width: Double, style: MKTextStyle, fonts: any MKFontProviding = SystemFontStubProvider()) async -> MKShapingCaptureResult {
        let service = MKShapingService(fonts: fonts)
        return await service.captureResult(MKShapingRequest(string: text, style: style, frame: .widthConstrained(width: width)))
    }

    /// Convenience: derive an `ArrangedComposition` for `text` end to end
    /// (capture + `ArrangeDeriver`), the shape most tests need.
    static func derive(_ text: String, style: MKTextStyle, fonts: any MKFontProviding = SystemFontStubProvider()) async -> ArrangedComposition {
        let captured = await capture(text, style: style, fonts: fonts)
        let deriver = ArrangeDeriver(fonts: fonts)
        return await deriver.derive(sourceText: text, style: style, capture: captured)
    }
}
