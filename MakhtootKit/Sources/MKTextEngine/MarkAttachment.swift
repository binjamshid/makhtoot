import CoreGraphics
import Foundation
import MKModel

/// One resolved mark → base attachment (ARCHITECTURE §5.1 step 2 / §6.3),
/// captured at the cluster-map layer (full `MKMarkNode` ، with transform,
/// style, stacking ، is an MKArrange/P5 concern; this is the raw geometric
/// fact D-105 asks the engine to capture: "relative offset (GPOS result
/// captured from shaped positions)").
///
/// P3-completion note: `relativeOffset` is a `CGSize` (matching
/// `MKMarkNode.relativeOffset`'s type exactly, for frictionless WS-04
/// handoff) and `markClass` is MKModel's `MKMarkClass`.
public struct MKMarkAttachment: Hashable, Sendable {
    /// Index into the owning line's `clusterMap.clusters` for the mark.
    public var markClusterIndex: Int
    /// The mark's own glyph, when it has a distinct one. `nil` when Core
    /// Text fused the mark into its base's glyph (a `.baseWithMarks`
    /// cluster with only one glyph total ، observed for shadda in this
    /// engine's fixture captures, see docs/impl-log/WS-03.md ADR
    /// WS03-A3). D-105 still requires the mark be recorded ("no mark is
    /// orphaned") even without a distinct offset.
    public var markGlyph: MKGlyphAddress?
    /// Index into `clusterMap.clusters` for the resolved base cluster.
    /// `nil` = a free mark (§6.3: no preceding base exists at all, e.g. a
    /// standalone tashkeel typed after whitespace or at string start).
    public var baseClusterIndex: Int?
    /// The base glyph the mark is positioned relative to.
    public var baseGlyph: MKGlyphAddress?
    /// `markPosition − basePosition`, both taken directly from
    /// `MKShapedRun.positions` in the same shaped-line (line-local)
    /// coordinate frame ، this **is** the GPOS `mark`/`mkmk` anchoring
    /// result by construction (D-105), no anchor-table parsing performed.
    /// `nil` exactly when `markGlyph` is `nil` (no distinct glyph to
    /// measure).
    public var relativeOffset: CGSize?
    public var markClass: MKMarkClass?

    public init(
        markClusterIndex: Int,
        markGlyph: MKGlyphAddress?,
        baseClusterIndex: Int?,
        baseGlyph: MKGlyphAddress?,
        relativeOffset: CGSize?,
        markClass: MKMarkClass?
    ) {
        self.markClusterIndex = markClusterIndex
        self.markGlyph = markGlyph
        self.baseClusterIndex = baseClusterIndex
        self.baseGlyph = baseGlyph
        self.relativeOffset = relativeOffset
        self.markClass = markClass
    }
}

/// Resolves every mark in a shaped line to its base, per §6.3: "the base is
/// the nearest preceding non-mark glyph"; walks backward across cluster
/// boundaries (and run boundaries ، clusters are already in logical order
/// in `clusterMap.clusters`) since Core Text frequently gives a mark its
/// own `.markOnly` cluster distinct from its base's cluster (empirically
/// the common case for harakat against system SF Arabic ، see
/// docs/impl-log/WS-03.md session log for the captured evidence this
/// implementation is based on, superseding the packet's illustrative
/// "same cluster" phrasing where the two differ).
public enum MKMarkAttacher {
    public static func attachments(in line: MKShapedLine) -> [MKMarkAttachment] {
        let clusters = line.clusterMap.clusters
        var results: [MKMarkAttachment] = []

        for (clusterIndex, cluster) in clusters.enumerated() {
            switch cluster.kind {
            case .markOnly:
                let markScalar = cluster.codepoints.first.flatMap(Unicode.Scalar.init)
                let base = Self.nearestPrecedingBase(before: clusterIndex, in: clusters)
                let markGlyph = cluster.glyphs.first
                var offset: CGSize?
                if let markGlyph, let base, let baseGlyph = base.glyph {
                    let markPos = line.runs[markGlyph.run].positions[markGlyph.glyph]
                    let basePos = line.runs[baseGlyph.run].positions[baseGlyph.glyph]
                    offset = CGSize(width: markPos.x - basePos.x, height: markPos.y - basePos.y)
                }
                results.append(MKMarkAttachment(
                    markClusterIndex: clusterIndex,
                    markGlyph: markGlyph,
                    baseClusterIndex: base?.clusterIndex,
                    baseGlyph: base?.glyph,
                    relativeOffset: offset,
                    markClass: markScalar.flatMap(MKMarkClassifier.classify)))

            case .baseWithMarks:
                // The base and its mark(s) share one cluster but Core Text
                // fused them into a single glyph (no distinct mark glyph to
                // offset) ، still enumerate each mark codepoint so callers
                // can count every mark without loss (D-105 "no mark is
                // orphaned"); base is this same cluster.
                for codepoint in cluster.codepoints {
                    guard let scalar = Unicode.Scalar(codepoint), MKMarkClassifier.isMark(scalar) else { continue }
                    results.append(MKMarkAttachment(
                        markClusterIndex: clusterIndex,
                        markGlyph: nil,
                        baseClusterIndex: clusterIndex,
                        baseGlyph: cluster.glyphs.first,
                        relativeOffset: nil,
                        markClass: MKMarkClassifier.classify(scalar)))
                }

            case .simple, .ligature, .control:
                continue
            }
        }
        return results
    }

    private static func nearestPrecedingBase(
        before index: Int,
        in clusters: [MKCluster]
    ) -> (clusterIndex: Int, glyph: MKGlyphAddress?)? {
        var i = index - 1
        while i >= 0 {
            switch clusters[i].kind {
            case .simple, .ligature, .baseWithMarks:
                return (i, clusters[i].glyphs.first)
            case .markOnly, .control:
                i -= 1
            }
        }
        return nil
    }
}
