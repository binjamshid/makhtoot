import CoreGraphics
import CoreText
import Foundation
import MKFoundation
import MKModel
import MKTextEngine

// WS-16 (`docs/impl-log/WS-16-cursive.md`). Shared fixtures for this
// target: registers the REAL bundled Amiri binary (not a system font) by
// file URL, same `NamedFontProvider`-by-`#filePath` pattern
// `ArrangeFixtures`/`Fixtures` already use for Geeza Pro elsewhere in this
// package ، duplicated here rather than shared, matching this repo's own
// "test targets don't import each other" convention (see
// `MKArrangeTests/PixelDiff.swift`'s header comment).
enum WS16Fixtures {
    static let amiriPostScriptName = "Amiri-Regular"

    /// The 5 D-222-step-8-held fonts (`docs/impl-log/WS-09.md`,
    /// `Resources/EXCLUDED_FONTS.md`) ، `(postScriptName, resource
    /// sub-path)` pairs, resource paths mirroring
    /// `Sources/MKFonts/Resources/Fonts/<Family>/<file>.ttf` exactly.
    static let heldFonts: [(postScriptName: String, resourcePath: String)] = [
        ("Amiri-Regular", "Amiri/Amiri-Regular.ttf"),
        ("AmiriQuran-Regular", "AmiriQuran/AmiriQuran-Regular.ttf"),
        ("ArefRuqaa-Regular", "ArefRuqaa/ArefRuqaa-Regular.ttf"),
        ("Rakkas-Regular", "Rakkas/Rakkas-Regular.ttf"),
        ("Qahiri-Regular", "Qahiri/Qahiri-Regular.ttf"),
    ]

    private static var fontsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WS16Fixtures.swift
            .deletingLastPathComponent()   // WS16CursiveTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Sources/MKFonts/Resources/Fonts")
    }

    /// Registers all 5 held fonts (not just Amiri) once per process ، the
    /// per-font fidelity/cursive-flag evidence in this target covers every
    /// D-222-step-8-flagged font, not just the one named in the WS-16
    /// packet's illustrative probe instructions.
    static let registerOnce: Void = {
        for (_, resourcePath) in heldFonts {
            let url = fontsRoot.appendingPathComponent(resourcePath)
            var err: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
        }
    }()

    struct NamedFontProvider: MKFontProviding {
        func resolve(_ handle: MKFontHandle) -> CTFont {
            CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        }
    }

    static let amiriFonts = NamedFontProvider()

    static func amiriStyle(size: Double = 36, lineHeight: Double = 1.2) -> MKTextStyle {
        _ = registerOnce
        return MKTextStyle(font: .system(postScriptName: amiriPostScriptName), pointSize: size, lineHeightMultiple: lineHeight)
    }

    static func style(postScriptName: String, size: Double = 36, lineHeight: Double = 1.2) -> MKTextStyle {
        _ = registerOnce
        return MKTextStyle(font: .system(postScriptName: postScriptName), pointSize: size, lineHeightMultiple: lineHeight)
    }

    static func capture(_ text: String, style: MKTextStyle) async -> MKShapingCaptureResult {
        let service = MKShapingService(fonts: NamedFontProvider())
        return await service.captureResult(MKShapingRequest(string: text, style: style))
    }
}

/// Local copy of `MKArrangeTests/PixelDiff.swift` ، see that file's header
/// for why this is duplicated rather than shared across test targets.
enum WS16PixelDiff {
    static func differingFraction(_ a: CGImage, _ b: CGImage, perChannelTolerance: UInt8 = 40) -> Double {
        guard a.width == b.width, a.height == b.height, a.width > 0, a.height > 0 else { return 1.0 }
        guard let dataA = pixelData(a), let dataB = pixelData(b) else { return 1.0 }
        guard dataA.count == dataB.count else { return 1.0 }

        var differing = 0
        let pixelCount = a.width * a.height
        for i in 0..<pixelCount {
            let offset = i * 4
            var differs = false
            for channel in 0..<4 {
                let diff = abs(Int(dataA[offset + channel]) - Int(dataB[offset + channel]))
                if diff > Int(perChannelTolerance) { differs = true; break }
            }
            if differs { differing += 1 }
        }
        return Double(differing) / Double(pixelCount)
    }

    private static func pixelData(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }
}
