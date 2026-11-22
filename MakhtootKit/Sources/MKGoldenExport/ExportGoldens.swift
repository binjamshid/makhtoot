// Work item 0.2 — category (i): export format byte-goldens. Exports
// each of the 4 canonical fixture scenes through the REAL production
// pipeline: `MKExportCoordinator` for PNG (opaque + alpha) and JPEG,
// and `SVGSerializer` for SVG. These outputs go to `android/fixtures/export/`.
// `DeterminismManifest.swift` records the JPEG exclusion for `gate.sh`.
//
// The explicit local PDF mode uses `PDFVectorExporter` and writes to the
// ignored SwiftPM build directory. Core Graphics can embed system font
// subsets and color profiles in these PDFs.

import CoreGraphics
import Foundation
import MKExport
import MKFoundation
import MKModel
import MKRender

func exportRasterVectorGoldens() async throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("export")
    RepoPaths.ensure(categoryRoot)
    var count = 0

    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)
        let pixelSize = scene.canvas.size

        // PNG opaque + PNG alpha + JPEG, via the real MKExportCoordinator
        // (entitlement: StubEntitlementResolver — always premium, so no
        // free-tier downscale fallback perturbs the golden pixel size).
        let coordinator = MKExportCoordinator()
        let entitlement = StubEntitlementResolver()

        let pngOpaque = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: pixelSize)),
            scene: scene, entitlement: entitlement, filenameBase: fixtureName, destinationDirectory: categoryRoot)
        _ = pngOpaque
        count += 1

        let pngAlphaURL = try await coordinator.export(
            MKExportRequest(format: .pngAlpha, target: .custom(pixelSize: pixelSize), background: .transparent),
            scene: scene, entitlement: entitlement, filenameBase: "\(fixtureName)-alpha", destinationDirectory: categoryRoot)
        _ = pngAlphaURL
        count += 1

        _ = try await coordinator.export(
            MKExportRequest(format: .jpegDefault, target: .custom(pixelSize: pixelSize)),
            scene: scene, entitlement: entitlement, filenameBase: fixtureName, destinationDirectory: categoryRoot)
        count += 1

        // SVG — direct `SVGSerializer.export`, deterministic string output.
        let svgResult = SVGSerializer.export(scene: scene, pixelSize: pixelSize)
        let svgURL = categoryRoot.appendingPathComponent("\(fixtureName).svg")
        try svgResult.svg.write(to: svgURL, atomically: true, encoding: .utf8)
        count += 1
    }
    print("[export] wrote \(count) files (png/png-alpha/jpg/svg per fixture) across \(fixtureNames.count) fixtures")
}

func exportLocalPDFs() throws {
    let destination = RepoPaths.makhtootKitRoot.appendingPathComponent(".build/mk-golden-export/pdf")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)
        let pdfURL = destination.appendingPathComponent("\(fixtureName).pdf")
        _ = try PDFVectorExporter.export(
            scene: scene, pixelSize: scene.canvas.size, dpi: 72, title: fixtureName,
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: pdfURL)
    }
    print("[export] wrote \(fixtureNames.count) local PDF samples to \(destination.path)")
}
