import Testing
import MKModel
@testable import MKTextEngine

/// WS-03 packet §5 task 9: ligature detection + kind classification.
@Suite struct LigatureDetectorTests {

    @Test(arguments: ["لا", "لأ", "لإ", "لآ"])
    func lamAlifFamilyDetectsAsRequired(word: String) {
        let line = Fixtures.shape(word)
        let detected = MKLigatureDetector.detect(in: line, activeSetting: .standard)
        #expect(detected.count == 1)
        #expect(detected.first?.kind == .required)
        #expect(detected.first?.constituentScalars.count == 2)
    }

    @Test func lamAlifStaysRequiredRegardlessOfSetting() {
        // Required means required: the kind must not drift with the active
        // feature setting.
        for setting in [MKLigatureSetting.standard, .discretionaryOn, .off] {
            let line = Fixtures.engine.shapeSingleLine(
                MKShapingRequest(string: "لا", style: Fixtures.style(ligatures: setting)))
            let detected = MKLigatureDetector.detect(in: line, activeSetting: setting)
            #expect(detected.first?.kind == .required, "lam-alif must classify required under \(setting)")
            #expect(detected.first?.activeSetting == setting, "active setting must be recorded for provenance")
        }
    }

    @Test func allahFusionDetectsAsContextualNotRequired() {
        // «الله» is alef+lam+lam+heh ، no adjacent lam→alef pair, so the
        // fusion is contextual (font-specific), not the lam-alif required
        // family. Against system SF Arabic it shapes as one glyph for all
        // four codepoints (documented per-font expectation).
        let line = Fixtures.shape(Fixtures.allah)
        let detected = MKLigatureDetector.detect(in: line, activeSetting: .standard)
        #expect(!detected.isEmpty, "«الله» must produce at least one multi-codepoint single-glyph detection")
        #expect(detected.allSatisfy { $0.kind == .contextual })
    }

    @Test func detectionKindFollowsActiveSettingForNonRequiredLigatures() {
        // The discretionary-vs-contextual half of the packet's heuristic ،
        // exercised directly on the classifier (SF Arabic exposes no dlig
        // pair to shape for real; the Amiri glyph-count test joins the
        // WS-09 re-run, docs/impl-log/WS-03.md).
        let nonLamAlif: [UInt32] = [0x0644, 0x0644, 0x0647]   // lam lam heh (no lam→alef adjacency)
        #expect(MKLigatureDetector.classify(nonMarkScalars: nonLamAlif, activeSetting: .discretionaryOn) == .discretionary)
        #expect(MKLigatureDetector.classify(nonMarkScalars: nonLamAlif, activeSetting: .standard) == .contextual)
        #expect(MKLigatureDetector.classify(nonMarkScalars: [0x0644, 0x0627], activeSetting: .discretionaryOn) == .required)
    }

    @Test func plainLettersProduceNoDetections() {
        let line = Fixtures.shape("به")
        #expect(MKLigatureDetector.detect(in: line, activeSetting: .standard).isEmpty)
    }

    @Test func detectionsCarryTheClusterProvenanceKey() {
        let line = Fixtures.shape(Fixtures.laIlahaIllaAllah)
        let detected = MKLigatureDetector.detect(in: line, activeSetting: .standard)
        #expect(!detected.isEmpty)
        for ligature in detected {
            // The detection's clusterID must be the id of the cluster at
            // its ordinal ، the provenance key WS-04 stores.
            #expect(line.clusterMap.clusters[ligature.clusterOrdinal].id == ligature.clusterID)
        }
    }
}
