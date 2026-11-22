import CoreGraphics
import Foundation
import MKFoundation

// WS-02 packet §5 task 4. The arranged structure itself: an ordered set of
// Glyph/Mark/Ligature nodes in visual order, plus the retained source
// backup and the arrangement's origin frame ، "nodes in visual order,
// sourceBackup: SourceTextBackup, origin frame" per the packet's literal
// task-4 field list.
//
// Deliberately out of scope for this packet (logged, not silently
// dropped): ARCHITECTURE.md §3.4's illustrative `MKArrangedTextNode` also
// carries a composition-wide `clusterTable: [MKClusterRecord]` and a
// `bidi: MKBidiSnapshot`. This packet's task 4 does not list either as a
// deliverable, and every field D-106 requires for the "both levels /
// switching loses nothing" contract is already present *per node* via
// `MKProvenance` (clusterID, codepoints, bidiLevel, visualIndex,
// logicalIndex) ، so no information is lost by omitting the composition-
// wide index structures. WS-04 (`MKArrange`, which builds and consumes
// these compositions) can add `clusterTable`/`bidi` as new, defaulted,
// additive fields later without a `schemaVersion` bump if cross-cluster
// codepoint mapping turns out to need a dedicated index beyond per-node
// provenance.

/// One arranged child ، the closed set D-111 requires (glyph/mark/ligature,
/// NOT plain `MKNode`, because these carry provenance/joining metadata
/// regular nodes do not).
public enum MKArrangedChild: Hashable, Sendable, Codable, Identifiable, Equatable {
    case glyph(MKGlyphNode)
    case mark(MKMarkNode)
    case ligature(MKLigatureGroup)

    public var id: MKNodeID {
        switch self {
        case .glyph(let n): return n.id
        case .mark(let n): return n.id
        case .ligature(let n): return n.id
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, glyph, mark, ligature }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "glyph": self = .glyph(try container.decode(MKGlyphNode.self, forKey: .glyph))
        case "mark": self = .mark(try container.decode(MKMarkNode.self, forKey: .mark))
        case "ligature": self = .ligature(try container.decode(MKLigatureGroup.self, forKey: .ligature))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container,
                debugDescription: "Unknown MKArrangedChild kind '\(kind)'"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .glyph(let n):
            try container.encode("glyph", forKey: .kind)
            try container.encode(n, forKey: .glyph)
        case .mark(let n):
            try container.encode("mark", forKey: .kind)
            try container.encode(n, forKey: .mark)
        case .ligature(let n):
            try container.encode("ligature", forKey: .kind)
            try container.encode(n, forKey: .ligature)
        }
    }
}

/// The frozen, non-reflowing structure an Arrange Mode derivation produces
/// (D-106, glossary: "Arranged Composition"). Task 4's literal field list:
/// "nodes in visual order, sourceBackup: SourceTextBackup, origin frame".
public struct ArrangedComposition: Hashable, Sendable, Codable, Equatable {
    /// Children in visual (paint) order at derivation time. Z-order among
    /// them is index order, same convention as `MKScene.nodes`.
    public var nodes: [MKArrangedChild]
    public var sourceBackup: MKSourceTextBackup
    /// The composition's bounding frame at derivation, in the owning
    /// `MKArrangedTextNode`'s local space ، the anchor every child's
    /// `layout.position`/`relativeOffset` is measured against.
    public var originFrame: CGRect

    public init(nodes: [MKArrangedChild], sourceBackup: MKSourceTextBackup, originFrame: CGRect) {
        self.nodes = nodes
        self.sourceBackup = sourceBackup
        self.originFrame = originFrame
    }

    /// Convenience find-by-id over `nodes` (linear ، compositions are
    /// bounded by a single text object's glyph count, not scene-wide node
    /// counts, so `MKNodeIndex`'s scene-level indexing doesn't apply here).
    public func child(id: MKNodeID) -> MKArrangedChild? {
        nodes.first { $0.id == id }
    }
}

/// What an Arranged Composition was derived from (D-106/D-110): a plain
/// Live Text object, or a Path Text object (the frozen path is retained so
/// per-glyph path-tangent context is still inspectable after arrangement).
public enum MKArrangeOrigin: Hashable, Sendable, Codable, Equatable {
    case liveText
    case pathText(MKBezierPathData)
}

/// The `arranged` `MKNode` case's payload: node header + the arranged
/// structure. Equivalent to ARCHITECTURE.md §3.4's `MKArrangedTextNode`
/// (same name kept ، the packet's own §8 deliverables list and §11
/// traceability table both refer to this node type as "arranged" /
/// `MKArrangedTextNode"-shaped without proposing a different name).
public struct MKArrangedTextNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var composition: ArrangedComposition
    public var derivedFrom: MKArrangeOrigin

    public init(core: MKNodeCore, composition: ArrangedComposition, derivedFrom: MKArrangeOrigin) {
        self.core = core
        self.composition = composition
        self.derivedFrom = derivedFrom
    }
}
