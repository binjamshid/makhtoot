import Testing
@testable import MKTextEngine

/// WS-03 packet §5 task 15, full scale: 10 000 random mixes of Arabic
/// letters, tashkeel, digits (both systems), Latin, punctuation, and
/// ZWJ/ZWNJ, checking every invariant the packet names:
/// - every scalar in exactly one cluster (totality);
/// - every glyph in exactly one cluster;
/// - marks always have a base or the documented fallback (free mark,
///   `baseClusterIndex == nil` ، never a crash, never silently dropped);
/// - visual indices are a permutation of `0..<glyphCount`;
/// - no crash on empty/whitespace/mark-only input.
///
/// Seeded (`SplitMix64`) so any failure reproduces exactly.
@Suite struct ClusterMapFuzzTests {
    private static let alphabet: [Character] = Array(
        "ابتثجحخدذرزسشصضطظعغفقكلمنهويءآأإؤئىة" +   // Arabic letters
        "\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}\u{0670}" +  // core tashkeel + superscript alef
        "٠١٢٣٤٥٦٧٨٩0123456789" +                     // both digit systems
        "abcXYZ .,!؟" +                                // Latin + punctuation
        "\u{200C}\u{200D}"                             // ZWNJ/ZWJ
    )

    @Test func tenThousandRandomMixesUpholdAllInvariants() {
        var generator = SplitMix64(seed: 0xC0FFEE)
        for iteration in 0..<10_000 {
            let length = Int.random(in: 0...24, using: &generator)
            let text = String((0..<length).map { _ in Self.alphabet.randomElement(using: &generator)! })
            let line = Fixtures.shape(text)

            // Invariant 1: cluster-map totality over every UTF-16 index.
            let utf16Count = text.utf16.count
            for i in 0..<utf16Count {
                #expect(line.clusterMap.utf16ToCluster[i] != nil, "iteration \(iteration): gap at index \(i) in \"\(text)\"")
            }

            // Invariant 2: every glyph belongs to exactly one cluster.
            var glyphCount = 0
            for (runIndex, run) in line.runs.enumerated() {
                for glyphIndex in run.glyphs.indices {
                    let address = MKGlyphAddress(run: runIndex, glyph: glyphIndex)
                    #expect(line.clusterMap.glyphToCluster[address] != nil, "iteration \(iteration): unmapped glyph in \"\(text)\"")
                    glyphCount += 1
                }
            }

            // Invariant 3: marks have a base or are documented free marks;
            // the attacher never crashes and never drops a markOnly cluster.
            let attachments = MKMarkAttacher.attachments(in: line)
            let markOnlyClusters = line.clusterMap.clusters.enumerated().filter { $0.element.kind == .markOnly }
            for (ordinal, _) in markOnlyClusters {
                #expect(attachments.contains { $0.markClusterIndex == ordinal }, "iteration \(iteration): markOnly cluster \(ordinal) unreported in \"\(text)\"")
            }

            // Invariant 4: glyph visual indices are a permutation.
            let visualIndices = line.bidiMap.glyphVisualIndex.values.sorted()
            #expect(visualIndices == Array(0..<glyphCount), "iteration \(iteration): visual indices not a permutation in \"\(text)\"")
        }
    }

    @Test func whitespaceOnlyAndMarkOnlyInputsNeverCrash() {
        for text in [" ", "   ", "\u{064B}", "\u{064B}\u{064B}\u{064B}", "\u{200D}", "\u{200C}\u{200D}"] {
            let line = Fixtures.shape(text)
            #expect(line.clusterMap.clusters.reduce(0) { $0 + $1.codepoints.count } == text.unicodeScalars.count)
            _ = MKMarkAttacher.attachments(in: line)
        }
    }
}

/// Minimal deterministic PRNG (SplitMix64) so fuzz failures are
/// reproducible across runs without pulling in a dependency (D-101: zero
/// third-party deps).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
