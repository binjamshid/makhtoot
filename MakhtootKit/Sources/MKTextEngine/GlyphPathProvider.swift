import CoreText
import CoreGraphics
import Foundation
import MKFoundation
import MKModel

/// WS-03 packet §5 task 12: glyph outline extraction
/// (`CTFontCreatePathForGlyph`) into MKModel's `MKPathData` (the flat,
/// 1000/em-normalized command stream `MKGlyphNode.outline` persists ،
/// INV-13's lock-resilient representation), with an LRU cache keyed
/// (font handle, glyph id).
///
/// Actor-isolated (D-102): the cache is mutable state; `CTFont` handles
/// never escape.
public actor MKGlyphPathProvider {
    public struct CacheStats: Sendable, Equatable {
        public var hits: Int
        public var misses: Int
    }

    private struct Key: Hashable {
        var postScriptName: String
        var pointSize: CGFloat
        var glyphID: UInt16
    }

    private let fonts: MKFontProviding
    private let capacity: Int
    private var cache: [Key: MKPathData] = [:]
    private var order: [Key] = []   // LRU order, most-recent last
    private var stats = CacheStats(hits: 0, misses: 0)

    public init(fonts: MKFontProviding = SystemFontStubProvider(), capacity: Int = 512) {
        self.fonts = fonts
        self.capacity = max(1, capacity)
    }

    /// The outline for `glyphID` in the font `handle` resolves to,
    /// normalized to 1000/em glyph space (render at any size via
    /// `MKPathData.cgPath(at:)`). Returns `nil` for glyphs with no outline
    /// (whitespace, zero-width controls) ، an empty path is normalized to
    /// `nil` so callers can distinguish "no visual" without probing
    /// command streams.
    public func path(for glyphID: UInt16, font handle: MKFontHandle) -> MKPathData? {
        let key = Key(postScriptName: handle.postScriptName, pointSize: handle.pointSize, glyphID: glyphID)
        if let hit = cache[key] {
            stats.hits += 1
            touch(key)
            return hit.commands.isEmpty ? nil : hit
        }
        stats.misses += 1
        let ctFont = fonts.resolve(handle)
        let extracted: MKPathData
        if let cgPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyphID), nil) {
            extracted = MKPathData.from(cgPath, pointSize: Double(CTFontGetSize(ctFont)))
        } else {
            extracted = MKPathData(commands: [])   // negative-cache glyphs with no outline
        }
        insert(key, extracted)
        return extracted.commands.isEmpty ? nil : extracted
    }

    /// Cache statistics (test observability ، the packet's "cache hit
    /// test" accept criterion).
    public func cacheStats() -> CacheStats { stats }

    /// Drops every cached outline (font re-registration / memory-pressure
    /// hook ، wired by WS-09/WS-07 when those exist).
    public func invalidate() {
        cache.removeAll()
        order.removeAll()
    }

    // MARK: - LRU bookkeeping

    private func touch(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
            order.append(key)
        }
    }

    private func insert(_ key: Key, _ value: MKPathData) {
        cache[key] = value
        order.append(key)
        while order.count > capacity {
            let evicted = order.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}
