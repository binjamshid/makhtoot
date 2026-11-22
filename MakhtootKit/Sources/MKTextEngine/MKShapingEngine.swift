import CoreText
import CoreGraphics
import Foundation
import MKFoundation
import MKModel

/// The WS-03 shaping-capture core (D-103): builds the attributed string,
/// drives `CTTypesetter`/`CTLine`/`CTRun` capture, and assembles
/// `MKShapedLine`/`MKShapedParagraph` with cluster (D-105) and bidi
/// (D-109) maps attached.
///
/// This struct is the **pure, uncached** core; `MKShapingService` (actor)
/// is the cached facade ARCHITECTURE §4.4/§4.7 specifies ، consumers on
/// the typing-echo path use the service, batch/analysis callers may use
/// this directly. `Sendable` per D-102; stateless, cheap to construct.
public struct MKShapingEngine: Sendable {
    private let fonts: MKFontProviding

    /// Defaults to `SystemFontStubProvider` ، the P0 `MKFontProviding` seam
    /// (DEPENDENCY_GRAPH.md stub S2) every fixture shapes against until
    /// WS-09 ships the real font registry.
    public init(fonts: MKFontProviding = SystemFontStubProvider()) {
        self.fonts = fonts
    }

    /// Resolves the feature-configured `CTFont` for a style: provider
    /// variant resolution (E-F1 seam, Phase A real bold/italic ، a
    /// genuine cut/axis or the base font, never synthesized) + D-108
    /// feature application. This is the ONE propagation point: every
    /// downstream consumer (drawers, outlining, arrange derivation, glyph
    /// paths) reads the RESOLVED font back off the captured run
    /// (`MKShapedRun.font`, captured from `CTRunGetAttributes[.font]` in
    /// `capture(_:...)` below), not `style.font` ، so canvas/PDF/PNG/path-
    /// text/arrange all follow this one call automatically.
    func resolvedFont(for style: MKTextStyle) -> CTFont {
        let variant = MKFontVariantRequest(bold: style.isBold, italic: style.isItalic)
        return MKFontFeatureControl.font(
            fonts.resolve(style.fontHandle, variant: variant), applying: style.ligatureSetting)
    }

    /// Shapes `request.text` as one `CTLine` with no width constraint
    /// (packet task 4's capture core). Ignores `request.frame` ، callers
    /// wanting width-constrained wrapping should call `shapeParagraph(_:)`.
    public func shapeSingleLine(_ request: MKShapingRequest) -> MKShapedLine {
        let attributed = makeAttributed(request)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: 0, length: attributed.length))
        return Self.capture(
            ctLine,
            lineIndex: 0,
            sourceText: request.text.string,
            sourceRange: 0..<attributed.length,
            baseDirection: request.style.baseDirection)
    }

    /// Multi-line support (packet task 5): `CTTypesetterSuggestLineBreak`
    /// loop when `request.frame` is `.widthConstrained`; falls back to a
    /// single line (equivalent to `shapeSingleLine(_:)`) for `.singleLine`.
    public func shapeParagraph(_ request: MKShapingRequest) -> MKShapedParagraph {
        guard case .widthConstrained(let maxWidth) = request.frame else {
            return MKShapedParagraph(lines: [shapeSingleLine(request)], sourceText: request.text.string)
        }
        let attributed = makeAttributed(request)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let length = attributed.length

        var lines: [MKShapedLine] = []
        var start = 0
        while start < length {
            let suggested = CTTypesetterSuggestLineBreak(typesetter, start, maxWidth)
            // Defensive floor: a pathological width narrower than any single
            // glyph must still make forward progress rather than looping
            // forever (task 11 "empty/degenerate input safety" spirit).
            let count = max(suggested, 1)
            let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
            let shaped = Self.capture(
                ctLine,
                lineIndex: lines.count,
                sourceText: request.text.string,
                sourceRange: start..<(start + count),
                baseDirection: request.style.baseDirection)
            lines.append(shaped)
            start += count
        }
        return MKShapedParagraph(lines: lines, sourceText: request.text.string)
    }

    // MARK: - Attributed-string assembly (incl. kern-override second pass)

    /// Builds the attributed string for `request`. When the style carries
    /// per-cluster-pair kerning overrides (`MKTextStyle.kerningOverrides`,
    /// D-105 cluster model), this runs a **two-pass** pipeline: first shape
    /// without overrides to obtain cluster boundaries, then map each
    /// `clusterPairIndex` to its earlier-in-logical-order cluster's UTF-16
    /// range and re-build with `.kern` attributes on those ranges. (Kern
    /// applies between a character and its successor, so the value lands on
    /// the pair's first cluster.)
    func makeAttributed(_ request: MKShapingRequest) -> NSAttributedString {
        let resolve: (MKTextStyle) -> CTFont = { self.resolvedFont(for: $0) }
        guard !request.style.kerningOverrides.isEmpty else {
            return MKAttributedStringBuilder.make(text: request.text, style: request.style, resolveFont: resolve)
        }

        // Pass 1: shape without overrides to learn cluster boundaries.
        var strippedStyle = request.style
        strippedStyle.kerningOverrides = []
        let baseline = MKAttributedStringBuilder.make(text: request.text, style: strippedStyle, resolveFont: resolve)
        let typesetter = CTTypesetterCreateWithAttributedString(baseline)
        let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: 0, length: baseline.length))
        let shaped = Self.capture(
            ctLine, lineIndex: 0,
            sourceText: request.text.string,
            sourceRange: 0..<baseline.length,
            baseDirection: request.style.baseDirection)

        // Pair k = (cluster k, cluster k+1) over non-control clusters in
        // logical order; the kern value attaches to cluster k's range.
        let kernableClusters = shaped.clusterMap.clusters.filter { $0.kind != .control }
        var extraKerning: [(range: Range<Int>, value: Double)] = []
        for override in request.style.kerningOverrides {
            let k = override.clusterPairIndex
            guard k >= 0, k + 1 < kernableClusters.count else { continue }   // dangling pair index: ignore, not crash
            extraKerning.append((range: kernableClusters[k].utf16Range, value: override.value))
        }

        // Pass 2: full style (minus the overrides list itself ، they are
        // realized as extraKerning attributes) + kern ranges.
        return MKAttributedStringBuilder.make(
            text: request.text, style: strippedStyle, resolveFont: resolve, extraKerning: extraKerning)
    }

    // MARK: - Capture core

    /// The capture core (packet task 4): iterates `CTLineGetGlyphRuns`,
    /// copies glyphs/positions/advances/string indices/status per run
    /// verbatim, then builds the cluster and bidi maps.
    static func capture(
        _ ctLine: CTLine,
        lineIndex: Int,
        sourceText: String,
        sourceRange: Range<Int>,
        baseDirection: MKBaseDirection
    ) -> MKShapedLine {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)

        let ctRuns = (CTLineGetGlyphRuns(ctLine) as? [CTRun]) ?? []
        var runs: [MKShapedRun] = []
        runs.reserveCapacity(ctRuns.count)

        for ctRun in ctRuns {
            let glyphCount = CTRunGetGlyphCount(ctRun)
            guard glyphCount > 0 else { continue }
            let all = CFRange(location: 0, length: glyphCount)

            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            var advances = [CGSize](repeating: .zero, count: glyphCount)
            var indices = [CFIndex](repeating: 0, count: glyphCount)
            CTRunGetGlyphs(ctRun, all, &glyphs)
            CTRunGetPositions(ctRun, all, &positions)
            CTRunGetAdvances(ctRun, all, &advances)
            CTRunGetStringIndices(ctRun, all, &indices)

            let status = CTRunGetStatus(ctRun)
            let stringRange = CTRunGetStringRange(ctRun)
            let attributes = (CTRunGetAttributes(ctRun) as? [NSAttributedString.Key: Any]) ?? [:]

            // Core Text always resolves a concrete font onto the run
            // (ARCHITECTURE §4.4) ، the `unknown` fallback only guards the
            // case CTRunGetAttributes returns no `.font` entry at all (not
            // observed; kept defensive per task 11).
            let fontHandle: MKFontHandle
            // WS-16: glyph IDs in this run that are members of the run's
            // font's GPOS cursive-attachment (LookupType 3) coverage ،
            // computed here (not in a separate pass) since this is the one
            // place the real `CTFont` for the run is already in hand.
            var cursiveAttachedFlags = [Bool](repeating: false, count: glyphCount)
            if let fontAny = attributes[.font] {
                let font = fontAny as! CTFont
                let postScriptName = (CTFontCopyPostScriptName(font) as String?) ?? "unknown"
                fontHandle = MKFontHandle(postScriptName: postScriptName, pointSize: CTFontGetSize(font))
                let coverage = MKCursiveCoverageCache.shared.coveredGlyphs(for: font)
                if !coverage.isEmpty {
                    for i in 0..<glyphCount { cursiveAttachedFlags[i] = coverage.contains(UInt16(glyphs[i])) }
                }
            } else {
                fontHandle = MKFontHandle(postScriptName: "unknown", pointSize: 0)
            }

            // Resolved-attribute capture (T-TXT-10: tracking/baseline
            // survive into the captured structures).
            let tracking = (attributes[.kern] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let baselineShift = (attributes[.baselineOffset] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let ligatureValue = (attributes[.ligature] as? NSNumber)?.intValue ?? 1
            let resolvedAttributes = MKResolvedRunAttributes(
                tracking: tracking,
                baselineShift: baselineShift,
                standardLigaturesEnabled: ligatureValue != 0)

            // Hoisted, explicitly-typed locals: a denser inline initializer
            // call here previously crashed the Swift 6.3.3 type checker
            // ("failed to produce diagnostic") ، see docs/impl-log/WS-03.md.
            let glyphIDs: [UInt16] = glyphs.map { UInt16($0) }
            let stringIndexInts: [Int] = indices.map { Int($0) }
            let capturedRange: Range<Int> = stringRange.location..<(stringRange.location + stringRange.length)
            let isRTLRun: Bool = status.contains(.rightToLeft)
            let isNonMonotonicRun: Bool = status.contains(.nonMonotonic)

            let capturedRun = MKShapedRun(
                glyphs: glyphIDs,
                positions: positions,
                advances: advances,
                stringIndices: stringIndexInts,
                stringRange: capturedRange,
                isRTL: isRTLRun,
                isNonMonotonic: isNonMonotonicRun,
                font: fontHandle,
                attributes: resolvedAttributes,
                cursiveAttached: cursiveAttachedFlags)
            runs.append(capturedRun)
        }

        let sourceUTF16 = Array(sourceText.utf16)
        let clusterMap = MKClusterMapBuilder.build(runs: runs, sourceUTF16: sourceUTF16)
        let bidiMap = MKBidiMapBuilder.build(runs: runs, baseDirection: baseDirection)

        return MKShapedLine(
            runs: runs,
            typographicBounds: MKLineMetrics(ascent: ascent, descent: descent, leading: leading, width: width),
            clusterMap: clusterMap,
            bidiMap: bidiMap,
            lineIndexInParagraph: lineIndex,
            sourceRange: sourceRange,
            sourceText: sourceText)
    }
}
