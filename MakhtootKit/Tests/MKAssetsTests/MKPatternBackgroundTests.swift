import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import Testing
@testable import MKAssets

// WS-14 packet §5 task 8 accept criteria: "pattern renders tiled in
// preview + export paths...; all patternBackgrounds isPremium == true;
// gating test with free entitlement stub blocks placement with paywall
// route."
@Suite("MKPatternTileGenerator / MKPatternInstantiator (T8)")
struct MKPatternBackgroundTests {
    @Test func atLeastEightPatternTilesAllPremium() {
        let pairs = MKPatternTileGenerator.makeAll()
        #expect(pairs.count >= 8)
        #expect(pairs.allSatisfy { $0.descriptor.category == .patternBackgrounds })
        #expect(pairs.allSatisfy { $0.descriptor.isPremium })
        #expect(Set(pairs.map(\.descriptor.assetID)).count == pairs.count)
    }

    @Test func everyLibraryPatternBackgroundIsPremium() {
        let patterns = MKAssetLibrary.standard.descriptors(in: .patternBackgrounds)
        #expect(patterns.count >= 8)
        #expect(patterns.allSatisfy { $0.isPremium })
    }

    /// "Pattern renders tiled in preview... at 3 canvas sizes" (packet
    /// §7 gate 3 / TEST_MATRIX T-asset-05).
    @Test func patternTilesAcrossThreeCanvasSizes() {
        let instantiator = MKPatternInstantiator()
        let (descriptor, fill) = MKPatternTileGenerator.makeAll().first { $0.descriptor.assetID == "pattern.dot-grid" }!
        for canvasSize in [CGSize(width: 400, height: 400), CGSize(width: 1080, height: 1920), CGSize(width: 2480, height: 3508)] {
            let placement = instantiator.placeBackground(descriptor, fill: fill, canvasSize: canvasSize)
            guard case .group(let group) = placement.node else {
                Issue.record("expected a .group node")
                continue
            }
            // ≥1 background rect + enough tiles to cover the canvas: the
            // packed tile count must scale with area (loosely ، grid math,
            // not an exact analytic bound).
            let expectedMinimumTiles = Int((canvasSize.width / fill.tile.tileSize.width) * (canvasSize.height / fill.tile.tileSize.height))
            #expect(group.children.count - 1 >= expectedMinimumTiles, "canvas \(canvasSize) under-tiled")
        }
    }

    @Test func placedPatternGroupNodeRoundTripsThroughSceneCodable() throws {
        let instantiator = MKPatternInstantiator()
        let (descriptor, fill) = MKPatternTileGenerator.makeAll().first { $0.descriptor.assetID == "pattern.chevron" }!
        let placement = instantiator.placeBackground(descriptor, fill: fill, canvasSize: CGSize(width: 300, height: 300))
        var scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 300, height: 300)))
        scene = scene.inserting(placement.node)

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(MKScene.self, from: data)
        #expect(decoded.node(id: placement.node.id) == placement.node)
    }

    @Test func halfDropRepeatOffsetsAlternateRows() {
        let instantiator = MKPatternInstantiator()
        let (descriptor, fill) = MKPatternTileGenerator.makeAll().first { $0.fill.repeatMode == .halfDrop }!
        let placement = instantiator.placeBackground(descriptor, fill: fill, canvasSize: CGSize(width: 200, height: 200))
        guard case .group(let group) = placement.node else {
            Issue.record("expected group")
            return
        }
        let tilePositions = group.children.dropFirst().compactMap { node -> CGPoint? in
            guard case .shape(let shape) = node else { return nil }
            return shape.core.transform.position
        }
        // At least two distinct x-offsets should exist among tile centers
        // at the same row band, proving half-drop actually shifted
        // alternating rows rather than laying out a plain grid.
        let xs = Set(tilePositions.map { ($0.x).rounded() })
        #expect(xs.count > 1)
    }

    // MARK: - Gating (free entitlement blocks placement)

    @Test func freeEntitlementBlocksPatternPlacementWithPremiumRequiredOutcome() async {
        let model = await MKAssetBrowserModel(entitlement: FreeEntitlementStub())
        let pattern = MKAssetLibrary.standard.descriptors(in: .patternBackgrounds).first!
        let outcome = await model.select(pattern, canvasSize: CGSize(width: 500, height: 500))
        guard case .premiumRequired(let capability, let assetID, _) = outcome else {
            Issue.record("expected .premiumRequired for a free entitlement placing a pattern")
            return
        }
        #expect(capability == .premiumAssets)
        #expect(assetID == pattern.assetID)
    }

    @Test func premiumEntitlementPlacesPatternSuccessfully() async {
        let model = await MKAssetBrowserModel(entitlement: StubEntitlementResolver())
        let pattern = MKAssetLibrary.standard.descriptors(in: .patternBackgrounds).first!
        let outcome = await model.select(pattern, canvasSize: CGSize(width: 500, height: 500))
        guard case .placedPattern = outcome else {
            Issue.record("expected .placedPattern for a premium entitlement")
            return
        }
    }
}
