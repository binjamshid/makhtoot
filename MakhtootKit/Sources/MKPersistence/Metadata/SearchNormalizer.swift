import Foundation
import MKModel

// WS-02 packet §5 tasks 15/16. Arabic-normalized project search.
//
// *** Reported conflict, not silently resolved ، see docs/impl-log/WS-02.md
// ADR WS02-A3 for the full writeup. *** Packet task 16 literally asks for
// search text extraction to "walk scene for liveText/pathText source
// strings + SourceTextBackup strings of arranged nodes" ، i.e. index scene
// TEXT CONTENT. That directly contradicts FOUNDATION.md D-112 as amended
// (quoted verbatim by this run's own orchestrator instructions): "SwiftData
// metadata index with titles+layer-names-only search text... search text
// (project titles + layer names only ، never scene text content)."
// FOUNDATION.md governs over any deliverable that contradicts it (its own
// §0 preamble). This implementation follows the LOCKED decision
// (titles + layer names only) and does NOT extract live-text/arranged
// source strings into `MKProjectRecord.searchText` ، see
// `SearchTextExtractor.swift`. Task 16's literal accept criterion
// ("arranged-only project findable by 'بسم'" via CONTENT search) is
// therefore NOT implemented as literally worded; §13.6's own model comment
// independently confirms the locked behavior: "full-text search across
// project *content*... is performed by streaming decode... on demand...
// NOT persisted to SwiftData... to honor INV-14" ، i.e. content search is
// explicitly an on-demand, non-indexed, out-of-SwiftData feature, which
// this packet does not implement (no consumer/UI exists yet to drive it;
// WS-13's project browser is the natural owner of that on-demand path).

/// Arabic-aware normalization for search matching (task 15 accept
/// criterion's exact rule): strips tashkeel U+064B–U+0652, and unifies
/// ا/أ/إ/آ → ا, ة → ه, ى → ي, before lowercasing (for any incidental
/// Latin/mixed content in a title).
public enum SearchNormalizer {
    public static func normalize(_ input: String) -> String {
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(input.unicodeScalars.count)
        for scalar in input.unicodeScalars {
            if (0x064B...0x0652).contains(scalar.value) { continue } // strip tashkeel
            scalars.append(unify(scalar))
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    private static func unify(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar.value {
        case 0x0623, 0x0625, 0x0622: return Unicode.Scalar(0x0627)! // أ إ آ → ا
        case 0x0629: return Unicode.Scalar(0x0647)! // ة → ه
        case 0x0649: return Unicode.Scalar(0x064A)! // ى → ي
        default: return scalar
        }
    }

    public static func matches(query: String, in text: String) -> Bool {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return true }
        return normalize(text).contains(normalizedQuery)
    }
}

/// Builds `MKProjectRecord.searchText` (task 16) ، title + every node's
/// `core.name` (recursively, including into groups), normalized. Never
/// includes `MKLiveTextNode.text.string`, `MKPathTextNode.text.string`, or
/// `MKArrangedTextNode.composition.sourceBackup.sourceString` ، see this
/// file's top-of-file note for why (D-112 as amended, INV-14).
public enum SearchTextExtractor {
    public static func extract(scene: MKScene, title: String) -> String {
        var parts: [String] = [title]
        parts.append(scene.background.core.name)
        for node in scene.nodes { collectNames(node, into: &parts) }
        return SearchNormalizer.normalize(parts.joined(separator: " "))
    }

    private static func collectNames(_ node: MKNode, into parts: inout [String]) {
        parts.append(node.core.name)
        if case .group(let g) = node {
            for child in g.children { collectNames(child, into: &parts) }
        }
    }
}
