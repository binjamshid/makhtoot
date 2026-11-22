// Work item 0.2 — category (h): render goldens. Renders each of the 4
// canonical `Tests/Fixtures/*.makhtoot` scenes to a PNG via
// `MKSnapshotRenderer.renderFullCanvas` (the same single render path every
// MKRender pixel consumer uses — canvas layers, thumbnails, export strips),
// at export quality. PNG (not JPEG) so this category is fully deterministic
// (see `DeterminismManifest.swift` for the JPEG exclusion).
//
// Output: `android/fixtures/render/<fixture-name>.png` (whole canvas, 2×)
// plus `android/fixtures/render/<fixture-name>.report.json` (the
// `MKRenderReport` — substitution events, node count — so Batch 4/5's
// render-porting agents get a machine-readable "no substitutions expected"
// baseline alongside the pixels).

import CoreGraphics
import Foundation
import ImageIO
import MKExport
import MKFoundation
import MKModel
import MKRender

// `MKRenderReport.duration` (wall-clock `TimeInterval`) is deliberately
// OMITTED — a timing measurement, not content, and would break the
// byte-identical second-run requirement (same class of hazard as a `Date`,
// Support.swift's header note).
struct RenderReportDTO: Encodable {
    var nodeCount: Int
    var substitutionCount: Int
    var substitutionReasons: [String]
}

func exportRender() throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("render")
    let renderer = MKSnapshotRenderer()
    var count = 0

    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)
        let region = CGRect(origin: .zero, size: scene.canvas.size)
        let (image, report) = renderer.renderWithReport(scene, region: region, scale: 2, quality: .exportQuality)
        guard let image else {
            print("[render] WARNING: \(fixtureName) produced no image (degenerate canvas size \(scene.canvas.size)) — skipped")
            continue
        }
        let pngURL = categoryRoot.appendingPathComponent("\(fixtureName).png")
        RepoPaths.ensure(categoryRoot)
        try MKRasterEncoders.writePNG(image, to: pngURL, dpi: 144)

        let reportDTO = RenderReportDTO(
            nodeCount: report.nodeCount,
            substitutionCount: report.substitutions.count,
            substitutionReasons: report.substitutions.map { String(describing: $0) }.sorted())
        try GoldenJSON.write(reportDTO, to: categoryRoot.appendingPathComponent("\(fixtureName).report.json"))
        count += 2
    }
    print("[render] wrote \(count) files (PNG + report per fixture) across \(fixtureNames.count) fixtures")
}
