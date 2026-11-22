import CoreText
import Foundation
import MKFoundation
import MKModel

/// Per-line semantic analysis bundled with a capture (WS-03 packet §5
/// task 13's `ShapingCaptureResult`).
public struct MKLineAnalysis: Hashable, Sendable {
    public var marks: [MKMarkAttachment]
    public var ligatures: [MKDetectedLigature]
    public var joining: [MKLetterJoining]

    public init(marks: [MKMarkAttachment], ligatures: [MKDetectedLigature], joining: [MKLetterJoining]) {
        self.marks = marks
        self.ligatures = ligatures
        self.joining = joining
    }
}

/// The full engine output WS-04 consumes at derivation time: the raw
/// capture plus every analyzer's result, computed once, per line.
public struct MKShapingCaptureResult: Hashable, Sendable {
    public var paragraph: MKShapedParagraph
    /// Index-parallel with `paragraph.lines`.
    public var lineAnalyses: [MKLineAnalysis]

    public init(paragraph: MKShapedParagraph, lineAnalyses: [MKLineAnalysis]) {
        self.paragraph = paragraph
        self.lineAnalyses = lineAnalyses
    }
}

/// The cached engine facade (WS-03 packet §5 task 13; ARCHITECTURE
/// §4.4/§4.7): an actor wrapping `MKShapingEngine` with an LRU cache keyed
/// on the full `MKShapingRequest` hash, cost-accounted at 64 bytes per
/// glyph with a 32 MB default limit. Signposts `typingEcho` (D-115, the
/// reserved `MKSignpost` vocabulary) around single-line shaping so WS-07's
/// device-level verification can measure the real path.
///
/// Cache invalidation events (ARCHITECTURE §4.7) wire up later:
/// `invalidateCache()` is the hook WS-09 calls on font re-registration and
/// WS-07 calls at memory-ladder stage ≥1 ، neither caller exists yet, the
/// hook does.
public actor MKShapingService {
    private let engine: MKShapingEngine
    private let costLimit: Int
    private var cache: [MKShapingRequest: MKShapedParagraph] = [:]
    private var order: [MKShapingRequest] = []   // LRU, most-recent last
    private var totalCost = 0
    private var hitCount = 0
    private var missCount = 0

    public init(fonts: MKFontProviding = SystemFontStubProvider(), costLimit: Int = 32 * 1024 * 1024) {
        self.engine = MKShapingEngine(fonts: fonts)
        self.costLimit = max(1, costLimit)
    }

    /// Shapes `request` (cached). Single-line requests are wrapped in the
    /// `typingEcho` signpost interval ، this is the path on the D-115
    /// <50 ms typing-echo budget.
    public func shape(_ request: MKShapingRequest) -> MKShapedParagraph {
        if let hit = cache[request] {
            hitCount += 1
            touch(request)
            return hit
        }
        missCount += 1

        let result: MKShapedParagraph
        if case .singleLine = request.frame {
            let signposter = MKSignpost.signposter
            let state = signposter.beginInterval("typingEcho")
            result = engine.shapeParagraph(request)
            signposter.endInterval("typingEcho", state)
        } else {
            result = engine.shapeParagraph(request)
        }

        insert(request, result)
        return result
    }

    /// Full capture + analyzers (WS-04's derivation input). The paragraph
    /// itself is served from/into the same cache as `shape(_:)`; analyses
    /// are computed fresh per call (cheap, O(clusters)).
    public func captureResult(_ request: MKShapingRequest) -> MKShapingCaptureResult {
        let paragraph = shape(request)
        // Joining is analyzed ONCE over the full logical text (letters at a
        // line-wrap boundary still join logically ، the analysis must not
        // see an artificial text edge there), then partitioned per line by
        // `sourceRange` so every reported `utf16Index` stays in the same
        // absolute (full-string) index space the cluster/bidi maps use.
        let allJoining = MKJoiningAnalyzer.analyze(text: paragraph.sourceText)
        let analyses = paragraph.lines.map { line in
            MKLineAnalysis(
                marks: MKMarkAttacher.attachments(in: line),
                ligatures: MKLigatureDetector.detect(in: line, activeSetting: request.style.ligatureSetting),
                joining: allJoining.filter { line.sourceRange.contains($0.utf16Index) })
        }
        return MKShapingCaptureResult(paragraph: paragraph, lineAnalyses: analyses)
    }

    /// Drops the shaping cache. ARCHITECTURE §4.7's invalidation hook:
    /// font re-registration (WS-09), memory-pressure ladder stage ≥1
    /// (WS-07), document close.
    public func invalidateCache() {
        cache.removeAll()
        order.removeAll()
        totalCost = 0
    }

    /// (hits, misses) ، test observability for the cache-behavior gates.
    public func cacheCounters() -> (hits: Int, misses: Int) {
        (hitCount, missCount)
    }

    // MARK: - LRU bookkeeping (cost = glyphCount × 64 bytes, §4.7)

    private func cost(of paragraph: MKShapedParagraph) -> Int {
        paragraph.glyphCount * 64
    }

    private func touch(_ key: MKShapingRequest) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
            order.append(key)
        }
    }

    private func insert(_ key: MKShapingRequest, _ value: MKShapedParagraph) {
        cache[key] = value
        order.append(key)
        totalCost += cost(of: value)
        while totalCost > costLimit, !order.isEmpty {
            let evicted = order.removeFirst()
            if let evictedValue = cache.removeValue(forKey: evicted) {
                totalCost -= cost(of: evictedValue)
            }
        }
    }
}
