import CoreGraphics
import MKFoundation
import MKModel
@testable import MKPathText
import MKTextEngine
import Testing

// `docs/impl-log/WS-05.md` §3/§4 item 6: two of the packet's §6 Arabic-
// correctness fixtures (`Fixtures.shaddaStack`, `Fixtures.numeralsArabic`/
// `numeralsLatin`) are defined in `Fixtures.swift` but had no
// `PathLayoutEngineTests` test asserting them BY NAME ، only possibly
// covered incidentally by other tests. This file closes that gap. Split
// into its own file rather than folded into the already-dense 17-test
// `PathLayoutEngineTests.swift` so each fixture's dedicated coverage stays
// easy to find; same suite family (task 4d marks-ride-base, T-PTH-2
// logical-order pen walk), same helpers/assertion idioms as that file.
@Suite("PathLayoutEngine ، §6 fixture coverage: shaddaStack, numeralsArabic/numeralsLatin")
struct PathLayoutEngineFixtureCoverageTests {
    // MARK: - §6 "stacked marks on a wave" fixture

    @Test("Shadda stack «شَدَّةٌ» on a wave: marks ride their base's arc position, offset off it, no NaN")
    func shaddaStackOnWaveMarksStackWithoutNaN() {
        let line = Fixtures.shape(Fixtures.shaddaStack)
        let path = BezierPathModel.wave(rect: CGRect(x: 0, y: 0, width: 800, height: 200), periods: 3, amplitude: 60)
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())

        #expect(!result.placements.isEmpty)
        for placement in result.placements {
            #expect(placement.position.x.isFinite && placement.position.y.isFinite)
            #expect(placement.rotation.isFinite)
        }

        // Every mark's arc length coincides with its base's arc length ،
        // it rides the base's frame rather than being independently
        // placed on the path (same invariant `circleFixtureMonotonicNoNaN`
        // already checks for `Fixtures.bismillah`).
        let baseByCluster = Dictionary(uniqueKeysWithValues: result.placements.filter { !$0.isMark }.map { ($0.clusterID, $0) })
        let marks = result.placements.filter { $0.isMark && $0.baseClusterID != nil }
        // شَدَّةٌ (ش+fatha, د+shadda+fatha, ة+tanwin) must survive shaping
        // with at least one mark surfaced as its own `markOnly` placement
        // per base (probed directly: each of the 3 consonants gets
        // exactly one separate mark placement ، the OTHER diacritic on
        // shares a base fuses into a `.baseWithMarks` cluster with no
        // separate placement of its own, per `MarkAttachment.swift`'s
        // fused-vs-markOnly split; that fused case is exercised
        // implicitly here too since it produces no stray NaN/placement).
        #expect(marks.count == 3)
        for mark in marks {
            let base = baseByCluster[mark.baseClusterID!]
            #expect(base != nil)
            guard let base else { continue }
            #expect(abs(mark.arcLength - base.arcLength) < 1e-6)
            // `MKMarkAttacher` (`MarkAttachment.swift`) preserves each
            // mark's OWN pre-shaped relative offset from Core Text's GPOS
            // mark/mkmk stacking, applied on top of the base's
            // path-projected position ، a stacked mark's final position
            // is NOT collapsed onto its base's position, it visibly
            // displaces off it. This is the guarantee `shaddaStack`'s §6
            // "stacked marks" purpose actually targets.
            let dx = mark.position.x - base.position.x
            let dy = mark.position.y - base.position.y
            #expect(hypot(dx, dy) > 1.0)
        }

        // The three marks (fatha on ش, shadda on د, tanwin on ة) carry
        // distinct, individually-derived offsets rather than one
        // hardcoded nudge applied to every mark ، confirms the stacking
        // offset really comes from each mark's own shaped position (task
        // 4d), not a constant.
        let offsets = marks.compactMap { mark -> CGPoint? in
            guard let base = baseByCluster[mark.baseClusterID!] else { return nil }
            return CGPoint(x: mark.position.x - base.position.x, y: mark.position.y - base.position.y)
        }
        if let first = offsets.first {
            let anyDiffers = offsets.dropFirst().contains { hypot($0.x - first.x, $0.y - first.y) > 0.5 }
            #expect(anyDiffers)
        }
    }

    // MARK: - §6 "numerals stay sequential" fixture

    @Test("Numerals stay sequential «١٢٣٤٥» / «12345»: arc-length order matches logical left-to-right digit order")
    func numeralsStaySequentialAlongPath() {
        for fixture in [Fixtures.numeralsArabic, Fixtures.numeralsLatin] {
            let line = Fixtures.shape(fixture) // default direction: .rightToLeft ، the point of this fixture
            let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 2000, y: 0))
            let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
            let bases = result.placements.filter { !$0.isMark }
            #expect(bases.count == 5) // one simple cluster per digit, no marks

            // Numerals read left-to-right even inside an RTL paragraph ،
            // "numerals stay sequential" means arc-length position along
            // the path strictly increases in LOGICAL typed order
            // (1,2,3,4,5 / ١,٢,٣,٤,٥), the same arc-offset-monotonicity
            // technique `multiSwitchFixtureArcOffsetsMonotonic` and
            // `mixedBidiContiguous` already use for their own fixtures.
            for i in 1..<bases.count {
                #expect(bases[i].arcLength > bases[i - 1].arcLength)
            }

            // The placement array itself (T-PTH-2's logical-reading-order
            // pen walk) must visit the digits in their TYPED order, not
            // reversed by RTL bidi handling of the surrounding base
            // direction ، compare directly against the source string's
            // own codepoint order rather than a hardcoded literal.
            let clustersByID = Dictionary(uniqueKeysWithValues: line.clusterMap.clusters.map { ($0.id, $0) })
            let orderedCodepoints = bases.compactMap { clustersByID[$0.clusterID]?.codepoints.first }
            let expectedCodepoints = fixture.unicodeScalars.map { $0.value }
            #expect(orderedCodepoints == expectedCodepoints)
        }
    }
}
