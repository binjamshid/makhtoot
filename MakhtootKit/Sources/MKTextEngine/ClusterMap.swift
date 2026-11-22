import Foundation
import MKFoundation

/// One cluster: the unit D-105 defines as "codepoint index ↔ cluster ↔
/// glyph(s)". See `MKClusterMapBuilder` for the construction algorithm.
///
/// P3-completion note: `id` is now the real `MKFoundation.MKClusterID`
/// (UUID phantom type ، the durable key `MKProvenance.clusterID` stores),
/// minted fresh per cluster at capture time. The maps below key on the
/// cluster's array **ordinal** (index into `MKClusterMap.clusters`), which
/// is the cheap capture-local join key; `id` is what survives into
/// MKModel provenance when WS-04 derives an `ArrangedComposition`.
public struct MKCluster: Hashable, Sendable {
    /// Mirrors ARCHITECTURE.md §4.5's `MKCluster.Kind` exactly (the
    /// "1 codepoint → N glyphs" rare case from packet task 6d is *not* a
    /// separate kind ، ARCHITECTURE §4.5's correctness caveat treats it as
    /// a `.simple` cluster whose `glyphs` array simply has more than one
    /// entry; "the table never assumes 1:1 anywhere". Verified against a
    /// real capture ، see docs/impl-log/WS-03.md, "به" fixture).
    public enum Kind: Hashable, Sendable {
        /// 1 non-mark codepoint → 1 or more glyphs, no combining marks.
        case simple
        /// >1 non-mark codepoint → exactly 1 glyph (ligature candidate,
        /// e.g. lam-alif ، D-105).
        case ligature
        /// ≥1 non-mark codepoint plus ≥1 mark codepoint sharing this
        /// cluster (marks may or may not have their own glyph within the
        /// cluster ، font-dependent, see `MKMarkAttacher`).
        case baseWithMarks(baseCount: Int)
        /// All codepoints in the cluster are marks; no base letter shares
        /// it (base resolution walks to the nearest preceding cluster ،
        /// §6.3 "free mark" case when no preceding base exists at all).
        case markOnly
        /// All codepoints are ZWJ/ZWNJ/bidi-control formatting characters
        /// (`MKMarkClassifier.isControlFormatter`). Dropped from
        /// renderable children downstream; retained here so revert/
        /// Unicode-level editing still sees them (§5.1 step 2).
        case control
    }

    /// Durable id (MKFoundation `MKClusterID`, UUID-backed) ، the value
    /// WS-04 writes into `MKProvenance.clusterID`.
    public var id: MKClusterID
    /// UTF-16 range in the shaped line's source text.
    public var utf16Range: Range<Int>
    /// Scalars in `utf16Range`, logical (source) order.
    public var codepoints: [UInt32]
    /// Every glyph realizing this cluster, in the order they were found
    /// while scanning the owning run (not guaranteed logical order for
    /// multi-glyph clusters ، callers needing logical sub-order should not
    /// assume one; none of this module's consumers do).
    public var glyphs: [MKGlyphAddress]
    public var kind: Kind

    public init(id: MKClusterID = MKClusterID(), utf16Range: Range<Int>, codepoints: [UInt32], glyphs: [MKGlyphAddress], kind: Kind) {
        self.id = id
        self.utf16Range = utf16Range
        self.codepoints = codepoints
        self.glyphs = glyphs
        self.kind = kind
    }
}

/// D-105's bidirectional map: codepoint index ↔ cluster ↔ glyph(s).
public struct MKClusterMap: Hashable, Sendable {
    /// Logical order (ascending `utf16Range.lowerBound`) ، this is what
    /// makes cross-run bidi reordering transparent to consumers walking
    /// `clusters` in array order (ARCHITECTURE §4.5 step 5: "Assign
    /// ClusterID per (line, logical start index)").
    public var clusters: [MKCluster]
    /// Every glyph address that belongs to some cluster → index into
    /// `clusters`.
    public var glyphToCluster: [MKGlyphAddress: Int]
    /// Every UTF-16 index covered by some cluster → index into `clusters`.
    public var utf16ToCluster: [Int: Int]
}

/// D-105 cluster-map construction (WS-03 packet §5 task 6). Algorithm,
/// matching ARCHITECTURE.md §4.5 exactly:
///
/// 1. Collect `(address, stringIndex)` for every glyph in every run.
/// 2. Within each run, group glyphs sharing the same `stringIndex` ، that
///    shared value is `CTRunGetStringIndices`' "first codepoint of this
///    glyph's cluster". The **set of distinct string indices in the run**,
///    sorted ascending, defines cluster boundaries *within that run*: for
///    RTL runs the glyph array is visually left-to-right while string
///    indices *descend* through it, so sorting by value (not glyph-array
///    position) is what restores logical order ، never assume glyph order
///    reflects logical order.
/// 3. A cluster spans `[distinctIndex, nextDistinctIndex)`; the last
///    cluster in a run spans to `CTRunGetStringRange`'s upper bound.
/// 4. Once every run's raw clusters are collected, sort ALL of them by
///    `utf16Range.lowerBound` ascending ، this is what makes the final
///    `clusters` array logical-order even when runs themselves appear in
///    visual (bidi-reordered) order in the source `MKShapedRun` array.
/// 5. Decode `codepoints` for each range directly from the source text's
///    UTF-16 view (surrogate-pair aware).
/// 6. Classify `kind` per `MKCluster.Kind`'s doc comments.
public enum MKClusterMapBuilder {
    public static func build(runs: [MKShapedRun], sourceUTF16: [UInt16]) -> MKClusterMap {
        struct RawCluster {
            var startIndex: Int
            var endIndex: Int
            var glyphs: [MKGlyphAddress]
        }

        var raw: [RawCluster] = []
        for (runIndex, run) in runs.enumerated() {
            guard !run.glyphs.isEmpty else { continue }
            var byStringIndex: [Int: [Int]] = [:]   // stringIndex -> glyph indices within this run
            for glyphIndex in run.glyphs.indices {
                byStringIndex[run.stringIndices[glyphIndex], default: []].append(glyphIndex)
            }
            let sortedKeys = byStringIndex.keys.sorted()
            for (position, key) in sortedKeys.enumerated() {
                let nextBoundary = (position + 1 < sortedKeys.count) ? sortedKeys[position + 1] : run.stringRange.upperBound
                let end = max(nextBoundary, key + 1)
                let addresses = (byStringIndex[key] ?? []).map { MKGlyphAddress(run: runIndex, glyph: $0) }
                raw.append(RawCluster(startIndex: key, endIndex: end, glyphs: addresses))
            }
        }

        // Logical order across runs (step 4 above) ، the crux of D-105's
        // "for an RTL run, glyph order is visually LTR but string indices
        // descend; sorting by string index restores logical order".
        raw.sort { $0.startIndex < $1.startIndex }

        var clusters: [MKCluster] = []
        clusters.reserveCapacity(raw.count)
        var glyphToCluster: [MKGlyphAddress: Int] = [:]
        var utf16ToCluster: [Int: Int] = [:]

        for rc in raw {
            let range = rc.startIndex..<min(rc.endIndex, sourceUTF16.count)
            guard !range.isEmpty else { continue }
            let scalars = Self.scalars(in: range, of: sourceUTF16)
            let kind = Self.classify(codepoints: scalars, glyphCount: rc.glyphs.count)
            let clusterIndex = clusters.count
            clusters.append(MKCluster(
                utf16Range: range,
                codepoints: scalars.map(\.value),
                glyphs: rc.glyphs,
                kind: kind))
            for address in rc.glyphs { glyphToCluster[address] = clusterIndex }
            for utf16Index in range { utf16ToCluster[utf16Index] = clusterIndex }
        }

        return MKClusterMap(clusters: clusters, glyphToCluster: glyphToCluster, utf16ToCluster: utf16ToCluster)
    }

    /// Decodes the scalars covered by `range` from the source text's raw
    /// UTF-16 units, surrogate-pair aware.
    static func scalars(in range: Range<Int>, of utf16: [UInt16]) -> [Unicode.Scalar] {
        guard range.lowerBound >= 0, range.upperBound <= utf16.count, !range.isEmpty else { return [] }
        var result: [Unicode.Scalar] = []
        var codec = UTF16()
        var iterator = utf16[range].makeIterator()
        loop: while true {
            switch codec.decode(&iterator) {
            case .scalarValue(let scalar): result.append(scalar)
            case .emptyInput: break loop
            case .error: break loop   // malformed input (unpaired surrogate) ، stop rather than crash; D-105 makes no well-formedness guarantee beyond what CT itself accepted
            }
        }
        return result
    }

    /// Classification per `MKCluster.Kind` (ARCHITECTURE §4.5 step 5).
    static func classify(codepoints: [Unicode.Scalar], glyphCount: Int) -> MKCluster.Kind {
        guard !codepoints.isEmpty else { return .control }
        if codepoints.allSatisfy(MKMarkClassifier.isControlFormatter) { return .control }

        let nonMarkCount = codepoints.filter { !MKMarkClassifier.isMark($0) }.count
        let markCount = codepoints.count - nonMarkCount

        if nonMarkCount > 1 && glyphCount == 1 {
            return .ligature
        }
        if nonMarkCount == 0 && markCount > 0 {
            return .markOnly
        }
        if nonMarkCount >= 1 && markCount > 0 {
            return .baseWithMarks(baseCount: nonMarkCount)
        }
        return .simple
    }
}
