import Testing
import CoreGraphics
@testable import MKTextEngine

/// T-TXT-2 (TEST_MATRIX.md §5): "codepoint ↔ cluster ↔ glyph map is total
/// and invertible." Also covers WS-03 packet §5 task 6's accept criteria
/// ("لا" one cluster/2cp/1glyph/ligature; "به" two clusters; round trip).
@Suite struct ClusterMapTests {

    // MARK: - Totality + invertibility (the core D-105 guarantee)

    @Test(arguments: [
        "لا إله إلا الله", "مُحَمَّدٌ", "عام 2026", "شَدَّةٌ", "بِسۡمِ ٱللَّهِ",
        "عام ٢٠٢٦ ميلادي", "سعر 3$ فقط", "Makhtoot مخطوط", "مـحـمـد",
        "به", "بَ", "بِ", "الله", "\u{064B}", "م\u{200C}ي",
    ])
    func clusterMapIsTotalAndInvertible(source: String) {
        let line = Fixtures.shape(source)
        let map = line.clusterMap
        let utf16Count = source.utf16.count

        // Totality: every UTF-16 index maps to exactly one cluster.
        for i in 0..<utf16Count {
            #expect(map.utf16ToCluster[i] != nil)
        }

        // Every glyph belongs to exactly one cluster.
        for (runIndex, run) in line.runs.enumerated() {
            for glyphIndex in run.glyphs.indices {
                let address = MKGlyphAddress(run: runIndex, glyph: glyphIndex)
                #expect(map.glyphToCluster[address] != nil)
            }
        }

        // Round trip: every codepoint/glyph inside a cluster maps back to
        // that same cluster (no duplication, no drift).
        for (clusterIndex, cluster) in map.clusters.enumerated() {
            for utf16Index in cluster.utf16Range {
                #expect(map.utf16ToCluster[utf16Index] == clusterIndex)
            }
            for address in cluster.glyphs {
                #expect(map.glyphToCluster[address] == clusterIndex)
            }
        }

        // Clusters partition [0, utf16Count) with no gaps and no overlaps.
        let orderedRanges = map.clusters.map(\.utf16Range).sorted { $0.lowerBound < $1.lowerBound }
        var cursor = 0
        for range in orderedRanges {
            #expect(range.lowerBound == cursor)
            cursor = range.upperBound
        }
        #expect(cursor == utf16Count)
    }

    // MARK: - Lam-alif family: required ligature, never two glyphs

    @Test(arguments: ["لا", "لأ", "لإ", "لآ"])
    func lamAlifIsOneLigatureClusterTwoCodepointsOneGlyph(word: String) {
        let line = Fixtures.shape(word)
        #expect(line.clusterMap.clusters.count == 1)
        guard let cluster = line.clusterMap.clusters.first else { return }
        #expect(cluster.codepoints.count == 2)
        #expect(cluster.glyphs.count == 1)
        #expect(cluster.kind == .ligature)
    }

    @Test func lamAlifInsideASentenceStaysOneLigatureCluster() {
        let line = Fixtures.shape(Fixtures.laIlahaIllaAllah)
        let ligatureClusters = line.clusterMap.clusters.filter { $0.kind == .ligature }
        #expect(!ligatureClusters.isEmpty, "«لا إله إلا الله» must contain at least one lam-alif ligature cluster")
        for cluster in ligatureClusters {
            #expect(cluster.codepoints.count >= 2)
            #expect(cluster.glyphs.count == 1)
        }
    }

    // MARK: - "به" two-letter, no-mark fixture

    @Test func baHaFormsTwoClusters() {
        let line = Fixtures.shape("به")
        #expect(line.clusterMap.clusters.count == 2)
        let totalCodepoints = line.clusterMap.clusters.reduce(0) { $0 + $1.codepoints.count }
        #expect(totalCodepoints == 2)
    }

    // MARK: - "الله" ، document per-font expectation, don't hardcode glyph count

    @Test func allahProducesAtLeastOneMultiCodepointCluster() {
        // Packet task 9 accept criterion verbatim: "assert ≥1 multi-codepoint
        // cluster ...; document per-font expectations rather than
        // hardcoding one glyph count." Against system SF Arabic on this
        // host, «الله» shapes to exactly one glyph for all 4 codepoints ،
        // see docs/impl-log/WS-03.md for the captured evidence.
        let line = Fixtures.shape(Fixtures.allah)
        let hasMultiCodepointCluster = line.clusterMap.clusters.contains { $0.codepoints.count > 1 }
        #expect(hasMultiCodepointCluster)
    }

    // MARK: - Durable cluster ids (P3-completion: MKClusterID provenance key)

    @Test func clusterIDsAreUniqueWithinALine() {
        let line = Fixtures.shape(Fixtures.laIlahaIllaAllah)
        let ids = line.clusterMap.clusters.map(\.id)
        #expect(Set(ids).count == ids.count, "every cluster mints a distinct MKClusterID for provenance")
    }

    // MARK: - Kashida: tatweel is a joining base, not a mark, not dropped

    @Test func kashidaChainRetainsAllLetterCodepoints() {
        let line = Fixtures.shape(Fixtures.kashidaChain)
        let allCodepoints = line.clusterMap.clusters.flatMap(\.codepoints)
        #expect(allCodepoints.count == Fixtures.kashidaChain.unicodeScalars.count)
        // U+0640 TATWEEL must appear as its own (non-control, non-mark) codepoint.
        #expect(allCodepoints.contains(0x0640))
    }

    // MARK: - ZWNJ: control cluster, never a mark, never a base

    @Test func zwnjFormsItsOwnControlCluster() {
        let line = Fixtures.shape(Fixtures.zwnjBroken)
        let controlClusters = line.clusterMap.clusters.filter { $0.kind == .control }
        #expect(controlClusters.contains { $0.codepoints == [0x200C] })
    }

    // MARK: - Degenerate input safety (task 11)

    @Test func lonelyMarkNeverCrashesAndYieldsOneCluster() {
        let line = Fixtures.shape(Fixtures.standaloneFathatan)
        #expect(line.clusterMap.clusters.count == 1)
        #expect(line.clusterMap.clusters.first?.kind == .markOnly)
    }

    @Test func emptyStringNeverCrashes() {
        let line = Fixtures.shape("")
        #expect(line.clusterMap.clusters.isEmpty)
        #expect(line.runs.isEmpty)
    }
}
