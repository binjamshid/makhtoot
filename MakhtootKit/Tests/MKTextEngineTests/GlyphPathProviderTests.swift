import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKTextEngine

/// WS-03 packet §5 task 12: glyph outline provider + LRU cache.
@Suite struct GlyphPathProviderTests {

    @Test func lamAlifOutlineIsNonEmpty() async {
        // Packet accept: "path for lam-alif glyph non-empty."
        let line = Fixtures.shape("لا")
        guard
            let cluster = line.clusterMap.clusters.first,
            let address = cluster.glyphs.first
        else {
            Issue.record("no lam-alif glyph captured")
            return
        }
        let glyphID = line.runs[address.run].glyphs[address.glyph]
        let fontHandle = line.runs[address.run].font

        let provider = MKGlyphPathProvider()
        let path = await provider.path(for: glyphID, font: fontHandle)
        #expect(path != nil)
        if let path {
            #expect(!path.commands.isEmpty)
            #expect(path.unitsPerEm == 1000, "outlines normalize to 1000/em (INV-13 / MKPathData convention)")
            let cgPath = path.cgPath(at: 36)
            #expect(!cgPath.boundingBox.isEmpty)
        }
    }

    @Test func repeatLookupHitsTheCache() async {
        // Packet accept: "cache hit test."
        let line = Fixtures.shape("لا")
        guard let address = line.clusterMap.clusters.first?.glyphs.first else {
            Issue.record("no glyph captured")
            return
        }
        let glyphID = line.runs[address.run].glyphs[address.glyph]
        let fontHandle = line.runs[address.run].font

        let provider = MKGlyphPathProvider()
        let first = await provider.path(for: glyphID, font: fontHandle)
        let second = await provider.path(for: glyphID, font: fontHandle)
        #expect(first == second)

        let stats = await provider.cacheStats()
        #expect(stats.misses == 1)
        #expect(stats.hits == 1)
    }

    @Test func lruEvictsBeyondCapacity() async {
        let provider = MKGlyphPathProvider(capacity: 2)
        let line = Fixtures.shape("محمد")
        let handle = line.runs[0].font
        let glyphs = line.runs.flatMap(\.glyphs)
        #expect(glyphs.count >= 3)

        // Fill beyond capacity, then re-request the first glyph ، it must
        // have been evicted (a miss, not a hit).
        for glyph in glyphs.prefix(3) {
            _ = await provider.path(for: glyph, font: handle)
        }
        let beforeStats = await provider.cacheStats()
        _ = await provider.path(for: glyphs[0], font: handle)
        let afterStats = await provider.cacheStats()
        #expect(afterStats.misses == beforeStats.misses + 1, "capacity-2 cache must have evicted the first of three entries")
    }

    @Test func glyphWithNoOutlineReturnsNilConsistently() async {
        // A space's glyph has no outline; both the fresh and the cached
        // path must come back nil (negative caching).
        let line = Fixtures.shape("ا ب")
        // Find the space's glyph via its cluster (utf16 index 1).
        guard
            let clusterIndex = line.clusterMap.utf16ToCluster[1],
            let address = line.clusterMap.clusters[clusterIndex].glyphs.first
        else {
            Issue.record("space glyph not found")
            return
        }
        let glyphID = line.runs[address.run].glyphs[address.glyph]
        let handle = line.runs[address.run].font

        let provider = MKGlyphPathProvider()
        let first = await provider.path(for: glyphID, font: handle)
        let second = await provider.path(for: glyphID, font: handle)
        #expect(first == nil)
        #expect(second == nil)
    }
}
