import Foundation
import MKFoundation
import MKModel

/// Classification of a detected ligature (WS-03 packet §5 task 9).
public enum MKLigatureKind: Hashable, Sendable {
    /// The lam-alif family (lam + any alef variant) ، `rlig`, non-negotiable
    /// in Arabic, present regardless of feature settings.
    case required
    /// Present only because discretionary ligatures were enabled
    /// (`MKLigatureSetting.discretionaryOn`).
    case discretionary
    /// Any other multi-codepoint fusion the font produced under default
    /// features (`liga`/`calt` contextual behavior).
    case contextual
}

/// One detected ligature: a cluster the font realized as a single glyph
/// from multiple non-mark codepoints (D-105's "ligature candidate",
/// promoted to a detection record with kind + provenance so WS-04 can
/// build `MKLigatureGroup`s with the feature-state provenance D-108
/// requires).
public struct MKDetectedLigature: Hashable, Sendable {
    /// Ordinal into the owning line's `clusterMap.clusters`.
    public var clusterOrdinal: Int
    /// The cluster's durable id (→ `MKProvenance.clusterID`).
    public var clusterID: MKClusterID
    /// The single glyph realizing the ligature.
    public var glyph: MKGlyphAddress
    /// All constituent scalars, logical order (marks included if the
    /// cluster carried any ، `MKLigatureGroup.provenance.codepoints` wants
    /// the full constituent list per D-106).
    public var constituentScalars: [UInt32]
    public var kind: MKLigatureKind
    /// The ligature setting active when this shape was captured ، WS-04
    /// records this as provenance (packet task 9: "store the active
    /// feature settings so WS-04 records provenance").
    public var activeSetting: MKLigatureSetting

    public init(
        clusterOrdinal: Int,
        clusterID: MKClusterID,
        glyph: MKGlyphAddress,
        constituentScalars: [UInt32],
        kind: MKLigatureKind,
        activeSetting: MKLigatureSetting
    ) {
        self.clusterOrdinal = clusterOrdinal
        self.clusterID = clusterID
        self.glyph = glyph
        self.constituentScalars = constituentScalars
        self.kind = kind
        self.activeSetting = activeSetting
    }
}

/// WS-03 packet §5 task 9: promotes `.ligature`-kind clusters (and
/// base-with-marks clusters that fused into one glyph) to detection
/// records with a required/discretionary/contextual classification.
///
/// Kind heuristic (packet task 9 verbatim): lam+alef pairs = required;
/// others = discretionary-if-dlig-else-contextual.
public enum MKLigatureDetector {
    /// Lam is U+0644; the alef family it forms required ligatures with:
    /// alef (0627), alef madda (0622), alef hamza above (0623), alef hamza
    /// below (0625), alef wasla (0671).
    static let lam: UInt32 = 0x0644
    static let alefFamily: Set<UInt32> = [0x0627, 0x0622, 0x0623, 0x0625, 0x0671]

    public static func detect(in line: MKShapedLine, activeSetting: MKLigatureSetting) -> [MKDetectedLigature] {
        var results: [MKDetectedLigature] = []
        for (ordinal, cluster) in line.clusterMap.clusters.enumerated() {
            // A ligature detection requires: exactly one glyph realizing
            // >1 non-mark codepoints. `.ligature` is the direct case;
            // `.baseWithMarks` with 1 glyph and >1 non-mark codepoint is
            // the fused base+base+marks case (e.g. «الله» in fonts that
            // shape it as one glyph including its marks).
            let nonMarkScalars = cluster.codepoints.compactMap(Unicode.Scalar.init).filter { !MKMarkClassifier.isMark($0) }
            let isSingleGlyphFusion = cluster.glyphs.count == 1 && nonMarkScalars.count > 1
            let isLigatureKind: Bool
            switch cluster.kind {
            case .ligature: isLigatureKind = true
            case .baseWithMarks: isLigatureKind = isSingleGlyphFusion
            default: isLigatureKind = false
            }
            guard isLigatureKind, let glyph = cluster.glyphs.first else { continue }

            results.append(MKDetectedLigature(
                clusterOrdinal: ordinal,
                clusterID: cluster.id,
                glyph: glyph,
                constituentScalars: cluster.codepoints,
                kind: classify(nonMarkScalars: nonMarkScalars.map(\.value), activeSetting: activeSetting),
                activeSetting: activeSetting))
        }
        return results
    }

    /// Packet task 9's heuristic. Any adjacent lam→alef-family pair in the
    /// constituent sequence marks the whole fusion required (covers both
    /// plain lam-alif and larger fusions built on one, e.g. «الله»).
    static func classify(nonMarkScalars: [UInt32], activeSetting: MKLigatureSetting) -> MKLigatureKind {
        for i in 0..<max(0, nonMarkScalars.count - 1) {
            if nonMarkScalars[i] == lam && alefFamily.contains(nonMarkScalars[i + 1]) {
                return .required
            }
        }
        return activeSetting == .discretionaryOn ? .discretionary : .contextual
    }
}
