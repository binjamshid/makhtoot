import Foundation
import MKFoundation
import MKModel

// WS-04 packet §5 task 5: glyph-level ↔ Unicode-letter-level mapping
// utilities. Both editing levels (§5.2 of ARCHITECTURE) address the SAME
// underlying children through `MKProvenance` ، a level switch is a VIEW
// change over one retained `ArrangedComposition`, never a data conversion,
// so nothing is lost switching either direction (BRIEF requirement).

/// One flattened, addressable element of an `ArrangedComposition` ، the
/// shared lookup this whole module needs repeatedly (`LevelMapping`,
/// `JoinController`, `LigatureDecomposer`, `MarkAttachmentController`).
/// Flattens a `.decomposed` `MKLigatureGroup`'s components into the same id
/// space as top-level children, mirroring `MKRender`'s own
/// `MKArrangedGeometry.Index` flattening rule exactly (documented there as
/// the judgment call this module inherits, not reinvents) ، but `MKArrange`
/// does not depend on `MKRender`, so this is an independent, small
/// re-implementation for the one thing this module needs from it:
/// id → (provenance, kind) lookup, not full geometry.
public struct ArrangedCompositionIndex: Sendable {
    public enum Kind: Sendable {
        case glyph
        case composedLigature
        case decomposedLigatureComponent(groupID: MKNodeID)
        case mark
    }

    public struct Entry: Sendable {
        public var id: MKNodeID
        public var provenance: MKProvenance
        public var kind: Kind
        public var attachedTo: MKNodeID?
    }

    public private(set) var entries: [MKNodeID: Entry] = [:]
    /// Top-level composition order (NOT flattened ، one entry per
    /// `MKArrangedChild`, `.ligature` included even when decomposed) for
    /// callers that need to walk `composition.nodes` structurally.
    public let composition: ArrangedComposition

    public init(_ composition: ArrangedComposition) {
        self.composition = composition
        for child in composition.nodes {
            switch child {
            case .glyph(let g):
                entries[g.id] = Entry(id: g.id, provenance: g.provenance, kind: .glyph, attachedTo: nil)
            case .mark(let m):
                entries[m.id] = Entry(id: m.id, provenance: m.provenance, kind: .mark, attachedTo: m.attachedTo)
            case .ligature(let group):
                switch group.state {
                case .composed:
                    entries[group.id] = Entry(id: group.id, provenance: group.provenance, kind: .composedLigature, attachedTo: nil)
                case .decomposed(let d):
                    for component in d.components {
                        entries[component.id] = Entry(id: component.id, provenance: component.provenance, kind: .decomposedLigatureComponent(groupID: group.id), attachedTo: nil)
                    }
                }
            }
        }
    }

    public func entry(id: MKNodeID) -> Entry? { entries[id] }
    public func isMark(_ id: MKNodeID) -> Bool {
        if case .mark = entries[id]?.kind { return true }
        return false
    }
}

public enum LevelMapping {
    /// Letter level → node set (packet task 5). `range` is a UTF-16 range
    /// into `composition.sourceBackup.sourceString`. Every child whose OWN
    /// provenance range overlaps `range` is included (glyph, ligature, or a
    /// mark whose own codepoint was explicitly in range); when
    /// `includeMarks` is `true`, marks ATTACHED to an included base are
    /// additionally pulled in even if the mark's own codepoint fell outside
    /// `range` ، this is the literal "selecting fatha's base letter
    /// includes the base but not the mark... with `includeMarks` toggling
    /// it" accept criterion: selecting just the base letter's own span
    /// never implicitly covers the mark's span, so the flag is what adds
    /// it, not range containment.
    public static func nodeIDs(forUTF16Range range: Range<Int>, in composition: ArrangedComposition, includeMarks: Bool = true) -> Set<MKNodeID> {
        let index = ArrangedCompositionIndex(composition)
        var result: Set<MKNodeID> = []
        for (id, entry) in index.entries {
            let entryRange = entry.provenance.utf16Start..<(entry.provenance.utf16Start + entry.provenance.utf16Length)
            if rangesOverlap(entryRange, range) {
                result.insert(id)
            }
        }
        if includeMarks {
            for (id, entry) in index.entries {
                if case .mark = entry.kind, let base = entry.attachedTo, result.contains(base) {
                    result.insert(id)
                }
            }
        }
        return result
    }

    /// Node set → covering codepoint ranges (letter level, packet task 5's
    /// reverse direction). Adjacent/overlapping per-node ranges are merged
    /// into the minimal covering set, sorted ascending.
    public static func utf16Ranges(forNodeIDs ids: Set<MKNodeID>, in composition: ArrangedComposition) -> [Range<Int>] {
        let index = ArrangedCompositionIndex(composition)
        var raw: [Range<Int>] = []
        for id in ids {
            guard let entry = index.entry(id: id) else { continue }
            raw.append(entry.provenance.utf16Start..<(entry.provenance.utf16Start + entry.provenance.utf16Length))
        }
        return Self.mergeRanges(raw)
    }

    /// Convenience: the node set for a single node id, expanded to every
    /// OTHER node sharing the same `MKProvenance.clusterID` (glyphs of a
    /// multi-glyph `.simple` cluster, or a base + its fused marks) ، used
    /// by callers that select "the whole cluster" from one hit-tested
    /// child.
    public static func clusterSiblings(of id: MKNodeID, in composition: ArrangedComposition) -> Set<MKNodeID> {
        let index = ArrangedCompositionIndex(composition)
        guard let clusterID = index.entry(id: id)?.provenance.clusterID else { return [id] }
        return Set(index.entries.values.filter { $0.provenance.clusterID == clusterID }.map(\.id))
    }

    private static func rangesOverlap(_ a: Range<Int>, _ b: Range<Int>) -> Bool {
        a.lowerBound < b.upperBound && b.lowerBound < a.upperBound
    }

    private static func mergeRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges.filter { !$0.isEmpty }.sorted { $0.lowerBound < $1.lowerBound }
        guard !sorted.isEmpty else { return [] }
        var merged: [Range<Int>] = [sorted[0]]
        for range in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            if range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
