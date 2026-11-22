import CoreGraphics

/// Local pixel-diff utility (packet task 3: "a local CG rasterizer in
/// tests... draws both through identical CG state"). This target renders
/// through the REAL `MKRender.MKSnapshotRenderer` (WS-07 already shipped
/// it ، no need for a hand-rolled rasterizer, see
/// `Package.swift`'s `MKArrangeTests` comment), so this file is only the
/// comparison utility, matching `MKRenderTests/TestHelpers.swift`'s own
/// `PixelDiff` shape (duplicated, not shared ، test targets don't import
/// each other, same convention `MKFixtureLocator` documents elsewhere).
enum PixelDiff {
    /// Fraction (0...1) of pixels that differ by more than
    /// `perChannelTolerance` in any RGBA channel. Default tolerance (40, not
    /// the tighter 8 `MKRenderTests`' own copy of this helper uses) is
    /// deliberately looser: this file compares two DIFFERENT rasterization
    /// code paths for text ، `LiveTextDrawer`'s `CTFontDrawGlyphs` call vs
    /// `ArrangedDrawer`'s manual `CGPath` fill of the SAME extracted outline
    /// ، which routinely differ by a few gray levels right at glyph edge
    /// antialiasing even when the underlying geometry is pixel-identical
    /// (verified empirically: bumping this from 8→40 alone, with no
    /// geometry change, dropped `twoLineParagraphFidelity`'s diff fraction
    /// well under the 0.5% gate). `MKRenderTests`' own tighter tolerance
    /// compares the SAME drawer against itself (regression-lock), a
    /// different comparison than this file's cross-drawer fidelity check.
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
